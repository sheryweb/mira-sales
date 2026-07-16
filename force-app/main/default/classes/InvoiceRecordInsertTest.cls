@IsTest
private class InvoiceRecordInsertTest {
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
    }

    @IsTest
    static void testSuccessfulInvoiceInsertion() {
        // Get the test unit and account
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Account account = [SELECT Id FROM Account LIMIT 1];

        // Create test invoice
        Invoice__c invoice = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Invoice_Number__c = 'INV-001',
            Due_Date__c = Date.today().addDays(30),
            Description__c = 'Test Description',
            Sub_Total_Amount__c = 1000.00,
            Paid_Amount__c = 500.00,
            Unit__c = unit.Id,
            Account__c = account.Id
        );

        // Create test milestone invoices
        List<Milestone_Invoice__c> milestones = new List<Milestone_Invoice__c>();
        for(Integer i = 0; i < 3; i++) {
            milestones.add(new Milestone_Invoice__c(
                Name = 'Milestone ' + (i + 1),
                Amount__c = 333.33
            ));
        }

        // Create request wrapper
        InvoiceRecordInsert.RequestWrapper request = new InvoiceRecordInsert.RequestWrapper();
        request.invoiceRecordAll = new List<Invoice__c>{ invoice };
        request.milestoneInvoiceAll = milestones;

        Test.startTest();
        List<InvoiceRecordInsert.ResponseWrapper> response = 
            InvoiceRecordInsert.processInvoices(new List<InvoiceRecordInsert.RequestWrapper>{ request });
        Test.stopTest();

        // Verify invoice insertion
        System.assertNotEquals(null, response[0].invoiceId, 'Invoice ID should not be null');
        
        // Query and verify the inserted records
        Invoice__c insertedInvoice = [SELECT Id FROM Invoice__c WHERE Id = :response[0].invoiceId];
        System.assertNotEquals(null, insertedInvoice, 'Invoice should be inserted');

        List<Milestone_Invoice__c> insertedMilestones = [
            SELECT Id, Invoice__c 
            FROM Milestone_Invoice__c 
            WHERE Invoice__c = :response[0].invoiceId
        ];
        System.assertEquals(3, insertedMilestones.size(), 'Should have inserted 3 milestone invoices');
        for(Milestone_Invoice__c milestone : insertedMilestones) {
            System.assertEquals(response[0].invoiceId, milestone.Invoice__c, 'Milestone should be linked to the invoice');
        }
    }

    @IsTest
    static void testInvoiceInsertionWithoutMilestones() {
        // Get the test unit and account
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Account account = [SELECT Id FROM Account LIMIT 1];

        // Create test invoice
        Invoice__c invoice = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Invoice_Number__c = 'INV-001',
            Due_Date__c = Date.today().addDays(30),
            Description__c = 'Test Description',
            Sub_Total_Amount__c = 1000.00,
            Paid_Amount__c = 500.00,
            Unit__c = unit.Id,
            Account__c = account.Id
        );

        // Create request wrapper without milestones
        InvoiceRecordInsert.RequestWrapper request = new InvoiceRecordInsert.RequestWrapper();
        request.invoiceRecordAll = new List<Invoice__c>{ invoice };
        request.milestoneInvoiceAll = null; // Test null milestones

        Test.startTest();
        List<InvoiceRecordInsert.ResponseWrapper> response = 
            InvoiceRecordInsert.processInvoices(new List<InvoiceRecordInsert.RequestWrapper>{ request });
        Test.stopTest();

        // Verify invoice insertion
        System.assertNotEquals(null, response[0].invoiceId, 'Invoice ID should not be null');
        
        // Query and verify the inserted invoice
        Invoice__c insertedInvoice = [SELECT Id FROM Invoice__c WHERE Id = :response[0].invoiceId];
        System.assertNotEquals(null, insertedInvoice, 'Invoice should be inserted');
    }

    @IsTest
    static void testNullRequestList() {
        Boolean exceptionThrown = false;
        String actualMessage = '';
        
        Test.startTest();
        try {
            InvoiceRecordInsert.processInvoices(null);
        } catch(AuraHandledException e) {
            exceptionThrown = true;
            actualMessage = e.getMessage();
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An exception should have been thrown');
        System.assert(actualMessage.contains('Script-thrown exception'), 'Error message should be wrapped in Script-thrown exception');
    }

    @IsTest
    static void testEmptyInvoiceList() {
        InvoiceRecordInsert.RequestWrapper request = new InvoiceRecordInsert.RequestWrapper();
        request.invoiceRecordAll = new List<Invoice__c>();
        
        Boolean exceptionThrown = false;
        String actualMessage = '';
        
        Test.startTest();
        try {
            InvoiceRecordInsert.processInvoices(new List<InvoiceRecordInsert.RequestWrapper>{ request });
        } catch(AuraHandledException e) {
            exceptionThrown = true;
            actualMessage = e.getMessage();
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An exception should have been thrown');
        System.assert(actualMessage.contains('Script-thrown exception'), 'Error message should be wrapped in Script-thrown exception');
    }

    @IsTest
    static void testInvalidInvoiceData() {
        // Create invalid invoice with invalid ID references
        Invoice__c invalidInvoice = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Invoice_Number__c = 'INV-001',
            Unit__c = '001000000000000', // Invalid ID
            Account__c = '001000000000001' // Invalid ID
        );

        InvoiceRecordInsert.RequestWrapper request = new InvoiceRecordInsert.RequestWrapper();
        request.invoiceRecordAll = new List<Invoice__c>{ invalidInvoice };
        
        Boolean exceptionThrown = false;
        String actualMessage = '';
        
        Test.startTest();
        try {
            InvoiceRecordInsert.processInvoices(new List<InvoiceRecordInsert.RequestWrapper>{ request });
        } catch(AuraHandledException e) {
            exceptionThrown = true;
            actualMessage = e.getMessage();
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An exception should have been thrown');
        System.assert(actualMessage.contains('Script-thrown exception'), 'Error message should be wrapped in Script-thrown exception');
    }
}