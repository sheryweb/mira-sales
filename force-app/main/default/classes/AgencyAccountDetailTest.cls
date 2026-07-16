@isTest
public class AgencyAccountDetailTest {
    @isTest
    static void testCheckAccountStatus_Success() {
        // Setup: Create a test account
        Account testAccount = new Account(
            Name = 'Test Account',
            Status__c = 'Incomplete Registration',
            Is_Agency_International__c = 'No',
            Serial__c = 1
        );
        insert testAccount;

        // Query the account to get the computed Registration_Number__c
        testAccount = [SELECT Registration_Number__c FROM Account WHERE Id = :testAccount.Id];

        // Test: Call the method with a valid registration number
        Test.startTest();
        String result = AgencyAccountDetail.checkAccountStatus(testAccount.Registration_Number__c);
        Test.stopTest();

        // Validate: Parse the JSON response
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assertEquals('success', responseMap.get('status'), 'Expected status to be success');
        System.assertEquals('Account found', responseMap.get('message'), 'Expected message to indicate account found');

        // Validate account data in response
        Map<String, Object> accountData = (Map<String, Object>)responseMap.get('data');
        System.assert(accountData != null, 'Expected account data to be present in the response');
        System.assertEquals('Test Account', accountData.get('Name'), 'Account name should match');
    }

    @isTest
    static void testCheckAccountStatus_Error() {
        // Test: Call the method with an invalid registration number
        Test.startTest();
        String result = AgencyAccountDetail.checkAccountStatus('INVALID_REG');
        Test.stopTest();

        // Validate: Parse the JSON response
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assertEquals('error', responseMap.get('status'), 'Expected status to be error');
        System.assert(responseMap.get('message') != null, 'Expected error message to be present');
    }
}