@isTest
private class GenerateLeadServiceTest {
    @isTest
    static void testLeadGeneration() {
        // Set up test data
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testleaduser@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        req.httpMethod = 'POST';
        req.addParameter('firstName', 'John');
        req.addParameter('lastName', 'Doe');
        req.addParameter('clientEmail', 'john.doe@example.com');
        req.addParameter('clientPhone', '1234567890');
        req.addParameter('company', 'ExampleCompany');
        req.addParameter('clientLocation', 'NewYork');
        req.addParameter('applicationUrl', 'http://example.com');
        req.addParameter('clientLanguage', 'English');
        req.addParameter('pageLanguage', 'English');
        req.addParameter('building', 'BuildingA');
        req.addParameter('phase', 'Phase1');
        req.addParameter('budget', '1000.00');
        req.addParameter('gcid', '123456');
        req.addParameter('clientCountry', 'USA');
        req.addParameter('project', 'ProjectX');
        req.addParameter('entity', 'EntityY');
        req.addParameter('unit', 'UnitZ');
        req.addParameter('utm', 'some utm');
        req.addParameter('rmemail', 'testuser@example.com');

        // Call the method
        String response = GenerateLeadService.leadGeneration();

        // Verify the response
        System.assert(response != null);
        Lead createdLead = (Lead) JSON.deserialize(response, Lead.class);
        //System.assertEquals('John', createdLead.FirstName);
        //System.assertEquals('Doe', createdLead.LastName);
        //System.assertEquals('testleaduser@example.com', createdLead.Owner.Email);
    }

    @isTest
    static void testEmptyRequestBody() {
        // Set up test data
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        req.requestBody = Blob.valueOf('');
        req.httpMethod = 'POST';

        // Call the method
        String response = GenerateLeadService.leadGeneration();

        // Verify the response
        System.assert(response != null);
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('error', responseMap.get('status'));
        System.assertEquals('Request parameters are empty', responseMap.get('message'));
    }
}