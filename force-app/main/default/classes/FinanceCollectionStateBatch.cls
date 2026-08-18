/**
 * FinanceCollectionStateBatch — the Finance Center's nightly job. Three responsibilities:
 *
 *  1. FULL SWEEP: re-stamps every unit's collection state (FinanceCollectionStateService).
 *     This is what handles the midnight due-date rollover (instalments becoming due is a time
 *     event, not a transaction) and self-heals anything the intraday hooks missed, so drift
 *     can never exceed 24 hours.
 *  2. DAILY SNAPSHOT: one Finance_Daily_Snapshot__c row per project per day — the only source
 *     for aging / DSO / collection-efficiency trend charts.
 *  3. FORECAST REBUILD: Finance_Forecast_Line__c live lines (per project per month) are
 *     deleted and recreated; on the first run of a month a FROZEN copy of that month's line
 *     is created and never touched again (forecast-vs-actual variance baseline).
 *
 * CURRENCY: everything is kept in the PROJECT'S OWN CURRENCY — finance receives money in the
 * project currency, not AED (per Sheraz, 2026-08-17). Unit prices come from
 * Unit__c.Unit_Cost_Number__c (CASE on Project_Currency__c → Cost_AED / Cost_USD / Cost_CHF),
 * and cash-flow / invoice / receipt amounts are already in project currency. A snapshot or
 * forecast row never mixes currencies because it is per project; its currency is the project's
 * (Project__r.Project_Currency__c, AED when blank). Any cross-project rollup a dashboard needs
 * must convert AT READ TIME via CurrencyService — never here.
 *
 * Read-only over the FinancialEngine's outputs. Writes only the Finance Center fields/objects.
 * Scheduled nightly (see Schedulable). Safe to re-run in the same day: snapshots upsert on
 * Snapshot_Key__c and frozen forecast lines are only created when absent.
 */
public without sharing class FinanceCollectionStateBatch
        implements Database.Batchable<SObject>, Database.Stateful, Schedulable {

    private static final Set<String> SALES_STATUSES = new Set<String>{ 'Booked', 'Reserved', 'Sold' };
    private static final Decimal TOLERANCE = 0.005;
    /** Snapshot has 6 fixed aging fields; buckets beyond the 6th fold into the last. */
    @TestVisible static final Integer AGING_FIELD_COUNT = 6;
    /** A unit whose plan differs from Unit_Cost_Number__c by more than this is a DQ hit
     *  (both sides are in the project currency, so the comparison is strict). */
    private static final Decimal PLAN_MISMATCH_TOLERANCE = 1.0;

    /** Per-project accumulation across batch chunks. All amounts in the project's currency. */
    public class ProjectAgg {
        public Decimal contracted = 0;
        public Decimal received = 0;
        public Decimal due = 0;
        public Decimal notYetDue = 0;
        public Decimal invoiced = 0;
        public Decimal overdueInvoice = 0;
        public Decimal unallocated = 0;
        public Decimal dueNotInvoiced = 0;
        public List<Decimal> aging = new List<Decimal>{ 0, 0, 0, 0, 0, 0 };
        public Integer unitsTotal = 0;
        public Integer fullyPaid = 0;
        public Integer onTrack = 0;
        public Integer overdueUnits = 0;
        public Integer defaulted = 0;
        public Integer dq = 0;
        public Map<String, Decimal> forecast = new Map<String, Decimal>(); // YYYY-MM -> amount
    }

    private final Date runDate = Date.today();
    private Map<Id, ProjectAgg> aggByProject = new Map<Id, ProjectAgg>();

    // ---- Schedulable -----------------------------------------------------------

    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new FinanceCollectionStateBatch(), 200);
    }

    // ---- Batchable -------------------------------------------------------------

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        return Database.getQueryLocator([
            SELECT Id, Project__c, Status__c, Unit_Cost_Number__c, Total_Received_Amount__c
            FROM Unit__c
        ]);
    }

    public void execute(Database.BatchableContext ctx, List<Unit__c> scope) {
        // 1. Derive once, stamp every unit (also non-sold ones, so record pages stay honest).
        Map<Id, FinanceCollectionStateService.UnitState> states =
            FinanceCollectionStateService.deriveForUnits(new Map<Id, Unit__c>(scope).keySet());
        FinanceCollectionStateService.stampDerived(states);

        // 2. Accumulate portfolio aggregates for Booked/Reserved/Sold units with a project.
        //    All amounts stay in the project currency — no conversion, ever, in this class.
        Map<Id, Unit__c> eligible = new Map<Id, Unit__c>();
        for (Unit__c u : scope) {
            if (u.Project__c == null || !SALES_STATUSES.contains(u.Status__c)) continue;
            eligible.put(u.Id, u);
            ProjectAgg agg = aggFor(u.Project__c);
            FinanceCollectionStateService.UnitState st = states.get(u.Id);

            agg.unitsTotal++;
            agg.contracted += nz(u.Unit_Cost_Number__c); // price in the project currency
            agg.received += nz(u.Total_Received_Amount__c);
            agg.due += st.dueAmount;
            agg.notYetDue += st.notYetDueAmount;
            agg.dueNotInvoiced += st.dueNotInvoicedAmount;
            agg.dq += st.negativeRemainingCount;
            if (st.hasPricedPlan
                && Math.abs(st.plannedTotal - nz(u.Unit_Cost_Number__c)) > PLAN_MISMATCH_TOLERANCE) {
                agg.dq++; // the payment plan does not add up to the unit price
            }
            if (st.health == FinanceCollectionStateService.HEALTH_FULLY_PAID) agg.fullyPaid++;
            else if (st.health == FinanceCollectionStateService.HEALTH_ON_TRACK) agg.onTrack++;
            else if (st.health == FinanceCollectionStateService.HEALTH_OVERDUE) agg.overdueUnits++;
            else if (st.health == FinanceCollectionStateService.HEALTH_DEFAULTED) agg.defaulted++;
            for (String monthK : st.futureByMonth.keySet()) {
                Decimal cur = agg.forecast.get(monthK);
                agg.forecast.put(monthK, (cur == null ? 0 : cur) + st.futureByMonth.get(monthK));
            }
        }
        if (eligible.isEmpty()) return;

        // 3. Invoice-based figures: invoiced-to-date, overdue, CMDT-driven aging buckets.
        for (Invoice__c inv : [
            SELECT Unit__c, Sub_Total_Amount__c, VAT_Amount__c, Paid_Amount__c, Due_Date__c
            FROM Invoice__c
            WHERE Unit__c IN :eligible.keySet() AND Status__c != 'Cancelled'
        ]) {
            Unit__c u = eligible.get(inv.Unit__c);
            ProjectAgg agg = aggFor(u.Project__c);
            Decimal total = nz(inv.Sub_Total_Amount__c) + nz(inv.VAT_Amount__c);
            agg.invoiced += total;
            Decimal pending = total - nz(inv.Paid_Amount__c);
            if (nz(inv.Paid_Amount__c) > total + TOLERANCE) agg.dq++; // over-receipt
            if (pending <= TOLERANCE) continue;
            Integer daysOver = (inv.Due_Date__c != null && inv.Due_Date__c < runDate)
                ? inv.Due_Date__c.daysBetween(runDate) : 0;
            if (daysOver > 0) agg.overdueInvoice += pending;
            agg.aging[bucketIndexFor(daysOver)] += pending;
        }

        // 4. Unallocated receipt money, two sources:
        //    (a) stored Received_Amount above the invoice-allocated lines (legacy receipts the
        //        engine has not derived — ReceiptManageController's unapplied definition), and
        //    (b) on-account lines with no Invoice__c at all (the engine deliberately excludes
        //        them from Received_Amount, so (a) alone would never see them).
        // Summed in Apex, not GROUP BY: an aggregate query cannot queryMore past 2000 rows,
        // and a 200-unit production chunk exceeds that.
        Map<Id, Decimal> allocatedByReceipt = new Map<Id, Decimal>();
        Map<Id, Decimal> onAccountByReceipt = new Map<Id, Decimal>();
        for (Receipt_Amount__c line : [
            SELECT Receipt__c, Invoice__c, Amount__c
            FROM Receipt_Amount__c
            WHERE Receipt__r.Unit__c IN :eligible.keySet()
        ]) {
            Map<Id, Decimal> target = line.Invoice__c == null ? onAccountByReceipt : allocatedByReceipt;
            Decimal cur = target.get(line.Receipt__c);
            target.put(line.Receipt__c, (cur == null ? 0 : cur) + nz(line.Amount__c));
        }
        for (Receipt__c r : [
            SELECT Id, Unit__c, Received_Amount__c
            FROM Receipt__c
            WHERE Unit__c IN :eligible.keySet()
              AND Payment_Status__c != 'Cancelled' AND Status__c != 'Unreconciled'
        ]) {
            Unit__c u = eligible.get(r.Unit__c);
            ProjectAgg agg = aggFor(u.Project__c);
            Decimal allocated = allocatedByReceipt.get(r.Id);
            if (allocated == null && nz(r.Received_Amount__c) > TOLERANCE) {
                agg.dq++; // receipt carrying money but allocated to no invoice at all
            }
            Decimal unapplied = Math.max(0, nz(r.Received_Amount__c) - nz(allocated));
            Decimal onAccount = nz(onAccountByReceipt.get(r.Id));
            if (onAccount > 0) unapplied += onAccount;
            if (unapplied > TOLERANCE) {
                agg.unallocated += unapplied;
            }
        }
    }

    public void finish(Database.BatchableContext ctx) {
        writeSnapshots();
        rebuildForecastLines();
    }

    // ---- write side ------------------------------------------------------------

    private void writeSnapshots() {
        List<Finance_Daily_Snapshot__c> snaps = new List<Finance_Daily_Snapshot__c>();
        for (Id projId : aggByProject.keySet()) {
            ProjectAgg agg = aggByProject.get(projId);
            snaps.add(new Finance_Daily_Snapshot__c(
                Snapshot_Key__c = projId + '|' + String.valueOf(runDate),
                Snapshot_Date__c = runDate,
                Project__c = projId,
                Contracted_Value__c = agg.contracted,
                Invoiced_To_Date__c = agg.invoiced,
                Received_To_Date__c = agg.received,
                Due_Amount__c = agg.due,
                Not_Yet_Due_Amount__c = agg.notYetDue,
                Overdue_Invoice_Amount__c = agg.overdueInvoice,
                Unallocated_Amount__c = agg.unallocated,
                Due_Not_Invoiced_Amount__c = agg.dueNotInvoiced,
                Aging_Current__c = agg.aging[0],
                Aging_1_30__c = agg.aging[1],
                Aging_31_60__c = agg.aging[2],
                Aging_61_90__c = agg.aging[3],
                Aging_91_180__c = agg.aging[4],
                Aging_180_Plus__c = agg.aging[5],
                Units_Total__c = agg.unitsTotal,
                Units_Fully_Paid__c = agg.fullyPaid,
                Units_On_Track__c = agg.onTrack,
                Units_Overdue__c = agg.overdueUnits,
                Units_Defaulted__c = agg.defaulted,
                DQ_Exception_Count__c = agg.dq
            ));
        }
        if (!snaps.isEmpty()) upsert snaps Finance_Daily_Snapshot__c.Snapshot_Key__c;
    }

    private void rebuildForecastLines() {
        // Live lines are a full rebuild every run.
        delete [SELECT Id FROM Finance_Forecast_Line__c WHERE Is_Frozen__c = false];

        String currentMonthKey = FinanceCollectionStateService.monthKey(runDate);
        Set<Id> projectsWithFrozenCurrentMonth = new Set<Id>();
        for (Finance_Forecast_Line__c f : [
            SELECT Project__c FROM Finance_Forecast_Line__c
            WHERE Is_Frozen__c = true AND Forecast_Month__c = :runDate.toStartOfMonth()
        ]) {
            projectsWithFrozenCurrentMonth.add(f.Project__c);
        }

        List<Finance_Forecast_Line__c> lines = new List<Finance_Forecast_Line__c>();
        for (Id projId : aggByProject.keySet()) {
            ProjectAgg agg = aggByProject.get(projId);
            for (String monthK : agg.forecast.keySet()) {
                lines.add(new Finance_Forecast_Line__c(
                    Line_Key__c = projId + '|' + monthK + '|LIVE',
                    Project__c = projId,
                    Forecast_Month__c = firstOfMonth(monthK),
                    Expected_Amount__c = agg.forecast.get(monthK),
                    Is_Frozen__c = false
                ));
            }
            // First run of the month: freeze this month's expectation as the variance baseline
            // (created even at zero — "we expected nothing" is a valid baseline).
            if (!projectsWithFrozenCurrentMonth.contains(projId)) {
                Decimal expected = agg.forecast.get(currentMonthKey);
                lines.add(new Finance_Forecast_Line__c(
                    Line_Key__c = projId + '|' + currentMonthKey + '|FROZEN',
                    Project__c = projId,
                    Forecast_Month__c = runDate.toStartOfMonth(),
                    Expected_Amount__c = expected == null ? 0 : expected,
                    Is_Frozen__c = true
                ));
            }
        }
        if (!lines.isEmpty()) upsert lines Finance_Forecast_Line__c.Line_Key__c;
    }

    // ---- aging buckets (Aging_Bucket__mdt) --------------------------------------

    private static List<Aging_Bucket__mdt> bucketCache;

    /** CMDT SOQL does not reliably honor ORDER BY on custom fields (rows can come back in
     *  DeveloperName order), so the sort happens in Apex — otherwise the snapshot's fixed
     *  aging columns would be filled in a nondeterministic order. */
    private static List<Aging_Bucket__mdt> buckets() {
        if (bucketCache == null) {
            List<Aging_Bucket__mdt> sorted = new List<Aging_Bucket__mdt>();
            for (Aging_Bucket__mdt row : [
                SELECT Min_Days_Overdue__c, Max_Days_Overdue__c, Sort_Order__c
                FROM Aging_Bucket__mdt
            ]) {
                Integer i = 0;
                while (i < sorted.size() && sorted[i].Sort_Order__c <= row.Sort_Order__c) i++;
                if (i == sorted.size()) sorted.add(row); else sorted.add(i, row);
            }
            bucketCache = sorted;
        }
        return bucketCache;
    }

    /** Index into the snapshot's 6 aging fields for a days-overdue value. */
    @TestVisible
    static Integer bucketIndexFor(Integer daysOverdue) {
        List<Aging_Bucket__mdt> all = buckets();
        for (Integer i = 0; i < all.size(); i++) {
            if (daysOverdue >= all[i].Min_Days_Overdue__c
                && (all[i].Max_Days_Overdue__c == null
                    || daysOverdue <= all[i].Max_Days_Overdue__c)) {
                return Math.min(i, AGING_FIELD_COUNT - 1);
            }
        }
        return AGING_FIELD_COUNT - 1;
    }

    // ---- helpers ----------------------------------------------------------------

    private ProjectAgg aggFor(Id projectId) {
        ProjectAgg agg = aggByProject.get(projectId);
        if (agg == null) {
            agg = new ProjectAgg();
            aggByProject.put(projectId, agg);
        }
        return agg;
    }

    private static Decimal nz(Decimal d) { return d == null ? 0 : d; }

    /** 'YYYY-MM' -> Date of the 1st. */
    private static Date firstOfMonth(String monthK) {
        return Date.newInstance(
            Integer.valueOf(monthK.substring(0, 4)),
            Integer.valueOf(monthK.substring(5, 7)),
            1
        );
    }
}
