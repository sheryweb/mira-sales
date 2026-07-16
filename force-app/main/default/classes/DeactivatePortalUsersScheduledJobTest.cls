@isTest
private class DeactivatePortalUsersScheduledJobTest {

    @isTest
    static void testExecute() {
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

        User testUser1 = new User(
            FirstName = 'Schedule Test',
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
        insert testUser1;

        Test.startTest();
        String jobId = System.schedule('Test Deactivate Portal Users Job', 
                                        '0 0 0 * * ?',
                                        new DeactivatePortalUsersScheduledJob());
        Test.stopTest();

        System.assertNotEquals(null, jobId);

        User updatedUser1 = [SELECT Id, IsActive, Deactivated_by_process__c FROM User WHERE Id = :testUser1.Id LIMIT 1];

        System.assertEquals(false, updatedUser1.IsActive);
        System.assertEquals(true, updatedUser1.Deactivated_by_process__c);

    }
}