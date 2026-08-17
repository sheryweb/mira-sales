/**
 * FinanceCashflowDashboardController — data + actions for the Finance Center's
 * "Cash Flow & Forecast" dashboard (financeCashflowDashboard LWC).
 *
 * WITHOUT SHARING, deliberately: org-wide portfolio view gated by the Finance_Center_Access
 * permission set (same justification as the other dashboard controllers).
 *
 * DATA MODEL: expected receipts come from Finance_Forecast_Line__c — LIVE lines (rebuilt
 * nightly from unpaid instalments) for the current and future months, FROZEN month-start
 * baselines for past months, which is also what the variance table compares against. Actual
 * receipts come straight from Receipt__c.Payment_Date__c. The escrow split classifies each
 * receipt's Deposited_To__c via Bank_Account_Class__mdt — metadata-driven, never string
 * matching.
 *
 * CURRENCY: portfolio series, tiles and the escrow split combine projects, so they are AED at
 * read time. Per-project forecast scopes and the variance rows are per project, so they stay
 * in the project's own currency.
 */
public without sharing class FinanceCashflowDashboardController {

    private static final Integer HISTORY_MONTHS = 6;
    private static final Integer FUTURE_MONTHS = 18;
    private static final Integer ESCROW_MONTHS = 12;
    private static final Set<String> SALES_STATUSES = new Set<String>{ 'Booked', 'Reserved', 'Sold' };

    // ---------------------------------------------------------------- DTOs ----

    public class DashboardData {
        @AuraEnabled public Datetime ratesAsOf;
        // scenario / tile figures (AED)
        @AuraEnabled public Decimal currentMonthExpectedAed = 0;
        @AuraEnabled public Decimal currentMonthActualAed = 0;
        @AuraEnabled public Decimal nextMonthExpectedAed = 0;
        @AuraEnabled public Decimal next3ExpectedAed = 0;
        @AuraEnabled public Decimal overdueAed = 0; // stamped due backlog across the portfolio
        @AuraEnabled public List<MonthPoint> portfolio = new List<MonthPoint>(); // AED
        @AuraEnabled public List<ProjectForecast> projects = new List<ProjectForecast>(); // native
        @AuraEnabled public List<EscrowMonth> escrow = new List<EscrowMonth>(); // AED
        @AuraEnabled public List<VarianceRow> variance = new List<VarianceRow>(); // native
    }

    public class MonthPoint {
        @AuraEnabled public String monthKey;
        @AuraEnabled public Date monthStart;
        @AuraEnabled public Decimal expected = 0;
        @AuraEnabled public Decimal actual = 0;
        @AuraEnabled public Boolean hasActual = false; // false for future months (line gap)
        public MonthPoint(String k, Date d) { monthKey = k; monthStart = d; }
    }

    public class ProjectForecast {
        @AuraEnabled public String projectId;
        @AuraEnabled public String name;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public List<MonthPoint> months = new List<MonthPoint>();
    }

    public class EscrowMonth {
        @AuraEnabled public String monthKey;
        @AuraEnabled public Decimal escrowAed = 0;
        @AuraEnabled public Decimal operatingAed = 0;
        @AuraEnabled public Decimal cashAed = 0;
        @AuraEnabled public Decimal otherAed = 0; // Deposited_To values with no CMDT mapping
        public EscrowMonth(String k) { monthKey = k; }
    }

    public class VarianceRow implements Comparable {
        @AuraEnabled public String lineId;
        @AuraEnabled public String projectId;
        @AuraEnabled public String projectName;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public Date monthStart;
        @AuraEnabled public String monthKey;
        @AuraEnabled public Decimal expected = 0;
        @AuraEnabled public Decimal actual = 0;
        @AuraEnabled public Decimal varianceAmount = 0; // actual - expected
        @AuraEnabled public Decimal variancePct = 0;
        @AuraEnabled public String slippageReason;
        public Integer compareTo(Object other) {
            VarianceRow o = (VarianceRow) other;
            if (monthStart != o.monthStart) return monthStart > o.monthStart ? -1 : 1; // newest first
            return projectName.compareTo(o.projectName);
        }
    }

    // ------------------------------------------------------------- reads ----

    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        try {
            DashboardData data = new DashboardData();
            data.ratesAsOf = CurrencyService.lastRefreshed();
            Date currentMonth = Date.today().toStartOfMonth();
            Date historyStart = currentMonth.addMonths(-HISTORY_MONTHS);
            Date futureEnd = currentMonth.addMonths(FUTURE_MONTHS);
            String currentKey = FinanceCollectionStateService.monthKey(currentMonth);

            // ---- month axis ----
            Map<String, MonthPoint> portfolioByKey = new Map<String, MonthPoint>();
            for (Date m = historyStart; m <= futureEnd; m = m.addMonths(1)) {
                String k = FinanceCollectionStateService.monthKey(m);
                MonthPoint pt = new MonthPoint(k, m);
                pt.hasActual = m <= currentMonth;
                portfolioByKey.put(k, pt);
                data.portfolio.add(pt);
            }

            // ---- project currencies (also feeds the overdue backlog tile) ----
            Map<Id, String> ccyByProject = new Map<Id, String>();
            Map<Id, String> nameByProject = new Map<Id, String>();
            for (Unit__c u : [
                SELECT Project__c, Project__r.Name, Project__r.Project_Currency__c, Due_Amount__c
                FROM Unit__c
                WHERE Project__c != null AND Status__c IN :SALES_STATUSES
            ]) {
                String ccy = String.isBlank(u.Project__r.Project_Currency__c)
                    ? CurrencyService.CORPORATE_ISO : u.Project__r.Project_Currency__c;
                ccyByProject.put(u.Project__c, ccy);
                nameByProject.put(u.Project__c, u.Project__r.Name);
                data.overdueAed += toAed(nz(u.Due_Amount__c), ccy);
            }

            // ---- forecast lines: LIVE for current/future, FROZEN for the past + variance ----
            Map<Id, ProjectForecast> projByIdMap = new Map<Id, ProjectForecast>();
            Map<String, VarianceRow> varianceByKey = new Map<String, VarianceRow>(); // proj|month
            for (Finance_Forecast_Line__c line : [
                SELECT Id, Project__c, Project__r.Name, Project__r.Project_Currency__c,
                       Forecast_Month__c, Expected_Amount__c, Is_Frozen__c, Slippage_Reason__c
                FROM Finance_Forecast_Line__c
                WHERE Forecast_Month__c >= :historyStart AND Forecast_Month__c <= :futureEnd
            ]) {
                String k = FinanceCollectionStateService.monthKey(line.Forecast_Month__c);
                String ccy = ccyByProject.get(line.Project__c);
                if (ccy == null) {
                    ccy = String.isBlank(line.Project__r.Project_Currency__c)
                        ? CurrencyService.CORPORATE_ISO : line.Project__r.Project_Currency__c;
                }
                Boolean isPastMonth = line.Forecast_Month__c < currentMonth;
                // expected series: frozen lines own past months, live lines own current+future
                // (the current month has both — the live one wins, the frozen one feeds variance)
                if (line.Is_Frozen__c == isPastMonth) {
                    Decimal amount = nz(line.Expected_Amount__c);
                    MonthPoint pt = portfolioByKey.get(k);
                    if (pt != null) {
                        pt.expected += toAed(amount, ccy);
                        ProjectForecast pf = projectForecast(projByIdMap, line.Project__c,
                            line.Project__r.Name, ccy, portfolioByKey.values());
                        for (MonthPoint projPt : pf.months) {
                            if (projPt.monthKey == k) { projPt.expected += amount; break; }
                        }
                        if (k == currentKey) data.currentMonthExpectedAed += toAed(amount, ccy);
                        Date nextMonth = currentMonth.addMonths(1);
                        if (line.Forecast_Month__c == nextMonth) data.nextMonthExpectedAed += toAed(amount, ccy);
                        if (!isPastMonth && line.Forecast_Month__c < currentMonth.addMonths(3)) {
                            data.next3ExpectedAed += toAed(amount, ccy);
                        }
                    }
                }
                // variance rows: every frozen line for a month that has started
                if (line.Is_Frozen__c && line.Forecast_Month__c <= currentMonth) {
                    VarianceRow row = new VarianceRow();
                    row.lineId = line.Id;
                    row.projectId = line.Project__c;
                    row.projectName = line.Project__r.Name;
                    row.currencyCode = ccy;
                    row.monthStart = line.Forecast_Month__c;
                    row.monthKey = k;
                    row.expected = nz(line.Expected_Amount__c);
                    row.slippageReason = line.Slippage_Reason__c;
                    varianceByKey.put(line.Project__c + '|' + k, row);
                }
            }

            // ---- actual receipts by month (portfolio AED + per-project native) ----
            Map<String, Map<String, Decimal>> actualNative = new Map<String, Map<String, Decimal>>();
            Map<String, EscrowMonth> escrowByKey = new Map<String, EscrowMonth>();
            Date escrowStart = currentMonth.addMonths(-(ESCROW_MONTHS - 1));
            for (Date m = escrowStart; m <= currentMonth; m = m.addMonths(1)) {
                String k = FinanceCollectionStateService.monthKey(m);
                escrowByKey.put(k, new EscrowMonth(k));
                data.escrow.add(escrowByKey.get(k));
            }
            Map<String, String> classByDepositedTo = bankClassMap();
            Date receiptsFrom = historyStart < escrowStart ? historyStart : escrowStart;
            for (Receipt__c r : [
                SELECT Payment_Date__c, Received_Amount__c, Deposited_To__c,
                       Unit__r.Project__c, Unit__r.Project__r.Project_Currency__c
                FROM Receipt__c
                WHERE Unit__c != null AND Payment_Date__c >= :receiptsFrom
                  AND Payment_Status__c != 'Cancelled' AND Status__c != 'Unreconciled'
            ]) {
                if (nz(r.Received_Amount__c) == 0 || r.Unit__r.Project__c == null) continue;
                String k = FinanceCollectionStateService.monthKey(r.Payment_Date__c);
                String ccy = ccyByProject.get(r.Unit__r.Project__c);
                if (ccy == null) {
                    ccy = String.isBlank(r.Unit__r.Project__r.Project_Currency__c)
                        ? CurrencyService.CORPORATE_ISO : r.Unit__r.Project__r.Project_Currency__c;
                }
                Decimal amountAed = toAed(r.Received_Amount__c, ccy);

                MonthPoint pt = portfolioByKey.get(k);
                if (pt != null) {
                    pt.actual += amountAed;
                    if (k == currentKey) data.currentMonthActualAed += amountAed;
                    String projKey = r.Unit__r.Project__c;
                    Map<String, Decimal> perMonth = actualNative.get(projKey);
                    if (perMonth == null) {
                        perMonth = new Map<String, Decimal>();
                        actualNative.put(projKey, perMonth);
                    }
                    perMonth.put(k, nz(perMonth.get(k)) + r.Received_Amount__c);
                }

                EscrowMonth em = escrowByKey.get(k);
                if (em != null) {
                    String cls = classByDepositedTo.get(r.Deposited_To__c);
                    if (cls == 'Escrow') em.escrowAed += amountAed;
                    else if (cls == 'Operating') em.operatingAed += amountAed;
                    else if (cls == 'Cash') em.cashAed += amountAed;
                    else em.otherAed += amountAed;
                }
            }

            // per-project actuals onto the native series
            for (ProjectForecast pf : projByIdMap.values()) {
                Map<String, Decimal> perMonth = actualNative.get(pf.projectId);
                if (perMonth == null) continue;
                for (MonthPoint pt : pf.months) {
                    if (perMonth.containsKey(pt.monthKey)) pt.actual = perMonth.get(pt.monthKey);
                }
            }
            data.projects = projByIdMap.values();

            // ---- finalize variance (native currency per row) ----
            for (VarianceRow row : varianceByKey.values()) {
                Map<String, Decimal> perMonth = actualNative.get(row.projectId);
                row.actual = perMonth == null ? 0 : nz(perMonth.get(row.monthKey));
                row.varianceAmount = row.actual - row.expected;
                row.variancePct = row.expected > 0
                    ? (100 * row.varianceAmount / row.expected).setScale(1) : 0;
                data.variance.add(row);
            }
            data.variance.sort();
            return data;
        } catch (Exception e) {
            throw auraError(e, 'Cash flow dashboard failed: ');
        }
    }

    // ------------------------------------------------------------ actions ----

    /** Edit the slippage note on a FROZEN month-start baseline line. */
    @AuraEnabled
    public static void updateSlippageReason(String lineId, String reason) {
        try {
            Finance_Forecast_Line__c line = [
                SELECT Id, Is_Frozen__c FROM Finance_Forecast_Line__c
                WHERE Id = :Id.valueOf(lineId) LIMIT 1
            ];
            if (!line.Is_Frozen__c) {
                throw new IllegalArgumentException(
                    'Slippage reasons live on the frozen month-start baselines only.');
            }
            update new Finance_Forecast_Line__c(Id = line.Id, Slippage_Reason__c = reason);
        } catch (Exception e) {
            throw auraError(e, 'Could not save the slippage reason: ');
        }
    }

    // ----------------------------------------------------------- helpers ----

    private static ProjectForecast projectForecast(Map<Id, ProjectForecast> registry, Id projectId,
            String name, String ccy, List<MonthPoint> axis) {
        ProjectForecast pf = registry.get(projectId);
        if (pf == null) {
            pf = new ProjectForecast();
            pf.projectId = projectId;
            pf.name = name;
            pf.currencyCode = ccy;
            for (MonthPoint pt : axis) {
                MonthPoint own = new MonthPoint(pt.monthKey, pt.monthStart);
                own.hasActual = pt.hasActual;
                pf.months.add(own);
            }
            registry.put(projectId, pf);
        }
        return pf;
    }

    /** Deposited_To__c value -> Escrow / Operating / Cash from Bank_Account_Class__mdt. */
    private static Map<String, String> bankClassMap() {
        Map<String, String> result = new Map<String, String>();
        for (Bank_Account_Class__mdt row : [
            SELECT Deposited_To_Value__c, Classification__c FROM Bank_Account_Class__mdt
        ]) {
            result.put(row.Deposited_To_Value__c, row.Classification__c);
        }
        return result;
    }

    private static Decimal toAed(Decimal amount, String iso) {
        return CurrencyService.convertToAed(amount, iso);
    }

    private static Decimal nz(Decimal d) { return d == null ? 0 : d; }

    private static AuraHandledException auraError(Exception e, String prefix) {
        AuraHandledException aura = new AuraHandledException(prefix + e.getMessage());
        aura.setMessage(prefix + e.getMessage());
        return aura;
    }
}
