public with sharing class PaymentPlanApprovalController {
    @AuraEnabled
    public static Boolean canUserRequestPaymentPlanChange() {
        return PaymentPlanApprovalService.canUserRequestPaymentPlanChange();
    }

    @AuraEnabled(cacheable=true)
    public static PaymentPlanApprovalService.PaymentPlanLinesResultDTO getUnitPaymentPlanLines(Id unitId) {
        try {
            return PaymentPlanApprovalService.getUnitPaymentPlanLinesResult(unitId);
        } catch (Exception e) {
            throw buildAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static OpenPaymentPlanRequestDTO getOpenPaymentPlanRequestForUnit(Id unitId) {
        try {
            return PaymentPlanApprovalService.getOpenPaymentPlanRequestForUnit(unitId);
        } catch (Exception e) {
            throw buildAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PaymentPlanApprovalService.CashFlowSumOptionDTO> getUnitCashFlowSums(Id unitId) {
        try {
            return PaymentPlanApprovalService.getUnitCashFlowSums(unitId);
        } catch (Exception e) {
            throw buildAuraException(e);
        }
    }

    @AuraEnabled
    public static Id createUnitCashFlowSum(Id unitId, String yearName) {
        try {
            return PaymentPlanApprovalService.createUnitCashFlowSum(unitId, yearName);
        } catch (Exception e) {
            throw buildAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PaymentPlanApprovalService.ApproverOptionDTO> getPaymentPlanApproverOptions() {
        try {
            return PaymentPlanApprovalService.getPaymentPlanApproverOptions();
        } catch (Exception e) {
            throw buildAuraException(e);
        }
    }

    @AuraEnabled
    public static Id createDraftRequest(Id unitId, String justification) {
        try {
            return PaymentPlanApprovalService.createDraftRequest(unitId, justification);
        } catch (Exception e) {
            throw buildAuraException(e);
        }
    }

    @AuraEnabled
    public static void saveApprovalLines(Id approvalRequestId, String linesJson) {
        try {
            PaymentPlanApprovalService.saveApprovalLines(
                approvalRequestId,
                PaymentPlanApprovalService.parseLineInputs(linesJson)
            );
        } catch (Exception e) {
            throw buildAuraException(e);
        }
    }

    @AuraEnabled
    public static Id submitPaymentPlanApproval(
        Id unitId,
        String justification,
        String linesJson,
        Id approvalRequestId,
        Id approverUserId
    ) {
        try {
            return PaymentPlanApprovalService.submitPaymentPlanApproval(
                unitId,
                justification,
                linesJson,
                approvalRequestId,
                approverUserId
            );
        } catch (Exception e) {
            throw buildAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static Approval_Request__c getApprovalRequest(Id approvalRequestId) {
        return [
            SELECT Id, Name, Status__c, Justification__c, Unit__c, Unit__r.Title__c,
                   Approver__c, Approver__r.Name
            FROM Approval_Request__c
            WHERE Id = :approvalRequestId
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Payment_Plan_Approval_Line__c> getApprovalRequestLines(Id approvalRequestId) {
        return [
            SELECT Id, Action__c, Cash_Flow__c, Milestone_Name__c, Date__c, Percent__c,
                   Constant__c, Cash_Flow_Sum__c, Cash_Flow_Sum__r.Name,
                   Is_Additional_Payment__c, Sort_Order__c
            FROM Payment_Plan_Approval_Line__c
            WHERE Approval_Request__c = :approvalRequestId
            ORDER BY Sort_Order__c ASC NULLS LAST
        ];
    }

    @AuraEnabled(cacheable=true)
    public static PaymentPlanApprovalService.PaymentPlanComparisonDTO getPaymentPlanComparison(Id approvalRequestId) {
        try {
            return PaymentPlanApprovalService.getPaymentPlanComparison(approvalRequestId);
        } catch (Exception e) {
            throw buildAuraException(e);
        }
    }

    private static AuraHandledException buildAuraException(Exception e) {
        if (e instanceof AuraHandledException) {
            return (AuraHandledException) e;
        }
        return new AuraHandledException(PaymentPlanApprovalService.getExceptionMessage(e));
    }
}