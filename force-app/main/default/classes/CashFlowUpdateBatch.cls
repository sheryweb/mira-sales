public class CashFlowUpdateBatch implements Database.Batchable<SObject>, Database.Stateful {
    public Database.QueryLocator start(Database.BatchableContext BC) {
        System.debug('Start method invoked');
        return Database.getQueryLocator(
            [SELECT Id, Unit__c, Date__c, Installment_Milestone__c 
             FROM Cash_Flow__c 
             WHERE Installment_Milestone__c = NULL]
        );
    }
    
    public void execute(Database.BatchableContext BC, List<Cash_Flow__c> scope) {
        System.debug('Execute method invoked with scope size: ' + scope.size());
        for (Cash_Flow__c cashFlow : scope) {
            System.debug('Processing record: ' + cashFlow.Id);
        }
    }

    // Final steps after all batches are processed
    public void finish(Database.BatchableContext BC) {
        // Optional: Add logging or notifications here
    }
}