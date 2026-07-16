@isTest
public class AppUserLoginTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test App_User__c records with encrypted passwords
        List<App_User__c> testUsers = new List<App_User__c>();
        
        // Create an active user
        Blob passwordBlob1 = Blob.valueOf('testPassword123');
        Blob encryptedBlob1 = Crypto.generateDigest('SHA256', passwordBlob1);
        String encryptedPassword1 = EncodingUtil.convertToHex(encryptedBlob1);
        
        testUsers.add(new App_User__c(
            Full_Name__c = 'Active User',
            Email__c = 'active@test.com',
            Password__c = encryptedPassword1,
            Status__c = 'Active'
        ));
        
        // Create an inactive user
        Blob passwordBlob2 = Blob.valueOf('inactivePassword456');
        Blob encryptedBlob2 = Crypto.generateDigest('SHA256', passwordBlob2);
        String encryptedPassword2 = EncodingUtil.convertToHex(encryptedBlob2);
        
        testUsers.add(new App_User__c(
            Full_Name__c = 'Inactive User',
            Email__c = 'inactive@test.com',
            Password__c = encryptedPassword2,
            Status__c = 'Inactive'
        ));
        
        // Create a user with null status (should be treated as active)
        Blob passwordBlob3 = Blob.valueOf('nullStatusPassword789');
        Blob encryptedBlob3 = Crypto.generateDigest('SHA256', passwordBlob3);
        String encryptedPassword3 = EncodingUtil.convertToHex(encryptedBlob3);
        
        testUsers.add(new App_User__c(
            Full_Name__c = 'Null Status User',
            Email__c = 'nullstatus@test.com',
            Password__c = encryptedPassword3,
            Status__c = null
        ));
        
        insert testUsers;
    }
    
    @isTest
    static void testSuccessfulLogin() {
        // Test successful login with active user
        String testJson = '{"email":"active@test.com","password":"testPassword123"}';
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the login method
        AppUserLogin.LoginResponse result = AppUserLogin.loginAppUser();
        
        Test.stopTest();
        
        // Verify successful response
        System.assertEquals(true, result.success, 'Login should be successful');
        System.assertEquals('Login successful', result.message);
        System.assertNotEquals(null, result.userId, 'User ID should not be null');
        System.assertEquals('Active User', result.fullName, 'Full name should match');
        System.assertEquals(200, response.statusCode, 'Status code should be 200');
    }
    
    @isTest
    static void testSuccessfulLoginFormEncoded() {
        // Test successful login with form-encoded data (application/x-www-form-urlencoded)
        
        // Setup REST context with form parameters instead of JSON body
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        // Simulate form-encoded parameters
        request.params.put('email', 'active@test.com');
        request.params.put('password', 'testPassword123');
        
        // No request body for form-encoded
        request.requestBody = null;
        
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the login method
        AppUserLogin.LoginResponse result = AppUserLogin.loginAppUser();
        
        Test.stopTest();
        
        // Verify successful response
        System.assertEquals(true, result.success, 'Form-encoded login should be successful');
        System.assertEquals('Login successful', result.message);
        System.assertNotEquals(null, result.userId, 'User ID should not be null');
        System.assertEquals('Active User', result.fullName, 'Full name should match');
        System.assertEquals(200, response.statusCode, 'Status code should be 200');
    }
    
    @isTest
    static void testInvalidEmail() {
        // Test login with non-existent email
        String testJson = '{"email":"nonexistent@test.com","password":"anyPassword"}';
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the login method
        AppUserLogin.LoginResponse result = AppUserLogin.loginAppUser();
        
        Test.stopTest();
        
        // Verify failed response
        System.assertEquals(false, result.success, 'Login should fail');
        System.assertEquals('Invalid email or password', result.message);
        System.assertEquals(null, result.userId, 'User ID should be null');
        System.assertEquals(null, result.fullName, 'Full name should be null');
        System.assertEquals(401, response.statusCode, 'Status code should be 401');
    }
    
    @isTest
    static void testInvalidPassword() {
        // Test login with correct email but wrong password
        String testJson = '{"email":"active@test.com","password":"wrongPassword"}';
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the login method
        AppUserLogin.LoginResponse result = AppUserLogin.loginAppUser();
        
        Test.stopTest();
        
        // Verify failed response
        System.assertEquals(false, result.success, 'Login should fail');
        System.assertEquals('Invalid email or password', result.message);
        System.assertEquals(null, result.userId, 'User ID should be null');
        System.assertEquals(401, response.statusCode, 'Status code should be 401');
    }
    
    @isTest
    static void testInvalidPasswordFormEncoded() {
        // Test form-encoded login with wrong password
        
        // Setup REST context with form parameters
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        // Simulate form-encoded parameters with wrong password
        request.params.put('email', 'active@test.com');
        request.params.put('password', 'wrongPassword');
        
        request.requestBody = null;
        
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the login method
        AppUserLogin.LoginResponse result = AppUserLogin.loginAppUser();
        
        Test.stopTest();
        
        // Verify failed response
        System.assertEquals(false, result.success, 'Wrong password should fail');
        System.assertEquals('Invalid email or password', result.message);
        System.assertEquals(null, result.userId, 'User ID should be null');
        System.assertEquals(401, response.statusCode, 'Status code should be 401');
    }
    
    @isTest
    static void testInactiveUser() {
        // Test login with inactive user
        String testJson = '{"email":"inactive@test.com","password":"inactivePassword456"}';
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the login method
        AppUserLogin.LoginResponse result = AppUserLogin.loginAppUser();
        
        Test.stopTest();
        
        // Verify failed response (inactive users treated same as invalid credentials for security)
        System.assertEquals(false, result.success, 'Login should fail for inactive user');
        System.assertEquals('Invalid email or password', result.message);
        System.assertEquals(null, result.userId, 'User ID should be null');
        System.assertEquals(401, response.statusCode, 'Status code should be 401');
    }
    
    @isTest
    static void testNullStatusUser() {
        // Test login with user having null status (should be treated as active)
        String testJson = '{"email":"nullstatus@test.com","password":"nullStatusPassword789"}';
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the login method
        AppUserLogin.LoginResponse result = AppUserLogin.loginAppUser();
        
        Test.stopTest();
        
        // Verify successful response
        System.assertEquals(true, result.success, 'Login should be successful for null status user');
        System.assertEquals('Login successful', result.message);
        System.assertNotEquals(null, result.userId, 'User ID should not be null');
        System.assertEquals('Null Status User', result.fullName, 'Full name should match');
        System.assertEquals(200, response.statusCode, 'Status code should be 200');
    }
    
    @isTest
    static void testEmptyRequestBody() {
        // Test with empty request body
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf('');
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the login method
        AppUserLogin.LoginResponse result = AppUserLogin.loginAppUser();
        
        Test.stopTest();
        
        // Verify error response
        System.assertEquals(false, result.success, 'Login should fail');
        System.assert(result.message.contains('Request body is empty'), 'Should contain empty body error message');
        System.assertEquals(400, response.statusCode, 'Status code should be 400');
    }
    
    @isTest
    static void testMissingEmail() {
        // Test with missing email
        String testJson = '{"password":"testPassword123"}';
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the login method
        AppUserLogin.LoginResponse result = AppUserLogin.loginAppUser();
        
        Test.stopTest();
        
        // Verify error response
        System.assertEquals(false, result.success, 'Login should fail');
        System.assert(result.message.contains('Email and Password are required'), 'Should contain validation error message');
        System.assertEquals(400, response.statusCode, 'Status code should be 400');
    }
    
    @isTest
    static void testMissingPassword() {
        // Test with missing password
        String testJson = '{"email":"active@test.com"}';
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the login method
        AppUserLogin.LoginResponse result = AppUserLogin.loginAppUser();
        
        Test.stopTest();
        
        // Verify error response
        System.assertEquals(false, result.success, 'Login should fail');
        System.assert(result.message.contains('Email and Password are required'), 'Should contain validation error message');
        System.assertEquals(400, response.statusCode, 'Status code should be 400');
    }
    
    @isTest
    static void testInvalidJson() {
        // Test with invalid JSON
        String testJson = '{"email":"active@test.com","password":"testPassword123"'; // Missing closing brace
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the login method
        AppUserLogin.LoginResponse result = AppUserLogin.loginAppUser();
        
        Test.stopTest();
        
        // Verify error response
        System.assertEquals(false, result.success, 'Login should fail');
        System.assert(result.message.contains('Error:'), 'Should contain error message');
        System.assertEquals(400, response.statusCode, 'Status code should be 400');
    }
    
    @isTest
    static void testLoginRequestWrapper() {
        // Test the LoginRequest wrapper class
        AppUserLogin.LoginRequest request = new AppUserLogin.LoginRequest();
        request.email = 'test@test.com';
        request.password = 'testpass';
        
        // Verify properties are set correctly
        System.assertEquals('test@test.com', request.email);
        System.assertEquals('testpass', request.password);
    }
    
    @isTest
    static void testLoginResponseWrapper() {
        // Test the LoginResponse wrapper class
        AppUserLogin.LoginResponse response = new AppUserLogin.LoginResponse('test@test.com', true, 'Success', 'userId123', 'Test User');
        
        // Verify properties are set correctly
        System.assertEquals(true, response.success);
        System.assertEquals('Success', response.message);
        System.assertEquals('userId123', response.userId);
        System.assertEquals('Test User', response.fullName);
        
        // Test error response
        AppUserLogin.LoginResponse errorResponse = new AppUserLogin.LoginResponse(null, false, 'Error occurred', null, null);
        System.assertEquals(false, errorResponse.success);
        System.assertEquals('Error occurred', errorResponse.message);
        System.assertEquals(null, errorResponse.userId);
        System.assertEquals(null, errorResponse.fullName);
    }
    
    @isTest
    static void testWrongCredentialsExplicit() {
        // Explicit test to ensure wrong credentials return false
        String testJson = '{"email":"active@test.com","password":"definitelyWrongPassword123"}';
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the login method
        AppUserLogin.LoginResponse result = AppUserLogin.loginAppUser();
        
        Test.stopTest();
        
        // Debug for troubleshooting
        System.debug('Wrong credentials test - Success: ' + result.success);
        System.debug('Wrong credentials test - Message: ' + result.message);
        
        // This should definitely fail
        System.assertEquals(false, result.success, 'Wrong password should fail. Message: ' + result.message);
        System.assertEquals('Invalid email or password', result.message);
        System.assertEquals(401, response.statusCode, 'Should return 401 for wrong credentials');
    }
    
    @isTest
    static void testPasswordEncryptionHelper() {
        // Test the password encryption helper method
        Test.startTest();
        
        String password1 = 'testPassword123';
        String password2 = 'differentPassword456';
        
        String encrypted1 = AppUserLogin.encryptPassword(password1);
        String encrypted2 = AppUserLogin.encryptPassword(password2);
        
        Test.stopTest();
        
        // Verify encryption works
        System.assertNotEquals(null, encrypted1, 'Encrypted password should not be null');
        System.assertNotEquals(null, encrypted2, 'Encrypted password should not be null');
        System.assertNotEquals(password1, encrypted1, 'Encrypted password should be different from original');
        System.assertNotEquals(password2, encrypted2, 'Encrypted password should be different from original');
        System.assertNotEquals(encrypted1, encrypted2, 'Different passwords should have different encrypted values');
        
        // Test with same password should give same encryption
        String encrypted1Again = AppUserLogin.encryptPassword(password1);
        System.assertEquals(encrypted1, encrypted1Again, 'Same password should encrypt to same value');
        
        System.debug('Password: ' + password1);
        System.debug('Encrypted: ' + encrypted1);
        System.debug('Encrypted length: ' + encrypted1.length());
    }
    
    @isTest
    static void testFreshUserWrongPassword() {
        // Create a fresh user and immediately test wrong password
        // This bypasses any setup data issues
        
        Test.startTest();
        
        // Create a user with a known password
        String correctPassword = 'myCorrectPassword123';
        String wrongPassword = 'definitelyWrongPassword456';
        String email = 'fresh@test.com';
        
        // Encrypt the correct password the same way AppUserGenerate does
        Blob passwordBlob = Blob.valueOf(correctPassword);
        Blob encryptedBlob = Crypto.generateDigest('SHA256', passwordBlob);
        String encryptedPassword = EncodingUtil.convertToHex(encryptedBlob);
        
        // Create the user record
        App_User__c freshUser = new App_User__c(
            Full_Name__c = 'Fresh Test User',
            Email__c = email,
            Password__c = encryptedPassword,
            Status__c = 'Active'
        );
        insert freshUser;
        
        System.debug('FRESH USER CREATED:');
        System.debug('Email: ' + email);
        System.debug('Correct Password: ' + correctPassword);
        System.debug('Wrong Password: ' + wrongPassword);
        System.debug('Stored Encrypted: ' + encryptedPassword);
        
        // Now test with WRONG password
        String wrongJson = '{"email":"' + email + '","password":"' + wrongPassword + '"}';
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(wrongJson);
        RestContext.request = request;
        RestContext.response = response;
        
        // Call login with wrong password
        AppUserLogin.LoginResponse result = AppUserLogin.loginAppUser();
        
                 Test.stopTest();
         
         System.debug('FRESH USER TEST RESULT:');
        System.debug('Success: ' + result.success);
        System.debug('Message: ' + result.message);
        System.debug('Status Code: ' + response.statusCode);
        
        // This MUST fail
        System.assertEquals(false, result.success, 'Wrong password must fail! Message: ' + result.message);
        System.assertEquals('Invalid email or password', result.message, 'Wrong message returned');
        System.assertEquals(401, response.statusCode, 'Wrong status code');
        
        // Now test with CORRECT password to verify the user works
        String correctJson = '{"email":"' + email + '","password":"' + correctPassword + '"}';
        
        RestRequest correctRequest = new RestRequest();
        RestResponse correctResponse = new RestResponse();
        correctRequest.requestBody = Blob.valueOf(correctJson);
        RestContext.request = correctRequest;
        RestContext.response = correctResponse;
        
        AppUserLogin.LoginResponse correctResult = AppUserLogin.loginAppUser();
        
        System.debug('CORRECT PASSWORD TEST:');
        System.debug('Success: ' + correctResult.success);
        System.debug('Message: ' + correctResult.message);
        
        // This MUST succeed
        System.assertEquals(true, correctResult.success, 'Correct password must succeed! Message: ' + correctResult.message);
    }
}