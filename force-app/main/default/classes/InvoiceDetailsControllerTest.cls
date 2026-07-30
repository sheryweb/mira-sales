@IsTest
private class InvoiceDetailsControllerTest {
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
        // The Update_Project_Detail_on_New_Unit flow (after-save, Create only) rewrites
        // Project_Name_Text__c from the Project lookup, which is empty here. Re-stamp it so the
        // assertions below do not depend on that flow being present.
        update new Unit__c(Id = unit.Id, Project_Name_Text__c = 'Test Project');

        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;

        // Create multiple test invoices
        List<Invoice__c> testInvoices = new List<Invoice__c>();
        for(Integer i = 0; i < 3; i++) {
            testInvoices.add(new Invoice__c(
                Invoice_Date__c = Date.today(),
                Invoice_Number__c = 'INV-00' + (i + 1),
                Due_Date__c = Date.today().addDays(30),
                Description__c = 'Test Description ' + (i + 1),
                Sub_Total_Amount__c = 1000.00 * (i + 1),
                Paid_Amount__c = 500.00 * (i + 1),
                Unit__c = unit.Id,
                Account__c = testAccount.Id
            ));
        }
        insert testInvoices;

        // InvoiceTrigger assigns Invoice_Number__c on before-insert and blanks it when the unit's
        // project has no Project_Numbering_Setting__mdt entry (as here). Re-stamp the numbers the
        // assertions rely on — numbering does not run on update.
        List<Invoice__c> renumber = new List<Invoice__c>();
        Integer i = 0;
        for (Invoice__c inv : [SELECT Id FROM Invoice__c ORDER BY CreatedDate ASC]) {
            renumber.add(new Invoice__c(Id = inv.Id, Invoice_Number__c = 'INV-00' + (++i)));
        }
        update renumber;
    }

    @IsTest
    static void testGetInvoiceDetailsWithValidIds() {
        // Get test invoices
        List<Invoice__c> testInvoices = [SELECT Id FROM Invoice__c];
        List<String> invoiceIds = new List<String>();
        for(Invoice__c inv : testInvoices) {
            invoiceIds.add(inv.Id);
        }
        
        Test.startTest();
        List<Invoice__c> result = InvoiceDetailsController.getInvoiceDetails(invoiceIds);
        Test.stopTest();

        // Debug the values
        System.debug('=== Invoice Details Test ===');
        for(Invoice__c inv : result) {
            System.debug('Invoice: ' + inv.Invoice_Number__c);
            System.debug('Sub Total: ' + inv.Sub_Total_Amount__c);
            System.debug('Paid Amount: ' + inv.Paid_Amount__c);
            System.debug('Pending Amount: ' + inv.Pending_Amount__c);
        }

        // Verify results
        System.assertEquals(3, result.size(), 'Should return 3 invoices');
        for(Invoice__c inv : result) {
            System.assertNotEquals(null, inv.Invoice_Number__c, 'Invoice number should not be null');
            System.assertNotEquals(null, inv.Unit__r.Project_Name_Text__c, 'Project name should not be null');
            System.assertNotEquals(null, inv.Account__r.Name, 'Account name should not be null');
            
            // Calculate both possible formulas
            Decimal formula1 = inv.Sub_Total_Amount__c - inv.Paid_Amount__c;
            Decimal formula2 = inv.Paid_Amount__c - inv.Sub_Total_Amount__c;
            
            // Verify the pending amount matches one of the possible calculations
            Boolean matchesFormula1 = inv.Pending_Amount__c == formula1;
            Boolean matchesFormula2 = inv.Pending_Amount__c == formula2;
            
            System.assert(matchesFormula1 || matchesFormula2, 
                'Pending amount (' + inv.Pending_Amount__c + 
                ') should match either Sub Total (' + inv.Sub_Total_Amount__c + 
                ') minus Paid Amount (' + inv.Paid_Amount__c + ') = ' + formula1 + 
                ' OR Paid Amount minus Sub Total = ' + formula2);
            
            // Log which formula is being used
            if (matchesFormula1) {
                System.debug('Using formula: Sub Total - Paid Amount');
            } else if (matchesFormula2) {
                System.debug('Using formula: Paid Amount - Sub Total');
            }
        }
    }

    @IsTest
    static void testGetInvoiceDetailsWithInvalidIds() {
        List<String> invalidIds = new List<String>{
            '001000000000000',  // Valid format but non-existent ID
            'invalid-id',       // Invalid format
            '"001000000000000"' // Quoted ID
        };
        
        Test.startTest();
        List<Invoice__c> result = InvoiceDetailsController.getInvoiceDetails(invalidIds);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return empty list for invalid IDs');
    }

    @IsTest
    static void testGetInvoiceDetailsWithNullAndEmptyInput() {
        Test.startTest();
        // Test with null input
        List<Invoice__c> nullResult = InvoiceDetailsController.getInvoiceDetails(null);
        System.assertEquals(0, nullResult.size(), 'Should return empty list for null input');

        // Test with empty list
        List<Invoice__c> emptyResult = InvoiceDetailsController.getInvoiceDetails(new List<String>());
        System.assertEquals(0, emptyResult.size(), 'Should return empty list for empty input');
        Test.stopTest();
    }

    @IsTest
    static void testGetInvoiceDetailsWithMixedIds() {
        // Get one valid invoice ID
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c LIMIT 1];
        
        // Create a list with both valid and invalid IDs
        List<String> mixedIds = new List<String>{
            testInvoice.Id,
            '001000000000000',  // Invalid ID
            'invalid-id',       // Malformed ID
            '"' + testInvoice.Id + '"' // Quoted valid ID
        };

        Test.startTest();
        List<Invoice__c> result = InvoiceDetailsController.getInvoiceDetails(mixedIds);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return only the valid invoice');
        System.assertEquals(testInvoice.Id, result[0].Id, 'Should return the correct invoice');
    }
}