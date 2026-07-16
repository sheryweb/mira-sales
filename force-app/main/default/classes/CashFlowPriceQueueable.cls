public without sharing class CashFlowPriceQueueable implements Queueable {
    private Set<Id> cashFlowIds;
    public CashFlowPriceQueueable (Set<Id> cfIds) {
        this.cashFlowIds = cfIds;
    }
    public void execute(QueueableContext context) {
        List<Cash_Flow__c> cashFlowsToUpdate = new List<Cash_Flow__c>();
        for (Cash_Flow__c cf : [
            SELECT Id, Price_Formula__c, Price_Dublication__c
            FROM Cash_Flow__c
            WHERE Id IN :cashFlowIds
        ]){
            if (cf.Price_Dublication__c != cf.Price_Formula__c){
                cf.Price_Dublication__c = cf.Price_Formula__c;
                cashFlowsToUpdate.add(cf);
            }
        }

        if (!cashFlowsToUpdate.isEmpty()){
            update cashFlowsToUpdate;
        }
    }
}