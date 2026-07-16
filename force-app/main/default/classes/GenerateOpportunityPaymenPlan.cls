public class GenerateOpportunityPaymenPlan {
    @InvocableMethod(label='Generate Opportunity Payment Plan' description='Generate Opportunity Payment Plan')
    public static void AddPaymentPlan(List<FlowParams> params) {
        List<Payment_Plan__c> payplan = [SELECT Id, Name, Date__c, Percent__c FROM Payment_Plan__c WHERE Project__c = :params[0].ProjectId];
        
        List<Opportunity_Payment_Plan__c> recordsToInsert = new List<Opportunity_Payment_Plan__c>();
        List<Cash_Flow__c> cashFlowToInsert = new List<Cash_Flow__c>();
        
        for (Payment_Plan__c pl: payplan) {
            Opportunity_Payment_Plan__c opplan = new Opportunity_Payment_Plan__c(
                OpportunityId__c = params[0].OpportunityId,
                UnitId__c = params[0].UnitId,
                Name = pl.Name,
                Date__c = pl.Date__c,
                Percent__c = pl.Percent__c
            );
            recordsToInsert.add(opplan);
            
            Cash_Flow__c cf = new Cash_Flow__c(
            	Unit__c = params[0].UnitId,
                Name = pl.Name,
                Date__c = pl.Date__c,
                Percent__c = pl.Percent__c
            );
        }
        insert recordsToInsert;
    }
    
    public class FlowParams {
        @invocableVariable
        public Id ProjectId;
        
        @invocableVariable
        public Id OpportunityId;
        
        @invocableVariable
        public Id UnitId;
    }
}