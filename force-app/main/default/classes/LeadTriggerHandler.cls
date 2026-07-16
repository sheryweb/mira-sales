public class LeadTriggerHandler {

    // Record Type IDs (you can also fetch dynamically if you prefer)
    private static final Id DATABASE_RT_ID = '012Rg000004MLB8IAO'; //Production
    private static final Id MASTER_RT_ID   = '012Rg000004MNYLIA4'; //Production
    //private static final Id DATABASE_RT_ID = '012U9000001VJQnIAO'; //SandBox
    //private static final Id MASTER_RT_ID   = '012U9000001VCnVIAW'; //SandBox

    public static void assignRecordTypes(List<Lead> newLeads, Map<Id, Lead> oldLeads) {
        for (Lead lead : newLeads) {
            String funnelType = lead.Funnel_Type__c;

            // Handle insert
            if (oldLeads == null) {
                lead.RecordTypeId = (funnelType == 'Database') ? DATABASE_RT_ID : MASTER_RT_ID;
            }
            // Handle update only if Funnel Type changed
            else {
                Lead oldLead = oldLeads.get(lead.Id);
                if (lead.Funnel_Type__c != oldLead.Funnel_Type__c) {
                    lead.RecordTypeId = (funnelType == 'Database') ? DATABASE_RT_ID : MASTER_RT_ID;
                }
            }
        }
    }
}