public with sharing class UnitPriceApprovalController {
    @AuraEnabled(cacheable=true)
    public static UnitPriceApprovalService.UnitPriceInfoDTO getUnitPriceInfo(Id unitId) {
        return UnitPriceApprovalService.getUnitPriceInfo(unitId);
    }

    @AuraEnabled(cacheable=true)
    public static UnitPriceApprovalService.OpenUnitPriceRequestDTO getOpenUnitPriceRequestForUnit(Id unitId) {
        return UnitPriceApprovalService.getOpenUnitPriceRequestForUnit(unitId);
    }

    @AuraEnabled
    public static Id createDraftRequest(Id unitId, String justification, Decimal requestedPrice) {
        return UnitPriceApprovalService.createDraftRequest(unitId, justification, requestedPrice);
    }

    @AuraEnabled
    public static Id submitUnitPriceApproval(
        Id unitId,
        String justification,
        Integer discountPercent,
        Id approvalRequestId
    ) {
        return UnitPriceApprovalService.submitUnitPriceApproval(
            unitId,
            justification,
            discountPercent,
            approvalRequestId
        );
    }

    @AuraEnabled(cacheable=true)
    public static UnitPriceApprovalService.UnitPriceComparisonDTO getUnitPriceComparison(Id approvalRequestId) {
        try {
            return UnitPriceApprovalService.getUnitPriceComparison(approvalRequestId);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to load unit price comparison: ' +
                (String.isNotBlank(e.getMessage()) ? e.getMessage() : e.getTypeName())
            );
        }
    }
}