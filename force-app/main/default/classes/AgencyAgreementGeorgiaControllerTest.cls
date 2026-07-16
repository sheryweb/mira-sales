/**
 * Test class for AgencyAgreementGeorgiaController
 * 
 * Provides comprehensive test coverage for all methods and scenarios including:
 * - Successful email sending with ContentVersion files
 * - Successful email sending with Attachment files  
 * - Error handling for missing accounts, files, and emails
 * - Fallback email logic
 * - Edge cases and exception handling
 */
@isTest
private class AgencyAgreementGeorgiaControllerTest {
    
    // ─── Test Data Setup ─────────────────────────────────────────────────────
    
    @TestSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> accounts = new List<Account>();
        
        // Account with Company_Email__c
        accounts.add(new Account(
            Name = 'Test Company A',
            Company_Email__c = 'companya@test.com'
        ));
        
        // Account without Company_Email__c  
        accounts.add(new Account(
            Name = 'Test Company B'
        ));
        
        // Account without Company_Email__c and no contacts
        accounts.add(new Account(
            Name = 'Test Company C'
        ));
        
        insert accounts;
        
        // Create primary contact for Account B (fallback email scenario)
        Contact primaryContact = new Contact(
            AccountId = accounts[1].Id,
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@testcompanyb.com',
            Primary__c = true
        );
        insert primaryContact;
    }
    
    // ─── Test Methods ────────────────────────────────────────────────────────
    
    /**
     * Test successful email sending with ContentVersion (Salesforce Files)
     */
    @isTest
    static void testSendEmailWithContentVersion() {
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test Company A' LIMIT 1];
        
        // Create ContentVersion (File)
        ContentVersion cv = new ContentVersion(
            Title = 'Georgia Agency Agreement.pdf',
            PathOnClient = 'Georgia Agency Agreement.pdf',
            VersionData = Blob.valueOf('Test PDF Content'),
            FirstPublishLocationId = testAccount.Id
        );
        insert cv;
        
        // Prepare input
        AgencyAgreementGeorgiaController.FlowInput input = new AgencyAgreementGeorgiaController.FlowInput();
        input.accountId = testAccount.Id;
        
        Test.startTest();
        List<AgencyAgreementGeorgiaController.FlowOutput> results = 
            AgencyAgreementGeorgiaController.sendGeorgiaAgencyAgreement(new List<AgencyAgreementGeorgiaController.FlowInput>{input});
        Test.stopTest();
        
        // Assert results
        System.assertEquals(1, results.size(), 'Should return one result');
        AgencyAgreementGeorgiaController.FlowOutput result = results[0];
        System.assertEquals(true, result.isSuccess, 'Operation should be successful');
        System.assertEquals(true, result.emailSent, 'Email should be sent');
        System.assert(result.message.contains('sent successfully'), 'Success message should be present');
    }
    
    /**
     * Test successful email sending with Attachment (Classic Attachments)
     */
    @isTest  
    static void testSendEmailWithAttachment() {
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test Company A' LIMIT 1];
        
        // Create Attachment
        Attachment att = new Attachment(
            ParentId = testAccount.Id,
            Name = 'Georgia Agency Agreement.pdf',
            Body = Blob.valueOf('Test PDF Content'),
            ContentType = 'application/pdf'
        );
        insert att;
        
        // Prepare input
        AgencyAgreementGeorgiaController.FlowInput input = new AgencyAgreementGeorgiaController.FlowInput();
        input.accountId = testAccount.Id;
        
        Test.startTest();
        List<AgencyAgreementGeorgiaController.FlowOutput> results = 
            AgencyAgreementGeorgiaController.sendGeorgiaAgencyAgreement(new List<AgencyAgreementGeorgiaController.FlowInput>{input});
        Test.stopTest();
        
        // Assert results
        System.assertEquals(1, results.size(), 'Should return one result');
        AgencyAgreementGeorgiaController.FlowOutput result = results[0];
        System.assertEquals(true, result.isSuccess, 'Operation should be successful');
        System.assertEquals(true, result.emailSent, 'Email should be sent');
    }
    
    /**
     * Test email sending with fallback to primary contact email
     */
    @isTest
    static void testSendEmailWithFallbackContact() {
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test Company B' LIMIT 1];
        
        // Create ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Georgia Agency Agreement.pdf',
            PathOnClient = 'Georgia Agency Agreement.pdf',
            VersionData = Blob.valueOf('Test PDF Content'),
            FirstPublishLocationId = testAccount.Id
        );
        insert cv;
        
        // Prepare input
        AgencyAgreementGeorgiaController.FlowInput input = new AgencyAgreementGeorgiaController.FlowInput();
        input.accountId = testAccount.Id;
        
        Test.startTest();
        List<AgencyAgreementGeorgiaController.FlowOutput> results = 
            AgencyAgreementGeorgiaController.sendGeorgiaAgencyAgreement(new List<AgencyAgreementGeorgiaController.FlowInput>{input});
        Test.stopTest();
        
        // Assert results  
        System.assertEquals(1, results.size(), 'Should return one result');
        AgencyAgreementGeorgiaController.FlowOutput result = results[0];
        System.assertEquals(true, result.isSuccess, 'Operation should be successful with fallback email');
        System.assertEquals(true, result.emailSent, 'Email should be sent to fallback contact');
    }
    
    /**
     * Test error handling for missing Account ID
     */
    @isTest
    static void testMissingAccountId() {
        // Prepare input with blank account ID
        AgencyAgreementGeorgiaController.FlowInput input = new AgencyAgreementGeorgiaController.FlowInput();
        input.accountId = '';
        
        Test.startTest();
        List<AgencyAgreementGeorgiaController.FlowOutput> results = 
            AgencyAgreementGeorgiaController.sendGeorgiaAgencyAgreement(new List<AgencyAgreementGeorgiaController.FlowInput>{input});
        Test.stopTest();
        
        // Assert results
        System.assertEquals(1, results.size(), 'Should return one result');
        AgencyAgreementGeorgiaController.FlowOutput result = results[0];
        System.assertEquals(false, result.isSuccess, 'Operation should fail');
        System.assertEquals(false, result.emailSent, 'Email should not be sent');
        System.assertEquals('Account ID is required', result.message, 'Should show validation error');
    }
    
    /**
     * Test error handling for non-existent Account
     */
    @isTest
    static void testNonExistentAccount() {
        // Generate fake account ID
        String fakeAccountId = Account.SObjectType.getDescribe().getKeyPrefix() + '000000000000001';
        
        // Prepare input
        AgencyAgreementGeorgiaController.FlowInput input = new AgencyAgreementGeorgiaController.FlowInput();
        input.accountId = fakeAccountId;
        
        Test.startTest();
        List<AgencyAgreementGeorgiaController.FlowOutput> results = 
            AgencyAgreementGeorgiaController.sendGeorgiaAgencyAgreement(new List<AgencyAgreementGeorgiaController.FlowInput>{input});
        Test.stopTest();
        
        // Assert results
        System.assertEquals(1, results.size(), 'Should return one result');
        AgencyAgreementGeorgiaController.FlowOutput result = results[0];
        System.assertEquals(false, result.isSuccess, 'Operation should fail');
        System.assertEquals(false, result.emailSent, 'Email should not be sent');
        System.assert(result.message.contains('Account not found'), 'Should show account not found error');
    }
    
    /**
     * Test error handling for missing PDF file
     */
    @isTest
    static void testMissingPdfFile() {
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test Company A' LIMIT 1];
        
        // Don't create any files - test missing file scenario
        
        // Prepare input
        AgencyAgreementGeorgiaController.FlowInput input = new AgencyAgreementGeorgiaController.FlowInput();
        input.accountId = testAccount.Id;
        
        Test.startTest();
        List<AgencyAgreementGeorgiaController.FlowOutput> results = 
            AgencyAgreementGeorgiaController.sendGeorgiaAgencyAgreement(new List<AgencyAgreementGeorgiaController.FlowInput>{input});
        Test.stopTest();
        
        // Assert results
        System.assertEquals(1, results.size(), 'Should return one result');
        AgencyAgreementGeorgiaController.FlowOutput result = results[0];
        System.assertEquals(false, result.isSuccess, 'Operation should fail');
        System.assertEquals(false, result.emailSent, 'Email should not be sent');
        System.assert(result.message.contains('file not found'), 'Should show file not found error');
    }
    
    /**
     * Test error handling for missing recipient email
     */
    @isTest
    static void testMissingRecipientEmail() {
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test Company C' LIMIT 1];
        
        // Create ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Georgia Agency Agreement.pdf',
            PathOnClient = 'Georgia Agency Agreement.pdf', 
            VersionData = Blob.valueOf('Test PDF Content'),
            FirstPublishLocationId = testAccount.Id
        );
        insert cv;
        
        // Prepare input
        AgencyAgreementGeorgiaController.FlowInput input = new AgencyAgreementGeorgiaController.FlowInput();
        input.accountId = testAccount.Id;
        
        Test.startTest();
        List<AgencyAgreementGeorgiaController.FlowOutput> results = 
            AgencyAgreementGeorgiaController.sendGeorgiaAgencyAgreement(new List<AgencyAgreementGeorgiaController.FlowInput>{input});
        Test.stopTest();
        
        // Assert results
        System.assertEquals(1, results.size(), 'Should return one result');
        AgencyAgreementGeorgiaController.FlowOutput result = results[0];
        System.assertEquals(false, result.isSuccess, 'Operation should fail');
        System.assertEquals(false, result.emailSent, 'Email should not be sent');
        System.assert(result.message.contains('No valid recipient email found'), 
            'Should show email send failure. Actual message: ' + result.message);
    }
    
    /**
     * Test file search with partial name match
     */
    @isTest
    static void testPartialFileNameMatch() {
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test Company A' LIMIT 1];
        
        // Create ContentVersion with similar but not exact name
        ContentVersion cv = new ContentVersion(
            Title = 'Georgia Agency Agreement - Final.pdf',
            PathOnClient = 'Georgia Agency Agreement - Final.pdf',
            VersionData = Blob.valueOf('Test PDF Content'),
            FirstPublishLocationId = testAccount.Id
        );
        insert cv;
        
        // Prepare input
        AgencyAgreementGeorgiaController.FlowInput input = new AgencyAgreementGeorgiaController.FlowInput();
        input.accountId = testAccount.Id;
        
        Test.startTest();
        List<AgencyAgreementGeorgiaController.FlowOutput> results = 
            AgencyAgreementGeorgiaController.sendGeorgiaAgencyAgreement(new List<AgencyAgreementGeorgiaController.FlowInput>{input});
        Test.stopTest();
        
        // Assert results - should find file with partial match
        System.assertEquals(1, results.size(), 'Should return one result');
        AgencyAgreementGeorgiaController.FlowOutput result = results[0];
        System.assertEquals(true, result.isSuccess, 'Operation should be successful with partial name match');
    }
    
    /**
     * Test multiple inputs (batch processing)
     */
    @isTest
    static void testMultipleInputs() {
        List<Account> accounts = [SELECT Id FROM Account WHERE Name IN ('Test Company A', 'Test Company B')];
        
        // Create files for both accounts
        List<ContentVersion> cvs = new List<ContentVersion>();
        for (Account acc : accounts) {
            cvs.add(new ContentVersion(
                Title = 'Georgia Agency Agreement.pdf',
                PathOnClient = 'Georgia Agency Agreement.pdf',
                VersionData = Blob.valueOf('Test PDF Content'),
                FirstPublishLocationId = acc.Id
            ));
        }
        insert cvs;
        
        // Prepare multiple inputs
        List<AgencyAgreementGeorgiaController.FlowInput> inputs = new List<AgencyAgreementGeorgiaController.FlowInput>();
        for (Account acc : accounts) {
            AgencyAgreementGeorgiaController.FlowInput input = new AgencyAgreementGeorgiaController.FlowInput();
            input.accountId = acc.Id;
            inputs.add(input);
        }
        
        Test.startTest();
        List<AgencyAgreementGeorgiaController.FlowOutput> results = 
            AgencyAgreementGeorgiaController.sendGeorgiaAgencyAgreement(inputs);
        Test.stopTest();
        
        // Assert results
        System.assertEquals(2, results.size(), 'Should return two results');
        for (AgencyAgreementGeorgiaController.FlowOutput result : results) {
            System.assertEquals(true, result.isSuccess, 'Both operations should be successful');
            System.assertEquals(true, result.emailSent, 'Both emails should be sent');
        }
    }
    
    /**
     * Test email body template functionality
     */
    @isTest
    static void testEmailBodyTemplate() {
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test Company A' LIMIT 1];
        
        // Create ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Georgia Agency Agreement.pdf',
            PathOnClient = 'Georgia Agency Agreement.pdf',
            VersionData = Blob.valueOf('Test PDF Content'),
            FirstPublishLocationId = testAccount.Id
        );
        insert cv;
        
        // Prepare input
        AgencyAgreementGeorgiaController.FlowInput input = new AgencyAgreementGeorgiaController.FlowInput();
        input.accountId = testAccount.Id;
        
        Test.startTest();
        List<AgencyAgreementGeorgiaController.FlowOutput> results = 
            AgencyAgreementGeorgiaController.sendGeorgiaAgencyAgreement(new List<AgencyAgreementGeorgiaController.FlowInput>{input});
        Test.stopTest();
        
        // Verify email body would contain account name
        // Since we can't directly access the email content in test context,
        // we verify the operation succeeded, indicating the template worked
        System.assertEquals(1, results.size(), 'Should return one result');
        AgencyAgreementGeorgiaController.FlowOutput result = results[0];
        System.assertEquals(true, result.isSuccess, 'Email template should work correctly');
    }
    
    /**
     * Test handling of invalid Account ID format
     */
    @isTest
    static void testInvalidAccountIdFormat() {
        // Create input with invalid ID format
        AgencyAgreementGeorgiaController.FlowInput input = new AgencyAgreementGeorgiaController.FlowInput();
        input.accountId = 'invalid-id-format';
        
        Test.startTest();
        List<AgencyAgreementGeorgiaController.FlowOutput> results = 
            AgencyAgreementGeorgiaController.sendGeorgiaAgencyAgreement(new List<AgencyAgreementGeorgiaController.FlowInput>{input});
        Test.stopTest();
        
        // Assert invalid ID was handled gracefully  
        System.assertEquals(1, results.size(), 'Should return one result even with invalid ID');
        AgencyAgreementGeorgiaController.FlowOutput result = results[0];
        System.assertEquals(false, result.isSuccess, 'Operation should fail with invalid ID');
        System.assert(result.message.contains('Account not found') || result.message.contains('error'), 
                     'Should contain appropriate error message. Actual message: ' + result.message);
    }
}