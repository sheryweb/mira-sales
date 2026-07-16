public class OpenPaymentPlanRequestDTO {
    @AuraEnabled public Id approvalRequestId;
    @AuraEnabled public String name;
    @AuraEnabled public String status;
    @AuraEnabled public String statusLabel;
    @AuraEnabled public String approvalStageLabel;
    @AuraEnabled public Boolean inApprovalProcess;
    @AuraEnabled public String justification;
}