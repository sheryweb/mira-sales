@isTest
private class UserDeactivationServiceTest {

    @TestSetup
    static void makeData(){
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Agency User' LIMIT 1];

        Account testAccount = new Account(
            Name = 'Test Acc'
        );
        insert testAccount;

        Contact testContact = new Contact(
            AccountId = testAccount.Id,
            LastName = 'Test Contact'
        );
        insert testContact;

        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test@example.com',
            Alias = 'tuser',
            Username = 'test@example.com',
            ProfileId = profile.Id,
            IsActive = true,
            Deactivated_by_process__c = false,
            ContactId = testContact.Id,
            emailencodingkey='UTF-8',
            timezonesidkey='Europe/Dublin',
            languagelocalekey='en_US',
            localesidkey='en_US'
        );
        insert testUser;

    }

    @isTest
    static void testManageUserDeactivation() {

        User user = [SELECT Id FROM User WHERE Name = 'Test User' LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse response = new RestResponse();
        RestContext.response = response;
        req.requestURI = '/services/apexrest/DeactivateUser';
        req.httpMethod = 'DELETE';
        req.addParameter('userId', user.Id);
        RestContext.request = req;

        Test.startTest();
        UserDeactivationService.manageUserDeactivation();
        Test.stopTest();
        user = [SELECT Id, IsActive FROM User WHERE Name = 'Test User' LIMIT 1];

        System.assertEquals(false, user.IsActive);
    }

    @isTest
    static void testManageUserDeactivationInactiveUser() {

        User user = [SELECT Id FROM User WHERE Name = 'Test User' LIMIT 1];
        user.IsActive = false;
        update user;

        RestRequest req = new RestRequest();
        RestResponse response = new RestResponse();
        RestContext.response = response;
        req.requestURI = '/services/apexrest/DeactivateUser';
        req.httpMethod = 'DELETE';
        req.addParameter('userId', user.Id);
        RestContext.request = req;

        Test.startTest();
        String responseString = UserDeactivationService.manageUserDeactivation();
        Test.stopTest();
        user = [SELECT Id, IsActive FROM User WHERE Name = 'Test User' LIMIT 1];

        System.assertEquals(false, user.IsActive);
        System.assertEquals('inactive_user', responseString);
    }
}