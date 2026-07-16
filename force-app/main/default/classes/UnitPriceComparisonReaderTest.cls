@IsTest
private class UnitPriceComparisonReaderTest {

    @TestSetup
    static void setupData() {
        Project__c project = new Project__c(
            Name = 'Unit Price Reader Project',
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
            Title__c = 'Reader Test Unit',
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
        update new Unit__c(Id = unit.Id, Status__c = 'Booked');
    }

    private static Approval_Request__c buildUnitPriceRequest(Id unitId) {
        return new Approval_Request__c(
            Request_Type__c = UnitPriceApprovalService.REQUEST_TYPE_UNIT_PRICE,
            Unit__c = unitId,
            Status__c = 'Pending',
            Requester__c = UserInfo.getUserId(),
            Justification__c = 'Unit price reader test justification.',
            Price_Currency__c = 'AED',
            Current_Price__c = 1000000,
            Requested_Price__c = 1200000,
            Current_Cost_AED__c = 1000000,
            Requested_Cost_AED__c = 1200000,
            Conversion_Rate__c = 1,
            Related_Record_Id__c = String.valueOf(unitId),
            Related_Object_Type__c = 'Unit__c',
            Field_To_Update__c = 'Cost_AED__c',
            Current_Value__c = 'AED 1000000.00',
            Requested_Value__c = 'AED 1200000.00'
        );
    }

    @IsTest
    static void testResolveApprovalRequestId_Null_ReturnsNull() {
        Test.startTest();
        Id result = UnitPriceComparisonReader.resolveApprovalRequestId(null);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testResolveApprovalRequestId_ApprovalRequestId_ReturnsSelf() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Approval_Request__c request = buildUnitPriceRequest(unit.Id);
        insert request;

        Test.startTest();
        Id result = UnitPriceComparisonReader.resolveApprovalRequestId(request.Id);
        Test.stopTest();

        System.assertEquals(request.Id, result);
    }

    @IsTest
    static void testResolveApprovalRequestId_UnknownId_ReturnsNull() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        Id result = UnitPriceComparisonReader.resolveApprovalRequestId(unit.Id);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testQueryRequest_ReturnsMatchingRequestWithPriceFields() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Approval_Request__c request = buildUnitPriceRequest(unit.Id);
        insert request;

        Test.startTest();
        List<Approval_Request__c> result = UnitPriceComparisonReader.queryRequest(request.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(request.Id, result[0].Id);
        System.assertEquals(UnitPriceApprovalService.REQUEST_TYPE_UNIT_PRICE, result[0].Request_Type__c);
        System.assertEquals('Pending', result[0].Status__c);
        System.assertEquals('Unit price reader test justification.', result[0].Justification__c);
        System.assertEquals('AED', result[0].Price_Currency__c);
        System.assertEquals(1000000, result[0].Current_Price__c);
        System.assertEquals(1200000, result[0].Requested_Price__c);
        System.assertEquals(1000000, result[0].Current_Cost_AED__c);
        System.assertEquals(1200000, result[0].Requested_Cost_AED__c);
        System.assertEquals(1, result[0].Conversion_Rate__c);
        System.assertNotEquals(null, result[0].Requester__r);
    }

    @IsTest
    static void testQueryRequest_NotFound_ReturnsEmpty() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        List<Approval_Request__c> result = UnitPriceComparisonReader.queryRequest(unit.Id);
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testQueryUnit_ReturnsUnit() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        List<Unit__c> result = UnitPriceComparisonReader.queryUnit(unit.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('Reader Test Unit', result[0].Title__c);
        System.assertEquals('Tower A', result[0].Building__c);
        System.assertNotEquals(null, result[0].Project_Name_F__c);
    }

    @IsTest
    static void testQueryUnit_NotFound_ReturnsEmpty() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Approval_Request__c request = buildUnitPriceRequest(unit.Id);
        insert request;

        Test.startTest();
        List<Unit__c> result = UnitPriceComparisonReader.queryUnit(request.Id);
        Test.stopTest();

        System.assertEquals(0, result.size());
    }
}