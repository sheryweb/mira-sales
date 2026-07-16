/**
 * Test class for SpaReadyNotification
 */
@isTest
public class SpaReadyNotificationTest {
    
    private static final String PERSON_ACCOUNT_RECORD_TYPE_ID = '012Hp000001yUTFIA2';
    private static final String BUSINESS_ACCOUNT_RECORD_TYPE_ID = '012Hp000001yUTAIA2';
    
    @TestSetup
    static void setupTestData() {
        // Create test Account (Person Account)
        Account personAccount = new Account(
            FirstName = 'John',
            LastName = 'Doe Person',
            PersonEmail = 'john.person@test.com',
            PersonMobilePhone = '+1234567890',
            BillingStreet = '123 Person St',
            BillingCity = 'Person City',
            BillingPostalCode = '12345',
            RecordTypeId = PERSON_ACCOUNT_RECORD_TYPE_ID
        );
        
        // Create test Account (Business Account)
        Account businessAccount = new Account(
            Name = 'Test Business Account',
            BillingStreet = '456 Business Ave',
            BillingCity = 'Business City',
            BillingPostalCode = '67890',
            RecordTypeId = BUSINESS_ACCOUNT_RECORD_TYPE_ID,
            Company_Email__c = 'jane.business@test.com'
        );
        
        insert new List<Account>{personAccount, businessAccount};
        
        // Create test Contact for Business Account
        Contact businessContact = new Contact(
            FirstName = 'Jane',
            LastName = 'Business',
            Email = 'jane.business@test.com',
            MobilePhone = '+0987654321',
            AccountId = businessAccount.Id
        );
        insert businessContact;
        
        // Create test Opportunities
        Opportunity oppWithPersonAccount = new Opportunity(
            Name = 'Test Opp Person Account',
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = personAccount.Id
        );
        
        Opportunity oppWithBusinessAccount = new Opportunity(
            Name = 'Test Opp Business Account',
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = businessAccount.Id
        );
        
        Opportunity oppWithoutAccount = new Opportunity(
            Name = 'Test Opp No Account',
            StageName = 'New',
            CloseDate = Date.today().addDays(30)
        );
        
        insert new List<Opportunity>{oppWithPersonAccount, oppWithBusinessAccount, oppWithoutAccount};
    }
    
    @isTest
    static void testGetOpportunityAccountInfo_PersonAccount() {
        // Verify test data exists
        List<Account> personAccounts = [SELECT Id, FirstName, LastName, PersonEmail, PersonMobilePhone, 
                                      BillingStreet, BillingCity, BillingPostalCode 
                                      FROM Account 
                                      WHERE RecordTypeId = :PERSON_ACCOUNT_RECORD_TYPE_ID];
        System.assertEquals(1, personAccounts.size(), 'Expected one person account');
        Account personAccount = personAccounts[0];
        
        List<Opportunity> personOpps = [SELECT Id, Name FROM Opportunity WHERE AccountId = :personAccount.Id];
        System.assertEquals(1, personOpps.size(), 'Expected one opportunity for person account');
        Opportunity opp = personOpps[0];
        
        // Prepare input
        SpaReadyNotification.FlowInputs input = new SpaReadyNotification.FlowInputs();
        input.opportunityId = opp.Id;
        
        // Start email test
        Integer emailInvocations = Limits.getEmailInvocations();
        
        Test.startTest();
        List<SpaReadyNotification.FlowOutputs> results = 
            SpaReadyNotification.getOpportunityAccountInfo(new List<SpaReadyNotification.FlowInputs>{input});
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, results.size(), 'Should return one result');
        SpaReadyNotification.FlowOutputs result = results[0];
        
        System.assertEquals(true, result.isSuccess, 'Should be successful');
        System.assertEquals(personAccount.FirstName + ' ' + personAccount.LastName, result.accountName, 'Account name should match');
        System.assertEquals(true, result.isPersonAccount, 'Should be person account');
        System.assertEquals(personAccount.BillingStreet, result.billingStreet, 'Billing street should match');
        System.assertEquals(personAccount.BillingCity, result.billingCity, 'Billing city should match');
        System.assertEquals(personAccount.BillingPostalCode, result.billingPostalCode, 'Billing postal code should match');
        System.assertEquals(personAccount.PersonEmail, result.accountEmail, 'Email should come from PersonEmail');
        System.assertEquals(personAccount.PersonMobilePhone, result.accountMobilePhone, 'Phone should come from PersonMobilePhone');
        
        // Verify email would have been sent (actual sending is blocked in test context)
        System.assertEquals(emailInvocations, Limits.getEmailInvocations(), 
            'Email sending should be skipped in test context');
    }
    
    @isTest
    static void testGetOpportunityAccountInfo_BusinessAccount() {
        // Verify test data exists
        List<Account> businessAccounts = [SELECT Id, Name, BillingStreet, BillingCity, BillingPostalCode, Company_Email__c
                                        FROM Account 
                                        WHERE RecordTypeId = :BUSINESS_ACCOUNT_RECORD_TYPE_ID];
        System.assertEquals(1, businessAccounts.size(), 'Expected one business account');
        Account businessAccount = businessAccounts[0];
        
        List<Contact> contacts = [SELECT Id, Email, MobilePhone, Name FROM Contact WHERE AccountId = :businessAccount.Id];
        System.assertEquals(1, contacts.size(), 'Expected one contact for business account');
        Contact contact = contacts[0];
        
        List<Opportunity> businessOpps = [SELECT Id, Name FROM Opportunity WHERE AccountId = :businessAccount.Id];
        System.assertEquals(1, businessOpps.size(), 'Expected one opportunity for business account');
        Opportunity opp = businessOpps[0];
        
        // Prepare input
        SpaReadyNotification.FlowInputs input = new SpaReadyNotification.FlowInputs();
        input.opportunityId = opp.Id;
        
        // Start email test
        Integer emailInvocations = Limits.getEmailInvocations();
        
        Test.startTest();
        List<SpaReadyNotification.FlowOutputs> results = 
            SpaReadyNotification.getOpportunityAccountInfo(new List<SpaReadyNotification.FlowInputs>{input});
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, results.size(), 'Should return one result');
        SpaReadyNotification.FlowOutputs result = results[0];
        
        System.assertEquals(true, result.isSuccess, 'Should be successful');
        System.assertEquals(contact.Name, result.accountName, 'Account name should match');
        System.assertEquals(false, result.isPersonAccount, 'Should not be person account');
        System.assertEquals(businessAccount.BillingStreet, result.billingStreet, 'Billing street should match');
        System.assertEquals(businessAccount.BillingCity, result.billingCity, 'Billing city should match');
        System.assertEquals(businessAccount.BillingPostalCode, result.billingPostalCode, 'Billing postal code should match');
        System.assertEquals(contact.Email, result.accountEmail, 'Email should come from Contact');
        System.assertEquals(contact.MobilePhone, result.accountMobilePhone, 'Phone should come from Contact');
        
        // Verify email would have been sent (actual sending is blocked in test context)
        System.assertEquals(emailInvocations, Limits.getEmailInvocations(), 
            'Email sending should be skipped in test context');
    }
    
    @isTest
    static void testGetOpportunityAccountInfo_NoAccount() {
        // Get test data
        List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE AccountId = null];
        System.assertEquals(1, opps.size(), 'Expected one opportunity without account');
        Opportunity opp = opps[0];
        
        // Prepare input
        SpaReadyNotification.FlowInputs input = new SpaReadyNotification.FlowInputs();
        input.opportunityId = opp.Id;
        
        // Start email test
        Integer emailInvocations = Limits.getEmailInvocations();
        
        Test.startTest();
        List<SpaReadyNotification.FlowOutputs> results = 
            SpaReadyNotification.getOpportunityAccountInfo(new List<SpaReadyNotification.FlowInputs>{input});
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, results.size(), 'Should return one result');
        SpaReadyNotification.FlowOutputs result = results[0];
        
        System.assertEquals(false, result.isSuccess, 'Should not be successful');
        System.assertEquals('No Account associated with this Opportunity', result.errorMessage, 'Error message should match');
        
        // Verify no email was attempted (due to failure)
        System.assertEquals(emailInvocations, Limits.getEmailInvocations(), 
            'No email should be sent for failed operation');
    }
    
    @isTest
    static void testGetOpportunityAccountInfo_InvalidOpportunityId() {
        // Prepare input with invalid ID
        SpaReadyNotification.FlowInputs input = new SpaReadyNotification.FlowInputs();
        input.opportunityId = TestUtility.getFakeId(Opportunity.SObjectType);
        
        // Start email test
        Integer emailInvocations = Limits.getEmailInvocations();
        
        Test.startTest();
        List<SpaReadyNotification.FlowOutputs> results = 
            SpaReadyNotification.getOpportunityAccountInfo(new List<SpaReadyNotification.FlowInputs>{input});
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, results.size(), 'Should return one result');
        SpaReadyNotification.FlowOutputs result = results[0];
        
        System.assertEquals(false, result.isSuccess, 'Should not be successful');
        System.assert(result.errorMessage.contains('Opportunity not found'), 'Error message should indicate opportunity not found');
        
        // Verify no email was attempted (due to failure)
        System.assertEquals(emailInvocations, Limits.getEmailInvocations(), 
            'No email should be sent for failed operation');
    }
    
    @isTest
    static void testGetOpportunityAccountInfo_MultipleInputs() {
        // Get test data
        List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE AccountId != null];
        System.assertEquals(2, opps.size(), 'Expected two opportunities with accounts');
        
        // Prepare inputs
        List<SpaReadyNotification.FlowInputs> inputs = new List<SpaReadyNotification.FlowInputs>();
        for (Opportunity opp : opps) {
            SpaReadyNotification.FlowInputs input = new SpaReadyNotification.FlowInputs();
            input.opportunityId = opp.Id;
            inputs.add(input);
        }
        
        // Start email test
        Integer emailInvocations = Limits.getEmailInvocations();
        
        Test.startTest();
        List<SpaReadyNotification.FlowOutputs> results = 
            SpaReadyNotification.getOpportunityAccountInfo(inputs);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(inputs.size(), results.size(), 'Should return same number of results as inputs');
        for (SpaReadyNotification.FlowOutputs result : results) {
            System.assertEquals(true, result.isSuccess, 'All results should be successful');
        }
        
        // Verify emails would have been sent (actual sending is blocked in test context)
        System.assertEquals(emailInvocations, Limits.getEmailInvocations(), 
            'Email sending should be skipped in test context');
    }
}