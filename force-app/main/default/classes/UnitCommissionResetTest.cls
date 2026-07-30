@isTest
private class UnitCommissionResetTest {

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
        Id commissionId;
    }

    private static TestRefs createSoldUnitWithCommission() {
        Account agency = new Account(
            Name = 'ResetTest Agency ' + String.valueOf(Crypto.getRandomLong()),
            Company_Email__c = 'resettest_' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
            Status__c = 'Completed',
            Skip_Trigger__c = true
        );
        Id rtId = getAccountRecordTypeId();
        if (rtId != null) agency.RecordTypeId = rtId;
        insert agency;

        Contact agent = new Contact(
            LastName = 'ResetTest Agent ' + String.valueOf(Crypto.getRandomLong()),
            AccountId = agency.Id
        );
        insert agent;

        // Units must be created in the Blocked (Draft) status, then moved to Sold.
        Unit__c unit = new Unit__c(Title__c = 'ResetTest Unit ' + String.valueOf(Crypto.getRandomLong()));
        insert unit;
        update new Unit__c(Id = unit.Id, Status__c = 'Sold');

        Opportunity opp = new Opportunity(
            Name = 'ResetTest Opp ' + String.valueOf(Crypto.getRandomLong()),
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = agency.Id,
            Agency__c = agency.Id,
            Assisted_by_Agent__c = true,
            Agent__c = agent.Id,
            Unit__c = unit.Id,
            Amount = 1000000
        );
        insert opp;

        Commission__c c = new Commission__c(
            Agency__c = agency.Id,
            Opportunity__c = opp.Id,
            Unit__c = unit.Id,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4
        );
        insert c;

        TestRefs refs = new TestRefs();
        refs.agencyId = agency.Id;
        refs.oppId = opp.Id;
        refs.unitId = unit.Id;
        refs.commissionId = c.Id;
        return refs;
    }

    @isTest
    static void testCancellationClearsUnitStatusAndKeepsCommissionUntouched() {
        TestRefs refs = createSoldUnitWithCommission();

        Unit__c unitBefore = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :refs.unitId];
        System.assertEquals('Unpaid', unitBefore.Commission_Status__c,
            'Commission insert should have marked the unit Unpaid');

        Test.startTest();
        update new Unit__c(Id = refs.unitId, Status__c = 'Draft');
        Test.stopTest();

        Commission__c saved = [SELECT Status__c, Manual_Override__c FROM Commission__c WHERE Id = :refs.commissionId];
        System.assertEquals('Eligible', saved.Status__c,
            'Commission keeps its current status when the unit sale is cancelled');
        System.assertEquals(null, saved.Manual_Override__c,
            'Cancellation must not touch the commission record');

        Unit__c unitAfter = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :refs.unitId];
        System.assertEquals(null, unitAfter.Commission_Status__c,
            'Unit commission status should be cleared so eligibility restarts from scratch');
    }

    @isTest
    static void testCancellationKeepsFullyPaidCommission() {
        TestRefs refs = createSoldUnitWithCommission();

        Commission__c beforePay = [
            SELECT Total_Commission_Amount__c, Commission_Amount__c
            FROM Commission__c
            WHERE Id = :refs.commissionId
        ];
        Decimal fullAmount = (beforePay.Total_Commission_Amount__c != null && beforePay.Total_Commission_Amount__c > 0)
            ? beforePay.Total_Commission_Amount__c
            : beforePay.Commission_Amount__c;
        update new Commission__c(Id = refs.commissionId, Paid_Amount__c = fullAmount);

        Test.startTest();
        update new Unit__c(Id = refs.unitId, Status__c = 'Draft');
        Test.stopTest();

        Commission__c saved = [SELECT Status__c FROM Commission__c WHERE Id = :refs.commissionId];
        System.assertEquals('Fully Paid', saved.Status__c,
            'Fully paid commissions are kept for audit history');

        Unit__c unitAfter = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :refs.unitId];
        System.assertEquals(null, unitAfter.Commission_Status__c,
            'Unit commission status is still cleared so a resale starts a fresh cycle');
    }

    @isTest
    static void testAlreadyCancelledCommissionIsUntouched() {
        TestRefs refs = createSoldUnitWithCommission();
        update new Commission__c(Id = refs.commissionId, Manual_Override__c = 'Cancelled');

        Test.startTest();
        update new Unit__c(Id = refs.unitId, Status__c = 'Draft');
        Test.stopTest();

        Commission__c saved = [SELECT Status__c FROM Commission__c WHERE Id = :refs.commissionId];
        System.assertEquals('Cancelled', saved.Status__c);

        Unit__c unitAfter = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :refs.unitId];
        System.assertEquals(null, unitAfter.Commission_Status__c);
    }

    @isTest
    static void testNonSoldStatusChangeDoesNotTouchCommission() {
        TestRefs refs = createSoldUnitWithCommission();

        Test.startTest();
        // Sold -> Sold with an unrelated field change: nothing should reset.
        update new Unit__c(Id = refs.unitId, Status__c = 'Sold', Description__c = 'Updated');
        Test.stopTest();

        Commission__c saved = [SELECT Status__c FROM Commission__c WHERE Id = :refs.commissionId];
        System.assertEquals('Eligible', saved.Status__c,
            'Commission must stay untouched while the unit remains Sold');

        Unit__c unitAfter = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :refs.unitId];
        System.assertEquals('Unpaid', unitAfter.Commission_Status__c);
    }

    @isTest
    static void testStatusChangeBetweenNonSoldValuesDoesNothing() {
        // Units must be created in the Blocked (Draft) status, then moved elsewhere.
        Unit__c unit = new Unit__c(
            Title__c = 'ResetTest NonSold ' + String.valueOf(Crypto.getRandomLong()),
            Commission_Status__c = 'Unpaid'
        );
        insert unit;
        update new Unit__c(Id = unit.Id, Status__c = 'Published');

        Test.startTest();
        update new Unit__c(Id = unit.Id, Status__c = 'Draft');
        Test.stopTest();

        Unit__c unitAfter = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals('Unpaid', unitAfter.Commission_Status__c,
            'Only a transition away from Sold resets commission tracking');
    }
}
