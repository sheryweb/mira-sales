/**
 * FinancePortfolioDashboardController — data provider for the Finance Center's
 * "Portfolio Position" dashboard (financePortfolioDashboard LWC).
 *
 * WITHOUT SHARING, deliberately: the dashboard is an org-wide portfolio view gated by the
 * Finance_Center_Access permission set, while the underlying finance objects have restricted
 * OWDs. Only aggregates, unit titles and money figures leave this class (same justification
 * as the Performance Center controllers).
 *
 * CURRENCY: per-project rows, unit rows, and the heatmap stay in the PROJECT'S OWN currency
 * (finance receives in project currency; Unit_Cost_Number__c is the price source). Only the
 * portfolio-level KPI tiles and cross-project charts convert to AED at read time via
 * CurrencyService — mixed currencies are never summed raw.
 *
 * Data sources are all stored/live: the FinanceCollectionStateService-stamped Unit fields
 * (due split, health — event-driven within seconds of any transaction), DLRS
 * Total_Received_Amount__c, live Invoice__c pending amounts, and the engine's
 * Milestone_Receipt__c allocation ledger (Avg Days to Collect = amount-weighted lag between
 * the instalment date and the receipt's payment date, floored at 0 for early payers).
 */
public without sharing class FinancePortfolioDashboardController {

    private static final Set<String> SALES_STATUSES = new Set<String>{ 'Booked', 'Reserved', 'Sold' };
    private static final Decimal TOLERANCE = 0.005;

    // ---------------------------------------------------------------- DTOs ----

    public class DashboardData {
        @AuraEnabled public Datetime ratesAsOf;
        // portfolio tiles — AED, converted at read time
        @AuraEnabled public Decimal contractedAed = 0;
        @AuraEnabled public Decimal invoicedAed = 0;
        @AuraEnabled public Decimal receivedAed = 0;
        @AuraEnabled public Decimal dueAed = 0;
        @AuraEnabled public Decimal notYetDueAed = 0;
        @AuraEnabled public Decimal overdueInvoiceAed = 0;
        @AuraEnabled public Decimal unallocatedAed = 0;
        @AuraEnabled public Decimal efficiencyPct = 0;      // received / (received + due)
        @AuraEnabled public Decimal avgDaysToCollect = 0;   // amount-weighted, portfolio
        @AuraEnabled public Integer unitsTotal = 0;
        @AuraEnabled public List<ProjectRow> projects = new List<ProjectRow>();
        @AuraEnabled public List<HeatCell> heatmap = new List<HeatCell>();
    }

    /** One project — all money in the project's own currency, plus one AED figure for
     *  cross-project charts (top-10 outstanding). */
    public class ProjectRow implements Comparable {
        @AuraEnabled public String projectId;
        @AuraEnabled public String name;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public Decimal contracted = 0;
        @AuraEnabled public Decimal invoiced = 0;
        @AuraEnabled public Decimal received = 0;
        @AuraEnabled public Decimal remaining = 0;      // contracted - received
        @AuraEnabled public Decimal due = 0;
        @AuraEnabled public Decimal notYetDue = 0;
        @AuraEnabled public Decimal overdueInvoice = 0;
        @AuraEnabled public Decimal unallocated = 0;
        @AuraEnabled public Decimal collectedPct = 0;
        @AuraEnabled public Decimal efficiencyPct = 0;
        @AuraEnabled public Decimal avgDaysToCollect = 0;
        @AuraEnabled public Decimal outstandingAed = 0; // (due + notYetDue) in AED
        @AuraEnabled public Integer units = 0;
        @AuraEnabled public Integer unitsFullyPaid = 0;
        @AuraEnabled public Integer unitsOnTrack = 0;
        @AuraEnabled public Integer unitsOverdue = 0;
        @AuraEnabled public Integer unitsDefaulted = 0;
        // avg-days accumulation (not sent as such; exposed values are finalized)
        private Decimal daysWeight = 0;
        private Decimal daysWeighted = 0;

        public Integer compareTo(Object other) {
            ProjectRow o = (ProjectRow) other;
            if (outstandingAed == o.outstandingAed) return name.compareTo(o.name);
            return outstandingAed > o.outstandingAed ? -1 : 1; // descending
        }
    }

    /** One unit cell for the tower/floor heatmap. */
    public class HeatCell {
        @AuraEnabled public String unitId;
        @AuraEnabled public String unitName;
        @AuraEnabled public String projectId;
        @AuraEnabled public String projectName;
        @AuraEnabled public String tower;
        @AuraEnabled public String floorLabel;
        @AuraEnabled public Decimal floorSort = 0;
        @AuraEnabled public String health;
        @AuraEnabled public Decimal due = 0;
        @AuraEnabled public Integer overdueDays = 0;
    }

    /** One unit row for the expandable project table (project currency). */
    public class UnitRow {
        @AuraEnabled public String unitId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String health;
        @AuraEnabled public Decimal total = 0;
        @AuraEnabled public Decimal received = 0;
        @AuraEnabled public Decimal due = 0;
        @AuraEnabled public Decimal notYetDue = 0;
        @AuraEnabled public Decimal remaining = 0;
        @AuraEnabled public Decimal paidPct = 0;
        @AuraEnabled public Integer overdueDays = 0;
        @AuraEnabled public Integer missedInstalments = 0;
    }

    // ------------------------------------------------------------- reads ----

    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        try {
            DashboardData data = new DashboardData();
            data.ratesAsOf = CurrencyService.lastRefreshed();

            // ---- units: per-project aggregates + heatmap cells ----
            Map<Id, ProjectRow> rows = new Map<Id, ProjectRow>();
            Map<Id, String> ccyByProject = new Map<Id, String>();
            Set<Id> unitIds = new Set<Id>();
            for (Unit__c u : [
                SELECT Id, Name, Title__c, Status__c, Project__c, Project__r.Name,
                       Project__r.Project_Currency__c, Unit_Cost_Number__c,
                       Total_Received_Amount__c, Due_Amount__c, Not_Yet_Due_Amount__c,
                       Overdue_Days_Max__c, Collection_Health__c,
                       Tower__c, Floor__c, Floor_Text__c
                FROM Unit__c
                WHERE Project__c != null AND Status__c IN :SALES_STATUSES
            ]) {
                unitIds.add(u.Id);
                ProjectRow row = rows.get(u.Project__c);
                if (row == null) {
                    row = new ProjectRow();
                    row.projectId = u.Project__c;
                    row.name = u.Project__r.Name;
                    row.currencyCode = String.isBlank(u.Project__r.Project_Currency__c)
                        ? CurrencyService.CORPORATE_ISO : u.Project__r.Project_Currency__c;
                    rows.put(u.Project__c, row);
                    ccyByProject.put(u.Project__c, row.currencyCode);
                }
                row.units++;
                row.contracted += nz(u.Unit_Cost_Number__c);
                row.received += nz(u.Total_Received_Amount__c);
                row.due += nz(u.Due_Amount__c);
                row.notYetDue += nz(u.Not_Yet_Due_Amount__c);
                if (u.Collection_Health__c == FinanceCollectionStateService.HEALTH_FULLY_PAID) row.unitsFullyPaid++;
                else if (u.Collection_Health__c == FinanceCollectionStateService.HEALTH_ON_TRACK) row.unitsOnTrack++;
                else if (u.Collection_Health__c == FinanceCollectionStateService.HEALTH_OVERDUE) row.unitsOverdue++;
                else if (u.Collection_Health__c == FinanceCollectionStateService.HEALTH_DEFAULTED) row.unitsDefaulted++;

                HeatCell cell = new HeatCell();
                cell.unitId = u.Id;
                cell.unitName = String.isBlank(u.Title__c) ? u.Name : u.Title__c;
                cell.projectId = u.Project__c;
                cell.projectName = u.Project__r.Name;
                cell.tower = String.isBlank(u.Tower__c) ? '—' : u.Tower__c;
                cell.floorLabel = String.isBlank(u.Floor_Text__c)
                    ? (u.Floor__c == null ? '' : String.valueOf(u.Floor__c.intValue()))
                    : u.Floor_Text__c;
                cell.floorSort = u.Floor__c == null ? 0 : u.Floor__c;
                cell.health = u.Collection_Health__c;
                cell.due = nz(u.Due_Amount__c);
                cell.overdueDays = u.Overdue_Days_Max__c == null ? 0 : u.Overdue_Days_Max__c.intValue();
                data.heatmap.add(cell);
            }

            // ---- invoices: invoiced-to-date + overdue pending, per project ----
            if (!unitIds.isEmpty()) {
                Date today = Date.today();
                for (Invoice__c inv : [
                    SELECT Unit__r.Project__c, Sub_Total_Amount__c, VAT_Amount__c,
                           Paid_Amount__c, Due_Date__c
                    FROM Invoice__c
                    WHERE Unit__c IN :unitIds AND Status__c != 'Cancelled'
                ]) {
                    ProjectRow row = rows.get(inv.Unit__r.Project__c);
                    if (row == null) continue;
                    Decimal total = nz(inv.Sub_Total_Amount__c) + nz(inv.VAT_Amount__c);
                    row.invoiced += total;
                    Decimal pending = total - nz(inv.Paid_Amount__c);
                    if (pending > TOLERANCE && inv.Due_Date__c != null && inv.Due_Date__c < today) {
                        row.overdueInvoice += pending;
                    }
                }

                // ---- unallocated receipt money (same math as FinanceCollectionStateBatch) ----
                Map<Id, Decimal> allocatedByReceipt = new Map<Id, Decimal>();
                Map<Id, Decimal> onAccountByReceipt = new Map<Id, Decimal>();
                // Summed in Apex, not GROUP BY: an aggregate query cannot queryMore past
                // 2000 rows and production exceeds that.
                for (Receipt_Amount__c line : [
                    SELECT Receipt__c, Invoice__c, Amount__c
                    FROM Receipt_Amount__c
                    WHERE Receipt__r.Unit__c IN :unitIds
                ]) {
                    Map<Id, Decimal> target = line.Invoice__c == null ? onAccountByReceipt : allocatedByReceipt;
                    target.put(line.Receipt__c, nz(target.get(line.Receipt__c)) + nz(line.Amount__c));
                }
                for (Receipt__c r : [
                    SELECT Id, Unit__r.Project__c, Received_Amount__c
                    FROM Receipt__c
                    WHERE Unit__c IN :unitIds
                      AND Payment_Status__c != 'Cancelled' AND Status__c != 'Unreconciled'
                ]) {
                    ProjectRow row = rows.get(r.Unit__r.Project__c);
                    if (row == null) continue;
                    Decimal unapplied = Math.max(0, nz(r.Received_Amount__c) - nz(allocatedByReceipt.get(r.Id)))
                        + Math.max(0, nz(onAccountByReceipt.get(r.Id)));
                    if (unapplied > TOLERANCE) row.unallocated += unapplied;
                }

                // ---- avg days to collect from the engine's allocation ledger ----
                for (Milestone_Receipt__c mr : [
                    SELECT Amount__c, Installment_Date__c,
                           Receipt__r.Payment_Date__c, Receipt__r.Unit__r.Project__c
                    FROM Milestone_Receipt__c
                    WHERE Receipt__r.Unit__c IN :unitIds
                      AND Receipt__r.Payment_Status__c != 'Cancelled'
                      AND Receipt__r.Status__c != 'Unreconciled'
                      AND Amount__c > 0
                      AND Installment_Date__c != null
                      AND Receipt__r.Payment_Date__c != null
                ]) {
                    ProjectRow row = rows.get(mr.Receipt__r.Unit__r.Project__c);
                    if (row == null) continue;
                    // early payments count as 0 lag, not negative
                    Integer days = Math.max(0, mr.Installment_Date__c.daysBetween(mr.Receipt__r.Payment_Date__c));
                    row.daysWeighted += mr.Amount__c * days;
                    row.daysWeight += mr.Amount__c;
                }
            }

            // ---- finalize rows + portfolio tiles (AED at read time) ----
            Decimal portfolioDaysWeightedAed = 0, portfolioDaysWeightAed = 0;
            for (ProjectRow row : rows.values()) {
                row.remaining = row.contracted - row.received;
                row.collectedPct = pct(row.received, row.contracted);
                row.efficiencyPct = pct(row.received, row.received + row.due);
                row.avgDaysToCollect = row.daysWeight > 0
                    ? (row.daysWeighted / row.daysWeight).setScale(1) : 0;
                String ccy = row.currencyCode;
                row.outstandingAed = toAed(row.due + row.notYetDue, ccy);

                data.unitsTotal += row.units;
                data.contractedAed += toAed(row.contracted, ccy);
                data.invoicedAed += toAed(row.invoiced, ccy);
                data.receivedAed += toAed(row.received, ccy);
                data.dueAed += toAed(row.due, ccy);
                data.notYetDueAed += toAed(row.notYetDue, ccy);
                data.overdueInvoiceAed += toAed(row.overdueInvoice, ccy);
                data.unallocatedAed += toAed(row.unallocated, ccy);
                portfolioDaysWeightedAed += toAed(row.daysWeighted, ccy);
                portfolioDaysWeightAed += toAed(row.daysWeight, ccy);
            }
            data.efficiencyPct = pct(data.receivedAed, data.receivedAed + data.dueAed);
            data.avgDaysToCollect = portfolioDaysWeightAed > 0
                ? (portfolioDaysWeightedAed / portfolioDaysWeightAed).setScale(1) : 0;

            data.projects = rows.values();
            data.projects.sort(); // descending outstanding — also the top-10 order
            return data;
        } catch (Exception e) {
            throw auraError(e, 'Portfolio dashboard failed: ');
        }
    }

    /**
     * Unit rows for one project's expandable section (and the CSV export). String param on
     * purpose — Id-typed params inside wrappers arrive null from LWC. Not cacheable so the
     * expansion always reflects the latest stamped state after a manual refresh.
     */
    @AuraEnabled
    public static List<UnitRow> getUnitRows(String projectId) {
        try {
            Id projId = Id.valueOf(projectId);
            List<UnitRow> result = new List<UnitRow>();
            for (Unit__c u : [
                SELECT Id, Name, Title__c, Status__c, Unit_Cost_Number__c,
                       Total_Received_Amount__c, Due_Amount__c, Not_Yet_Due_Amount__c,
                       Overdue_Days_Max__c, Missed_Instalments__c, Collection_Health__c
                FROM Unit__c
                WHERE Project__c = :projId AND Status__c IN :SALES_STATUSES
                ORDER BY Title__c ASC NULLS LAST, Name ASC
            ]) {
                UnitRow row = new UnitRow();
                row.unitId = u.Id;
                row.name = String.isBlank(u.Title__c) ? u.Name : u.Title__c;
                row.status = u.Status__c;
                row.health = u.Collection_Health__c;
                row.total = nz(u.Unit_Cost_Number__c);
                row.received = nz(u.Total_Received_Amount__c);
                row.due = nz(u.Due_Amount__c);
                row.notYetDue = nz(u.Not_Yet_Due_Amount__c);
                row.remaining = row.total - row.received;
                row.paidPct = pct(row.received, row.total);
                row.overdueDays = u.Overdue_Days_Max__c == null ? 0 : u.Overdue_Days_Max__c.intValue();
                row.missedInstalments = u.Missed_Instalments__c == null ? 0 : u.Missed_Instalments__c.intValue();
                result.add(row);
            }
            return result;
        } catch (Exception e) {
            throw auraError(e, 'Unit rows failed: ');
        }
    }

    // ----------------------------------------------------------- helpers ----

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
