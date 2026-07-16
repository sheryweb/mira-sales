@RestResource(urlMapping='/generateSalesOfferPdf/*')
global without sharing class UnitGeneratePdfRestService {

    @HttpGet
    global static void generateSalesOfferPdf() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String unitId = req.params.get('unitId');
            String sCurrency = req.params.get('sCurrency');   // optional secondary currency override

            // 1. Validate input
            if (String.isBlank(unitId)) {
                writeJsonError(res, 400, 'unitId query parameter is required');
                return;
            }

            List<Unit__c> units = [
                SELECT Id, Project_Name_F__c, Title__c
                FROM   Unit__c
                WHERE  Id = :unitId
                AND Status__c = 'Published'
                LIMIT  1
            ];
            if (units.isEmpty()) {
                writeJsonError(res, 404, 'Unit not found for Id: ' + unitId);
                return;
            }
            Unit__c unit = units[0];

            // 2. Pick the right Visualforce page based on project
            //    (Mirrors UnitGeneratePdfActionController.generatePdf — kept in sync manually.)
            PageReference pdfPage;
            String projectName = unit.Project_Name_F__c;
            if      (projectName == 'POST HOTEL & RESIDENCES By ELIE SAAB') pdfPage = Page.SalesOfferElliePDF;
            else if (projectName == 'Trussardi Residences 2')               pdfPage = Page.SalesOfferT2PDF;
            else if (projectName == 'GIANFRANCO FERRE RESIDENCES')          pdfPage = Page.SalesOfferGianfrancoPDF;
            else if (projectName == 'Trussardi Residences 2 Offices')       pdfPage = Page.SalesOfferT2OfficePDF;
            else if (projectName == 'Trussardi Residences MIRA VERDE')      pdfPage = Page.SalesOfferMIRAVerdePDF;
            else if (projectName == 'John Richmond Residences')               pdfPage = Page.SalesOfferRichmondPDF;
            else                                                            pdfPage = Page.SalesOfferPDF;

            pdfPage.getParameters().put('unitId', unitId);
            if (String.isNotBlank(sCurrency)) {
                pdfPage.getParameters().put('sCurrency', sCurrency);
            }

            // 3. Render PDF (test-mode short circuit matches existing controller)
            Blob pdfBody = Test.isRunningTest()
                ? Blob.valueOf('TEST')
                : pdfPage.getContentAsPDF();

            String fileName = unit.Title__c + ' - Sales Offer ' + Date.today().format() + '.pdf';

            // 4. Delete existing 'Sales Offer%' ContentDocuments linked to this Unit
            //    (same dedup behavior as existing controller)
            Set<Id> existingDocIds = new Set<Id>();
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId
                FROM   ContentDocumentLink
                WHERE  LinkedEntityId = :unitId
                AND    ContentDocument.Title LIKE '%Sales Offer%'
            ]) {
                existingDocIds.add(cdl.ContentDocumentId);
            }
            if (!existingDocIds.isEmpty()) {
                delete [SELECT Id FROM ContentDocument WHERE Id IN :existingDocIds];
            }

            // 5. Insert ContentVersion + ContentDocumentLink
            ContentVersion cv = new ContentVersion(
                Title           = fileName,
                PathOnClient    = fileName,
                VersionData     = pdfBody,
                ContentLocation = 'S'
            );
            insert cv;

            Id contentDocumentId = [
                SELECT ContentDocumentId
                FROM   ContentVersion
                WHERE  Id = :cv.Id
            ].ContentDocumentId;

            insert new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId    = unitId,
                ShareType         = 'V'
            );

            // 6. Return the PDF as the response body
            res.statusCode = 200;
            res.addHeader('Content-Type', 'application/pdf');
            res.addHeader('Content-Disposition', 'attachment; filename="' + fileName + '"');
            res.responseBody = pdfBody;

        } catch (Exception e) {
            writeJsonError(RestContext.response, 500, e.getMessage());
        }
    }

    private static void writeJsonError(RestResponse res, Integer status, String msg) {
        res.statusCode = status;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(JSON.serialize(
            new Map<String, Object>{ 'success' => false, 'message' => msg }
        ));
    }
}