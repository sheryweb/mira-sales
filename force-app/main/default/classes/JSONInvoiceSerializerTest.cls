@IsTest
private class JSONInvoiceSerializerTest {
    @TestSetup
    static void setupTestData() {
        // Create test Unit
        Unit__c unit = new Unit__c(
            Project_Name_Text__c = 'Test Project',
            Building__c = 'Test Building',
            Title__c = 'Test Property',
            Property_Code_Text__c = 'TEST-001'
        );
        insert unit;

        // Create test Invoice
        Invoice__c invoice = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Invoice_Number__c = 'INV-001',
            Sub_Total_Amount__c = 1000.00,
            VAT_Amount__c = 150.00, // Add VAT amount to calculate Grand Total
            Unit__c = unit.Id
        );
        insert invoice;

        // Create test Milestone Invoice
        Milestone_Invoice__c milestone = new Milestone_Invoice__c(
            Name = 'Test Milestone',
            Amount__c = 500.00,
            Invoice__c = invoice.Id
        );
        insert milestone;
    }

    @IsTest
    static void testSerializeInvoicesWithValidData() {
        // Get test data with formula fields
        List<Invoice__c> invoices = [SELECT Id, Sub_Total_Amount__c, Grand_Total_Amount__c, VAT_Amount__c FROM Invoice__c];
        List<Milestone_Invoice__c> milestones = [SELECT Id, Amount__c FROM Milestone_Invoice__c];
        
        // Debug the original data
        System.debug('Original Invoice Data:');
        System.debug('Sub Total: ' + invoices[0].Sub_Total_Amount__c);
        System.debug('VAT Amount: ' + invoices[0].VAT_Amount__c);
        System.debug('Grand Total: ' + invoices[0].Grand_Total_Amount__c);
        
        // Create input collections
        List<List<SObject>> inputCollections = new List<List<SObject>>{
            invoices,
            milestones
        };

        Test.startTest();
        List<String> result = JSONInvoiceSerializer.serializeInvoices(inputCollections);
        Test.stopTest();

        // Debug the serialized JSON
        System.debug('Serialized JSON: ' + result[0]);

        // Verify results
        System.assertEquals(2, result.size(), 'Should return 2 JSON strings');
        System.assertNotEquals('[]', result[0], 'First collection should not be empty');
        System.assertNotEquals('[]', result[1], 'Second collection should not be empty');

        // Parse and verify first JSON (Invoices)
        List<Invoice__c> parsedInvoices = (List<Invoice__c>)JSON.deserialize(result[0], List<Invoice__c>.class);
        System.assertEquals(1, parsedInvoices.size(), 'Should have 1 invoice');
        
        // Debug the parsed data
        System.debug('Parsed Invoice Data:');
        System.debug('Sub Total: ' + parsedInvoices[0].Sub_Total_Amount__c);
        System.debug('VAT Amount: ' + parsedInvoices[0].VAT_Amount__c);
        System.debug('Grand Total: ' + parsedInvoices[0].Grand_Total_Amount__c);
        
        // Verify individual components
        System.assertEquals(1000.00, parsedInvoices[0].Sub_Total_Amount__c, 'Sub total should match');
        System.assertEquals(150.00, parsedInvoices[0].VAT_Amount__c, 'VAT amount should match');
        
        // Verify the calculation components are present
        System.assertNotEquals(null, parsedInvoices[0].Sub_Total_Amount__c, 'Sub total should not be null');
        System.assertNotEquals(null, parsedInvoices[0].VAT_Amount__c, 'VAT amount should not be null');
        
        // Calculate and verify the total
        Decimal calculatedTotal = parsedInvoices[0].Sub_Total_Amount__c + parsedInvoices[0].VAT_Amount__c;
        System.assertEquals(1150.00, calculatedTotal, 
            'Calculated total should be Sub Total (' + parsedInvoices[0].Sub_Total_Amount__c + 
            ') plus VAT (' + parsedInvoices[0].VAT_Amount__c + ')');

        // Parse and verify second JSON (Milestones)
        List<Milestone_Invoice__c> parsedMilestones = (List<Milestone_Invoice__c>)JSON.deserialize(result[1], List<Milestone_Invoice__c>.class);
        System.assertEquals(1, parsedMilestones.size(), 'Should have 1 milestone');
        System.assertEquals(500.00, parsedMilestones[0].Amount__c, 'Amount should match');
    }

    @IsTest
    static void testSerializeInvoicesWithNullCollection() {
        List<List<SObject>> inputCollections = new List<List<SObject>>{
            null
        };

        Test.startTest();
        List<String> result = JSONInvoiceSerializer.serializeInvoices(inputCollections);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return 1 JSON string');
        System.assertEquals('[]', result[0], 'Should return empty array for null collection');
    }

    @IsTest
    static void testSerializeInvoicesWithEmptyCollection() {
        List<List<SObject>> inputCollections = new List<List<SObject>>{
            new List<SObject>()
        };

        Test.startTest();
        List<String> result = JSONInvoiceSerializer.serializeInvoices(inputCollections);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return 1 JSON string');
        System.assertEquals('[]', result[0], 'Should return empty array for empty collection');
    }

    @IsTest
    static void testSerializeInvoicesWithMixedData() {
        // Get test data with formula fields
        List<Invoice__c> invoices = [SELECT Id, Sub_Total_Amount__c, Grand_Total_Amount__c, VAT_Amount__c FROM Invoice__c];
        List<Milestone_Invoice__c> milestones = [SELECT Id, Amount__c FROM Milestone_Invoice__c];
        
        // Create a mixed collection
        List<SObject> mixedCollection = new List<SObject>();
        mixedCollection.addAll(invoices);
        mixedCollection.addAll(milestones);

        List<List<SObject>> inputCollections = new List<List<SObject>>{
            mixedCollection
        };

        Test.startTest();
        List<String> result = JSONInvoiceSerializer.serializeInvoices(inputCollections);
        Test.stopTest();

        // Verify results
        System.assertEquals(1, result.size(), 'Should return 1 JSON string');
        System.assertNotEquals('[]', result[0], 'Collection should not be empty');

        // Parse and verify the mixed collection
        List<Object> parsedObjects = (List<Object>)JSON.deserializeUntyped(result[0]);
        System.assertEquals(2, parsedObjects.size(), 'Should have 2 objects');
        
        // Verify the first object is an Invoice
        Map<String, Object> firstObject = (Map<String, Object>)parsedObjects[0];
        System.assertNotEquals(null, firstObject.get('Sub_Total_Amount__c'), 'First object should be an Invoice');
        
        // Verify the second object is a Milestone
        Map<String, Object> secondObject = (Map<String, Object>)parsedObjects[1];
        System.assertNotEquals(null, secondObject.get('Amount__c'), 'Second object should be a Milestone');
    }

    @IsTest
    static void testSerializeInvoicesWithNullValues() {
        // Create test Unit
        Unit__c unit = new Unit__c(
            Project_Name_Text__c = 'Test Project',
            Building__c = 'Test Building',
            Title__c = 'Test Property',
            Property_Code_Text__c = 'TEST-001'
        );
        insert unit;

        // Create test Invoice with null values
        Invoice__c invoice = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Invoice_Number__c = 'INV-002',
            Unit__c = unit.Id
        );
        insert invoice;

        List<List<SObject>> inputCollections = new List<List<SObject>>{
            new List<Invoice__c>{invoice}
        };

        Test.startTest();
        List<String> result = JSONInvoiceSerializer.serializeInvoices(inputCollections);
        Test.stopTest();

        // Verify results
        System.assertEquals(1, result.size(), 'Should return 1 JSON string');
        System.assertNotEquals('[]', result[0], 'Collection should not be empty');

        // Parse and verify the invoice with null values
        List<Invoice__c> parsedInvoices = (List<Invoice__c>)JSON.deserialize(result[0], List<Invoice__c>.class);
        System.assertEquals(1, parsedInvoices.size(), 'Should have 1 invoice');
        System.assertEquals(null, parsedInvoices[0].Sub_Total_Amount__c, 'Sub total should be null');
        System.assertEquals(null, parsedInvoices[0].VAT_Amount__c, 'VAT amount should be null');
        System.assertEquals(null, parsedInvoices[0].Grand_Total_Amount__c, 'Grand total should be null');
    }
}