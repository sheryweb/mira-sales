public class OpportunityTriggerHandler {
    public static void handleBeforeInsertOrUpdate(List<Opportunity> opportunities) {
        Set<Id> ownerIds = new Set<Id>();
        for (Opportunity opp : opportunities) {
            if (opp.OwnerId != null) {
                ownerIds.add(opp.OwnerId);
            }
        }

        Map<Id, User> owners = new Map<Id, User>([SELECT Id, Name FROM User WHERE Id IN :ownerIds]);

        for (Opportunity opp : opportunities) {
            if (opp.OwnerId != null && owners.containsKey(opp.OwnerId)) {
                opp.Assigned_To__c = owners.get(opp.OwnerId).Name;
            }
        }
    }
}