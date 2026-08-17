/**
 * Tests for FinanceCashflowDashboardController.
 *
 * Data shape (@TestSetup) — engine OFF, forecast lines inserted directly:
 *  - ALPHA (AED): U1 Booked with CF -40d 1000 unpaid (stamped -> overdue backlog 1000).
 *      LIVE lines: current month 3000, next month 1500. FROZEN current month 2500.
 *      Receipts this month: 1000 operating (Emirates NBD - AED) + 500 escrow (EI Escrow TR1).
 *  - BRAVO (USD, rate 0.25/AED -> 1 USD = 4 AED): U2 Sold.
 *      LIVE line next month 100 USD (-> 400 AED). FROZEN last month 200 USD.
 *      Receipt last month 50 USD deposited as Cash.
 */
@IsTest
private class FinanceCashflowDashboardCtrlTest {

    @TestSetup
    static void setup() {
        insert new Currency_Exchange_Rate__c(
            Name = 'USD', Rate_Per_AED__c = 0.25, Last_Refreshed__c = System.now(), Source__c = 'Test'
        );

        Project__c alpha = new Project__c(
            Name = 'FCF Alpha', Description__c = 'Test', District__c = 'Meydan',
            Coordinates_Latitude__c = 1, Coordinates_Longitude__c = 1, Handover__c = Date.today()
        );
        Project__c bravo = new Project__c(
            Name = 'FCF Bravo', Description__c = 'Test', District__c = 'Meydan',
            Coordinates_Latitude__c = 1, Coordinates_Longitude__c = 1, Handover__c = Date.today(),
            Project_Currency__c = 'USD'
        );
        insert new List<Project__c>{ alpha, bravo };

        Unit__c u1 = new Unit__c(Title__c = 'FCF-U1', Project__c = alpha.Id, Status__c = 'Draft', Cost_AED__c = 3000);
        Unit__c u2 = new Unit__c(Title__c = 'FCF-U2', Project__c = bravo.Id, Status__c = 'Draft', Cost_AED__c = 400, Cost_USD__c = 100);
        insert new List<Unit__c>{ u1, u2 };
        u1.Status__c = 'Booked';
        u2.Status__c = 'Sold';
        update new List<Unit__c>{ u1, u2 };

        Cash_Flow_Sum__c s1 = new Cash_Flow_Sum__c(Name = 'CFS1', Unit__c = u1.Id);
        insert s1;
        insert new Cash_Flow__c(Name = 'M1', Unit__c = u1.Id, Cash_Flow_Sum__c = s1.Id,
            Date__c = Date.today().addDays(-40), Constant__c = 1000, Received_Amount__c = 0);

        Date currentMonth = Date.today().toStartOfMonth();
        Date lastMonth = currentMonth.addMonths(-1);
        Date nextMonth = currentMonth.addMonths(1);
        String curKey = FinanceCollectionStateService.monthKey(currentMonth);
        String lastKey = FinanceCollectionStateService.monthKey(lastMonth);
        String nextKey = FinanceCollectionStateService.monthKey(nextMonth);
        insert new List<Finance_Forecast_Line__c>{
            new Finance_Forecast_Line__c(Line_Key__c = alpha.Id + '|' + curKey + '|LIVE',
                Project__c = alpha.Id, Forecast_Month__c = currentMonth, Expected_Amount__c = 3000, Is_Frozen__c = false),
            new Finance_Forecast_Line__c(Line_Key__c = alpha.Id + '|' + nextKey + '|LIVE',
                Project__c = alpha.Id, Forecast_Month__c = nextMonth, Expected_Amount__c = 1500, Is_Frozen__c = false),
            new Finance_Forecast_Line__c(Line_Key__c = alpha.Id + '|' + curKey + '|FROZEN',
                Project__c = alpha.Id, Forecast_Month__c = currentMonth, Expected_Amount__c = 2500, Is_Frozen__c = true),
            new Finance_Forecast_Line__c(Line_Key__c = bravo.Id + '|' + nextKey + '|LIVE',
                Project__c = bravo.Id, Forecast_Month__c = nextMonth, Expected_Amount__c = 100, Is_Frozen__c = false),
            new Finance_Forecast_Line__c(Line_Key__c = bravo.Id + '|' + lastKey + '|FROZEN',
                Project__c = bravo.Id, Forecast_Month__c = lastMonth, Expected_Amount__c = 200, Is_Frozen__c = true)
        };

        insert new List<Receipt__c>{
            new Receipt__c(Unit__c = u1.Id, Description__c = 'Op', Payment_Date__c = currentMonth,
                Received_Amount__c = 1000, Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid',
                Deposited_To__c = 'Emirates NBD - AED'),
            new Receipt__c(Unit__c = u1.Id, Description__c = 'Esc', Payment_Date__c = currentMonth,
                Received_Amount__c = 500, Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid',
                Deposited_To__c = 'Emirates Islamic Escrow - TR1'),
            new Receipt__c(Unit__c = u2.Id, Description__c = 'Cash', Payment_Date__c = lastMonth,
                Received_Amount__c = 50, Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid',
                Deposited_To__c = 'Cash')
        };

        FinanceCollectionStateService.stampUnits(new Set<Id>{ u1.Id, u2.Id });
    }

    private static FinanceCashflowDashboardController.MonthPoint pointFor(
            List<FinanceCashflowDashboardController.MonthPoint> months, Date monthStart) {
        for (FinanceCashflowDashboardController.MonthPoint pt : months) {
            if (pt.monthStart == monthStart) return pt;
        }
        return null;
    }

    @IsTest
    static void tilesAndPortfolioSeries() {
        Test.startTest();
        FinanceCashflowDashboardController.DashboardData data =
            FinanceCashflowDashboardController.getDashboardData();
        Test.stopTest();

        System.assertEquals(3000, data.currentMonthExpectedAed, 'Alpha live current-month line');
        System.assertEquals(1500, data.currentMonthActualAed, '1000 + 500 receipts this month');
        System.assertEquals(1900, data.nextMonthExpectedAed, '1500 AED + 100 USD as 400 AED');
        System.assertEquals(4900, data.next3ExpectedAed, 'Current + next 2 months of live lines');
        System.assertEquals(1000, data.overdueAed, 'Stamped due backlog');

        Date currentMonth = Date.today().toStartOfMonth();
        FinanceCashflowDashboardController.MonthPoint cur = pointFor(data.portfolio, currentMonth);
        System.assertEquals(3000, cur.expected, 'Live line owns the current month');
        System.assertEquals(1500, cur.actual);
        System.assertEquals(true, cur.hasActual);

        FinanceCashflowDashboardController.MonthPoint last = pointFor(data.portfolio, currentMonth.addMonths(-1));
        System.assertEquals(800, last.expected, 'Frozen 200 USD baseline owns the past month (800 AED)');
        System.assertEquals(200, last.actual, '50 USD receipt as 200 AED');

        FinanceCashflowDashboardController.MonthPoint next = pointFor(data.portfolio, currentMonth.addMonths(1));
        System.assertEquals(1900, next.expected);
        System.assertEquals(false, next.hasActual, 'Future months have no actual point');
    }

    @IsTest
    static void projectScopesStayNative() {
        FinanceCashflowDashboardController.DashboardData data =
            FinanceCashflowDashboardController.getDashboardData();

        FinanceCashflowDashboardController.ProjectForecast bravo;
        for (FinanceCashflowDashboardController.ProjectForecast pf : data.projects) {
            if (pf.name == 'FCF Bravo') bravo = pf;
        }
        System.assertEquals('USD', bravo.currencyCode);
        Date nextMonth = Date.today().toStartOfMonth().addMonths(1);
        System.assertEquals(100, pointFor(bravo.months, nextMonth).expected, 'Kept in USD');
        Date lastMonth = Date.today().toStartOfMonth().addMonths(-1);
        System.assertEquals(50, pointFor(bravo.months, lastMonth).actual, 'Receipt kept in USD');
    }

    @IsTest
    static void escrowSplitClassifiesViaMetadata() {
        FinanceCashflowDashboardController.DashboardData data =
            FinanceCashflowDashboardController.getDashboardData();

        String curKey = FinanceCollectionStateService.monthKey(Date.today().toStartOfMonth());
        String lastKey = FinanceCollectionStateService.monthKey(Date.today().toStartOfMonth().addMonths(-1));
        FinanceCashflowDashboardController.EscrowMonth cur;
        FinanceCashflowDashboardController.EscrowMonth last;
        for (FinanceCashflowDashboardController.EscrowMonth em : data.escrow) {
            if (em.monthKey == curKey) cur = em;
            if (em.monthKey == lastKey) last = em;
        }
        System.assertEquals(500, cur.escrowAed, 'EI Escrow TR1 -> Escrow');
        System.assertEquals(1000, cur.operatingAed, 'Emirates NBD AED -> Operating');
        System.assertEquals(0, cur.cashAed);
        System.assertEquals(200, last.cashAed, 'Cash deposit, 50 USD as 200 AED');
    }

    @IsTest
    static void varianceRowsCompareFrozenBaselineToActuals() {
        FinanceCashflowDashboardController.DashboardData data =
            FinanceCashflowDashboardController.getDashboardData();

        System.assertEquals(2, data.variance.size(), 'One frozen baseline per started month');
        FinanceCashflowDashboardController.VarianceRow newest = data.variance[0];
        System.assertEquals('FCF Alpha', newest.projectName, 'Sorted newest month first');
        System.assertEquals(2500, newest.expected);
        System.assertEquals(1500, newest.actual);
        System.assertEquals(-1000, newest.varianceAmount);
        System.assertEquals(-40.0, newest.variancePct);

        FinanceCashflowDashboardController.VarianceRow bravo = data.variance[1];
        System.assertEquals('USD', bravo.currencyCode, 'Variance stays in project currency');
        System.assertEquals(200, bravo.expected);
        System.assertEquals(50, bravo.actual);
        System.assertEquals(-150, bravo.varianceAmount);
        System.assertEquals(-75.0, bravo.variancePct);
    }

    @IsTest
    static void slippageReasonOnlyOnFrozenLines() {
        Finance_Forecast_Line__c frozen = [SELECT Id FROM Finance_Forecast_Line__c WHERE Is_Frozen__c = true LIMIT 1];
        Finance_Forecast_Line__c live = [SELECT Id FROM Finance_Forecast_Line__c WHERE Is_Frozen__c = false LIMIT 1];

        Test.startTest();
        FinanceCashflowDashboardController.updateSlippageReason(frozen.Id, 'Handover slipped to next month.');
        Test.stopTest();

        System.assertEquals('Handover slipped to next month.',
            [SELECT Slippage_Reason__c FROM Finance_Forecast_Line__c WHERE Id = :frozen.Id].Slippage_Reason__c);

        try {
            FinanceCashflowDashboardController.updateSlippageReason(live.Id, 'nope');
            System.assert(false, 'Expected an exception for a live line');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('frozen'), e.getMessage());
        }
    }
}
