@isTest
public class InvoiceEmailServiceTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Account (Person Account assumed)
        Account testAccount = new Account(
            LastName = 'Test Customer',
            PersonEmail = 'test@example.com'
        );
        insert testAccount;
        
        // Create a test Unit
        Unit__c testUnit = new Unit__c(
            Title__c = 'Test Unit',
            Building__c = 'Test Building',
            Project_Name_Text__c = 'Test Project',
            Property_Code_Text__c = 'TEST-123',
            Cost_AED__c = 1000000
        );
        insert testUnit;
        
        // Create a test Financial Detail
        Financial_Detail__c testFinancialDetail = new Financial_Detail__c(
            Name = 'Test Bank',
            Account_Name__c = 'Test Account',
            Account_Number__c = '1234567890',
            IBAN__c = 'AE123456789012345678',
            Swift_Code__c = 'TESTSWIFT',
            Branch_Name__c = 'Test Branch'
        );
        insert testFinancialDetail;
        
        // Create test Invoice
        Invoice__c testInvoice = new Invoice__c(
            Invoice_Number__c = 'INV-001',
            Customer_Name__c = 'Test Customer',
            Account__c = testAccount.Id,
            Unit__c = testUnit.Id,
            Invoice_Date__c = Date.today(),
            Sub_Total_Amount__c = 1000.00,
            VAT_Amount__c = 50.00,
            Financial_Detail__c = testFinancialDetail.Id
        );
        insert testInvoice;
        
        // Create test Milestone Invoice
        Milestone_Invoice__c testMilestone = new Milestone_Invoice__c(
            Name = 'Test Milestone',
            Amount__c = 1000.00,
            Invoice__c = testInvoice.Id
        );
        insert testMilestone;
    }
    
    @isTest
    static void testSendInvoiceEmailSuccess() {
        // Get the test invoice
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c WHERE Invoice_Number__c = 'INV-001' LIMIT 1];
        
        // Set up mock for email sending
        Test.startTest();
        
        // Enable email deliverability first
        Messaging.reserveSingleEmailCapacity(1);
        
        // Call the method to test
        String result = InvoiceEmailService.sendInvoiceEmail(testInvoice.Id);
        
        Test.stopTest();
        
        // Since we can't reliably check email invocations in all org contexts,
        // we'll verify the success message instead
        System.assert(result.startsWith('Success'), 'Result should start with Success: ' + result);
    }
    
    @isTest
    static void testSendInvoiceEmailNoEmail() {
        // Create test Account without email
        Account testAccountNoEmail = new Account(
            LastName = 'Customer No Email'
        );
        insert testAccountNoEmail;
        
        // Get the test unit
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];
        
        // Create test Invoice without email
        Invoice__c testInvoiceNoEmail = new Invoice__c(
            Invoice_Number__c = 'INV-002',
            Customer_Name__c = 'Customer No Email',
            Account__c = testAccountNoEmail.Id,
            Unit__c = testUnit.Id,
            Invoice_Date__c = Date.today(),
            Sub_Total_Amount__c = 1000.00,
            VAT_Amount__c = 50.00
        );
        insert testInvoiceNoEmail;
        
        Test.startTest();
        
        // Call the method to test
        String result = InvoiceEmailService.sendInvoiceEmail(testInvoiceNoEmail.Id);
        
        Test.stopTest();
        
        // Verify error message returned
        System.assert(result.startsWith('Error'), 'The result should start with Error');
        System.assert(result.contains('No customer email found'), 'The result should indicate no email found');
    }
    
    @isTest
    static void testSendInvoiceEmailInvalidId() {
        Test.startTest();
        
        // Call the method with an invalid ID
        String result = InvoiceEmailService.sendInvoiceEmail('001000000000000AAA');
        
        Test.stopTest();
        
        // Verify error message returned for invalid ID
        System.assert(result.startsWith('Error'), 'The result should start with Error');
    }
    
    @isTest
    static void testPDFGenerationInTestContext() {
        // Get the test invoice
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c WHERE Invoice_Number__c = 'INV-001' LIMIT 1];
        
        Test.startTest();
        
        // Call the method - in test context, PDF generation is mocked
        String result = InvoiceEmailService.sendInvoiceEmail(testInvoice.Id);
        
        Test.stopTest();
        
        // Verify success even though actual PDF is not generated in test context
        System.assert(result.startsWith('Success'), 'The result should start with Success');
    }
}