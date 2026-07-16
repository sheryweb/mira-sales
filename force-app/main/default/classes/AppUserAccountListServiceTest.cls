@isTest
public class AppUserAccountListServiceTest {
    
    // Record Type Constants (matching the service class)
    private static final String AGENCY_RECORD_TYPE_ID = '012Hp000001yUTAIA2';
    private static final String PERSON_ACCOUNT_RECORD_TYPE_ID = '012Hp000001yUTFIA2';
    
    @TestSetup
    static void setupTestData() {
        // Create test App_User__c records
        List<App_User__c> testUsers = new List<App_User__c>();
        
        // Create an active user with accounts
        Blob passwordBlob1 = Blob.valueOf('testPassword123');
        Blob encryptedBlob1 = Crypto.generateDigest('SHA256', passwordBlob1);
        String encryptedPassword1 = EncodingUtil.convertToHex(encryptedBlob1);
        
        App_User__c activeUser = new App_User__c(
            Full_Name__c = 'Active User',
            Email__c = 'active@test.com',
            Password__c = encryptedPassword1,
            Status__c = 'Active'
        );
        testUsers.add(activeUser);
        
        // Create an inactive user
        Blob passwordBlob2 = Blob.valueOf('inactivePassword456');
        Blob encryptedBlob2 = Crypto.generateDigest('SHA256', passwordBlob2);
        String encryptedPassword2 = EncodingUtil.convertToHex(encryptedBlob2);
        
        App_User__c inactiveUser = new App_User__c(
            Full_Name__c = 'Inactive User',
            Email__c = 'inactive@test.com',
            Password__c = encryptedPassword2,
            Status__c = 'Inactive'
        );
        testUsers.add(inactiveUser);
        
        // Create user with no accounts
        Blob passwordBlob3 = Blob.valueOf('noAccountsPassword789');
        Blob encryptedBlob3 = Crypto.generateDigest('SHA256', passwordBlob3);
        String encryptedPassword3 = EncodingUtil.convertToHex(encryptedBlob3);
        
        App_User__c userNoAccounts = new App_User__c(
            Full_Name__c = 'User No Accounts',
            Email__c = 'noaccounts@test.com',
            Password__c = encryptedPassword3,
            Status__c = 'Active'
        );
        testUsers.add(userNoAccounts);
        
        insert testUsers;
        
        // Create test Account records for the active user
        List<Account> testAccounts = new List<Account>();
        
        // Agency Record Type Accounts
        testAccounts.add(new Account(
            Name = 'Test Agency A',
            RecordTypeId = AGENCY_RECORD_TYPE_ID,
            Company_Email__c = 'agencya@test.com',
            Admin_Number__c = 'ADM001',
            TRN_Number__c = 'TRN123456789',
            Trade_License_Number__c = 'TL987654321',
            ORN_Number__c = 'ORN111222333',
            App_User__c = activeUser.Id
        ));
        
        testAccounts.add(new Account(
            Name = 'Test Agency B',
            RecordTypeId = AGENCY_RECORD_TYPE_ID,
            Company_Email__c = 'agencyb@test.com',
            Admin_Number__c = 'ADM002',
            TRN_Number__c = 'TRN987654321',
            Trade_License_Number__c = 'TL123456789',
            ORN_Number__c = 'ORN444555666',
            App_User__c = activeUser.Id
        ));
        
        // Person Account Record Type Accounts
        testAccounts.add(new Account(
            FirstName = 'John',
            LastName = 'Doe',
            RecordTypeId = PERSON_ACCOUNT_RECORD_TYPE_ID,
            PersonEmail = 'john.doe@test.com',
            Phone = '123-456-7890',
            PersonMobilePhone = '098-765-4321',
            Passport_No__pc = 'P123456789', // Person Account passport field
            App_User__c = activeUser.Id
        ));
        
        testAccounts.add(new Account(
            FirstName = 'Jane',
            LastName = 'Smith',
            RecordTypeId = PERSON_ACCOUNT_RECORD_TYPE_ID,
            PersonEmail = 'jane.smith@test.com',
            PersonMobilePhone = '555-123-4567',
            Passport_No__c = 'P987654321', // Regular Account passport field
            App_User__c = activeUser.Id
        ));
        
        // Add one more Person Account to test both passport fields (should prioritize __pc)
        testAccounts.add(new Account(
            FirstName = 'Mike',
            LastName = 'Johnson',
            RecordTypeId = PERSON_ACCOUNT_RECORD_TYPE_ID,
            PersonEmail = 'mike.johnson@test.com',
            Phone = '333-444-5555',
            Passport_No__pc = 'P111222333', // Person Account passport field (should be prioritized)
            Passport_No__c = 'P999888777',  // Regular Account passport field
            App_User__c = activeUser.Id
        ));
        
        insert testAccounts;
    }
    
    @isTest
    static void testGetAccountListAgencyRecordType() {
        // Get the test user
        App_User__c testUser = [SELECT Id FROM App_User__c WHERE Email__c = 'active@test.com' LIMIT 1];
        
        // Setup REST context with GET method for Agency Record Type
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.params.put('userId', testUser.Id);
        request.params.put('recordTypeId', AGENCY_RECORD_TYPE_ID);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the GET method
        AppUserAccountListService.getAccountList();
        
        Test.stopTest();
        
        // Parse response from responseBody
        String responseBody = response.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        
        // Verify successful response
        System.assertEquals(true, result.get('success'), 'Request should be successful');
        System.assertEquals('Accounts retrieved successfully', result.get('message'));
        List<Object> accounts = (List<Object>) result.get('accounts');
        System.assertNotEquals(null, accounts, 'Accounts list should not be null');
        System.assertEquals(2, accounts.size(), 'Should return 2 agency accounts');
        System.assertEquals(200, response.statusCode, 'Status code should be 200');
        
        // Cast first account to Map and verify agency-specific fields
        Map<String, Object> firstAccountMap = (Map<String, Object>) accounts[0];
        System.assertNotEquals(null, firstAccountMap.get('id'), 'Account ID should not be null');
        System.assertEquals('Test Agency A', firstAccountMap.get('name'), 'Account name should match');
        System.assertEquals('agencya@test.com', firstAccountMap.get('companyEmail'), 'Company email should match');
        System.assertEquals('ADM001', firstAccountMap.get('adminNumber'), 'Admin number should match');
        System.assertEquals('TRN123456789', firstAccountMap.get('trnNumber'), 'TRN number should match');
        System.assertEquals('TL987654321', firstAccountMap.get('tradeLicenseNumber'), 'Trade license number should match');
        System.assertEquals('ORN111222333', firstAccountMap.get('ornNumber'), 'ORN number should match');
        System.assertNotEquals(null, firstAccountMap.get('createdAt'), 'CreatedAt should not be null');
        
        // Verify Person Account fields are NOT present
        System.assertEquals(false, firstAccountMap.containsKey('personEmail'), 'PersonEmail should not be present for Agency');
        System.assertEquals(false, firstAccountMap.containsKey('phone'), 'Phone should not be present for Agency');
    }
    
    @isTest
    static void testGetAccountListPersonAccountRecordType() {
        // Get the test user
        App_User__c testUser = [SELECT Id FROM App_User__c WHERE Email__c = 'active@test.com' LIMIT 1];
        
        // Setup REST context with GET method for Person Account Record Type
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.params.put('userId', testUser.Id);
        request.params.put('recordTypeId', PERSON_ACCOUNT_RECORD_TYPE_ID);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the GET method
        AppUserAccountListService.getAccountList();
        
        Test.stopTest();
        
        // Parse response from responseBody
        String responseBody = response.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        
        // Verify successful response
        System.assertEquals(true, result.get('success'), 'Request should be successful');
        System.assertEquals('Accounts retrieved successfully', result.get('message'));
        List<Object> accounts = (List<Object>) result.get('accounts');
        System.assertNotEquals(null, accounts, 'Accounts list should not be null');
        System.assertEquals(3, accounts.size(), 'Should return 3 person accounts');
        System.assertEquals(200, response.statusCode, 'Status code should be 200');
        
        // Cast first account to Map and verify person-specific fields (sorted by LastName, FirstName)
        // First should be "John Doe" with Passport_No__pc
        Map<String, Object> firstAccountMap = (Map<String, Object>) accounts[0];
        System.assertNotEquals(null, firstAccountMap.get('id'), 'Account ID should not be null');
        System.assertEquals('John Doe', firstAccountMap.get('name'), 'Full name should match');
        System.assertEquals('john.doe@test.com', firstAccountMap.get('personEmail'), 'PersonEmail should match');
        System.assertEquals('123-456-7890', firstAccountMap.get('phone'), 'Phone should be Phone field (priority over mobile)');
        System.assertEquals('P123456789', firstAccountMap.get('passportNumber'), 'PassportNumber should match (from __pc field)');
        System.assertNotEquals(null, firstAccountMap.get('createdAt'), 'CreatedAt should not be null');
        
        // Verify Agency fields are NOT present
        System.assertEquals(false, firstAccountMap.containsKey('companyEmail'), 'Company_Email__c should not be present for Person Account');
        System.assertEquals(false, firstAccountMap.containsKey('adminNumber'), 'Admin_Number__c should not be present for Person Account');
        System.assertEquals(false, firstAccountMap.containsKey('status'), 'Status__c should not be present for Person Account');
        System.assertEquals(false, firstAccountMap.containsKey('trnNumber'), 'TRN_Number__c should not be present for Person Account');
        System.assertEquals(false, firstAccountMap.containsKey('tradeLicenseNumber'), 'Trade_License_Number__c should not be present for Person Account');
        System.assertEquals(false, firstAccountMap.containsKey('ornNumber'), 'ORN_Number__c should not be present for Person Account');
        
        // Second account should be "Mike Johnson" with Passport_No__pc (prioritized over __c)
        Map<String, Object> secondAccountMap = (Map<String, Object>) accounts[1];
        System.assertEquals('Mike Johnson', secondAccountMap.get('name'), 'Full name should match');
        System.assertEquals('333-444-5555', secondAccountMap.get('phone'), 'Phone should match');
        System.assertEquals('P111222333', secondAccountMap.get('passportNumber'), 'PassportNumber should be from __pc field (prioritized)');
        
        // Third account should be "Jane Smith" with Passport_No__c (since __pc is empty)
        Map<String, Object> thirdAccountMap = (Map<String, Object>) accounts[2];
        System.assertEquals('Jane Smith', thirdAccountMap.get('name'), 'Full name should match');
        System.assertEquals('555-123-4567', thirdAccountMap.get('phone'), 'Should use PersonMobilePhone when Phone is null');
        System.assertEquals('P987654321', thirdAccountMap.get('passportNumber'), 'PassportNumber should be from __c field');
    }
    
    @isTest
    static void testGetAccountListPostJSONAgency() {
        // Get the test user
        App_User__c testUser = [SELECT Id FROM App_User__c WHERE Email__c = 'active@test.com' LIMIT 1];
        
        // Setup REST context with POST method and JSON body for Agency
        String testJson = '{"userId":"' + testUser.Id + '","recordTypeId":"' + AGENCY_RECORD_TYPE_ID + '"}';
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestBody = Blob.valueOf(testJson);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the POST method
        AppUserAccountListService.getAccountListPost();
        
        Test.stopTest();
        
        // Parse response from responseBody
        String responseBody = response.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        
        // Verify successful response
        System.assertEquals(true, result.get('success'), 'Request should be successful');
        System.assertEquals('Accounts retrieved successfully', result.get('message'));
        List<Object> accounts = (List<Object>) result.get('accounts');
        System.assertEquals(2, accounts.size(), 'Should return 2 agency accounts');
        System.assertEquals(200, response.statusCode, 'Status code should be 200');
        
        // Verify it's returning agency data structure
        Map<String, Object> accountMap = (Map<String, Object>) accounts[0];
        System.assertEquals(true, accountMap.containsKey('companyEmail'), 'Should contain companyEmail for Agency');
        System.assertEquals(true, accountMap.containsKey('adminNumber'), 'Should contain adminNumber for Agency');
        System.assertEquals(false, accountMap.containsKey('personEmail'), 'Should not contain personEmail for Agency');
        System.assertEquals(false, accountMap.containsKey('phone'), 'Should not contain phone for Agency');
    }
    
    @isTest
    static void testGetAccountListPostFormEncodedPersonAccount() {
        // Get the test user
        App_User__c testUser = [SELECT Id FROM App_User__c WHERE Email__c = 'active@test.com' LIMIT 1];
        
        // Setup REST context with POST method and form parameters for Person Account
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.params.put('userId', testUser.Id);
        request.params.put('recordTypeId', PERSON_ACCOUNT_RECORD_TYPE_ID);
        request.requestBody = null; // No JSON body for form-encoded
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the POST method
        AppUserAccountListService.getAccountListPost();
        
        Test.stopTest();
        
        // Parse response from responseBody
        String responseBody = response.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        
        // Verify successful response
        System.assertEquals(true, result.get('success'), 'Request should be successful');
        List<Object> accounts = (List<Object>) result.get('accounts');
        System.assertEquals(3, accounts.size(), 'Should return 3 person accounts');
        System.assertEquals(200, response.statusCode, 'Status code should be 200');
        
        // Verify it's returning person account data structure
        Map<String, Object> accountMap = (Map<String, Object>) accounts[0];
        System.assertEquals(true, accountMap.containsKey('personEmail'), 'Should contain personEmail for Person Account');
        System.assertEquals(true, accountMap.containsKey('phone'), 'Should contain phone for Person Account');
        System.assertEquals(true, accountMap.containsKey('passportNumber'), 'Should contain passportNumber for Person Account');
        System.assertEquals(false, accountMap.containsKey('companyEmail'), 'Should not contain companyEmail for Person Account');
        System.assertEquals(false, accountMap.containsKey('adminNumber'), 'Should not contain adminNumber for Person Account');
    }
    
    @isTest
    static void testGetAccountListMissingRecordTypeId() {
        // Get the test user
        App_User__c testUser = [SELECT Id FROM App_User__c WHERE Email__c = 'active@test.com' LIMIT 1];
        
        // Setup REST context without recordTypeId parameter
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.params.put('userId', testUser.Id);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the service method
        AppUserAccountListService.getAccountList();
        
        Test.stopTest();
        
        // Parse response from responseBody
        String responseBody = response.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        
        // Verify error response
        System.assertEquals(false, result.get('success'), 'Request should fail without recordTypeId');
        System.assert(((String)result.get('message')).contains('recordTypeId parameter is required'), 'Should contain recordTypeId required error');
        System.assertEquals(400, response.statusCode, 'Status code should be 400');
    }
    
    @isTest
    static void testGetAccountListInvalidRecordTypeId() {
        // Get the test user
        App_User__c testUser = [SELECT Id FROM App_User__c WHERE Email__c = 'active@test.com' LIMIT 1];
        
        // Setup REST context with invalid recordTypeId
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.params.put('userId', testUser.Id);
        request.params.put('recordTypeId', 'invalid123');
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the service method
        AppUserAccountListService.getAccountList();
        
        Test.stopTest();
        
        // Parse response from responseBody
        String responseBody = response.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        
        // Verify error response
        System.assertEquals(false, result.get('success'), 'Request should fail with invalid recordTypeId');
        System.assert(((String)result.get('message')).contains('Invalid recordTypeId'), 'Should contain invalid recordTypeId error');
        System.assertEquals(400, response.statusCode, 'Status code should be 400');
    }
    
    @isTest
    static void testGetAccountListNoAccounts() {
        // Get the user with no accounts
        App_User__c testUser = [SELECT Id FROM App_User__c WHERE Email__c = 'noaccounts@test.com' LIMIT 1];
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.params.put('userId', testUser.Id);
        request.params.put('recordTypeId', AGENCY_RECORD_TYPE_ID);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the service method
        AppUserAccountListService.getAccountList();
        
        Test.stopTest();
        
        // Parse response from responseBody
        String responseBody = response.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        
        // Verify successful response with empty list
        System.assertEquals(true, result.get('success'), 'Request should be successful');
        System.assertEquals('Accounts retrieved successfully', result.get('message'));
        List<Object> accounts = (List<Object>) result.get('accounts');
        System.assertNotEquals(null, accounts, 'Accounts list should not be null');
        System.assertEquals(0, accounts.size(), 'Should return 0 accounts');
        System.assertEquals(200, response.statusCode, 'Status code should be 200');
    }
    
    @isTest
    static void testGetAccountListInactiveUser() {
        // Get the inactive user
        App_User__c testUser = [SELECT Id FROM App_User__c WHERE Email__c = 'inactive@test.com' LIMIT 1];
        
        // Setup REST context
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.params.put('userId', testUser.Id);
        request.params.put('recordTypeId', AGENCY_RECORD_TYPE_ID);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the service method
        AppUserAccountListService.getAccountList();
        
        Test.stopTest();
        
        // Parse response from responseBody
        String responseBody = response.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        
        // Verify error response
        System.assertEquals(false, result.get('success'), 'Request should fail for inactive user');
        System.assertEquals('App User not found or inactive', result.get('message'));
        System.assertEquals(null, result.get('accounts'), 'Accounts should be null');
        System.assertEquals(404, response.statusCode, 'Status code should be 404');
    }
    
    @isTest
    static void testGetAccountListMissingUserId() {
        // Setup REST context without userId parameter
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.params.put('recordTypeId', AGENCY_RECORD_TYPE_ID);
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        
        // Call the service method
        AppUserAccountListService.getAccountList();
        
        Test.stopTest();
        
        // Parse response from responseBody
        String responseBody = response.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        
        // Verify error response
        System.assertEquals(false, result.get('success'), 'Request should fail without userId');
        System.assert(((String)result.get('message')).contains('userId parameter is required'), 'Should contain userId required error');
        System.assertEquals(400, response.statusCode, 'Status code should be 400');
    }
    
    @isTest
    static void testUserAccountRequestWrapper() {
        // Test the UserAccountRequest wrapper class
        AppUserAccountListService.UserAccountRequest request = new AppUserAccountListService.UserAccountRequest();
        request.userId = 'testUserId123';
        request.recordTypeId = AGENCY_RECORD_TYPE_ID;
        
        // Verify properties are set correctly
        System.assertEquals('testUserId123', request.userId);
        System.assertEquals(AGENCY_RECORD_TYPE_ID, request.recordTypeId);
    }
    
    @isTest
    static void testAccountListResponseConstructor() {
        // Test the AccountListResponse wrapper class
        List<Object> testAccounts = new List<Object>();
        
        AppUserAccountListService.AccountListResponse response = new AppUserAccountListService.AccountListResponse(
            true, 
            'Success message', 
            testAccounts
        );
        
        // Verify properties are set correctly
        System.assertEquals(true, response.success);
        System.assertEquals('Success message', response.message);
        System.assertEquals(testAccounts, response.accounts);
    }
}