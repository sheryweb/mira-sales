@isTest
private class UserServiceTest {

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
            IsActive = false,
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
    static void testManageUserActivation() {
        User testUser = [SELECT Id FROM User WHERE Name = 'Test User' LIMIT 1];
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/services/apexrest/ChangeUserActiveFlag/';
        request.httpMethod = 'PUT';
        RestContext.request = request;
        RestContext.response = response;

        String inactiveUserId = testUser.Id;
        String inactiveUserResponse = UserService.manageUserActivation(inactiveUserId);
        System.assertEquals('inactive_user', inactiveUserResponse);

        testUser.IsActive = true;
        update testUser;

        String activeUserId = testUser.Id;
        String activeUserResponse = UserService.manageUserActivation(activeUserId);
        System.assertEquals('user_active', activeUserResponse);

        testUser.IsActive = false;
        testUser.Deactivated_by_process__c = true;
        update testUser;

        String activatingUserId = testUser.Id;
        String activatingUserResponse = UserService.manageUserActivation(activatingUserId);
        System.assertEquals('user_activated', activatingUserResponse);

        String incorrectUserId = '001XXXXXXXXXXXXXXX';
        String incorrectUserResponse = UserService.manageUserActivation(incorrectUserId);
        System.assertEquals('incorrect_user', incorrectUserResponse);

        Test.startTest();
        try {
            String errorResponse = UserService.manageUserActivation('invalidUserId');
        } catch (Exception e) {
            System.assertEquals('Error: Invalid ID', e.getMessage());
        }
        Test.stopTest();
    }
}