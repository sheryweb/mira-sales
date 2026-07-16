public class MultipleUnitsSalesOfferActionController {
	@AuraEnabled
    public static String generateMultiplePdf(String recordId){
        try {
            List<String> recordIds = recordId.split(',');
            
            List<ContentDocumentLink> existingLinks = [
                SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId IN :recordIds
                AND ContentDocument.Title LIKE 'Sales Offer%'
            ];
            
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
            
            PageReference pdfPage = Page.SalesOfferPage;
            pdfPage.getParameters().put('unitIds', recordId);
            Blob pdfBody;
            if(!test.isRunningTest()){
                pdfBody = pdfPage.getContentAsPDF();
            }else{
                pdfBody = blob.valueof('TEST');
            }
            
            ContentVersion fileToUpload = new ContentVersion();
            fileToUpload.ContentLocation = 'S'; 
            fileToUpload.PathOnClient = 'Sales Offer ' + Date.today().format() + '.pdf';
            fileToUpload.VersionData = pdfBody;
            insert fileToUpload;
        
            Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :fileToUpload.Id].ContentDocumentId;
            
            ContentDocumentLink linkToRecord = new ContentDocumentLink();
            linkToRecord.ContentDocumentId = contentDocumentId;
            linkToRecord.LinkedEntityId = recordIds[0];
            linkToRecord.ShareType = 'V';
            insert linkToRecord;

            return contentDocumentId;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}