public with sharing class InvoiceReceiptTransferController {
    @AuraEnabled
    public static InvoiceReceiptTransferService.TransferContextDTO getTransferContext(Id unitId) {
        try {
            return InvoiceReceiptTransferService.getTransferContext(unitId);
        } catch (Exception e) {
            throw new AuraHandledException(
                String.isNotBlank(e.getMessage()) ? e.getMessage() : e.getTypeName()
            );
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<InvoiceReceiptTransferService.OpportunityOptionDTO> searchOpportunities(
        Id unitId,
        String searchTerm
    ) {
        try {
            return InvoiceReceiptTransferService.searchOpportunities(unitId, searchTerm);
        } catch (Exception e) {
            throw new AuraHandledException(
                String.isNotBlank(e.getMessage()) ? e.getMessage() : e.getTypeName()
            );
        }
    }

    @AuraEnabled(cacheable=true)
    public static InvoiceReceiptTransferService.OpportunityOptionDTO getAccountPreview(Id opportunityId) {
        try {
            return InvoiceReceiptTransferService.getAccountPreview(opportunityId);
        } catch (Exception e) {
            throw new AuraHandledException(
                String.isNotBlank(e.getMessage()) ? e.getMessage() : e.getTypeName()
            );
        }
    }

    @AuraEnabled(cacheable=true)
    public static InvoiceReceiptTransferService.OpenTransferRequestDTO getOpenTransferRequestForUnit(
        Id unitId
    ) {
        try {
            return InvoiceReceiptTransferService.getOpenTransferRequestForUnit(unitId);
        } catch (Exception e) {
            throw new AuraHandledException(
                String.isNotBlank(e.getMessage()) ? e.getMessage() : e.getTypeName()
            );
        }
    }

    @AuraEnabled
    public static Id submitTransferRequest(Id unitId, Id targetOpportunityId, String justification) {
        try {
            return InvoiceReceiptTransferService.submitTransferRequest(
                unitId,
                targetOpportunityId,
                justification
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                String.isNotBlank(e.getMessage()) ? e.getMessage() : e.getTypeName()
            );
        }
    }
}
