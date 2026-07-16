@isTest
public class AgencyAgreementHalfExecutedTest {

    @testSetup
    static void setupTestData() {
        // Create a test Account record with the necessary fields
        Account acct = new Account(
            Name = 'Test Account',
            Company_Email__c = 'test@company.com'  // Ensure this field is populated for success case
        );
        insert acct;

        // Debug to confirm account creation
        System.debug('Test Account inserted: ' + acct.Id);
    }

    @isTest
    static void testSendEmailNotification_Success() {
        // Fetch the test Account
        Account testAccount = [SELECT Id, Company_Email__c FROM Account LIMIT 1];

        // Debug to confirm account retrieval
        System.debug('Fetched Account for test: ' + testAccount.Id);

        Test.startTest();

        // Call the method with valid data (valid account Id)
        List<Id> recordIds = new List<Id>{testAccount.Id};
        AgencyAgreementHalfExecuted.sendEmailNotification(recordIds);

        Test.stopTest();
    }
}