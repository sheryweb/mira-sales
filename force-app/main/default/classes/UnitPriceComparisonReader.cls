/**
 * Without-sharing queries for unit price comparison display on approval pages.
 */
public without sharing class UnitPriceComparisonReader {

    public static Id resolveApprovalRequestId(Id recordId) {
        return PaymentPlanComparisonReader.resolveApprovalRequestId(recordId);
    }

    public static List<Approval_Request__c> queryRequest(Id requestId) {
        return [
            SELECT Id, Name, Status__c, Justification__c, Unit__c, Request_Type__c,
                   Requester__r.Name, Price_Currency__c, Current_Price__c, Requested_Price__c,
                   Current_Cost_AED__c, Requested_Cost_AED__c, Conversion_Rate__c,
                   Discount_Percent__c
            FROM Approval_Request__c
            WHERE Id = :requestId
            LIMIT 1
        ];
    }

    public static List<Unit__c> queryUnit(Id unitId) {
        return [
            SELECT Id, Title__c, Project_Name_F__c, Building__c, Account__r.Name
            FROM Unit__c
            WHERE Id = :unitId
            LIMIT 1
        ];
    }

    public static Unit__c queryUnitForApplyValidation(Id unitId) {
        List<Unit__c> units = [
            SELECT Id, Status__c
            FROM Unit__c
            WHERE Id = :unitId
            LIMIT 1
        ];
        return units.isEmpty() ? null : units[0];
    }

    public static void applyUnitPriceToUnit(Unit__c unit) {
        update unit;
    }

    public static void markRequestApplied(Id approvalRequestId) {
        update new Approval_Request__c(
            Id = approvalRequestId,
            Status__c = 'Applied'
        );
    }
}