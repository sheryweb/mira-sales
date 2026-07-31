/**
 * Rebuilds RM_Deal_Credit__c rows for Opportunities in scope.
 * Use with empty constructor for all Opportunities, or pass a specific Id set.
 */
public without sharing class RMDealCreditRebuildBatch implements Database.Batchable<SObject> {
    private Set<Id> opportunityIds;

    public RMDealCreditRebuildBatch() {
        this.opportunityIds = null;
    }

    public RMDealCreditRebuildBatch(Set<Id> opportunityIds) {
        this.opportunityIds = opportunityIds;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (opportunityIds != null && !opportunityIds.isEmpty()) {
            return Database.getQueryLocator([
                SELECT Id
                FROM Opportunity
                WHERE Id IN :opportunityIds
            ]);
        }
        return Database.getQueryLocator([
            SELECT Id
            FROM Opportunity
            WHERE OwnerId != null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        Set<Id> ids = new Set<Id>();
        for (SObject row : scope) {
            ids.add(row.Id);
        }
        RMDealCreditService.rebuildForOpportunityIds(ids);
    }

    public void finish(Database.BatchableContext bc) {
    }
}
