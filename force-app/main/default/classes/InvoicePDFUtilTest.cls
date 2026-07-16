@IsTest
private class InvoicePDFUtilTest {
    @TestSetup
    static void setupTestData() {
        // Create test data
        Unit__c unit = new Unit__c(
            Project_Name_Text__c = 'Test Project',
            Building__c = 'Test Building',
            Title__c = 'Test Property',
            Property_Code_Text__c = 'TEST-001'
        );
        insert unit;

        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;

        // Create test invoice
        Invoice__c invoice = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Invoice_Number__c = 'INV-001',
            Due_Date__c = Date.today().addDays(30),
            Description__c = 'Test Description',
            Sub_Total_Amount__c = 1000.00,
            Paid_Amount__c = 500.00,
            Unit__c = unit.Id,
            Account__c = testAccount.Id
        );
        insert invoice;
    }

    @IsTest
    static void testGetInvoicePDFUrl() {
        // Get test invoice
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c LIMIT 1];
        
        Test.startTest();
        String pdfUrl = InvoicePDFUtil.getInvoicePDFUrl(testInvoice.Id);
        Test.stopTest();

        // Verify URL format
        System.assert(pdfUrl.endsWith('/apex/InvoicePDF?id=' + testInvoice.Id), 'URL should end with correct parameters');
        System.assert(pdfUrl.startsWith(System.URL.getOrgDomainUrl().toExternalForm()), 'URL should start with org domain');
    }

    @IsTest
    static void testGetInvoicePDFUrlWithNullId() {
        Boolean exceptionThrown = false;
        String actualMessage = '';
        
        Test.startTest();
        try {
            InvoicePDFUtil.getInvoicePDFUrl(null);
        } catch(AuraHandledException e) {
            exceptionThrown = true;
            actualMessage = e.getMessage();
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An exception should have been thrown');
        System.assert(actualMessage.contains('Script-thrown exception'), 'Error message should be wrapped in Script-thrown exception');
    }

    @IsTest
    static void testGetInvoicePDFPageRef() {
        // Get test invoice
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c LIMIT 1];
        
        Test.startTest();
        PageReference pageRef = InvoicePDFUtil.getInvoicePDFPageRef(testInvoice.Id);
        Test.stopTest();

        // Verify PageReference
        System.assertEquals(testInvoice.Id, pageRef.getParameters().get('id'), 'Page parameters should contain invoice ID');
        System.assert(pageRef.getUrl().toLowerCase().contains('/apex/invoicepdf'), 'Should reference InvoicePDF page');
    }

    @IsTest
    static void testGetInvoicePDFPageRefWithNullId() {
        Boolean exceptionThrown = false;
        String actualMessage = '';
        
        Test.startTest();
        try {
            InvoicePDFUtil.getInvoicePDFPageRef(null);
        } catch(AuraHandledException e) {
            exceptionThrown = true;
            actualMessage = e.getMessage();
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An exception should have been thrown');
        System.assert(actualMessage.contains('Script-thrown exception'), 'Error message should be wrapped in Script-thrown exception');
    }

    @IsTest
    static void testGenerateInvoicePDFBlob() {
        // Get test invoice
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c LIMIT 1];
        
        Test.startTest();
        Blob pdfBlob = InvoicePDFUtil.generateInvoicePDFBlob(testInvoice.Id);
        Test.stopTest();

        // Verify PDF generation
        System.assertNotEquals(null, pdfBlob, 'PDF Blob should not be null');
        System.assertEquals('Test PDF Content', pdfBlob.toString(), 'Should return test content in test context');
    }

    @IsTest
    static void testGenerateInvoicePDFBlobWithNullId() {
        Boolean exceptionThrown = false;
        String actualMessage = '';
        
        Test.startTest();
        try {
            InvoicePDFUtil.generateInvoicePDFBlob(null);
        } catch(AuraHandledException e) {
            exceptionThrown = true;
            actualMessage = e.getMessage();
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An exception should have been thrown');
        System.assert(actualMessage.contains('Script-thrown exception'), 'Error message should be wrapped in Script-thrown exception');
    }

    @IsTest
    static void testAttachInvoicePDF() {
        // Get test invoice
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c LIMIT 1];
        
        Test.startTest();
        Id attachmentId = InvoicePDFUtil.attachInvoicePDF(testInvoice.Id);
        Test.stopTest();

        // Query and verify the attachment
        Attachment attachment = [SELECT Id, Name, ParentId, ContentType FROM Attachment WHERE Id = :attachmentId];
        System.assertEquals(testInvoice.Id, attachment.ParentId, 'Attachment should be linked to the invoice');
        System.assertEquals('application/pdf', attachment.ContentType, 'Content type should be PDF');
        System.assert(attachment.Name.startsWith('Invoice_'), 'Filename should start with Invoice_');
    }

    @IsTest
    static void testAttachInvoicePDFWithNullId() {
        Boolean exceptionThrown = false;
        String actualMessage = '';
        
        Test.startTest();
        try {
            InvoicePDFUtil.attachInvoicePDF(null);
        } catch(AuraHandledException e) {
            exceptionThrown = true;
            actualMessage = e.getMessage();
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An exception should have been thrown');
        System.assert(actualMessage.contains('Script-thrown exception'), 'Error message should be wrapped in Script-thrown exception');
    }
}