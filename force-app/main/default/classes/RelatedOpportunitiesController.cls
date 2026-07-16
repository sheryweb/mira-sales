public with sharing class RelatedOpportunitiesController {
    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getRelatedOpportunities(Id accountId) {
        return [
            SELECT Id, Name, StageName, CloseDate, Owner.Name, Agency__c
            FROM Opportunity
            WHERE Agency__c = :accountId
            ORDER BY CloseDate DESC
            LIMIT 100
        ];
    }
}