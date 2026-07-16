@IsTest
private class ApprovalComparisonControllerTest {

    @TestSetup
    static void setupData() {
        Project__c project = new Project__c(
            Name = 'Comparison Router Project',
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
            Title__c = 'Comparison Router Unit',
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

    @IsTest
    static void testGetRequestType_UnitPrice() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Id requestId = UnitPriceApprovalService.createDraftRequest(
            unit.Id,
            'Router test justification.',
            1200000
        );

        Test.startTest();
        String requestType = ApprovalComparisonController.getRequestType(requestId);
        Test.stopTest();

        System.assertEquals(UnitPriceApprovalService.REQUEST_TYPE_UNIT_PRICE, requestType);
    }

    @IsTest
    static void testGetRequestType_NullId() {
        Test.startTest();
        String requestType = ApprovalComparisonController.getRequestType(null);
        Test.stopTest();
        System.assertEquals(null, requestType);
    }
}