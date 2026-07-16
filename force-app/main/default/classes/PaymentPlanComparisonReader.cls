/**
 * Runs without sharing so approvers can always read the comparison data
 * regardless of the Approval_Request__c OWD / sharing rules.
 */
public without sharing class PaymentPlanComparisonReader {

    private static final Set<String> EXCLUDED_MILESTONES = new Set<String>{
        'Oqood', 'DLD Fee', 'Registration Fee', 'Purchase Taxes'
    };

    public static Id resolveApprovalRequestId(Id recordId) {
        if (recordId == null) return null;
        String objType = String.valueOf(recordId.getSObjectType());
        if (objType == 'Approval_Request__c') {
            return recordId;
        }
        // ProcessInstanceWorkitem — resolve via ProcessInstance to the target record
        List<ProcessInstanceWorkitem> items = [
            SELECT ProcessInstance.TargetObjectId
            FROM ProcessInstanceWorkitem
            WHERE Id = :recordId
            LIMIT 1
        ];
        if (!items.isEmpty()) {
            return items[0].ProcessInstance.TargetObjectId;
        }
        // ProcessInstance itself
        List<ProcessInstance> instances = [
            SELECT TargetObjectId
            FROM ProcessInstance
            WHERE Id = :recordId
            LIMIT 1
        ];
        if (!instances.isEmpty()) {
            return instances[0].TargetObjectId;
        }
        return null;
    }

    public static List<Approval_Request__c> queryRequest(Id requestId) {
        return [
            SELECT Id, Name, Status__c, Justification__c, Unit__c, Request_Type__c,
                   Requester__r.Name
            FROM Approval_Request__c
            WHERE Id = :requestId
            LIMIT 1
        ];
    }

    public static List<Unit__c> queryUnit(Id unitId) {
        return [
            SELECT Id, Title__c, Project_Name_F__c, Building__c, Account__r.Name,
                   Cost_AED__c, Cost_USD__c
            FROM Unit__c
            WHERE Id = :unitId
            LIMIT 1
        ];
    }

    public static List<Cash_Flow__c> queryCashFlows(Id unitId) {
        return [
            SELECT Id, Name, Date__c, Percent__c, Constant__c, Received_Amount__c,
                   Price_Formula__c, Amount_AED__c
            FROM Cash_Flow__c
            WHERE Unit__c = :unitId
              AND Name NOT IN :EXCLUDED_MILESTONES
            ORDER BY Date__c ASC NULLS LAST, Name ASC
        ];
    }

    public static Integer countCashFlows(Id unitId) {
        return [
            SELECT COUNT()
            FROM Cash_Flow__c
            WHERE Unit__c = :unitId
              AND Name NOT IN :EXCLUDED_MILESTONES
        ];
    }

    public static List<Payment_Plan_Approval_Line__c> queryApprovalLines(Id approvalRequestId) {
        return [
            SELECT Id, Action__c, Cash_Flow__c, Milestone_Name__c,
                   Date__c, Percent__c, Constant__c, Sort_Order__c
            FROM Payment_Plan_Approval_Line__c
            WHERE Approval_Request__c = :approvalRequestId
              AND Milestone_Name__c NOT IN :EXCLUDED_MILESTONES
            ORDER BY Sort_Order__c ASC NULLS LAST
        ];
    }
}