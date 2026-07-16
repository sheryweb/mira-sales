@isTest
private class AgencyAccountDetailServiceTest {

    @isTest
    static void testGetAccountDetails() {
        // Setup test data
        Account testAccount = new Account(
            Name = 'Test Account'
            // Set other fields that the formula might depend on
            // For example, if the formula uses other fields, populate them accordingly.
            // e.g. Account_Type__c = 'Some Type' (if applicable)
        );
        insert testAccount;

        // Refresh the testAccount to get the formula field value
        testAccount = [SELECT Id, Registration_Number__c FROM Account WHERE Id = :testAccount.Id];

        Shareholder__c shareholder1 = new Shareholder__c(
            Name = 'Shareholder One',
            Percent__c = 50,
            Account__c = testAccount.Id
        );

        Shareholder__c shareholder2 = new Shareholder__c(
            Name = 'Shareholder Two',
            Percent__c = 50,
            Account__c = testAccount.Id
        );

        insert new List<Shareholder__c> { shareholder1, shareholder2 };

        Bank__c bank1 = new Bank__c(
            Name = 'Bank One',
            Bank_Account_Name__c = 'Bank Account 1',
            Bank_Account_Number__c = '123456789',
            IBAN__c = 'IBAN12345',
            Swift_Code__c = 'SWIFT123',
            Branch_Name__c = 'Branch One',
            Account__c = testAccount.Id
        );

        insert bank1;

        // Test case with a valid registration number
        Test.startTest();
        String response = AgencyAccountDetailService.getAccountDetails(testAccount.Registration_Number__c);
        Test.stopTest();

        // Verify the response
        AgencyAccountDetailService.AccountDetailsResponse accountDetails = (AgencyAccountDetailService.AccountDetailsResponse) JSON.deserialize(response, AgencyAccountDetailService.AccountDetailsResponse.class);
        System.assertEquals(testAccount.Id, accountDetails.account.Id);
        System.assertEquals(2, accountDetails.shareholders.size());
        System.assertEquals(1, accountDetails.banks.size());

        // Test case with a blank registration number
        try {
            AgencyAccountDetailService.getAccountDetails('');
            System.assert(false, 'Expected CustomException not thrown for blank registration number.');
        } catch (AgencyAccountDetailService.CustomException e) {
            System.assertEquals('Account not found', e.getMessage());
        }
    }
}