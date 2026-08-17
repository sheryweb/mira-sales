/**
 * Tests for FinanceCollectionStateService — the derive/stamp core and the intraday hooks.
 *
 * Fixture pattern mirrors FinancialEngineTest: units with no cost, cash flows priced via
 * Constant__c (Price_Formula__c short-circuits to Constant when non-zero), Remaining_Amount__c
 * therefore = Constant − Received_Amount__c (no VAT set).
 */
@IsTest
private class FinanceCollectionStateServiceTest {

    // ---- helpers -------------------------------------------------------------

    private static Unit__c makeUnit(String title) {
        Unit__c u = new Unit__c(Title__c = title);
        insert u;
        return u;
    }

    private static Cash_Flow_Sum__c makeSum(Id unitId) {
        Cash_Flow_Sum__c s = new Cash_Flow_Sum__c(Name = 'CFS', Unit__c = unitId);
        insert s;
        return s;
    }

    private static Cash_Flow__c makeCF(Id unitId, Id sumId, String name, Integer daysOffset,
                                       Decimal price, Decimal received) {
        return new Cash_Flow__c(
            Name = name,
            Unit__c = unitId,
            Cash_Flow_Sum__c = sumId,
            Date__c = System.today().addDays(daysOffset),
            Constant__c = price,
            Received_Amount__c = received
        );
    }

    private static Unit__c reload(Id unitId) {
        return [SELECT Id, Due_Amount__c, Not_Yet_Due_Amount__c, Overdue_Days_Max__c,
                       Missed_Instalments__c, Collection_Health__c, Collection_State_As_Of__c
                FROM Unit__c WHERE Id = :unitId];
    }

    private static void enableEngine() {
        insert new Financial_Engine_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Engine_Owns_Totals__c = true
        );
    }

    // ---- derive + stamp --------------------------------------------------------

    @IsTest
    static void dueSplitAndOverdueHealth() {
        Unit__c u = makeUnit('u1');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        insert new List<Cash_Flow__c>{
            makeCF(u.Id, s.Id, 'M1', -10, 1000, 0),
            makeCF(u.Id, s.Id, 'M2', 40, 2000, 0)
        };

        Test.startTest();
        FinanceCollectionStateService.stampUnits(new Set<Id>{ u.Id });
        Test.stopTest();

        Unit__c stamped = reload(u.Id);
        System.assertEquals(1000, stamped.Due_Amount__c, 'Past-dated remaining is due');
        System.assertEquals(2000, stamped.Not_Yet_Due_Amount__c, 'Future remaining is not yet due');
        System.assertEquals(10, stamped.Overdue_Days_Max__c, 'Oldest unpaid due instalment age');
        System.assertEquals(1, stamped.Missed_Instalments__c, 'One missed instalment');
        System.assertEquals(FinanceCollectionStateService.HEALTH_OVERDUE, stamped.Collection_Health__c);
        System.assertNotEquals(null, stamped.Collection_State_As_Of__c, 'As-of stamped on change');
    }

    @IsTest
    static void fullyPaidWhenNothingRemains() {
        Unit__c u = makeUnit('u2');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        insert makeCF(u.Id, s.Id, 'M1', -10, 1000, 1000);

        FinanceCollectionStateService.stampUnits(new Set<Id>{ u.Id });

        Unit__c stamped = reload(u.Id);
        System.assertEquals(0, stamped.Due_Amount__c);
        System.assertEquals(0, stamped.Not_Yet_Due_Amount__c);
        System.assertEquals(FinanceCollectionStateService.HEALTH_FULLY_PAID, stamped.Collection_Health__c);
    }

    @IsTest
    static void onTrackWhenOnlyFutureRemains() {
        Unit__c u = makeUnit('u3');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        insert makeCF(u.Id, s.Id, 'M1', 15, 500, 0);

        FinanceCollectionStateService.stampUnits(new Set<Id>{ u.Id });

        System.assertEquals(FinanceCollectionStateService.HEALTH_ON_TRACK,
            reload(u.Id).Collection_Health__c);
    }

    @IsTest
    static void defaultedNeedsAgeAndMissedCount() {
        Unit__c u = makeUnit('u4');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        insert new List<Cash_Flow__c>{
            makeCF(u.Id, s.Id, 'M1', -100, 100, 0),
            makeCF(u.Id, s.Id, 'M2', -95, 100, 0),
            makeCF(u.Id, s.Id, 'M3', -91, 100, 0)
        };

        FinanceCollectionStateService.stampUnits(new Set<Id>{ u.Id });

        Unit__c stamped = reload(u.Id);
        System.assertEquals(3, stamped.Missed_Instalments__c);
        System.assertEquals(100, stamped.Overdue_Days_Max__c);
        System.assertEquals(FinanceCollectionStateService.HEALTH_DEFAULTED, stamped.Collection_Health__c,
            '90+ days AND more than 2 missed instalments = Defaulted');
    }

    @IsTest
    static void twoMissedInstalmentsIsOverdueNotDefaulted() {
        Unit__c u = makeUnit('u5');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        insert new List<Cash_Flow__c>{
            makeCF(u.Id, s.Id, 'M1', -120, 100, 0),
            makeCF(u.Id, s.Id, 'M2', -100, 100, 0)
        };

        FinanceCollectionStateService.stampUnits(new Set<Id>{ u.Id });

        System.assertEquals(FinanceCollectionStateService.HEALTH_OVERDUE,
            reload(u.Id).Collection_Health__c, '2 missed is not "more than 2"');
    }

    @IsTest
    static void registrationItemsCountInDueButNotInMissed() {
        Unit__c u = makeUnit('u6');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        // Name contains 'DLD Fee' (registration pool) but is not exactly 'DLD Fee', so
        // Price_Formula__c still resolves to Constant__c.
        insert makeCF(u.Id, s.Id, 'DLD Fee 1', -30, 3150, 0);

        FinanceCollectionStateService.stampUnits(new Set<Id>{ u.Id });

        Unit__c stamped = reload(u.Id);
        System.assertEquals(3150, stamped.Due_Amount__c, 'Registration due money counts as due (SOA parity)');
        System.assertEquals(0, stamped.Missed_Instalments__c, 'Registration items are not missed instalments');
        System.assertEquals(0, stamped.Overdue_Days_Max__c);
        System.assertEquals(FinanceCollectionStateService.HEALTH_OVERDUE, stamped.Collection_Health__c);
    }

    @IsTest
    static void noPlanMeansBlankHealthAndNoStamp() {
        Unit__c u = makeUnit('u7');

        FinanceCollectionStateService.stampUnits(new Set<Id>{ u.Id });

        Unit__c stamped = reload(u.Id);
        System.assertEquals(null, stamped.Collection_Health__c, 'No priced plan -> blank health');
        System.assertEquals(null, stamped.Collection_State_As_Of__c, 'Nothing changed -> no write');
    }

    @IsTest
    static void deriveBuildsForecastByMonth() {
        Unit__c u = makeUnit('u8');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        insert new List<Cash_Flow__c>{
            makeCF(u.Id, s.Id, 'M1', 0, 1000, 0),   // due today: due AND expected this month
            makeCF(u.Id, s.Id, 'M2', 40, 2000, 250) // future, partially paid
        };

        Map<Id, FinanceCollectionStateService.UnitState> states =
            FinanceCollectionStateService.deriveForUnits(new Set<Id>{ u.Id });

        FinanceCollectionStateService.UnitState st = states.get(u.Id);
        String thisMonth = FinanceCollectionStateService.monthKey(System.today());
        String futureMonth = FinanceCollectionStateService.monthKey(System.today().addDays(40));
        System.assertEquals(1000, st.dueAmount);
        System.assertEquals(1000, st.futureByMonth.get(thisMonth),
            'Due-today money still counts as expected this month');
        System.assertEquals(1750, st.futureByMonth.get(futureMonth), 'Unpaid remaining only');
    }

    // ---- intraday hooks ----------------------------------------------------------

    @IsTest
    static void planEditRestampsViaCashFlowTrigger() {
        Unit__c u = makeUnit('u9');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        Cash_Flow__c cf = makeCF(u.Id, s.Id, 'M1', 30, 800, 0);
        insert cf;
        // Fixture DML above already queued (discarded) stamp jobs and marked the unit as
        // handled for this transaction — clear the guard so the action under test re-queues.
        FinanceCollectionStateService.stampedThisTransaction.clear();

        Test.startTest();
        cf.Date__c = System.today().addDays(-5); // pull the instalment into the past
        update cf;
        Test.stopTest(); // queued StampJob runs here

        Unit__c stamped = reload(u.Id);
        System.assertEquals(800, stamped.Due_Amount__c, 'Plan edit re-stamped the unit');
        System.assertEquals(FinanceCollectionStateService.HEALTH_OVERDUE, stamped.Collection_Health__c);
    }

    @IsTest
    static void receiptRestampsViaEngineHandlerHook() {
        enableEngine();
        Unit__c u = makeUnit('u10');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        Cash_Flow__c cf = makeCF(u.Id, s.Id, 'M1', -5, 1000, 0);
        insert cf;
        Invoice__c inv = new Invoice__c(
            Status__c = 'Pending', Invoice_Date__c = System.today(),
            Sub_Total_Amount__c = 1000, Paid_Amount__c = 0,
            Unit__c = u.Id, Invoice_Number__c = 'INV-FCS-1'
        );
        insert inv;
        insert new Milestone_Invoice__c(Invoice__c = inv.Id, Cash_Flow__c = cf.Id);
        FinanceCollectionStateService.stampedThisTransaction.clear(); // see planEdit test note

        Test.startTest();
        Receipt__c r = new Receipt__c(
            Description__c = 'R', Unit__c = u.Id, Payment_Date__c = System.today(),
            Received_Amount__c = 0, Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid'
        );
        insert r;
        insert new Receipt_Amount__c(Receipt__c = r.Id, Invoice__c = inv.Id, Amount__c = 1000);
        Test.stopTest(); // engine applied synchronously; StampJob runs here with fresh state

        Unit__c stamped = reload(u.Id);
        System.assertEquals(0, stamped.Due_Amount__c, 'Payment cleared the due amount');
        System.assertEquals(FinanceCollectionStateService.HEALTH_FULLY_PAID, stamped.Collection_Health__c);
    }

    @IsTest
    static void enqueueStampDedupesPerTransaction() {
        Unit__c u = makeUnit('u11');
        Set<Id> ids = new Set<Id>{ u.Id };

        Test.startTest();
        Integer before = Limits.getQueueableJobs();
        FinanceCollectionStateService.enqueueStamp(ids);
        FinanceCollectionStateService.enqueueStamp(ids);
        Integer after = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(1, after - before, 'Second call for the same unit queues nothing');
    }
}
