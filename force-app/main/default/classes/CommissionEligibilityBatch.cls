public class CommissionEligibilityBatch implements Database.Batchable<sObject> {
    public interface EligibilityEvaluator {
        List<Commission__c> evaluate(Set<Id> agencyIds);
    }

    private class DefaultEligibilityEvaluator implements EligibilityEvaluator {
        public List<Commission__c> evaluate(Set<Id> agencyIds) {
            return CommissionEligibilityService.evaluate(agencyIds);
        }
    }

    @TestVisible
    private static EligibilityEvaluator evaluator = new DefaultEligibilityEvaluator();

    @TestVisible
    private static void resetEvaluator() {
        evaluator = new DefaultEligibilityEvaluator();
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Id agencyRTId = getAgencyRecordTypeId();
        if (agencyRTId == null) {
            return Database.getQueryLocator([SELECT Id FROM Account WHERE Id = null]);
        }
        return Database.getQueryLocator([
            SELECT Id FROM Account WHERE RecordTypeId = :agencyRTId
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Account> agencies) {
        Set<Id> agencyIds = new Map<Id, Account>(agencies).keySet();
        List<Commission__c> drafts = evaluator.evaluate(agencyIds);
        if (!drafts.isEmpty()) {
            insert drafts;

            Set<Id> unitIds = new Set<Id>();
            for (Commission__c c : drafts) {
                if (c.Unit__c != null) unitIds.add(c.Unit__c);
            }
            if (!unitIds.isEmpty()) {
                List<Unit__c> unitsToFlag = new List<Unit__c>();
                for (Id unitId : unitIds) {
                    unitsToFlag.add(new Unit__c(Id = unitId, Commission_Status__c = 'Unpaid'));
                }
                update unitsToFlag;
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
    }

    private static Id getAgencyRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> rtByDevName =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (rtByDevName.containsKey('Agency') && rtByDevName.get('Agency').isAvailable()) {
            return rtByDevName.get('Agency').getRecordTypeId();
        }
        return null;
    }
}