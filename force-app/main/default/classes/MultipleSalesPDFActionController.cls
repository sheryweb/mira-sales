public class MultipleSalesPDFActionController {

    /**
     * Resolves the Visualforce page used for combined multi-unit sales offers.
     * Kept in sync with Flow invocable logic; REST services should call this instead of duplicating branches.
     */
    public static PageReference getPageReferenceForMultipleSalesOffer(String selectedProjectName) {
        if (selectedProjectName == 'Trussardi Residences 2') {
            return Page.MultipleSalesOfferT2Page;
        } else if (selectedProjectName == 'POST HOTEL & RESIDENCES By ELIE SAAB') {
            return Page.MultipleSalesOfferEliePage;
        } else if (selectedProjectName == 'GIANFRANCO FERRE RESIDENCES') {
            return Page.MultipleSalesOfferGianfrancoPage;
        } else if (selectedProjectName == 'Trussardi Residences 2 Offices') {
            return Page.MultipleSalesOfferT2OfficePage;
        } else if (selectedProjectName == 'Trussardi Residences MIRA VERDE') {
            return Page.MultipleSalesOfferMIRAVerdePage;
        } else if (selectedProjectName == 'John Richmond Residences') {
            return Page.MultipleSalesOfferRichmondPage;
        }
        return Page.SalesOfferPage;
    }

    /**
     * SOQL cannot combine LinkedEntityId IN (...) with ContentDocument.Title filters on ContentDocumentLink
     * (implementation restriction). Query by linked entities only, then apply the title rule in Apex.
     */
    public static List<ContentDocumentLink> querySalesOfferDocumentLinks(List<Id> linkedEntityIds) {
        if (linkedEntityIds == null || linkedEntityIds.isEmpty()) {
            return new List<ContentDocumentLink>();
        }
        List<ContentDocumentLink> rows = [
            SELECT ContentDocumentId, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :linkedEntityIds
        ];
        List<ContentDocumentLink> matches = new List<ContentDocumentLink>();
        for (ContentDocumentLink cdl : rows) {
            String t = cdl.ContentDocument.Title;
            if (!String.isBlank(t) && t.toUpperCase().startsWith('SALES OFFER')) {
                matches.add(cdl);
            }
        }
        return matches;
    }

	public class FlowInput {
        @InvocableVariable public String recordsIds;
        @invocableVariable public String selectedCurrency;
        @invocableVariable public String selectedProjectName;
    }
    
    @InvocableMethod public static FlowOutput[] getContentDocumentId(List<FlowInput> params) {
        List<String> recordIds = params[0].recordsIds.split(',');
        FlowOutput[] fResult = new List<FlowOutput>();
        
        List<Id> linkedIds = new List<Id>();
        for (String rid : recordIds) {
            if (String.isBlank(rid)) {
                continue;
            }
            linkedIds.add((Id) rid.trim());
        }
        List<ContentDocumentLink> existingLinks = querySalesOfferDocumentLinks(linkedIds);
        
        List<Id> contentDocumentIdsToDelete = new List<Id>();
        for(ContentDocumentLink link : existingLinks) {
            contentDocumentIdsToDelete.add(link.ContentDocumentId);
        }
        
        if(!contentDocumentIdsToDelete.isEmpty()) {
            delete existingLinks;
            
            List<ContentDocument> contentDocumentsToDelete = [
                SELECT Id 
                FROM ContentDocument 
                WHERE Id IN :contentDocumentIdsToDelete
            ];
            
            delete contentDocumentsToDelete;
        }
        
        PageReference pdfPage = getPageReferenceForMultipleSalesOffer(params[0].selectedProjectName);
        pdfPage.getParameters().put('unitIds', params[0].recordsIds);
        pdfPage.getParameters().put('sCurrency', params[0].selectedCurrency);
        Blob pdfBody;
        if(!test.isRunningTest()){
            pdfBody = pdfPage.getContentAsPDF();
        } else {
            pdfBody = blob.valueof('TEST');
        }
        
        ContentVersion fileToUpload = new ContentVersion();
        fileToUpload.ContentLocation = 'S';
        fileToUpload.PathOnClient = 'Sales Offer ' + Date.today().format() + '.pdf';
        fileToUpload.VersionData = pdfBody;
        insert fileToUpload;
        
        List<ContentVersion> contentDocument = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :fileToUpload.Id];
        
        ContentDocumentLink linkToRecord = new ContentDocumentLink();
        linkToRecord.ContentDocumentId = contentDocument[0].ContentDocumentId;
        linkToRecord.LinkedEntityId = recordIds[0];
        linkToRecord.ShareType = 'V';
        insert linkToRecord;
        
        List<String> cdIds = new List<String>();
        
        for (ContentVersion ctDc: contentDocument) {
            fResult.add(new FlowOutput(
                ctDc.ContentDocumentId
            ));
        }
        return fResult;
    }
    
    public class FlowOutput {
        @InvocableVariable public String contentDocumentId;
        public FlowOutput(String cdId) {
            this.contentDocumentId = cdId;
        }
    }
}