@isTest
public class AgencyAgreementGeorgianControllerTest {

    @isTest
    static void testConstructorWithValidAccount() {
        Account acct = new Account(
            Name = 'Test Agency LLC',
            BillingStreet = 'Test Street 123, Tbilisi',
            BillingPostalCode = '0100',
            Trade_License_Number__c = 'TL-12345',
            ORN_Number__c = 'ORN-67890',
            Phone = '+995577000000',
            Company_Email__c = 'test@example.com',
            Signatory_Name__c = 'Test Signatory',
            Registered_In__c = 'Georgia',
            //Issuing_Authority__c = 'Public Service Hall',
            Identification_Number__c = '405000000'
        );
        insert acct;

        PageReference pageRef = Page.AgencyAgreementDraftGeorgian;
        pageRef.getParameters().put('acctId', acct.Id);
        Test.setCurrentPage(pageRef);

        Test.startTest();
        AgencyAgreementGeorgianController ctrl = new AgencyAgreementGeorgianController();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.accData, 'accData should be initialized');
        System.assert(ctrl.accData.containsKey('agencyAccount'), 'accData should contain agencyAccount key');

        Account result = (Account) ctrl.accData.get('agencyAccount');
        System.assertEquals(acct.Id, result.Id, 'Returned Account Id should match');
        System.assertEquals('Test Agency LLC', result.Name, 'Account Name should match');
        System.assertEquals('405000000', result.Identification_Number__c, 'Identification Number should match');
    }
}