@isTest
private class AppUserOpportunityListServiceTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test App User
        App_User__c testAppUser = new App_User__c(
            Full_Name__c = 'Test User',
            Email__c = 'test@example.com',
            Status__c = 'Active'
        );
        insert testAppUser;
        
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account',
            App_User__c = testAppUser.Id
        );
        insert testAccount;
        
        // Create test Opportunities with minimal required fields
        List<Opportunity> testOpportunities = new List<Opportunity>();
        
        Opportunity opp1 = new Opportunity(
            Name = 'Test Opportunity 1',
            AccountId = testAccount.Id,
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            App_User__c = testAppUser.Id
        );
        testOpportunities.add(opp1);
        
        Opportunity opp2 = new Opportunity(
            Name = 'Test Opportunity 2',
            AccountId = testAccount.Id,
            StageName = 'New',
            CloseDate = Date.today().addDays(60),
            App_User__c = testAppUser.Id
        );
        testOpportunities.add(opp2);
        
        Opportunity opp3 = new Opportunity(
            Name = 'Test Opportunity 3',
            AccountId = testAccount.Id,
            StageName = 'New',
            CloseDate = Date.today().addDays(-10),
            App_User__c = testAppUser.Id
        );
        testOpportunities.add(opp3);
        
        insert testOpportunities;
    }
    
    @isTest
    static void testGetOpportunityListSuccess() {
        // Get test data
        App_User__c testAppUser = [SELECT Id FROM App_User__c LIMIT 1];
        
        // Set up the request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserOpportunityList/new';
        req.httpMethod = 'GET';
        req.params.put('userId', testAppUser.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserOpportunityListService.getOpportunityList();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(200, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'));
        System.assertEquals('New opportunities retrieved successfully', responseMap.get('message'));
        
        List<Object> opportunities = (List<Object>) responseMap.get('opportunities');
        System.assertEquals(3, opportunities.size());
        
        // Verify that we have the expected number of opportunities
        System.assertEquals(3, opportunities.size());
    }
    
    @isTest
    static void testGetOpportunityListPostSuccess() {
        // Get test data
        App_User__c testAppUser = [SELECT Id FROM App_User__c LIMIT 1];
        
        // Set up the request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserOpportunityList/new';
        req.httpMethod = 'POST';
        
        // Test with JSON body
        AppUserOpportunityListService.OpportunityListRequest request = new AppUserOpportunityListService.OpportunityListRequest();
        request.userId = testAppUser.Id;
        request.stageType = 'new';
        req.requestBody = Blob.valueOf(JSON.serialize(request));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserOpportunityListService.getOpportunityListPost();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(200, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'));
        System.assertEquals('New opportunities retrieved successfully', responseMap.get('message'));
        
        List<Object> opportunities = (List<Object>) responseMap.get('opportunities');
        System.assertEquals(3, opportunities.size());
    }
    
    @isTest
    static void testGetOpportunityListPostWithFormData() {
        // Get test data
        App_User__c testAppUser = [SELECT Id FROM App_User__c LIMIT 1];
        
        // Set up the request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserOpportunityList/new';
        req.httpMethod = 'POST';
        req.params.put('userId', testAppUser.Id);
        req.params.put('stageType', 'new');
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserOpportunityListService.getOpportunityListPost();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(200, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'));
        System.assertEquals('New opportunities retrieved successfully', responseMap.get('message'));
        
        List<Object> opportunities = (List<Object>) responseMap.get('opportunities');
        System.assertEquals(3, opportunities.size());
    }
    
    @isTest
    static void testGetOpportunityListMissingUserId() {
        // Set up the request without userId
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserOpportunityList/new';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserOpportunityListService.getOpportunityList();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(400, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, responseMap.get('success'));
        System.assert(((String) responseMap.get('message')).contains('userId parameter is required'));
    }
    
    @isTest
    static void testGetOpportunityListInvalidUserId() {
        // Set up the request with invalid userId
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserOpportunityList/new';
        req.httpMethod = 'GET';
        req.params.put('userId', 'invalid-id');
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserOpportunityListService.getOpportunityList();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(404, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, responseMap.get('success'));
        System.assertEquals('App User not found or inactive', responseMap.get('message'));
    }
    
    @isTest
    static void testGetOpportunityListInactiveUser() {
        // Create inactive App User
        App_User__c inactiveAppUser = new App_User__c(
            Full_Name__c = 'Inactive User',
            Email__c = 'inactive@example.com',
            Status__c = 'Inactive'
        );
        insert inactiveAppUser;
        
        // Set up the request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserOpportunityList/new';
        req.httpMethod = 'GET';
        req.params.put('userId', inactiveAppUser.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserOpportunityListService.getOpportunityList();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(404, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, responseMap.get('success'));
        System.assertEquals('App User not found or inactive', responseMap.get('message'));
    }
    
    @isTest
    static void testGetOpportunityListNoOpportunities() {
        // Create App User without opportunities
        App_User__c newAppUser = new App_User__c(
            Full_Name__c = 'New User',
            Email__c = 'new@example.com',
            Status__c = 'Active'
        );
        insert newAppUser;
        
        // Set up the request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserOpportunityList/new';
        req.httpMethod = 'GET';
        req.params.put('userId', newAppUser.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserOpportunityListService.getOpportunityList();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(200, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'));
        System.assertEquals('New opportunities retrieved successfully', responseMap.get('message'));
        
        List<Object> opportunities = (List<Object>) responseMap.get('opportunities');
        System.assertEquals(0, opportunities.size());
    }
    
    @isTest
    static void testGetOpportunityListWithNullAccount() {
        // Get test data
        App_User__c testAppUser = [SELECT Id FROM App_User__c LIMIT 1];
        
        // Create opportunity without account
        Opportunity oppWithoutAccount = new Opportunity(
            Name = 'Opportunity Without Account',
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            App_User__c = testAppUser.Id
        );
        insert oppWithoutAccount;
        
        // Set up the request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserOpportunityList/new';
        req.httpMethod = 'GET';
        req.params.put('userId', testAppUser.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserOpportunityListService.getOpportunityList();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(200, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'));
        
        List<Object> opportunities = (List<Object>) responseMap.get('opportunities');
        System.assertEquals(4, opportunities.size());
    }
    
    @isTest
    static void testGetOpportunityListBookedStage() {
        // Get test data
        App_User__c testAppUser = [SELECT Id FROM App_User__c LIMIT 1];
        
        // Create opportunity with Booked stage (if validation allows)
        try {
            Opportunity bookedOpp = new Opportunity(
                Name = 'Booked Opportunity',
                AccountId = [SELECT Id FROM Account LIMIT 1].Id,
                StageName = 'Booked',
                CloseDate = Date.today().addDays(30),
                App_User__c = testAppUser.Id
            );
            insert bookedOpp;
        } catch (Exception e) {
            // If validation prevents Booked stage, skip this test
            System.debug('Cannot create Booked opportunity: ' + e.getMessage());
            return;
        }
        
        // Set up the request for booked stage
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserOpportunityList/booked';
        req.httpMethod = 'GET';
        req.params.put('userId', testAppUser.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserOpportunityListService.getOpportunityList();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(200, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'));
        System.assertEquals('Booked/Reserved/Sold opportunities retrieved successfully', responseMap.get('message'));
    }
    
    @isTest
    static void testGetOpportunityListCancelledStage() {
        // Get test data
        App_User__c testAppUser = [SELECT Id FROM App_User__c LIMIT 1];
        
        // Create opportunity with Cancelled stage
        Opportunity cancelledOpp = new Opportunity(
            Name = 'Cancelled Opportunity',
            AccountId = [SELECT Id FROM Account LIMIT 1].Id,
            StageName = 'Cancelled',
            CloseDate = Date.today().addDays(30),
            App_User__c = testAppUser.Id
        );
        insert cancelledOpp;
        
        // Set up the request for cancelled stage
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserOpportunityList/cancelled';
        req.httpMethod = 'GET';
        req.params.put('userId', testAppUser.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserOpportunityListService.getOpportunityList();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(200, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'));
        System.assertEquals('Cancelled/Transferred opportunities retrieved successfully', responseMap.get('message'));
    }
    
    @isTest
    static void testGetOpportunityListInvalidStageType() {
        // Get test data
        App_User__c testAppUser = [SELECT Id FROM App_User__c LIMIT 1];
        
        // Set up the request with invalid stage type
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserOpportunityList/invalid';
        req.httpMethod = 'GET';
        req.params.put('userId', testAppUser.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserOpportunityListService.getOpportunityList();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(400, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, responseMap.get('success'));
        System.assert(((String) responseMap.get('message')).contains('Invalid stage type'));
    }
}