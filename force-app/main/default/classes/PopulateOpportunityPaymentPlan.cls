public class PopulateOpportunityPaymentPlan {
    
    @InvocableMethod(label='Populate Opportunity Payment Plan' description='Populate Opportunity Payment Plan')
    public static void PopulatePaymentPlan(List<FlowParams> params) {
        List<Cash_Flow__c> csflow = [SELECT Id, Name, Date__c, Percent__c FROM Cash_Flow__c WHERE Unit__c = :params[0].UnitId];
        
        List<Opportunity_Payment_Plan__c> recordsToInsert = new List<Opportunity_Payment_Plan__c>();
        
        for (Cash_Flow__c cf: csflow) {
            Opportunity_Payment_Plan__c opplan = new Opportunity_Payment_Plan__c(
                OpportunityId__c = params[0].OpportunityId,
                UnitId__c = params[0].UnitId,
                Name = cf.Name,
                Date__c = cf.Date__c,
                Percent__c = cf.Percent__c
            );
            recordsToInsert.add(opplan);
        }
        insert recordsToInsert;
    }
	public class FlowParams {
        @invocableVariable
        public Id UnitId;
        
        @invocableVariable
        public Id OpportunityId;
    }
}