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

    public static void handleAfterInsert(List<Opportunity> opportunities) {
        Set<Id> opportunityIds = new Set<Id>();
        for (Opportunity opp : opportunities) {
            if (opp.OwnerId != null) {
                opportunityIds.add(opp.Id);
            }
        }
        RMDealCreditService.rebuildForOpportunityIds(opportunityIds);
    }

    public static void handleAfterUpdate(
        List<Opportunity> opportunities,
        Map<Id, Opportunity> oldMap
    ) {
        Set<Id> opportunityIds = new Set<Id>();
        for (Opportunity opp : opportunities) {
            Opportunity oldOpp = oldMap.get(opp.Id);
            if (oldOpp == null) {
                continue;
            }
            Boolean ownerChanged = opp.OwnerId != oldOpp.OwnerId;
            Boolean shareChanged =
                opp.Share_Deal__c != oldOpp.Share_Deal__c ||
                opp.Shared_RM__c != oldOpp.Shared_RM__c;
            if (ownerChanged || shareChanged) {
                opportunityIds.add(opp.Id);
            }
        }
        RMDealCreditService.rebuildForOpportunityIds(opportunityIds);
    }
}
