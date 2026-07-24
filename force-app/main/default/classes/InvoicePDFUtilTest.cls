@IsTest
private class InvoicePDFUtilTest {
    @TestSetup
    static void setupTestData() {
        insert new Financial_Engine_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(), Engine_Owns_Totals__c = true);
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

    // Helper: add a reconciled receipt + line funding the invoice on the given date.
    private static void addReceipt(Id unitId, Id invoiceId, Date paymentDate) {
        Receipt__c r = new Receipt__c(
            Description__c = 'R',
            Unit__c = unitId,
            Payment_Date__c = paymentDate,
            Received_Amount__c = 0,
            Status__c = 'Reconciled',
            Payment_Status__c = 'Fully Paid'
        );
        insert r;
        insert new Receipt_Amount__c(Receipt__c = r.Id, Invoice__c = invoiceId, Amount__c = 500);
    }

    @IsTest
    static void testTaxInvoiceBlockedWithoutPayment() {
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c LIMIT 1];
        Boolean blocked = false;
        String msg = '';
        Test.startTest();
        try {
            InvoicePDFUtil.getTaxInvoicePDFUrl(testInvoice.Id);
        } catch (AuraHandledException e) {
            blocked = true;
            msg = e.getMessage();
        }
        Test.stopTest();
        System.assert(blocked, 'Tax invoice must be blocked when no payment exists');
        // date must remain unset
        Invoice__c after = [SELECT Tax_Invoice_Date__c FROM Invoice__c WHERE Id = :testInvoice.Id];
        System.assertEquals(null, after.Tax_Invoice_Date__c, 'Tax Invoice Date should stay blank when blocked');
    }

    @IsTest
    static void testTaxInvoiceLocksFirstPaymentDate() {
        Invoice__c testInvoice = [SELECT Id, Unit__c FROM Invoice__c LIMIT 1];
        Date early = Date.today().addDays(-10);
        Date later = Date.today().addDays(-3);
        addReceipt(testInvoice.Unit__c, testInvoice.Id, later);
        addReceipt(testInvoice.Unit__c, testInvoice.Id, early); // earliest -> should win

        Test.startTest();
        String url = InvoicePDFUtil.getTaxInvoicePDFUrl(testInvoice.Id);
        Test.stopTest();

        System.assert(url.endsWith('/apex/InvoicePDF?id=' + testInvoice.Id + '&mode=tax'), 'URL should carry mode=tax: ' + url);
        Invoice__c after = [SELECT Tax_Invoice_Date__c FROM Invoice__c WHERE Id = :testInvoice.Id];
        System.assertEquals(early, after.Tax_Invoice_Date__c, 'Should lock the earliest payment date');
    }

    @IsTest
    static void testTaxInvoiceDateNotOverwritten() {
        Invoice__c testInvoice = [SELECT Id, Unit__c FROM Invoice__c LIMIT 1];
        Date locked = Date.today().addDays(-30);
        testInvoice.Tax_Invoice_Date__c = locked;
        update testInvoice;
        // a later payment exists but must NOT change the already-locked date
        addReceipt(testInvoice.Unit__c, testInvoice.Id, Date.today());

        Test.startTest();
        String url = InvoicePDFUtil.getTaxInvoicePDFUrl(testInvoice.Id);
        Test.stopTest();

        Invoice__c after = [SELECT Tax_Invoice_Date__c FROM Invoice__c WHERE Id = :testInvoice.Id];
        System.assertEquals(locked, after.Tax_Invoice_Date__c, 'Existing Tax Invoice Date must not be overwritten');
        System.assert(url.contains('mode=tax'), 'URL should carry mode=tax');
    }

    @IsTest
    static void testGetTaxInvoicePDFUrlWithNullId() {
        Boolean thrown = false;
        Test.startTest();
        try {
            InvoicePDFUtil.getTaxInvoicePDFUrl(null);
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'Null id should throw');
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