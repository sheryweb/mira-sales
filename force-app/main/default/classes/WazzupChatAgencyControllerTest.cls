@IsTest
private class WazzupChatAgencyControllerTest {
    private static final String VALID_PHONE = '+971567347868';
    private static final String INVALID_PHONE = '123';
    
    @TestSetup
    static void setupTestData() {
        // Create admin user to run the setup
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        User adminUser = new User(
            Alias = 'admin',
            Email = 'admin@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'admin@testorg.com' + System.currentTimeMillis()
        );
        insert adminUser;

        System.runAs(adminUser) {
            // Create a test user who will be the Relationship Manager with Sales Manager MIRA profile
            Profile salesManagerProfile = [SELECT Id FROM Profile WHERE Name = 'Sales Manager MIRA'];
            User testUser = new User(
                Alias = 'tuser',
                Email = 'testuser@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = salesManagerProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'testuser@test.com' + System.currentTimeMillis()
            );
            insert testUser;

            System.runAs(testUser) {
                // Create test Account of type Agency
                Account testAccount = new Account(
                    Name = 'Test Account',
                    Type = 'Agency',  // Setting the Account type to Agency
                    Phone = VALID_PHONE  // Set phone on Account since Agency_Phone__c might be a formula
                );
                insert testAccount;

                // Create test Agency_Rm__c record with required relationships
                Agency_Rm__c testAgency = new Agency_Rm__c(
                    Name = 'Test Agency',
                    Agency__c = testAccount.Id,
                    Relationship_Manager__c = testUser.Id  // Using the User ID as Relationship Manager
                );
                insert testAgency;

                // Create another Account for invalid phone test
                Account testAccountInvalid = new Account(
                    Name = 'Test Account Invalid',
                    Type = 'Agency',
                    Phone = INVALID_PHONE
                );
                insert testAccountInvalid;

                // Create another Agency_Rm__c record for invalid phone test
                Agency_Rm__c testAgencyInvalidPhone = new Agency_Rm__c(
                    Name = 'Test Agency Invalid Phone',
                    Agency__c = testAccountInvalid.Id,
                    Relationship_Manager__c = testUser.Id
                );
                insert testAgencyInvalidPhone;
            }
        }
    }

    @IsTest
    static void testValidPhoneNumber() {
        Agency_Rm__c testAgency = [SELECT Id, Name, OwnerId, Owner.Name, Owner.Profile.Name, Owner.IsActive, Agency_Phone__c, Agency__r.Phone 
                                  FROM Agency_Rm__c 
                                  WHERE Agency__r.Phone = :VALID_PHONE LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@test.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            // Set up the test context
            PageReference pageRef = Page.ChatPageAgency;
            pageRef.getParameters().put('id', testAgency.Id);
            Test.setCurrentPage(pageRef);
            
            // Mock HTTP response
            Test.setMock(HttpCalloutMock.class, new WazzupHttpCalloutMock(true));
            
            WazzupChatAgencyController controller = new WazzupChatAgencyController();
            String result = controller.iframeUrl;
            
            Test.stopTest();
            
            System.assert(result.contains('https://iframe.wazzup24.com/'), 'Expected iframe URL not found');
        }
    }

    @IsTest
    static void testInvalidPhoneNumber() {
        Agency_Rm__c testAgency = [SELECT Id, Name, OwnerId, Owner.Name, Owner.Profile.Name, Owner.IsActive, Agency_Phone__c, Agency__r.Phone 
                                  FROM Agency_Rm__c 
                                  WHERE Agency__r.Phone = :INVALID_PHONE LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@test.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            PageReference pageRef = Page.ChatPageAgency;
            pageRef.getParameters().put('id', testAgency.Id);
            Test.setCurrentPage(pageRef);
            
            WazzupChatAgencyController controller = new WazzupChatAgencyController();
            String result = controller.iframeUrl;
            
            Test.stopTest();
            
            System.debug('Result from controller: ' + result);
            System.assert(result.contains('Error: Invalid phone number format'), 
                         'Expected error message not found. Actual result: ' + result);
        }
    }

    @IsTest
    static void testMissingAgencyId() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@test.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            PageReference pageRef = Page.ChatPageAgency;
            Test.setCurrentPage(pageRef);
            
            WazzupChatAgencyController controller = new WazzupChatAgencyController();
            String result = controller.iframeUrl;
            
            Test.stopTest();
            
            System.assert(result.contains('Error: Agency RM ID is required'), 'Expected error message not found');
        }
    }

    @IsTest
    static void testPhoneNumberFormatting() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@test.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            WazzupChatAgencyController controller = new WazzupChatAgencyController();
            
            // Test various phone number formats
            System.assertEquals('971567347868', controller.formatPhoneNumber('+971567347868'));
            System.assertEquals('971567347868', controller.formatPhoneNumber('00971567347868'));
            System.assertEquals('971567347868', controller.formatPhoneNumber('0971567347868'));
            System.assertEquals('', controller.formatPhoneNumber(''));
            System.assertEquals('', controller.formatPhoneNumber(null));
            
            Test.stopTest();
        }
    }

    @IsTest
    static void testApiError() {
        Agency_Rm__c testAgency = [SELECT Id, Name, OwnerId, Owner.Name, Owner.Profile.Name, Owner.IsActive FROM Agency_Rm__c LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@test.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            
            PageReference pageRef = Page.ChatPageAgency;
            pageRef.getParameters().put('id', testAgency.Id);
            Test.setCurrentPage(pageRef);
            
            Test.setMock(HttpCalloutMock.class, new WazzupHttpCalloutMock(false));
            
            WazzupChatAgencyController controller = new WazzupChatAgencyController();
            String result = controller.iframeUrl;
            
            Test.stopTest();
            
            System.assert(result.contains('Error loading chat'), 'Expected error message not found');
        }
    }

    // Mock HTTP Callout class
    private class WazzupHttpCalloutMock implements HttpCalloutMock {
        private Boolean isSuccess;
        
        public WazzupHttpCalloutMock(Boolean isSuccess) {
            this.isSuccess = isSuccess;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (isSuccess) {
                res.setStatusCode(200);
                res.setBody('{"url": "https://iframe.wazzup24.com/chat/123"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"description": "API Error"}');
            }
            
            return res;
        }
    }
}