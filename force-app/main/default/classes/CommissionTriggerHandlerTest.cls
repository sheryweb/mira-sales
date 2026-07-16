@isTest
private class CommissionTriggerHandlerTest {

    /**
     * Resolve a RecordTypeId for Account dynamically. Falls back to null if no
     * record type is available so the test does not break across environments.
     */
    private static Id getAccountRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> rtByDevName =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

        if (rtByDevName.containsKey('Agency') && rtByDevName.get('Agency').isAvailable()) {
            return rtByDevName.get('Agency').getRecordTypeId();
        }
        for (Schema.RecordTypeInfo info : rtByDevName.values()) {
            if (info.isAvailable() && !info.isMaster()) {
                return info.getRecordTypeId();
            }
        }
        return null;
    }

    private class TestRefs {
        Id agencyId;
        Id oppId;
        Id unitId;
    }

    private static TestRefs createTestData() {
        Account agency = new Account(
            Name = 'CommTest Agency ' + String.valueOf(Crypto.getRandomLong()),
            Company_Email__c = 'commtest_' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
            Skip_Trigger__c = true
        );
        Id rtId = getAccountRecordTypeId();
        if (rtId != null) {
            agency.RecordTypeId = rtId;
        }
        insert agency;

        Opportunity opp = new Opportunity(
            Name = 'CommTest Opp ' + String.valueOf(Crypto.getRandomLong()),
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = agency.Id
        );
        insert opp;

        TestRefs refs = new TestRefs();
        refs.agencyId = agency.Id;
        refs.oppId = opp.Id;
        return refs;
    }

    private static TestRefs createTestDataWithUnit() {
        TestRefs refs = createTestData();

        Unit__c unit = new Unit__c(Title__c = 'CommTest Unit ' + String.valueOf(Crypto.getRandomLong()));
        insert unit;
        refs.unitId = unit.Id;

        Opportunity opp = new Opportunity(
            Name = 'CommTest Unit Opp ' + String.valueOf(Crypto.getRandomLong()),
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = refs.agencyId,
            Agency__c = refs.agencyId,
            Unit__c = unit.Id,
            Amount = 1000000
        );
        insert opp;
        refs.oppId = opp.Id;
        return refs;
    }

    @isTest
    static void testCommissionAmountCalculatedOnInsert() {
        TestRefs refs = createTestData();

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        Commission__c saved = [SELECT Commission_Amount__c, Status__c FROM Commission__c WHERE Id = :c.Id];
        System.assertEquals(40000, saved.Commission_Amount__c, 'Commission_Amount__c should be 1,000,000 * 4% = 40,000');
        System.assertEquals('Eligible', saved.Status__c, 'Status__c should be Eligible when no invoice yet');
    }

    @isTest
    static void testManualCommissionAmountNotOverwritten() {
        TestRefs refs = createTestData();

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4,
            Commission_Amount__c = 50000
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        Commission__c saved = [SELECT Commission_Amount__c FROM Commission__c WHERE Id = :c.Id];
        System.assertEquals(50000, saved.Commission_Amount__c, 'Manual Commission_Amount__c should not be overwritten');
    }

    @isTest
    static void testManualOverrideOnHold() {
        TestRefs refs = createTestData();

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4
        );
        insert c;

        c.Manual_Override__c = 'On Hold';
        Test.startTest();
        update c;
        Test.stopTest();

        Commission__c saved = [SELECT Status__c FROM Commission__c WHERE Id = :c.Id];
        System.assertEquals('On Hold', saved.Status__c);
    }

    @isTest
    static void testManualOverrideCancelled() {
        TestRefs refs = createTestData();

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Base_Amount__c = 500000,
            Commission_Rate__c = 3
        );
        insert c;

        c.Manual_Override__c = 'Cancelled';
        Test.startTest();
        update c;
        Test.stopTest();

        Commission__c saved = [SELECT Status__c FROM Commission__c WHERE Id = :c.Id];
        System.assertEquals('Cancelled', saved.Status__c);
    }

    @isTest
    static void testStatusInvoicedWhenInvoiceLinkedAndNoPayment() {
        TestRefs refs = createTestData();

        Invoice__c inv = new Invoice__c();
        insert inv;

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4,
            Invoice__c = inv.Id,
            Paid_Amount__c = 0
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        Commission__c saved = [SELECT Status__c FROM Commission__c WHERE Id = :c.Id];
        System.assertEquals('Invoiced', saved.Status__c, 'With invoice but no payment, status should be Invoiced');
    }

    @isTest
    static void testStatusPartiallyPaid() {
        TestRefs refs = createTestData();

        Invoice__c inv = new Invoice__c();
        insert inv;

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4,
            Invoice__c = inv.Id,
            Paid_Amount__c = 10000
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        Commission__c saved = [SELECT Status__c FROM Commission__c WHERE Id = :c.Id];
        System.assertEquals('Partially Paid', saved.Status__c, 'Paid > 0 but < Commission_Amount should yield Partially Paid');
    }

    @isTest
    static void testStatusFullyPaid() {
        TestRefs refs = createTestData();

        Invoice__c inv = new Invoice__c();
        insert inv;

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4,
            Invoice__c = inv.Id
        );
        insert c;

        c.Paid_Amount__c = 40000;
        Test.startTest();
        update c;
        Test.stopTest();

        Commission__c saved = [SELECT Status__c FROM Commission__c WHERE Id = :c.Id];
        System.assertEquals('Fully Paid', saved.Status__c, 'Paid >= Total_Commission_Amount should yield Fully Paid');
    }

    @isTest
    static void testManualOverrideClearedReturnsToEligible() {
        TestRefs refs = createTestData();

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Base_Amount__c = 100000,
            Commission_Rate__c = 5,
            Manual_Override__c = 'On Hold'
        );
        insert c;

        c.Manual_Override__c = null;
        Test.startTest();
        update c;
        Test.stopTest();

        Commission__c saved = [SELECT Status__c FROM Commission__c WHERE Id = :c.Id];
        System.assertEquals('Eligible', saved.Status__c, 'Clearing override returns status to Eligible (no invoice yet)');
    }

    @isTest
    static void testCommissionAmountRecalculatedWhenRateChangesOnUpdate() {
        TestRefs refs = createTestData();

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4
        );
        insert c;

        c.Commission_Rate__c = 5;
        Test.startTest();
        update c;
        Test.stopTest();

        Commission__c saved = [SELECT Commission_Amount__c FROM Commission__c WHERE Id = :c.Id];
        System.assertEquals(50000, saved.Commission_Amount__c, 'Rate change should recalculate commission amount');
    }

    @isTest
    static void testHandleBeforeInsertOrUpdateSingleArgOverload() {
        TestRefs refs = createTestData();

        Commission__c draft = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Base_Amount__c = 200000,
            Commission_Rate__c = 10
        );

        Test.startTest();
        CommissionTriggerHandler.handleBeforeInsertOrUpdate(new List<Commission__c>{ draft });
        Test.stopTest();

        System.assertEquals(20000, draft.Commission_Amount__c);
        System.assertEquals('Eligible', draft.Status__c);
    }

    @isTest
    static void testSyncUnitStatusOnInsertSetsUnpaid() {
        TestRefs refs = createTestDataWithUnit();

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Unit__c = refs.unitId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        Unit__c unit = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :refs.unitId];
        System.assertEquals('Unpaid', unit.Commission_Status__c);
    }

    @isTest
    static void testSyncUnitStatusOnUpdateToPartiallyPaid() {
        TestRefs refs = createTestDataWithUnit();

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Unit__c = refs.unitId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4
        );
        insert c;

        c.Paid_Amount__c = 10000;
        Test.startTest();
        update c;
        Test.stopTest();

        Unit__c unit = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :refs.unitId];
        System.assertEquals('Partially Paid', unit.Commission_Status__c);
    }

    @isTest
    static void testSyncUnitStatusOnUpdateToPaid() {
        TestRefs refs = createTestDataWithUnit();

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Unit__c = refs.unitId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4
        );
        insert c;

        Commission__c beforePay = [
            SELECT Total_Commission_Amount__c, Commission_Amount__c
            FROM Commission__c
            WHERE Id = :c.Id
        ];
        Decimal fullAmount = (beforePay.Total_Commission_Amount__c != null && beforePay.Total_Commission_Amount__c > 0)
            ? beforePay.Total_Commission_Amount__c
            : beforePay.Commission_Amount__c;

        c.Paid_Amount__c = fullAmount;
        Test.startTest();
        update c;
        Test.stopTest();

        Unit__c unit = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :refs.unitId];
        System.assertEquals('Paid', unit.Commission_Status__c);
    }

    @isTest
    static void testHandleAfterInsertAndUpdateDirectly() {
        TestRefs refs = createTestDataWithUnit();

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Unit__c = refs.unitId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4
        );
        insert c;

        Commission__c current = [
            SELECT Id, Unit__c, Status__c, Paid_Amount__c, Commission_Rate__c, Base_Amount__c,
                   Manual_Override__c, Total_Commission_Amount__c, Invoice__c, Commission_Amount__c
            FROM Commission__c
            WHERE Id = :c.Id
        ];
        Commission__c oldSnapshot = current.clone(true, true, true, true);

        Test.startTest();
        CommissionTriggerHandler.handleAfterInsert(new List<Commission__c>{ current });
        current.Paid_Amount__c = 5000;
        CommissionTriggerHandler.handleBeforeInsertOrUpdate(
            new List<Commission__c>{ current },
            new Map<Id, Commission__c>{ current.Id => oldSnapshot }
        );
        CommissionTriggerHandler.handleAfterUpdate(
            new List<Commission__c>{ current },
            new Map<Id, Commission__c>{ current.Id => oldSnapshot }
        );
        Test.stopTest();

        Unit__c unit = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :refs.unitId];
        System.assertEquals('Partially Paid', unit.Commission_Status__c);
    }

    @isTest
    static void testSyncSkipsWhenStatusAndUnitUnchangedOnUpdate() {
        TestRefs refs = createTestDataWithUnit();

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Unit__c = refs.unitId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4
        );
        insert c;

        Unit__c unitAfterInsert = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :refs.unitId];
        System.assertEquals('Unpaid', unitAfterInsert.Commission_Status__c);

        Commission__c before = [
            SELECT Id, Unit__c, Status__c, Base_Amount__c, Commission_Rate__c,
                   Manual_Override__c, Paid_Amount__c, Total_Commission_Amount__c, Invoice__c, Commission_Amount__c
            FROM Commission__c
            WHERE Id = :c.Id
        ];
        Commission__c oldSnapshot = before.clone(true, true, true, true);
        before.Base_Amount__c = 1100000;

        Test.startTest();
        CommissionTriggerHandler.handleBeforeInsertOrUpdate(
            new List<Commission__c>{ before },
            new Map<Id, Commission__c>{ before.Id => oldSnapshot }
        );
        CommissionTriggerHandler.handleAfterUpdate(
            new List<Commission__c>{ before },
            new Map<Id, Commission__c>{ before.Id => oldSnapshot }
        );
        Test.stopTest();

        Unit__c unitAfterNoStatusChange = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :refs.unitId];
        System.assertEquals('Unpaid', unitAfterNoStatusChange.Commission_Status__c);
    }

    @isTest
    static void testCancelledCommissionDoesNotSyncUnitStatus() {
        TestRefs refs = createTestDataWithUnit();

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Unit__c = refs.unitId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4,
            Manual_Override__c = 'Cancelled'
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        Unit__c unit = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :refs.unitId];
        System.assertEquals(null, unit.Commission_Status__c, 'Cancelled maps to no unit status');
    }

    @isTest
    static void testCommissionWithoutUnitSkipsSync() {
        TestRefs refs = createTestData();

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4
        );

        Test.startTest();
        insert c;
        CommissionTriggerHandler.handleAfterInsert(new List<Commission__c>{ c });
        Test.stopTest();

        System.assertNotEquals(null, c.Id);
    }

    @isTest
    static void testOnHoldSyncsUnitToUnpaid() {
        TestRefs refs = createTestDataWithUnit();

        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Unit__c = refs.unitId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4,
            Manual_Override__c = 'On Hold'
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        Unit__c unit = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :refs.unitId];
        System.assertEquals('Unpaid', unit.Commission_Status__c);
    }
}