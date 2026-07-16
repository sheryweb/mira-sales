public class UnitGeneratePdfActionController {

    @AuraEnabled
    public static String generatePdf(Id recordId){
        try {
            Unit__c curRecord = [SELECT Id, Project_Name_F__c FROM Unit__c WHERE Id = :recordId];
            List<ContentDocumentLink> existingLinks = [
                SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :recordId
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
            PageReference pdfPage;
            if (curRecord.Project_Name_F__c == 'POST HOTEL & RESIDENCES By ELIE SAAB') {
                pdfPage = Page.SalesOfferElliePDF;
            } else if (curRecord.Project_Name_F__c == 'Trussardi Residences 2') {
                pdfPage = Page.SalesOfferT2PDF;
            } else if (curRecord.Project_Name_F__c == 'GIANFRANCO FERRE RESIDENCES') {
                pdfPage = Page.SalesOfferGianfrancoPDF;
            } else if (curRecord.Project_Name_F__c == 'Trussardi Residences 2 Offices') {
                pdfPage = Page.SalesOfferT2OfficePDF;
            } else if (curRecord.Project_Name_F__c == 'Trussardi Residences MIRA VERDE') {
                pdfPage = Page.SalesOfferMIRAVerdePDF;
            } else if (curRecord.Project_Name_F__c == 'John Richmond Residences') {
                pdfPage = Page.SalesOfferRichmondPDF;
            } else {
                pdfPage = Page.SalesOfferPDF;
            }
            pdfPage.getParameters().put('unitId', recordId);
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
            linkToRecord.LinkedEntityId = recordId;
            linkToRecord.ShareType = 'V';
            insert linkToRecord;

            return contentDocumentId;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

}