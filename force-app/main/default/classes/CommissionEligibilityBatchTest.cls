@isTest
private class CommissionEligibilityBatchTest {
    private static Id stubOpportunityId;


    private class EmptyDraftEvaluator implements CommissionEligibilityBatch.EligibilityEvaluator {
        public List<Commission__c> evaluate(Set<Id> agencyIds) {
            return new List<Commission__c>();
        }
    }

    private class DraftWithNoUnitEvaluator implements CommissionEligibilityBatch.EligibilityEvaluator {
        public List<Commission__c> evaluate(Set<Id> agencyIds) {
            Id agencyId = agencyIds.isEmpty() ? null : agencyIds.iterator().next();
            return new List<Commission__c>{
                new Commission__c(
                    Opportunity__c = stubOpportunityId,
                    Agency__c = agencyId,
                    Base_Amount__c = 1000,
                    Commission_Rate__c = 2,
                    Eligibility_Run_Date__c = System.now()
                )
            };
        }
    }

    private static Id getAccountRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> rtByDevName =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (rtByDevName.containsKey('Agency') && rtByDevName.get('Agency').isAvailable()) {
            return rtByDevName.get('Agency').getRecordTypeId();
        }
        return null;
    }

    @isTest
    static void testBatchExecutesWithoutError() {
        Id rtId = getAccountRecordTypeId();
        Account agency = new Account(
            Name = 'EligBatchTest Agency ' + String.valueOf(Crypto.getRandomLong()),
            Company_Email__c = 'eligbatch_' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
            Skip_Trigger__c = true
        );
        if (rtId != null) agency.RecordTypeId = rtId;
        insert agency;

        Test.startTest();
        Id batchId = Database.executeBatch(new CommissionEligibilityBatch(), 200);
        Test.stopTest();

        System.assertNotEquals(null, batchId, 'Batch should be queued successfully');
    }

    @isTest
    static void testExecuteWithNoDraftsDoesNothing() {
        Id rtId = getAccountRecordTypeId();
        Account agency = new Account(
            Name = 'EligBatch NoDrafts ' + String.valueOf(Crypto.getRandomLong()),
            Company_Email__c = 'eligbatch_nodraft_' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
            Skip_Trigger__c = true
        );
        if (rtId != null) agency.RecordTypeId = rtId;
        insert agency;

        CommissionEligibilityBatch.evaluator = new EmptyDraftEvaluator();
        Test.startTest();
        new CommissionEligibilityBatch().execute(null, new List<Account>{ agency });
        Test.stopTest();

        System.assertEquals(0, [SELECT count() FROM Commission__c WHERE Agency__c = :agency.Id]);
        CommissionEligibilityBatch.resetEvaluator();
    }

    @isTest
    static void testExecuteInsertsDraftWhenEvaluatorReturnsRows() {
        Id rtId = getAccountRecordTypeId();
        Account agency = new Account(
            Name = 'EligBatch Insert ' + String.valueOf(Crypto.getRandomLong()),
            Company_Email__c = 'eligbatch_insert_' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
            Skip_Trigger__c = true
        );
        if (rtId != null) agency.RecordTypeId = rtId;
        insert agency;

        Opportunity opp = new Opportunity(
            Name = 'Batch Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = agency.Id
        );
        insert opp;
        stubOpportunityId = opp.Id;

        CommissionEligibilityBatch.evaluator = new DraftWithNoUnitEvaluator();
        Test.startTest();
        new CommissionEligibilityBatch().execute(null, new List<Account>{ agency });
        Test.stopTest();

        System.assertEquals(1, [SELECT count() FROM Commission__c WHERE Agency__c = :agency.Id]);
        CommissionEligibilityBatch.resetEvaluator();
    }
}