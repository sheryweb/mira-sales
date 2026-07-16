@isTest
public class AgencyAgreementControllerTest {

    @testSetup
    static void setupTestData() {
        // Creating a test Account record
        Account testAccount = new Account(
            Name = 'Test Account',
            BillingStreet = '123 Test St',
            BillingPostalCode = '12345',
            Trade_License_Number__c = 'TL12345',
            ORN_Number__c = 'ORN12345',
            Phone = '123-456-7890',
            Company_Email__c = 'test@example.com',
            Signatory_Name__c = 'Test Signatory',
            Registered_In__c = 'Test City'
        );
        insert testAccount;

        // Store the inserted Account Id for use in the test method
        Test.setCurrentPageReference(new PageReference('/apex/somePage')); // Replace with actual VF Page if needed
        ApexPages.currentPage().getParameters().put('actId', testAccount.Id);
    }

    @isTest
    static void testAgencyAgreementController() {
        // Fetch the account id set up in testSetup
        Id accountId = [SELECT Id FROM Account LIMIT 1].Id;

        // Set the page parameters to use the accountId in the test
        Test.setCurrentPageReference(new PageReference('/apex/somePage')); // Replace with actual VF Page if needed
        ApexPages.currentPage().getParameters().put('actId', accountId);

        // Instantiate the controller
        AgencyAgreementController controller = new AgencyAgreementController();

        // Fetch the Account data from the controller's accData Map
        Account resultAccount = (Account) controller.accData.get('agencyAccount');

        // Validate that the Account record is returned correctly
        System.assertNotEquals(null, resultAccount, 'Account record should not be null.');
        System.assertEquals('Test Account', resultAccount.Name, 'Account Name does not match.');
        System.assertEquals('123 Test St', resultAccount.BillingStreet, 'Billing Street does not match.');
        System.assertEquals('12345', resultAccount.BillingPostalCode, 'Postal Code does not match.');
        System.assertEquals('TL12345', resultAccount.Trade_License_Number__c, 'Trade License Number does not match.');
        System.assertEquals('ORN12345', resultAccount.ORN_Number__c, 'ORN Number does not match.');
        System.assertEquals('123-456-7890', resultAccount.Phone, 'Phone number does not match.');
        System.assertEquals('test@example.com', resultAccount.Company_Email__c, 'Company Email does not match.');
        System.assertEquals('Test Signatory', resultAccount.Signatory_Name__c, 'Signatory Name does not match.');
        System.assertEquals('Test City', resultAccount.Registered_In__c, 'Registered In field does not match.');
    }
}