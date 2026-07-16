@IsTest
public class UnitGeneratePdfRestServiceTest {

    @TestSetup
    static void makeData() {
        Project__c project = new Project__c(
            Name = 'test project',
            Description__c = 'description',
            District__c = 'Meydan',
            Coordinates_Latitude__c = 2,
            Coordinates_Longitude__c = 1,
            Handover__c = Date.today(),
            Minimum_Cost__c = 20
        );
        insert project;

        Unit__c unit = new Unit__c(
            Title__c = 'Test Unit',
            Cost_AED__c = 1000000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Additional_Area__c = 200,
            Floor__c = 5,
            Number_of_Bedrooms__c = 2,
            Number_of_Bathrooms__c = 2,
            View__c = 'Test View',
            Building__c = 'Test Building',
            Panorama_Link__c = 'Test Link',
            Project__c = project.Id,
            Maids_Room__c = true,
            Status__c = 'Draft'
        );
        insert unit;

        unit.Status__c = 'Published';
        update unit;
    }

    private static RestRequest buildRequest(String unitIdParam) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/generateSalesOfferPdf/';
        req.httpMethod = 'GET';
        if (unitIdParam != null) {
            req.params.put('unitId', unitIdParam);
        }
        RestContext.request  = req;
        RestContext.response = new RestResponse();
        return req;
    }

    @IsTest
    static void happyPath_returnsPdfAndAttachesContentVersion() {
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];
        buildRequest(testUnit.Id);

        Test.startTest();
        UnitGeneratePdfRestService.generateSalesOfferPdf();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Expected 200 OK');
        System.assertEquals('application/pdf', res.headers.get('Content-Type'));
        System.assert(res.headers.get('Content-Disposition').startsWith('attachment;'),
            'Content-Disposition should be attachment');
        System.assertNotEquals(null, res.responseBody, 'Response body should contain the PDF bytes');
        System.assert(res.responseBody.size() > 0, 'PDF body should be non-empty');

        ContentDocumentLink cdl = [
            SELECT ContentDocumentId, ContentDocument.Title
            FROM   ContentDocumentLink
            WHERE  LinkedEntityId = :testUnit.Id
            AND    ContentDocument.Title LIKE '%Sales Offer%'
            LIMIT  1
        ];
        System.assertNotEquals(null, cdl, 'Sales Offer file should be attached to the Unit');
    }

    @IsTest
    static void missingUnitId_returns400Json() {
        buildRequest(null);

        Test.startTest();
        UnitGeneratePdfRestService.generateSalesOfferPdf();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode);
        System.assertEquals('application/json', res.headers.get('Content-Type'));
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, body.get('success'));
    }

    @IsTest
    static void unknownUnitId_returns404Json() {
        // Valid 18-char Id format but pointing to no record
        Id fakeUnitId = Unit__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';
        buildRequest(fakeUnitId);

        Test.startTest();
        UnitGeneratePdfRestService.generateSalesOfferPdf();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(404, res.statusCode);
        System.assertEquals('application/json', res.headers.get('Content-Type'));
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, body.get('success'));
    }

    @IsTest
    static void existingSalesOffer_isReplaced() {
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];

        ContentVersion existingCV = new ContentVersion(
            ContentLocation = 'S',
            PathOnClient    = 'Sales Offer Existing.pdf',
            Title           = 'Sales Offer Existing',
            VersionData     = Blob.valueOf('old pdf')
        );
        insert existingCV;
        Id oldDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :existingCV.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = oldDocId,
            LinkedEntityId    = testUnit.Id,
            ShareType         = 'V'
        );

        buildRequest(testUnit.Id);

        Test.startTest();
        UnitGeneratePdfRestService.generateSalesOfferPdf();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :oldDocId],
            'Old Sales Offer ContentDocument should be deleted');
        Integer salesOfferCount = [
            SELECT COUNT()
            FROM   ContentDocumentLink
            WHERE  LinkedEntityId = :testUnit.Id
            AND    ContentDocument.Title LIKE '%Sales Offer%'
        ];
        System.assertEquals(1, salesOfferCount, 'Exactly one Sales Offer file should remain');
    }
}