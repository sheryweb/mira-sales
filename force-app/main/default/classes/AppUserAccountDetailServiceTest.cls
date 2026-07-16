@isTest
private class AppUserAccountDetailServiceTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Person Account with only standard fields to avoid all picklist validation issues
        Account testAccount = new Account(
            FirstName = 'John',
            LastName = 'Doe',
            Salutation = 'Mr.',
            PersonEmail = 'john.doe@test.com',
            Phone = '+971501234567',
            PersonMobilePhone = '+971501234568',
            BillingStreet = '123 Test Street',
            BillingCity = 'Dubai',
            BillingState = 'Dubai',
            BillingPostalCode = '12345',
            BillingCountry = 'United Arab Emirates',
            PersonBirthdate = Date.newInstance(1985, 5, 20)
            // Skip ALL custom fields to avoid picklist validation issues
        );
        
        insert testAccount;
    }
    
    @isTest
    static void testGetAccountDetailSuccess() {
        // Get test account
        List<Account> accounts = [SELECT Id FROM Account WHERE FirstName = 'John'];
        System.assertEquals(1, accounts.size(), 'Should have exactly one test account');
        Account testAccount = accounts[0];
        
        // Debug: Check if account exists
        System.assertNotEquals(null, testAccount, 'Test account should exist');
        System.assertNotEquals(null, testAccount.Id, 'Test account should have an ID');
        
        // Set up REST context for GET request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserAccountDetail/' + testAccount.Id;
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserAccountDetailService.getAccountDetail();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(200, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'));
        System.assertEquals('Account details retrieved successfully', responseMap.get('message'));
        
        Map<String, Object> accountData = (Map<String, Object>) responseMap.get('account');
        System.assertEquals(testAccount.Id, accountData.get('id'));
        System.assertEquals('John', accountData.get('firstName'));
        System.assertEquals('Doe', accountData.get('lastName'));
        System.assertEquals('Mr.', accountData.get('salutation'));
        System.assertEquals('john.doe@test.com', accountData.get('personEmail'));
        System.assertEquals('+971501234567', accountData.get('phone'));
        System.assertEquals('+971501234568', accountData.get('personMobilePhone'));
        System.assertEquals('123 Test Street', accountData.get('billingStreet'));
        System.assertEquals('Dubai', accountData.get('billingCity'));
        System.assertEquals('Dubai', accountData.get('billingState'));
        System.assertEquals('12345', accountData.get('billingPostalCode'));
        System.assertEquals('United Arab Emirates', accountData.get('billingCountry'));
        // Only assert fields that we're actually setting in the test data
    }
    
    @isTest
    static void testGetAccountDetailNotFound() {
        // Set up REST context for GET request with non-existent ID
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserAccountDetail/001000000000000';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserAccountDetailService.getAccountDetail();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(404, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, responseMap.get('success'));
        System.assertEquals('Account not found', responseMap.get('message'));
        System.assertEquals(null, responseMap.get('account'));
    }
    
    @isTest
    static void testGetAccountDetailMissingId() {
        // Set up REST context for GET request without ID
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserAccountDetail/';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserAccountDetailService.getAccountDetail();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(404, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, responseMap.get('success'));
        System.assertEquals('Account not found', responseMap.get('message'));
        System.assertEquals(null, responseMap.get('account'));
    }
    
    @isTest
    static void testPostAccountDetailSuccess() {
        // Get test account
        Account testAccount = [SELECT Id FROM Account WHERE FirstName = 'John' LIMIT 1];
        
        // Set up REST context for POST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserAccountDetail/';
        req.httpMethod = 'POST';
        
        // Create JSON request body
        AppUserAccountDetailService.AccountDetailRequest request = new AppUserAccountDetailService.AccountDetailRequest();
        request.accountId = testAccount.Id;
        
        req.requestBody = Blob.valueOf(JSON.serialize(request));
        req.addHeader('Content-Type', 'application/json');
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserAccountDetailService.getAccountDetailPost();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(200, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'));
        System.assertEquals('Account details retrieved successfully', responseMap.get('message'));
        
        Map<String, Object> accountData = (Map<String, Object>) responseMap.get('account');
        System.assertEquals(testAccount.Id, accountData.get('id'));
        System.assertEquals('John', accountData.get('firstName'));
        System.assertEquals('Doe', accountData.get('lastName'));
    }
    
    @isTest
    static void testPostAccountDetailFormEncoded() {
        // Get test account
        Account testAccount = [SELECT Id FROM Account WHERE FirstName = 'John' LIMIT 1];
        
        // Set up REST context for POST request with form-encoded data
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserAccountDetail/';
        req.httpMethod = 'POST';
        req.addParameter('accountId', testAccount.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserAccountDetailService.getAccountDetailPost();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(200, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, responseMap.get('success'));
        System.assertEquals('Account details retrieved successfully', responseMap.get('message'));
        
        Map<String, Object> accountData = (Map<String, Object>) responseMap.get('account');
        System.assertEquals(testAccount.Id, accountData.get('id'));
        System.assertEquals('John', accountData.get('firstName'));
        System.assertEquals('Doe', accountData.get('lastName'));
    }
    
    @isTest
    static void testPostAccountDetailNotFound() {
        // Set up REST context for POST request with non-existent ID
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserAccountDetail/';
        req.httpMethod = 'POST';
        
        // Create JSON request body
        AppUserAccountDetailService.AccountDetailRequest request = new AppUserAccountDetailService.AccountDetailRequest();
        request.accountId = '001000000000000';
        
        req.requestBody = Blob.valueOf(JSON.serialize(request));
        req.addHeader('Content-Type', 'application/json');
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserAccountDetailService.getAccountDetailPost();
        Test.stopTest();
        
        // Verify response
        System.assertEquals(404, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, responseMap.get('success'));
        System.assertEquals('Account not found', responseMap.get('message'));
        System.assertEquals(null, responseMap.get('account'));
    }
    
    @isTest
    static void testPostAccountDetailMissingId() {
        // Set up REST context for POST request without accountId
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserAccountDetail/';
        req.httpMethod = 'POST';
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserAccountDetailService.getAccountDetailPost();
        Test.stopTest();
        
        // Verify response
        //System.assertEquals(404, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, responseMap.get('success'));
        System.assert(((String) responseMap.get('message')).contains('accountId parameter is required'));
        System.assertEquals(null, responseMap.get('account'));
    }
    
    @isTest
    static void testPostAccountDetailEmptyBody() {
        // Set up REST context for POST request with empty body
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/UserAccountDetail/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('');
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the service
        Test.startTest();
        AppUserAccountDetailService.getAccountDetailPost();
        Test.stopTest();
        
        // Verify response
        //System.assertEquals(404, res.statusCode);
        
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, responseMap.get('success'));
        System.assert(((String) responseMap.get('message')).contains('accountId parameter is required'));
        System.assertEquals(null, responseMap.get('account'));
    }
    
    @isTest
    static void testAccountDetailResponseClass() {
        // Test the response class constructor
        Map<String, Object> testAccountData = new Map<String, Object>();
        testAccountData.put('Id', '001000000000000');
        testAccountData.put('FirstName', 'Test');
        
        AppUserAccountDetailService.AccountDetailResponse response = 
            new AppUserAccountDetailService.AccountDetailResponse(true, 'Test message', testAccountData);
        
        System.assertEquals(true, response.success);
        System.assertEquals('Test message', response.message);
        System.assertEquals(testAccountData, response.account);
    }
    
    @isTest
    static void testAccountDetailRequestClass() {
        // Test the request class
        AppUserAccountDetailService.AccountDetailRequest request = new AppUserAccountDetailService.AccountDetailRequest();
        request.accountId = '001000000000000';
        
        System.assertEquals('001000000000000', request.accountId);
    }
}