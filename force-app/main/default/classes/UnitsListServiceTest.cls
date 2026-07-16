@IsTest
private class UnitsListServiceTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Project
        Project__c testProject = new Project__c(
            Name = 'Test Project',
            Coordinates_Latitude__c = 25.2048,
            Coordinates_Longitude__c = 55.2708,
            Handover__c = Date.today().addMonths(6),
            Publish_Project__c = 'Published'
        );
        insert testProject;
        
        // Create test Units with different statuses and costs
        List<Unit__c> testUnits = new List<Unit__c>();
        testUnits.add(new Unit__c(
            Title__c = 'Test Unit 1',
            Cost_Per_Square_Meter_AED__c = 1000,
            Status__c = 'Draft',
            Project__c = testProject.Id
        ));
        testUnits.add(new Unit__c(
            Title__c = 'Test Unit 2',
            Cost_Per_Square_Meter_AED__c = null,
            Status__c = 'Draft',
            Project__c = testProject.Id
        ));
        testUnits.add(new Unit__c(
            Title__c = null,
            Cost_Per_Square_Meter_AED__c = 2000,
            Status__c = 'Draft',
            Project__c = testProject.Id
        ));
        insert testUnits;
    }
    
    @IsTest
    static void testGetUnits_Success() {
        Project__c testProject = [SELECT Id FROM Project__c WHERE Name = 'Test Project' LIMIT 1];
        
        Test.startTest();
        UnitsListService.projectId = testProject.Id;
        String response = UnitsListService.getUnits();
        Test.stopTest();
        
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(response);
        System.assertEquals('success', responseMap.get('status'), 'Status should be success');
        
        List<Object> units = (List<Object>)responseMap.get('units');
        System.assertEquals(3, units.size(), 'Should return all units');
        
        Map<String, Object> firstUnit = (Map<String, Object>)units[0];
        System.assertNotEquals(null, firstUnit.get('title'), 'Title should not be null');
        System.assertNotEquals(null, firstUnit.get('costPerSquareMeter'), 'Cost should not be null');
    }
    
    @IsTest
    static void testGetUnits_UnpublishedProject() {
        // Create unpublished project
        Project__c unpublishedProject = new Project__c(
            Name = 'Unpublished Project',
            Coordinates_Latitude__c = 25.2048,
            Coordinates_Longitude__c = 55.2708,
            Handover__c = Date.today().addMonths(6),
            Publish_Project__c = 'Draft'
        );
        insert unpublishedProject;
        
        Test.startTest();
        UnitsListService.projectId = unpublishedProject.Id;
        String response = UnitsListService.getUnits();
        Test.stopTest();
        
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(response);
        System.assertEquals('error', responseMap.get('status'), 'Status should be error');
        System.assertEquals('Project is not published', responseMap.get('message'), 'Should return unpublished project message');
    }
    
    @IsTest
    static void testGetUnits_Error() {
        Test.startTest();
        UnitsListService.projectId = 'xyz123'; // Invalid project ID format
        String response = UnitsListService.getUnits();
        Test.stopTest();
        
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(response);
        System.assertEquals('error', responseMap.get('status'), 'Status should be error');
    }
    
    @IsTest
    static void testGetUnits_NoResults() {
        Project__c emptyProject = new Project__c(
            Name = 'Empty Project',
            Coordinates_Latitude__c = 25.2048,
            Coordinates_Longitude__c = 55.2708,
            Handover__c = Date.today().addMonths(6),
            Publish_Project__c = 'Published'
        );
        insert emptyProject;
        
        Test.startTest();
        UnitsListService.projectId = emptyProject.Id;
        String response = UnitsListService.getUnits();
        Test.stopTest();
        
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(response);
        List<Object> units = (List<Object>)responseMap.get('units');
        System.assertEquals(0, units.size(), 'Should return empty list');
    }
}