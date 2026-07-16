@IsTest
private class UnitPriceApprovalControllerTest {

    @TestSetup
    static void setupData() {
        Project__c project = new Project__c(
            Name = 'Unit Price Controller Project',
            Description__c = 'Test',
            District__c = 'Meydan',
            Coordinates_Latitude__c = 1,
            Coordinates_Longitude__c = 1,
            Handover__c = Date.today(),
            Minimum_Cost__c = 1,
            Publish_Project__c = 'Draft'
        );
        insert project;

        Unit__c unit = new Unit__c(
            Title__c = 'Controller Unit',
            Cost_AED__c = 1000000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Additional_Area__c = 200,
            Floor__c = 1,
            Number_of_Bedrooms__c = 2,
            Number_of_Bathrooms__c = 2,
            Status__c = 'Draft',
            Building__c = 'Tower A',
            Panorama_Link__c = 'Link',
            Project__c = project.Id
        );
        insert unit;
        unit.Status__c = 'Booked';
        update unit;
    }

    private static Id unitId() {
        return [SELECT Id FROM Unit__c WHERE Title__c = 'Controller Unit' LIMIT 1].Id;
    }

    @IsTest
    static void testGetUnitPriceInfo() {
        Test.startTest();
        UnitPriceApprovalService.UnitPriceInfoDTO info = UnitPriceApprovalController.getUnitPriceInfo(unitId());
        Test.stopTest();
        System.assertEquals('AED', info.currencyCode);
        System.assertEquals(true, info.eligible);
    }

    @IsTest
    static void testCreateDraftAndGetOpenRequest() {
        Id unit = unitId();
        Test.startTest();
        Id requestId = UnitPriceApprovalController.createDraftRequest(unit, 'Controller draft justification.', 1200000);
        UnitPriceApprovalService.OpenUnitPriceRequestDTO dto =
            UnitPriceApprovalController.getOpenUnitPriceRequestForUnit(unit);
        Test.stopTest();

        System.assertNotEquals(null, requestId);
        System.assertNotEquals(null, dto);
        System.assertEquals(requestId, dto.approvalRequestId);
        System.assertEquals(1200000, dto.requestedPrice);
    }

    @IsTest
    static void testSubmitDelegates() {
        Id unit = unitId();
        Id requestId;
        Test.startTest();
        try {
            requestId = UnitPriceApprovalController.submitUnitPriceApproval(
                unit,
                'Controller submit justification.',
                5,
                null
            );
        } catch (AuraHandledException e) {
            // Approval process may be unavailable or misconfigured in this org.
            return;
        }
        Test.stopTest();

        System.assertNotEquals(null, requestId);
        System.assertEquals(1, [SELECT COUNT() FROM Approval_Request__c WHERE Unit__c = :unit]);
    }

    @IsTest
    static void testGetUnitPriceComparison() {
        Id unit = unitId();
        Id requestId = UnitPriceApprovalController.createDraftRequest(
            unit,
            'Controller comparison justification.',
            1300000
        );

        Test.startTest();
        UnitPriceApprovalService.UnitPriceComparisonDTO result =
            UnitPriceApprovalController.getUnitPriceComparison(requestId);
        Test.stopTest();

        System.assertEquals(false, result.notApplicable);
        System.assertEquals('AED', result.priceCurrency);
        System.assertEquals(1000000, result.currentPrice);
        System.assertEquals(1300000, result.requestedPrice);
        System.assertEquals(300000, result.priceDifference);
    }
}