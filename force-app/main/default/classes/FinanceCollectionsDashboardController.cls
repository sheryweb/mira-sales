/**
 * FinanceCollectionsDashboardController — data + actions for the Finance Center's
 * "Collections & Aging" dashboard (financeCollectionsDashboard LWC).
 *
 * WITHOUT SHARING, deliberately: org-wide collections view gated by the Finance_Center_Access
 * permission set while the finance objects have restricted OWDs (same justification as the
 * other dashboard controllers).
 *
 * CURRENCY: aging by project, the customer matrix, and the trend lines all COMPARE OR COMBINE
 * across projects, so they are AED converted at read time (trend rows are converted at
 * today's rates — historical rates are not stored, and the UI says so). The actionable
 * overdue/defaulted lists are per unit, so they carry the project-currency amount plus its
 * currency code.
 *
 * Aging buckets come from Aging_Bucket__mdt (Sort_Order__c ascending) — never hardcoded.
 *
 * ACTIONS: createFollowUpTask and setCollectionFlag write a Task / the Unit's manual
 * collection flag; neither touches money, so neither is engine-gated. The Email SOA action is
 * the existing SOAEmailService.sendSOAEmail, which the LWC calls directly (engine-gated there).
 */
public without sharing class FinanceCollectionsDashboardController {

    private static final Set<String> SALES_STATUSES = new Set<String>{ 'Booked', 'Reserved', 'Sold' };
    private static final Set<String> BRS_STAGES = new Set<String>{ 'Booked', 'Reserved', 'Sold' };
    private static final Decimal TOLERANCE = 0.005;
    private static final Integer CUSTOMER_MATRIX_LIMIT = 25;
    private static final Integer OVERDUE_LIST_LIMIT = 25;
    private static final Integer TREND_DAYS = 120;
    private static final Set<String> VALID_FLAGS = new Set<String>{ 'Legal Notice', 'Termination Notice' };

    // ---------------------------------------------------------------- DTOs ----

    public class DashboardData {
        @AuraEnabled public Datetime ratesAsOf;
        @AuraEnabled public List<String> bucketLabels = new List<String>();
        @AuraEnabled public Decimal totalOverdueAed = 0;   // past-due buckets only
        @AuraEnabled public Decimal totalOpenAed = 0;      // all open invoice pending
        @AuraEnabled public Integer overdueCustomers = 0;
        @AuraEnabled public Integer defaultedUnits = 0;
        @AuraEnabled public Integer flaggedUnits = 0;
        @AuraEnabled public List<ProjectAging> projectAging = new List<ProjectAging>();
        @AuraEnabled public List<CustomerRow> customers = new List<CustomerRow>();
        @AuraEnabled public Integer customersNotShown = 0;
        @AuraEnabled public List<ActionRow> overdueRows = new List<ActionRow>();
        @AuraEnabled public List<ActionRow> defaultedRows = new List<ActionRow>();
        @AuraEnabled public List<TrendPoint> trend = new List<TrendPoint>();
    }

    public class ProjectAging {
        @AuraEnabled public String projectId;
        @AuraEnabled public String name;
        @AuraEnabled public List<Decimal> bucketsAed = new List<Decimal>();
        @AuraEnabled public Decimal totalAed = 0;
    }

    public class CustomerRow implements Comparable {
        @AuraEnabled public String accountId;
        @AuraEnabled public String name;
        @AuraEnabled public List<Decimal> bucketsAed = new List<Decimal>();
        @AuraEnabled public Decimal totalAed = 0;
        @AuraEnabled public Decimal overdueAed = 0; // past-due buckets only
        @AuraEnabled public Integer oldestDays = 0;
        public Integer compareTo(Object other) {
            CustomerRow o = (CustomerRow) other;
            if (overdueAed == o.overdueAed) return name.compareTo(o.name);
            return overdueAed > o.overdueAed ? -1 : 1;
        }
    }

    /** One actionable unit row (overdue or defaulted list). Amounts in project currency. */
    public class ActionRow implements Comparable {
        @AuraEnabled public String unitId;
        @AuraEnabled public String unitName;
        @AuraEnabled public String projectName;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String opportunityId;
        @AuraEnabled public Decimal due = 0;
        @AuraEnabled public Decimal dueAed = 0;
        @AuraEnabled public Integer overdueDays = 0;
        @AuraEnabled public Integer missedInstalments = 0;
        @AuraEnabled public String health;
        @AuraEnabled public String flag;
        @AuraEnabled public Date flagDate;
        public Integer compareTo(Object other) {
            ActionRow o = (ActionRow) other;
            if (dueAed == o.dueAed) return unitName.compareTo(o.unitName);
            return dueAed > o.dueAed ? -1 : 1;
        }
    }

    /** One snapshot day, portfolio-level, converted to AED at today's rates. */
    public class TrendPoint {
        @AuraEnabled public Date snapshotDate;
        @AuraEnabled public Decimal dueAed = 0;
        @AuraEnabled public List<Decimal> agingAed = new List<Decimal>{ 0, 0, 0, 0, 0, 0 };
        @AuraEnabled public Decimal receivedAed = 0;
        @AuraEnabled public Decimal invoicedAed = 0;
        @AuraEnabled public Decimal arAed = 0;          // Σ aging buckets (open invoice pending)
        @AuraEnabled public Decimal efficiencyPct = 0;  // received / (received + due)
        @AuraEnabled public Decimal dso = 0;            // 365 * AR / invoiced-to-date
    }

    // ------------------------------------------------------------- reads ----

    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        try {
            DashboardData data = new DashboardData();
            data.ratesAsOf = CurrencyService.lastRefreshed();
            List<Aging_Bucket__mdt> buckets = bucketDefs();
            for (Aging_Bucket__mdt b : buckets) data.bucketLabels.add(b.Label);

            // ---- sellable units: currency map + actionable rows + counters ----
            Map<Id, String> ccyByProject = new Map<Id, String>();
            Map<Id, ActionRow> rowByUnit = new Map<Id, ActionRow>();
            Set<Id> unitIds = new Set<Id>();
            for (Unit__c u : [
                SELECT Id, Name, Title__c, Project__c, Project__r.Name,
                       Project__r.Project_Currency__c, Due_Amount__c, Overdue_Days_Max__c,
                       Missed_Instalments__c, Collection_Health__c,
                       Collection_Flag__c, Collection_Flag_Date__c
                FROM Unit__c
                WHERE Project__c != null AND Status__c IN :SALES_STATUSES
            ]) {
                unitIds.add(u.Id);
                String ccy = String.isBlank(u.Project__r.Project_Currency__c)
                    ? CurrencyService.CORPORATE_ISO : u.Project__r.Project_Currency__c;
                ccyByProject.put(u.Project__c, ccy);
                if (u.Collection_Flag__c != null) data.flaggedUnits++;
                if (u.Collection_Health__c == FinanceCollectionStateService.HEALTH_DEFAULTED) {
                    data.defaultedUnits++;
                }
                if (nz(u.Due_Amount__c) <= TOLERANCE
                    && u.Collection_Health__c != FinanceCollectionStateService.HEALTH_DEFAULTED) {
                    continue;
                }
                ActionRow row = new ActionRow();
                row.unitId = u.Id;
                row.unitName = String.isBlank(u.Title__c) ? u.Name : u.Title__c;
                row.projectName = u.Project__r.Name;
                row.currencyCode = ccy;
                row.due = nz(u.Due_Amount__c);
                row.dueAed = toAed(row.due, ccy);
                row.overdueDays = u.Overdue_Days_Max__c == null ? 0 : u.Overdue_Days_Max__c.intValue();
                row.missedInstalments = u.Missed_Instalments__c == null ? 0 : u.Missed_Instalments__c.intValue();
                row.health = u.Collection_Health__c;
                row.flag = u.Collection_Flag__c;
                row.flagDate = u.Collection_Flag_Date__c;
                rowByUnit.put(u.Id, row);
            }

            // Account + opportunity context for the action rows. Two priorities: a deal in a
            // sellable stage wins, but ANY deal is better than none — the org's Opportunity
            // automation resets new deals to stage 'New', so a stage-only filter would leave
            // fresh bookings without customer context. ASC + overwrite -> newest wins per tier.
            if (!rowByUnit.isEmpty()) {
                Set<Id> unitsWithSellableDeal = new Set<Id>();
                for (Opportunity opp : [
                    SELECT Id, AccountId, Account.Name, StageName, Unit__c
                    FROM Opportunity
                    WHERE Unit__c IN :rowByUnit.keySet()
                    ORDER BY CreatedDate ASC
                ]) {
                    ActionRow row = rowByUnit.get(opp.Unit__c);
                    Boolean sellable = BRS_STAGES.contains(opp.StageName);
                    if (!sellable && unitsWithSellableDeal.contains(opp.Unit__c)) continue;
                    if (sellable) unitsWithSellableDeal.add(opp.Unit__c);
                    row.opportunityId = opp.Id;
                    row.accountId = opp.AccountId;
                    row.accountName = opp.Account != null ? opp.Account.Name : null;
                }
            }
            List<ActionRow> allRows = rowByUnit.values();
            allRows.sort();
            for (ActionRow row : allRows) {
                if (row.health == FinanceCollectionStateService.HEALTH_DEFAULTED) {
                    data.defaultedRows.add(row);
                } else if (row.due > TOLERANCE && data.overdueRows.size() < OVERDUE_LIST_LIMIT) {
                    data.overdueRows.add(row);
                }
            }

            // ---- open invoices: aging by project + customer matrix (AED) ----
            Map<Id, ProjectAging> agingByProject = new Map<Id, ProjectAging>();
            Map<Id, CustomerRow> customerById = new Map<Id, CustomerRow>();
            if (!unitIds.isEmpty()) {
                Date today = Date.today();
                for (Invoice__c inv : [
                    SELECT Unit__r.Project__c, Unit__r.Project__r.Name, Account__c, Account__r.Name,
                           Sub_Total_Amount__c, VAT_Amount__c, Paid_Amount__c, Due_Date__c
                    FROM Invoice__c
                    WHERE Unit__c IN :unitIds AND Status__c != 'Cancelled'
                ]) {
                    Decimal pending = nz(inv.Sub_Total_Amount__c) + nz(inv.VAT_Amount__c) - nz(inv.Paid_Amount__c);
                    if (pending <= TOLERANCE) continue;
                    Integer daysOver = (inv.Due_Date__c != null && inv.Due_Date__c < today)
                        ? inv.Due_Date__c.daysBetween(today) : 0;
                    Integer idx = bucketIndexFor(daysOver, buckets);
                    Decimal pendingAed = toAed(pending, ccyByProject.get(inv.Unit__r.Project__c));

                    ProjectAging pa = agingByProject.get(inv.Unit__r.Project__c);
                    if (pa == null) {
                        pa = new ProjectAging();
                        pa.projectId = inv.Unit__r.Project__c;
                        pa.name = inv.Unit__r.Project__r.Name;
                        for (Integer i = 0; i < buckets.size(); i++) pa.bucketsAed.add(0);
                        agingByProject.put(inv.Unit__r.Project__c, pa);
                    }
                    pa.bucketsAed[idx] += pendingAed;
                    pa.totalAed += pendingAed;

                    data.totalOpenAed += pendingAed;
                    if (daysOver > 0) data.totalOverdueAed += pendingAed;

                    if (inv.Account__c != null) {
                        CustomerRow cust = customerById.get(inv.Account__c);
                        if (cust == null) {
                            cust = new CustomerRow();
                            cust.accountId = inv.Account__c;
                            cust.name = inv.Account__r.Name;
                            for (Integer i = 0; i < buckets.size(); i++) cust.bucketsAed.add(0);
                            customerById.put(inv.Account__c, cust);
                        }
                        cust.bucketsAed[idx] += pendingAed;
                        cust.totalAed += pendingAed;
                        if (daysOver > 0) {
                            cust.overdueAed += pendingAed;
                            if (daysOver > cust.oldestDays) cust.oldestDays = daysOver;
                        }
                    }
                }
            }
            data.projectAging = agingByProject.values();
            List<CustomerRow> allCustomers = customerById.values();
            allCustomers.sort();
            for (CustomerRow cust : allCustomers) {
                if (cust.overdueAed > TOLERANCE) data.overdueCustomers++;
                if (data.customers.size() < CUSTOMER_MATRIX_LIMIT) data.customers.add(cust);
                else data.customersNotShown++;
            }

            // ---- trends from the daily snapshots (converted at TODAY's rates) ----
            Map<Date, TrendPoint> byDate = new Map<Date, TrendPoint>();
            for (Finance_Daily_Snapshot__c snap : [
                SELECT Snapshot_Date__c, Project__r.Project_Currency__c,
                       Due_Amount__c, Received_To_Date__c, Invoiced_To_Date__c,
                       Aging_Current__c, Aging_1_30__c, Aging_31_60__c,
                       Aging_61_90__c, Aging_91_180__c, Aging_180_Plus__c
                FROM Finance_Daily_Snapshot__c
                WHERE Snapshot_Date__c >= :Date.today().addDays(-TREND_DAYS)
                ORDER BY Snapshot_Date__c ASC
            ]) {
                TrendPoint pt = byDate.get(snap.Snapshot_Date__c);
                if (pt == null) {
                    pt = new TrendPoint();
                    pt.snapshotDate = snap.Snapshot_Date__c;
                    byDate.put(snap.Snapshot_Date__c, pt);
                }
                String ccy = snap.Project__r == null ? null : snap.Project__r.Project_Currency__c;
                pt.dueAed += toAed(nz(snap.Due_Amount__c), ccy);
                pt.receivedAed += toAed(nz(snap.Received_To_Date__c), ccy);
                pt.invoicedAed += toAed(nz(snap.Invoiced_To_Date__c), ccy);
                List<Decimal> aging = new List<Decimal>{
                    nz(snap.Aging_Current__c), nz(snap.Aging_1_30__c), nz(snap.Aging_31_60__c),
                    nz(snap.Aging_61_90__c), nz(snap.Aging_91_180__c), nz(snap.Aging_180_Plus__c)
                };
                for (Integer i = 0; i < 6; i++) {
                    Decimal converted = toAed(aging[i], ccy);
                    pt.agingAed[i] += converted;
                    pt.arAed += converted;
                }
            }
            for (TrendPoint pt : byDate.values()) {
                pt.efficiencyPct = pct(pt.receivedAed, pt.receivedAed + pt.dueAed);
                pt.dso = pt.invoicedAed > 0 ? (365 * pt.arAed / pt.invoicedAed).setScale(1) : 0;
                data.trend.add(pt);
            }
            return data;
        } catch (Exception e) {
            throw auraError(e, 'Collections dashboard failed: ');
        }
    }

    // ------------------------------------------------------------ actions ----

    /** Log a collections follow-up Task against the customer account. */
    @AuraEnabled
    public static Id createFollowUpTask(String accountId, String unitName, String note) {
        try {
            Task followUp = new Task(
                Subject = ('Collections follow-up: ' + (String.isBlank(unitName) ? 'unit' : unitName)).abbreviate(255),
                Description = note,
                WhatId = String.isBlank(accountId) ? null : Id.valueOf(accountId),
                ActivityDate = Date.today().addDays(3),
                Status = 'Not Started'
            );
            insert followUp;
            return followUp.Id;
        } catch (Exception e) {
            throw auraError(e, 'Could not create the follow-up task: ');
        }
    }

    /** Set or clear the unit's manual collection flag ('' or null clears). */
    @AuraEnabled
    public static void setCollectionFlag(String unitId, String flag) {
        try {
            Boolean clearing = String.isBlank(flag);
            if (!clearing && !VALID_FLAGS.contains(flag)) {
                throw new IllegalArgumentException('Unknown collection flag: ' + flag);
            }
            update new Unit__c(
                Id = Id.valueOf(unitId),
                Collection_Flag__c = clearing ? null : flag,
                Collection_Flag_Date__c = clearing ? null : Date.today()
            );
        } catch (Exception e) {
            throw auraError(e, 'Could not update the collection flag: ');
        }
    }

    // ----------------------------------------------------------- helpers ----

    /** CMDT SOQL does not reliably honor ORDER BY on custom fields (rows can come back in
     *  DeveloperName order), so the sort happens in Apex. */
    private static List<Aging_Bucket__mdt> bucketDefs() {
        List<Aging_Bucket__mdt> sorted = new List<Aging_Bucket__mdt>();
        for (Aging_Bucket__mdt row : [
            SELECT Label, Min_Days_Overdue__c, Max_Days_Overdue__c, Sort_Order__c
            FROM Aging_Bucket__mdt
        ]) {
            Integer i = 0;
            while (i < sorted.size() && sorted[i].Sort_Order__c <= row.Sort_Order__c) i++;
            if (i == sorted.size()) sorted.add(row); else sorted.add(i, row);
        }
        return sorted;
    }

    @TestVisible
    static Integer bucketIndexFor(Integer daysOverdue, List<Aging_Bucket__mdt> buckets) {
        for (Integer i = 0; i < buckets.size(); i++) {
            if (daysOverdue >= buckets[i].Min_Days_Overdue__c
                && (buckets[i].Max_Days_Overdue__c == null
                    || daysOverdue <= buckets[i].Max_Days_Overdue__c)) {
                return i;
            }
        }
        return buckets.size() - 1;
    }

    private static Decimal toAed(Decimal amount, String iso) {
        return CurrencyService.convertToAed(amount, iso);
    }

    private static Decimal pct(Decimal part, Decimal whole) {
        if (whole == null || whole <= 0) return 0;
        return (100 * part / whole).setScale(1);
    }

    private static Decimal nz(Decimal d) { return d == null ? 0 : d; }

    private static AuraHandledException auraError(Exception e, String prefix) {
        AuraHandledException aura = new AuraHandledException(prefix + e.getMessage());
        aura.setMessage(prefix + e.getMessage());
        return aura;
    }
}
