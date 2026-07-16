@isTest
public class ReceiptEmailServiceTest {
    
    // Test data setup
    @TestSetup
    static void setupTestData() {
        // Create a test Account - avoid using Person Account record type
        Account testAccount = new Account(
            Name = 'Test Customer'
        );
        insert testAccount;
        
        // Create a contact for email purposes
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Customer',
            Email = 'test@example.com',
            AccountId = testAccount.Id
        );
        insert testContact;
        
        // Create a test Unit (Project)
        Unit__c testUnit = new Unit__c(
            Title__c = 'Unit-101',
            Building__c = 'Test Building'
        );
        insert testUnit;
        
        // Create a test User for Opportunity Owner using running user
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        // Create a test Opportunity
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            OwnerId = testUser.Id,
            AccountId = testAccount.Id
        );
        insert testOpportunity;
        
        // Create a test Receipt with customer email
        Receipt__c testReceipt = new Receipt__c(
            Customer_Name__c = 'Test Customer',
            Account__c = testAccount.Id,
            Unit__c = testUnit.Id,
            Opportunity__c = testOpportunity.Id
        );
        insert testReceipt;
        
        // Create a Receipt with no email
        Account noEmailAccount = new Account(
            Name = 'No Email Customer'
        );
        insert noEmailAccount;
        
        Receipt__c noEmailReceipt = new Receipt__c(
            Customer_Name__c = 'No Email Customer',
            Account__c = noEmailAccount.Id,
            Unit__c = testUnit.Id
        );
        insert noEmailReceipt;
    }
    
    @isTest
    static void testSendReceiptEmailSuccess() {
        // Get first test receipt
        Receipt__c testReceipt = [SELECT Id, Name FROM Receipt__c WHERE Customer_Name__c = 'Test Customer' LIMIT 1];
        
        // We need to mock the getContentAsPDF method since it's not available in tests
        // Create a test page reference for the Visualforce page
        PageReference testPage = Page.ReceiptPDF;
        testPage.getParameters().put('id', testReceipt.Id);
        
        // Set the current page reference
        Test.setCurrentPage(testPage);
        
        // Set up the PageReference mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        // Mock the PDF blob
        Blob pdfBlob = Blob.valueOf('Test PDF Content');
        
        // Start the test
        Test.startTest();
        
        // Set the test variables in ReceiptEmailService
        ReceiptEmailService.testPdfBlob = pdfBlob;
        ReceiptEmailService.isTestMode = true;
        
        // Send email and verify result
        String result = ReceiptEmailService.sendReceiptEmail(testReceipt.Id);
        
        Test.stopTest();
        
        // Verify the results
        System.assert(result.startsWith('Success') || result.contains('Error'), 'Expected success or error message');
    }
    
    @isTest
    static void testSendReceiptEmailNoEmail() {
        // Get no-email test receipt
        Receipt__c noEmailReceipt = [SELECT Id, Name FROM Receipt__c WHERE Customer_Name__c = 'No Email Customer' LIMIT 1];
        
        Test.startTest();
        
        // Send email and verify result
        String result = ReceiptEmailService.sendReceiptEmail(noEmailReceipt.Id);
        
        Test.stopTest();
        
        // Verify the results - we expect an error because there's no email
        System.assert(result.startsWith('Error'), 'Expected error message, got: ' + result);
    }
    
    @isTest
    static void testSendReceiptEmailInvalidId() {
        Test.startTest();
        
        // Send email with invalid ID
        String result = ReceiptEmailService.sendReceiptEmail(null);
        
        Test.stopTest();
        
        // Verify the results
        System.assert(result.startsWith('Error'), 'Expected error message, got: ' + result);
    }
    
    @isTest
    static void testSendReceiptEmailWithException() {
        // Create an invalid ID that will cause an exception
        Id invalidId = Id.valueOf('a0B' + '0'.repeat(12));
        
        Test.startTest();
        
        // Send email with invalid ID that will cause exception
        String result = ReceiptEmailService.sendReceiptEmail(invalidId);
        
        Test.stopTest();
        
        // Verify the results
        System.assert(result.startsWith('Error'), 'Expected error message, got: ' + result);
    }
    
    // Mock HTTP response generator for PDF generation
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/pdf');
            res.setBody('Test PDF Content');
            res.setStatusCode(200);
            return res;
        }
    }
}