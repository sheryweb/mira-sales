public with sharing class ApprovalComparisonController {
    @AuraEnabled(cacheable=true)
    public static String getRequestType(Id recordId) {
        Id resolvedId = UnitPriceComparisonReader.resolveApprovalRequestId(recordId);
        if (resolvedId == null) {
            return null;
        }

        List<Approval_Request__c> requests = [
            SELECT Request_Type__c
            FROM Approval_Request__c
            WHERE Id = :resolvedId
            LIMIT 1
        ];
        return requests.isEmpty() ? null : requests[0].Request_Type__c;
    }
}