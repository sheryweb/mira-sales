@isTest
public class AppUserGenerateTest {
    
    @isTest
    static void testCreateAppUserSuccess() {
        // Setup test data
        String testJson = '{"fullName":"John Doe","email":"john.doe@test.com","password":"testPassword123","status":"Active"}';
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the service method
        AppUserGenerate.AppUserResponse result = AppUserGenerate.createAppUser();
        
        Test.stopTest();
        
        // Debug the actual response
        System.debug('Test Result Success: ' + result.success);
        System.debug('Test Result Message: ' + result.message);
        System.debug('Test Result UserId: ' + result.userId);
        System.debug('Test Response Status Code: ' + response.statusCode);
        
        // Verify response
        System.assertEquals(true, result.success, 'Response should be successful. Actual message: ' + result.message);
        System.assertEquals('App User created successfully', result.message);
        System.assertNotEquals(null, result.userId, 'User ID should not be null');
        System.assertEquals(201, response.statusCode, 'Status code should be 201');
        
        // Verify record was created
        List<App_User__c> createdUsers = [SELECT Id, Full_Name__c, Email__c, Status__c, Password__c FROM App_User__c WHERE Email__c = 'john.doe@test.com'];
        System.assertEquals(1, createdUsers.size(), 'One user should be created');
        
        App_User__c createdUser = createdUsers[0];
        System.assertEquals('John Doe', createdUser.Full_Name__c);
        System.assertEquals('john.doe@test.com', createdUser.Email__c);
        System.assertEquals('Active', createdUser.Status__c);
        System.assertNotEquals('testPassword123', createdUser.Password__c, 'Password should be encrypted');
        System.assertNotEquals(null, createdUser.Password__c, 'Encrypted password should not be null');
    }
    
    @isTest
    static void testCreateAppUserEmptyBody() {
        // Setup empty request body
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf('');
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the service method
        AppUserGenerate.AppUserResponse result = AppUserGenerate.createAppUser();
        
        Test.stopTest();
        
        // Verify error response
        System.assertEquals(false, result.success, 'Response should be unsuccessful');
        System.assert(result.message.contains('Request body is empty'), 'Should contain empty body error message');
        System.assertEquals(null, result.userId, 'User ID should be null for error');
        System.assertEquals(400, response.statusCode, 'Status code should be 400');
        
        // Verify no record was created
        List<App_User__c> users = [SELECT Id FROM App_User__c];
        System.assertEquals(0, users.size(), 'No users should be created');
    }
    
    @isTest
    static void testCreateAppUserMissingEmail() {
        // Setup test data with missing email
        String testJson = '{"fullName":"John Doe","password":"testPassword123","status":"Active"}';
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the service method
        AppUserGenerate.AppUserResponse result = AppUserGenerate.createAppUser();
        
        Test.stopTest();
        
        // Verify error response
        System.assertEquals(false, result.success, 'Response should be unsuccessful');
        System.assert(result.message.contains('Email, Full Name, and Password are required'), 'Should contain validation error message');
        System.assertEquals(null, result.userId, 'User ID should be null for error');
        System.assertEquals(400, response.statusCode, 'Status code should be 400');
        
        // Verify no record was created
        List<App_User__c> users = [SELECT Id FROM App_User__c];
        System.assertEquals(0, users.size(), 'No users should be created');
    }
    
    @isTest
    static void testCreateAppUserMissingFullName() {
        // Setup test data with missing fullName
        String testJson = '{"email":"john.doe@test.com","password":"testPassword123","status":"Active"}';
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the service method
        AppUserGenerate.AppUserResponse result = AppUserGenerate.createAppUser();
        
        Test.stopTest();
        
        // Verify error response
        System.assertEquals(false, result.success, 'Response should be unsuccessful');
        System.assert(result.message.contains('Email, Full Name, and Password are required'), 'Should contain validation error message');
        System.assertEquals(400, response.statusCode, 'Status code should be 400');
    }
    
    @isTest
    static void testCreateAppUserMissingPassword() {
        // Setup test data with missing password
        String testJson = '{"fullName":"John Doe","email":"john.doe@test.com","status":"Active"}';
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the service method
        AppUserGenerate.AppUserResponse result = AppUserGenerate.createAppUser();
        
        Test.stopTest();
        
        // Verify error response
        System.assertEquals(false, result.success, 'Response should be unsuccessful');
        System.assert(result.message.contains('Email, Full Name, and Password are required'), 'Should contain validation error message');
        System.assertEquals(400, response.statusCode, 'Status code should be 400');
    }
    
    @isTest
    static void testCreateAppUserInvalidJson() {
        // Setup invalid JSON
        String testJson = '{"fullName":"John Doe","email":"john.doe@test.com"'; // Missing closing brace
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the service method
        AppUserGenerate.AppUserResponse result = AppUserGenerate.createAppUser();
        
        Test.stopTest();
        
        // Verify error response
        System.assertEquals(false, result.success, 'Response should be unsuccessful');
        System.assert(result.message.contains('Error:'), 'Should contain error message');
        System.assertEquals(400, response.statusCode, 'Status code should be 400');
        
        // Verify no record was created
        List<App_User__c> users = [SELECT Id FROM App_User__c];
        System.assertEquals(0, users.size(), 'No users should be created');
    }
    
    @isTest
    static void testCreateAppUserWithDifferentStatus() {
        // Setup test data with different status
        String testJson = '{"fullName":"Jane Smith","email":"jane.smith@test.com","password":"testPassword456","status":"Inactive"}';
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the service method
        AppUserGenerate.AppUserResponse result = AppUserGenerate.createAppUser();
        
        Test.stopTest();
        
        // Debug the actual response for troubleshooting
        System.debug('Test Result Success: ' + result.success);
        System.debug('Test Result Message: ' + result.message);
        System.debug('Test Result UserId: ' + result.userId);
        System.debug('Test Response Status Code: ' + response.statusCode);
        
        // Additional debugging - output the error to the assertion failure
        if (!result.success) {
            System.assert(false, 'API call failed with message: ' + result.message);
        }
        
        // Verify response
        System.assertEquals(true, result.success, 'Response should be successful. Actual message: ' + result.message);
        System.assertEquals(201, response.statusCode, 'Status code should be 201');
        
        // Verify record was created with correct status
        App_User__c createdUser = [SELECT Status__c FROM App_User__c WHERE Email__c = 'jane.smith@test.com' LIMIT 1];
        System.assertEquals('Inactive', createdUser.Status__c, 'Status should be Inactive');
    }
    
    @isTest
    static void testDiagnosticAppUserCreation() {
        // Simple diagnostic test to see exactly what's failing
        Test.startTest();
        
        try {
            App_User__c testUser = new App_User__c(
                Full_Name__c = 'Diagnostic User',
                Email__c = 'diagnostic@test.com',
                Password__c = 'encryptedPassword123',
                Status__c = 'Inactive'
            );
            
            insert testUser;
            System.assert(true, 'App_User__c creation succeeded');
            
        } catch (Exception e) {
            System.assert(false, 'Direct App_User__c creation failed: ' + e.getMessage() + ' | Type: ' + e.getTypeName());
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testAppUserRequestWrapper() {
        // Test the AppUserRequest wrapper class
        AppUserGenerate.AppUserRequest request = new AppUserGenerate.AppUserRequest();
        request.email = 'test@test.com';
        request.fullName = 'Test User';
        request.password = 'testpass';
        request.status = 'Active';
        
        // Verify properties are set correctly
        System.assertEquals('test@test.com', request.email);
        System.assertEquals('Test User', request.fullName);
        System.assertEquals('testpass', request.password);
        System.assertEquals('Active', request.status);
    }
    
    @isTest
    static void testAppUserResponseWrapper() {
        // Test the AppUserResponse wrapper class
        AppUserGenerate.AppUserResponse response = new AppUserGenerate.AppUserResponse(true, 'Success', 'userId123');
        
        // Verify properties are set correctly
        System.assertEquals(true, response.success);
        System.assertEquals('Success', response.message);
        System.assertEquals('userId123', response.userId);
        
        // Test error response
        AppUserGenerate.AppUserResponse errorResponse = new AppUserGenerate.AppUserResponse(false, 'Error occurred', null);
        System.assertEquals(false, errorResponse.success);
        System.assertEquals('Error occurred', errorResponse.message);
        System.assertEquals(null, errorResponse.userId);
    }
    
    @isTest
    static void testAppUserObjectFields() {
        // Test to verify App_User__c object and fields exist
        Test.startTest();
        
        try {
            // Try to create an App_User__c record directly to test field availability
            App_User__c testUser = new App_User__c(
                Full_Name__c = 'Test User',
                Email__c = 'test@example.com',
                Password__c = 'encryptedPassword',
                Status__c = 'Active'
            );
            
            insert testUser;
            
            System.debug('App_User__c object and fields exist and are accessible');
            System.debug('Created test user with ID: ' + testUser.Id);
            
            // Clean up
            delete testUser;
            
        } catch (Exception e) {
            System.debug('Error creating App_User__c: ' + e.getMessage());
            System.debug('Error Type: ' + e.getTypeName());
            System.assert(false, 'App_User__c object issue: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testPasswordEncryption() {
        // Test that different passwords generate different encrypted values
        String testJson1 = '{"fullName":"User One","email":"user1@test.com","password":"password1","status":"Active"}';
        String testJson2 = '{"fullName":"User Two","email":"user2@test.com","password":"password2","status":"Active"}';
        
        // Create first user
        RestRequest request1 = new RestRequest();
        RestResponse response1 = new RestResponse();
        request1.requestBody = Blob.valueOf(testJson1);
        RestContext.request = request1;
        RestContext.response = response1;
        
        AppUserGenerate.createAppUser();
        
        // Create second user
        RestRequest request2 = new RestRequest();
        RestResponse response2 = new RestResponse();
        request2.requestBody = Blob.valueOf(testJson2);
        RestContext.request = request2;
        RestContext.response = response2;
        
        Test.startTest();
        AppUserGenerate.createAppUser();
        Test.stopTest();
        
        // Verify both users were created with different encrypted passwords
        List<App_User__c> users = [SELECT Password__c FROM App_User__c ORDER BY Email__c];
        System.assertEquals(2, users.size(), 'Two users should be created');
        System.assertNotEquals(users[0].Password__c, users[1].Password__c, 'Encrypted passwords should be different');
    }
}