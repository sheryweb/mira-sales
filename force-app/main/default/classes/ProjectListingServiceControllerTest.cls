@IsTest
private class ProjectListingServiceControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test projects
        List<Project__c> projects = new List<Project__c>();
        
        Project__c activeProject = new Project__c(
            Name = 'Test Active Project',
            Description__c = 'Test Description',
            Publish_Project__c = 'Published',
            Coordinates_Latitude__c = 25.1234,
            Coordinates_Longitude__c = 55.1234,
            Handover__c = Date.today().addMonths(6)
        );
        projects.add(activeProject);
        
        Project__c draftProject = new Project__c(
            Name = 'Test Draft Project',
            Description__c = 'Draft Description',
            Publish_Project__c = 'Draft',
            Coordinates_Latitude__c = 25.4321,
            Coordinates_Longitude__c = 55.4321,
            Handover__c = Date.today().addMonths(12)
        );
        projects.add(draftProject);
        
        insert projects;
    }
    
    @IsTest
    static void testGetProjects_Success() {
        // Call the REST endpoint
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/Projects';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute the test
        Test.startTest();
        ProjectListingServiceController.ResponseWrapper response = ProjectListingServiceController.getProjects();
        Test.stopTest();
        
        // Verify results
        System.assertEquals(true, response.success, 'Success flag should be true');
        System.assertEquals('Projects retrieved successfully', response.message, 'Success message should match');
        System.assertEquals(1, response.projects.size(), 'Should return only active projects');
        System.assertEquals('Test Active Project', response.projects[0].Name, 'Project name should match');
    }
    
    @IsTest
    static void testGetProjects_NoProjects() {
        // Delete all test data
        delete [SELECT Id FROM Project__c];
        
        // Call the REST endpoint
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/Projects';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute the test
        Test.startTest();
        ProjectListingServiceController.ResponseWrapper response = ProjectListingServiceController.getProjects();
        Test.stopTest();
        
        // Verify results
        System.assertEquals(true, response.success, 'Success flag should be true');
        System.assertEquals('No projects found', response.message, 'No projects message should match');
        System.assertEquals(0, response.projects.size(), 'Should return empty list');
    }
    
    @IsTest
    static void testGetProjects_Exception() {
        // Create a mock request with null values to force an exception
        RestRequest req = null;
        RestResponse res = null;
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        ProjectListingServiceController.ResponseWrapper response = ProjectListingServiceController.getProjects();
        Test.stopTest();
        
        // Verify results
        System.assertEquals(false, response.success, 'Success flag should be false');
        System.assert(response.message.startsWith('Error:'), 'Error message should be present');
        System.assertEquals(0, response.projects.size(), 'Should return empty list');
    }
}