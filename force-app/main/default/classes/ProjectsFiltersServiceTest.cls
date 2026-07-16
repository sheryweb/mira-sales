@isTest
private class ProjectsFiltersServiceTest {

    @TestSetup
    static void makeData(){
        
        List<Project__c> projects = new List<Project__c>();
        projects.add(new Project__c (
            Name = 'test project', 
            Description__c = 'description', 
            District__c = 'Meydan', 
            Coordinates_Latitude__c = 2, 
            Coordinates_Longitude__c = 1, 
            Handover__c = Date.today(), 
            Minimum_Cost__c = 2,
            Publish_Project__c = 'Published',
            Project_Status__c = 'Completed'
        ));
        insert projects;

        List<Unit__c> units = new List<Unit__c>();
        units.add(new Unit__c(
            Title__c = 'Test Unit',
            Cost_AED__c = 10,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Additional_Area__c = 200,
            Floor__c = 5,
            Number_of_Bedrooms__c = 0,
            Number_of_Bathrooms__c = 2,
            Building__c = 'Test Building',
            Panorama_Link__c = 'Test Link',
            Project__c = projects[0].Id,
            Status__c = 'Draft'
        ));
        units.add(new Unit__c(
            Title__c = 'Test Unit 2',
            Cost_AED__c = 1000000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Additional_Area__c = 200,
            Floor__c = 5,
            Number_of_Bedrooms__c = 2,
            Number_of_Bathrooms__c = 2,
            Building__c = 'Test Building',
            Panorama_Link__c = 'Test Link',
            Project__c = projects[0].Id,
            Status__c = 'Draft'
        ));
        insert units;
    }

    @isTest
    static void testDoGet() {
        List<Project__c> projects = [SELECT Id FROM Project__c];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/projectsFilters';
        req.httpMethod = 'GET';
        req.params.put('minimalPrice', '10');
        req.params.put('maximalPrice', '1000000');
        req.params.put('projects', projects[0].Id);
        req.params.put('districts', 'Discovery Gardens,Meydan');
        req.params.put('types', 'Villa,Apartment');
        req.params.put('bedrooms', '2,4');
        req.params.put('status', 'Completed,Off-Plan');
        RestResponse response = new RestResponse();

        RestContext.request = req;
        RestContext.response = response;


        Test.startTest();
        ProjectsFiltersService.doGet();
        Test.stopTest();

        System.assertEquals('application/json', RestContext.response.headers.get('Content-Type'));
        System.assertNotEquals(null, RestContext.response.responseBody);

        // Map<String, Object> responseBodyMap = (Map<String, Object>)JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        // System.assertEquals(units[0].Id, responseBodyMap.get('id'));
        // System.assertEquals(units[0].Title_Formula__c, responseBodyMap.get('title'));
    }

}