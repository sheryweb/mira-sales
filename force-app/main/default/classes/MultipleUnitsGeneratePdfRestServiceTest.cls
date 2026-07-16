@IsTest
private class MultipleUnitsGeneratePdfRestServiceTest {

    @TestSetup
    static void makeData() {
        Project__c project = new Project__c(
            Name                 = 'test project',
            Description__c       = 'description',
            District__c          = 'Meydan',
            Coordinates_Latitude__c  = 2,
            Coordinates_Longitude__c = 1,
            Handover__c          = Date.today(),
            Minimum_Cost__c      = 20
        );
        insert project;

        List<Unit__c> units = new List<Unit__c>();
        units.add(new Unit__c(
            Title__c               = 'Test Unit One',
            Cost_AED__c            = 1000000,
            Type__c                = 'Apartment',
            Total_Area__c          = 1000,
            Living_Space__c        = 800,
            Additional_Area__c     = 200,
            Floor__c               = 5,
            Number_of_Bedrooms__c  = 2,
            Number_of_Bathrooms__c = 2,
            View__c                = 'Test View',
            Building__c          = 'Test Building',
            Panorama_Link__c     = 'Test Link',
            Project__c           = project.Id,
            Maids_Room__c        = true,
            Status__c            = 'Draft'
        ));
        units.add(new Unit__c(
            Title__c               = 'Test Unit Two',
            Cost_AED__c            = 2000000,
            Type__c                = 'Apartment',
            Total_Area__c          = 1100,
            Living_Space__c        = 900,
            Additional_Area__c     = 200,
            Floor__c               = 6,
            Number_of_Bedrooms__c  = 3,
            Number_of_Bathrooms__c = 2,
            View__c                = 'Test View',
            Building__c          = 'Test Building',
            Panorama_Link__c     = 'Test Link',
            Project__c           = project.Id,
            Maids_Room__c        = true,
            Status__c            = 'Draft'
        ));
        insert units;

        for (Unit__c u : units) {
            u.Status__c = 'Published';
        }
        update units;
    }

    private static RestRequest buildRequest(String unitIdsParam, String sCurrencyParam) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/generateMultipleSalesOfferPdf/';
        req.httpMethod = 'GET';
        if (unitIdsParam != null) {
            req.params.put('unitIds', unitIdsParam);
        }
        if (sCurrencyParam != null) {
            req.params.put('sCurrency', sCurrencyParam);
        }
        RestContext.request  = req;
        RestContext.response = new RestResponse();
        return req;
    }

    /** Same title rule as MultipleUnitsGeneratePdfRestService / MultipleSalesPDFActionController (no CDL+Title SOQL). */
    private static Integer countSalesOfferLinks(List<Id> linkedEntityIds) {
        if (linkedEntityIds == null || linkedEntityIds.isEmpty()) {
            return 0;
        }
        Integer n = 0;
        for (ContentDocumentLink cdl : [
            SELECT ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :linkedEntityIds
        ]) {
            String t = cdl.ContentDocument.Title;
            if (!String.isBlank(t) && t.toUpperCase().startsWith('SALES OFFER')) {
                n++;
            }
        }
        return n;
    }

    @IsTest
    static void happyPath_twoUnits_returnsPdfAndAttachesContentVersion() {
        List<Unit__c> testUnits = [SELECT Id FROM Unit__c ORDER BY Title__c];
        String unitIdsCsv = testUnits[0].Id + ',' + testUnits[1].Id;
        buildRequest(unitIdsCsv, 'USD');

        Test.startTest();
        MultipleUnitsGeneratePdfRestService.generateMultipleSalesOfferPdf();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Expected 200 OK');
        System.assertEquals('application/pdf', res.headers.get('Content-Type'));
        System.assert(res.headers.get('Content-Disposition').startsWith('attachment;'),
            'Content-Disposition should be attachment');
        System.assertNotEquals(null, res.responseBody);
        System.assert(res.responseBody.size() > 0, 'PDF body should be non-empty');

        System.assertEquals(
            1,
            countSalesOfferLinks(new List<Id>{ testUnits[0].Id }),
            'Sales Offer file should be attached to the first Unit'
        );
    }

    @IsTest
    static void invalidUnitIdToken_returns400Json() {
        Unit__c one = [SELECT Id FROM Unit__c LIMIT 1];
        buildRequest(one.Id + ',not-a-valid-id', null);

        Test.startTest();
        MultipleUnitsGeneratePdfRestService.generateMultipleSalesOfferPdf();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, body.get('success'));
    }

    @IsTest
    static void missingUnitIds_returns400Json() {
        buildRequest(null, null);

        Test.startTest();
        MultipleUnitsGeneratePdfRestService.generateMultipleSalesOfferPdf();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, body.get('success'));
    }

    @IsTest
    static void unknownUnitId_returns404Json() {
        Unit__c one = [SELECT Id FROM Unit__c LIMIT 1];
        Id fakeUnitId = Unit__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';
        buildRequest(one.Id + ',' + fakeUnitId, null);

        Test.startTest();
        MultipleUnitsGeneratePdfRestService.generateMultipleSalesOfferPdf();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(404, res.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, body.get('success'));
    }

    @IsTest
    static void mixedProject_returns400Json() {
        Project__c otherProject = new Project__c(
            Name                 = 'other project',
            Description__c       = 'd',
            District__c          = 'Meydan',
            Coordinates_Latitude__c  = 1,
            Coordinates_Longitude__c = 1,
            Handover__c          = Date.today(),
            Minimum_Cost__c      = 10
        );
        insert otherProject;

        List<Unit__c> sameProjectUnits = [SELECT Id FROM Unit__c ORDER BY Title__c LIMIT 1];
        Unit__c otherUnit = new Unit__c(
            Title__c               = 'Other Project Unit',
            Cost_AED__c            = 500000,
            Type__c                = 'Apartment',
            Total_Area__c          = 500,
            Living_Space__c        = 400,
            Additional_Area__c     = 100,
            Floor__c               = 1,
            Number_of_Bedrooms__c  = 1,
            Number_of_Bathrooms__c = 1,
            View__c                = 'V',
            Building__c          = 'B',
            Panorama_Link__c     = 'L',
            Project__c           = otherProject.Id,
            Maids_Room__c        = false,
            Status__c            = 'Draft'
        );
        insert otherUnit;

        otherUnit.Status__c = 'Published';
        update otherUnit;

        buildRequest(sameProjectUnits[0].Id + ',' + otherUnit.Id, null);

        Test.startTest();
        MultipleUnitsGeneratePdfRestService.generateMultipleSalesOfferPdf();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, body.get('success'));
    }

    @IsTest
    static void existingSalesOffer_isReplacedOnAllUnits() {
        List<Unit__c> testUnits = [SELECT Id FROM Unit__c ORDER BY Title__c];

        ContentVersion existingCV = new ContentVersion(
            ContentLocation = 'S',
            PathOnClient    = 'Sales Offer Existing.pdf',
            Title           = 'Sales Offer Existing',
            VersionData     = Blob.valueOf('old pdf')
        );
        insert existingCV;
        Id oldDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :existingCV.Id].ContentDocumentId;
        insert new List<ContentDocumentLink>{
            new ContentDocumentLink(ContentDocumentId = oldDocId, LinkedEntityId = testUnits[0].Id, ShareType = 'V'),
            new ContentDocumentLink(ContentDocumentId = oldDocId, LinkedEntityId = testUnits[1].Id, ShareType = 'V')
        };

        buildRequest(testUnits[0].Id + ',' + testUnits[1].Id, null);

        Test.startTest();
        MultipleUnitsGeneratePdfRestService.generateMultipleSalesOfferPdf();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :oldDocId],
            'Old Sales Offer ContentDocument should be deleted');

        List<Id> unitIds = new List<Id>();
        for (Unit__c u : testUnits) {
            unitIds.add(u.Id);
        }
        System.assertEquals(1, countSalesOfferLinks(unitIds), 'Exactly one Sales Offer link should remain (first unit only)');
    }
}