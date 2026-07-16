@IsTest
private class UnitListingServiceControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create test project
        Project__c testProject = new Project__c(
            Name = 'Test Project',
            Description__c = 'Test Description',
            Publish_Project__c = 'Published',
            Coordinates_Latitude__c = 25.0,
            Coordinates_Longitude__c = 55.0,
            Handover__c = Date.today().addMonths(3)
        );
        insert testProject;

        // Create unit with Blocked status first (as per validation rule)
        Unit__c unit = new Unit__c(
            Title__c = 'Test Unit',
            Project__c = testProject.Id,
            Status__c = 'Draft',
            Cost_Per_Square_Meter_AED__c = 12000,
            Total_Area_Square_Meter__c = 95,
            Floor__c = 10
        );
        insert unit;
        
        // Now update to Published status
        unit.Status__c = 'Published';
        update unit;

        // Create File__c object for floor plan
        File__c file = new File__c(
            Unit__c = unit.Id,
            Type__c = 'Floor Plan'
        );
        insert file;
    }

    @IsTest
    static void testGetUnitsByProject_Success() {
        Project__c project = [SELECT Id FROM Project__c LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitsListing';
        req.httpMethod = 'GET';
        req.params.put('projectId', project.Id);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitListingServiceController.getUnitsByProject();
        Test.stopTest();

        // Parse the JSON response
        String responseBody = res.responseBody.toString();
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> units = (List<Object>) responseMap.get('units');
        Map<String, Object> unitData = (Map<String, Object>) units[0];

        System.assertEquals(true, responseMap.get('success'));
        System.assertEquals('Units retrieved successfully', responseMap.get('message'));
        System.assertEquals(1, units.size());
        System.assertEquals('Test Unit', unitData.get('title'));

        // Validate that floorPlanFileId is populated
        System.assertNotEquals(null, unitData.get('floorPlanFileId'), 'Floor plan file ID should not be null');
        
        // Validate other unit properties
        System.assertEquals(12000, unitData.get('costPerSquareMeterAED'));
        System.assertEquals(95, unitData.get('totalAreaSquareMeter'));
        System.assertEquals(10, unitData.get('floor'));
        System.assertEquals('Available', unitData.get('status'));
    }

    @IsTest
    static void testGetUnitsByProject_NoProjectId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitsListing';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitListingServiceController.getUnitsByProject();
        Test.stopTest();

        // Parse the JSON response
        String responseBody = res.responseBody.toString();
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        System.assertEquals(false, responseMap.get('success'));
        System.assertEquals('Invalid Project ID format', responseMap.get('message'));
    }

    @IsTest
    static void testGetUnitsByProject_NoUnits() {
        // Create another project with no units
        Project__c emptyProject = new Project__c(
            Name = 'Empty Project',
            Publish_Project__c = 'Published',
            Coordinates_Latitude__c = 24.0,
            Coordinates_Longitude__c = 54.0,
            Handover__c = Date.today().addMonths(6)
        );
        insert emptyProject;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitsListing';
        req.httpMethod = 'GET';
        req.params.put('projectId', emptyProject.Id);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitListingServiceController.getUnitsByProject();
        Test.stopTest();

        // Parse the JSON response
        String responseBody = res.responseBody.toString();
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> units = (List<Object>) responseMap.get('units');

        System.assertEquals(true, responseMap.get('success'));
        System.assertEquals('No units found for the specified project', responseMap.get('message'));
        System.assertEquals(0, units.size());
    }

    @IsTest
    static void testGetUnitsByProject_InvalidFormat() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitsListing';
        req.httpMethod = 'GET';
        req.params.put('projectId', '123INVALID');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitListingServiceController.getUnitsByProject();
        Test.stopTest();

        // Parse the JSON response
        String responseBody = res.responseBody.toString();
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        System.assertEquals(false, responseMap.get('success'));
        System.assertEquals('Invalid Project ID format', responseMap.get('message'));
    }

    @IsTest
    static void testGetUnitsByProject_ProjectNotPublished() {
        // Create unpublished project
        Project__c unpublishedProject = new Project__c(
            Name = 'Unpublished Project',
            Publish_Project__c = 'Draft',
            Coordinates_Latitude__c = 24.0,
            Coordinates_Longitude__c = 54.0,
            Handover__c = Date.today().addMonths(6)
        );
        insert unpublishedProject;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitsListing';
        req.httpMethod = 'GET';
        req.params.put('projectId', unpublishedProject.Id);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitListingServiceController.getUnitsByProject();
        Test.stopTest();

        // Parse the JSON response
        String responseBody = res.responseBody.toString();
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        System.assertEquals(false, responseMap.get('success'));
        System.assertEquals('Project not found or not published', responseMap.get('message'));
    }

    @IsTest
    static void testGetUnitsByProject_UnitWithoutFloorPlan() {
        // Create project and unit without floor plan file
        Project__c project = new Project__c(
            Name = 'Test Project 2',
            Publish_Project__c = 'Published',
            Coordinates_Latitude__c = 25.0,
            Coordinates_Longitude__c = 55.0,
            Handover__c = Date.today().addMonths(3)
        );
        insert project;

        // Create unit with Blocked status first (as per validation rule)
        Unit__c unit = new Unit__c(
            Title__c = 'Unit Without Floor Plan',
            Project__c = project.Id,
            Status__c = 'Draft',
            Cost_Per_Square_Meter_AED__c = 15000,
            Total_Area_Square_Meter__c = 100,
            Floor__c = 5
        );
        insert unit;
        
        // Now update to Published status
        unit.Status__c = 'Published';
        update unit;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitsListing';
        req.httpMethod = 'GET';
        req.params.put('projectId', project.Id);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitListingServiceController.getUnitsByProject();
        Test.stopTest();

        // Parse the JSON response
        String responseBody = res.responseBody.toString();
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> units = (List<Object>) responseMap.get('units');
        Map<String, Object> unitData = (Map<String, Object>) units[0];

        System.assertEquals(true, responseMap.get('success'));
        System.assertEquals('Units retrieved successfully', responseMap.get('message'));
        System.assertEquals(1, units.size());
        System.assertEquals('Unit Without Floor Plan', unitData.get('title'));
        
        // floorPlanFileId should be null when no floor plan file exists
        System.assertEquals(null, unitData.get('floorPlanFileId'), 'Floor plan file ID should be null when no file exists');
    }

    @IsTest
    static void testResponseWrapper_Constructor() {
        Test.startTest();
        UnitListingServiceController.ResponseWrapper response = new UnitListingServiceController.ResponseWrapper();
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('', response.message);
        System.assertEquals(0, response.units.size());
    }

    @IsTest
    static void testUnitWrapper_Constructor() {
        // Create project first
        Project__c project = new Project__c(
            Name = 'Test Project for Wrapper',
            Publish_Project__c = 'Published',
            Coordinates_Latitude__c = 25.0,
            Coordinates_Longitude__c = 55.0,
            Handover__c = Date.today().addMonths(3),
            Payment_Plan_Title__c = 'Test Payment Plan'
        );
        insert project;

        // Create unit with comprehensive data
        Unit__c testUnit = new Unit__c(
            Title__c = 'Test Wrapper Unit',
            Project__c = project.Id,
            Type__c = 'Apartment',
            Number_of_Bedrooms__c = 2,
            Number_of_Bathrooms__c = 2,
            Cost_AED__c = 1000000,
            Cost_CHF_Number__c = 250000,
            Cost_Per_Square_Meter_AED__c = 10000,
            Cost_per_square_foot_AED__c = 1000,
            Total_Area__c = 100,
            Total_Area_Square_Meter__c = 80,
            Living_Space__c = 70,
            Living_Space_Square_Meter__c = 60,
            Additional_Area__c = 20,
            Balcony_Size__c = 10,
            Floor__c = 3,
            Building__c = 'Test Building',
            Status__c = 'Draft'
        );
        insert testUnit;
        
        // Update to Published status
        testUnit.Status__c = 'Published';
        update testUnit;

        Test.startTest();
        // Query the unit with relationship data to get Project__r.Name
        Unit__c queriedUnit = [
            SELECT Id, Title__c, Project_Name_F__c, Project__r.Name, Building__c, Type__c,
                   Number_of_Bedrooms__c, Number_of_Bathrooms__c, Cost_AED__c, Cost_CHF_Number__c,
                   Cost_Per_Square_Meter_AED__c, Cost_per_square_foot_AED__c, Total_Area__c,
                   Total_Area_Square_Meter__c, Living_Space__c, Living_Space_Square_Meter__c,
                   Additional_Area__c, Balcony_Size__c, Floor__c, Project_Handover_Date__c,
                   Project__r.Payment_Plan_Title__c, Status__c
            FROM Unit__c 
            WHERE Id = :testUnit.Id
        ];
        UnitListingServiceController.UnitWrapper wrapper = new UnitListingServiceController.UnitWrapper(queriedUnit);
        Test.stopTest();

        // Test basic properties
        System.assertEquals(testUnit.Id, wrapper.id);
        System.assertEquals('Test Wrapper Unit', wrapper.title);
        // Test that projectName field exists (can be null if both source fields are null)
        System.assertNotEquals(null, wrapper.projectName, 'Project name should not be null - check if Project__r.Name is being populated');
        System.assertEquals('Test Building', wrapper.building);
        System.assertEquals('Apartment', wrapper.type);
        System.assertEquals('Available', wrapper.status);
        
        // Test numeric properties
        System.assertEquals(2, wrapper.numberOfBedrooms);
        System.assertEquals(2, wrapper.numberOfBathrooms);
        System.assertEquals(1000000, wrapper.costAED);
        System.assertEquals(250000, wrapper.costCHF);
        System.assertEquals(10000, wrapper.costPerSquareMeterAED);
        System.assertEquals(1000, wrapper.costPerSquareFootAED);
        System.assertEquals(100, wrapper.totalArea);
        System.assertEquals(80, wrapper.totalAreaSquareMeter);
        System.assertEquals(70, wrapper.livingSpace);
        System.assertEquals(60, wrapper.livingSpaceSquareMeter);
        System.assertEquals(20, wrapper.additionalArea);
        System.assertEquals(10, wrapper.balconySize);
        System.assertEquals(3, wrapper.floor);
        
        // Test project relationship properties
        System.assertEquals('Test Payment Plan', wrapper.projectPaymentPlanTitle);
        
        // Test file properties (should be null initially)
        System.assertEquals(null, wrapper.floorPlanFileId);
    }

    @IsTest
    static void testGetUnitsByProject_WithFloorPlanFile() {
        // Create project
        Project__c project = new Project__c(
            Name = 'Test Project with Floor Plan',
            Publish_Project__c = 'Published',
            Coordinates_Latitude__c = 25.0,
            Coordinates_Longitude__c = 55.0,
            Handover__c = Date.today().addMonths(3)
        );
        insert project;

        // Create unit
        Unit__c testUnit = new Unit__c(
            Title__c = 'Unit with Floor Plan File',
            Project__c = project.Id,
            Status__c = 'Draft',
            Cost_Per_Square_Meter_AED__c = 15000,
            Total_Area_Square_Meter__c = 120,
            Floor__c = 5
        );
        insert testUnit;
        
        // Update to Published status
        testUnit.Status__c = 'Published';
        update testUnit;

        // Create File__c object for floor plan
        File__c floorPlanFile = new File__c(
            Unit__c = testUnit.Id,
            Type__c = 'Floor Plan'
        );
        insert floorPlanFile;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitsListing';
        req.httpMethod = 'GET';
        req.params.put('projectId', project.Id);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitListingServiceController.getUnitsByProject();
        Test.stopTest();

        // Parse the JSON response
        String responseBody = res.responseBody.toString();
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> units = (List<Object>) responseMap.get('units');
        Map<String, Object> unitData = (Map<String, Object>) units[0];

        System.assertEquals(true, responseMap.get('success'));
        System.assertEquals('Units retrieved successfully', responseMap.get('message'));
        System.assertEquals(1, units.size());
        System.assertEquals('Unit with Floor Plan File', unitData.get('title'));

        // Validate that floorPlanFileId is populated
        System.assertNotEquals(null, unitData.get('floorPlanFileId'), 'Floor plan file ID should not be null');
        System.assertEquals(floorPlanFile.Id, unitData.get('floorPlanFileId'), 'Floor plan file ID should match the created file');
    }
}