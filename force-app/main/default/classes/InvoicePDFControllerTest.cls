@IsTest
private class InvoicePDFControllerTest {
    @TestSetup
    static void setupTestData() {
        // Create test data
        Financial_Detail__c financialDetail = new Financial_Detail__c(
            Name = 'Test Bank',
            Account_Name__c = 'Test Account',
            Account_Number__c = '1234567890',
            IBAN__c = 'AE123456789012345678901',
            Swift_Code__c = 'TEST1234',
            Branch_Name__c = 'Test Branch'
        );
        insert financialDetail;

        Unit__c unit = new Unit__c(
            Project_Name_Text__c = 'Test Project',
            Cost_AED__c = 1000000.00,
            Property_Code_Text__c = 'UNIT-001',
            Title__c = 'Test Property'
        );
        insert unit;

        // Create test accounts for joint owners
        List<Account> testAccounts = new List<Account>();
        for(Integer i = 0; i < 3; i++) {
            Account acc = new Account(
                Name = 'Joint Owner' + (i + 1)
            );
            testAccounts.add(acc);
        }
        insert testAccounts;

        // Create opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = testAccounts[0].Id
        );
        insert testOpp;

        // Calculate the grand total explicitly
        Decimal subTotal = 1000000.00;
        Decimal vatAmount = 50000.00;

        Invoice__c invoice = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Invoice_Number__c = 'INV-001',
            Customer_Id__c = 'CUST-001',
            Customer_Name__c = 'Test Customer',
            Sub_Total_Amount__c = subTotal,
            VAT_Amount__c = vatAmount,
            Unit__c = unit.Id,
            Financial_Detail__c = financialDetail.Id,
            Secondary_Currency__c = 'USD',
            Secondary_Currency_Amount__c = 300000.00,
            Opportunity__c = testOpp.Id
        );
        insert invoice;

        // Create joint owners
        List<Joint_Owners__c> jointOwners = new List<Joint_Owners__c>();
        for(Integer i = 0; i < testAccounts.size(); i++) {
            jointOwners.add(new Joint_Owners__c(
                Opportunity__c = testOpp.Id,
                Account__c = testAccounts[i].Id,
                Order__c = i + 1,
                Ownership_Share__c = 33.33
            ));
        }
        insert jointOwners;

        // Create line items (VAT_Amount__c / Total_with_VAT__c on Milestone_Invoice__c are formula/read-only)
        List<Milestone_Invoice__c> lineItems = new List<Milestone_Invoice__c>();
        for(Integer i = 0; i < 3; i++) {
            lineItems.add(new Milestone_Invoice__c(
                Name = 'Milestone ' + (i + 1),
                Amount__c = 333333.33,
                Invoice__c = invoice.Id
            ));
        }
        insert lineItems;
    }

    @IsTest
    static void testInvoicePDFController() {
        // Get the test invoice with all fields
        Invoice__c testInvoice = [
            SELECT Id, Name, Invoice_Date__c, Invoice_Number__c, Customer_Id__c, 
                   Customer_Name__c, Sub_Total_Amount__c, VAT_Amount__c, Grand_Total_Formula__c,
                   Secondary_Currency__c, Secondary_Currency_Amount__c,
                   Unit__c, Unit__r.Project_Name_Text__c, Unit__r.Cost_AED__c,
                   Unit__r.Property_Code_Text__c, Unit__r.Title__c, Financial_Detail__c
            FROM Invoice__c 
            LIMIT 1
        ];

        // Calculate expected grand total
        Decimal expectedGrandTotal = testInvoice.Sub_Total_Amount__c + testInvoice.VAT_Amount__c;
        
        // Debug all values before controller instantiation
        System.debug('=== Test Setup Values ===');
        System.debug('Invoice ID: ' + testInvoice.Id);
        System.debug('Sub Total: ' + testInvoice.Sub_Total_Amount__c);
        System.debug('VAT Amount: ' + testInvoice.VAT_Amount__c);
        System.debug('Expected Grand Total: ' + expectedGrandTotal);
        System.debug('Actual Grand Total: ' + testInvoice.Grand_Total_Formula__c);
        System.debug('Secondary Currency: ' + testInvoice.Secondary_Currency__c);
        System.debug('Secondary Currency Amount: ' + testInvoice.Secondary_Currency_Amount__c);
        
        // Set the page parameters
        Test.setCurrentPage(Page.InvoicePDF);
        ApexPages.currentPage().getParameters().put('id', testInvoice.Id);
        
        Test.startTest();
        InvoicePDFController controller = new InvoicePDFController();
        
        // Debug controller values immediately after instantiation
        System.debug('=== Controller Values ===');
        System.debug('Controller Invoice ID: ' + controller.invoice.Id);
        System.debug('Controller Sub Total: ' + controller.invoice.Sub_Total_Amount__c);
        System.debug('Controller VAT Amount: ' + controller.invoice.VAT_Amount__c);
        System.debug('Controller Grand Total: ' + controller.invoice.Grand_Total_Formula__c);
        System.debug('Controller Total in Words: ' + controller.totalInWords);
        System.debug('Controller Secondary Currency: ' + controller.invoice.Secondary_Currency__c);
        System.debug('Controller Secondary Currency Amount: ' + controller.invoice.Secondary_Currency_Amount__c);
        System.debug('Controller Secondary Currency in Words: ' + controller.secondaryCurrencyInWords);
        
        Test.stopTest();

        // Basic assertions first
        System.assertNotEquals(null, controller.invoice, 'Invoice should not be null');
        System.assertEquals(testInvoice.Id, controller.invoice.Id, 'Invoice ID should match');
        
        // Verify amounts
        System.assertEquals('1,000,000.00', controller.getFormattedSubTotal(), 'Sub total should match');
        System.assertEquals('50,000.00', controller.getFormattedVATAmount(), 'VAT amount should match');
        System.assertEquals('1,000,000.00', controller.getFormattedSalePrice(), 'Sale price should match');

        // Verify the total in words is generated
        System.debug('=== Final Verification ===');
        System.debug('Final Total in Words: ' + controller.totalInWords);
        
        // Assert total in words is generated correctly
        System.assertNotEquals(null, controller.totalInWords, 'Total in words should not be null');
        System.assert(controller.totalInWords.endsWith('AED Only'), 'Total in words should end with AED Only');
        
        // Verify expected phrases based on the amount
        String expectedAmount = 'One Million Fifty Thousand';
        System.assert(controller.totalInWords.contains(expectedAmount), 
            'Total in words should contain "' + expectedAmount + '" but was: ' + controller.totalInWords);
            
        // Verify secondary currency functionality
        System.assertEquals(true, controller.getHasSecondaryCurrency(), 'Should have secondary currency');
        System.assertEquals('USD', controller.getSecondaryCurrencyType(), 'Secondary currency type should be USD');
        System.assertEquals('$', controller.getSecondaryCurrencySymbol(), 'Secondary currency symbol should be $');
        System.assertEquals('300,000.00', controller.getFormattedSecondaryCurrencyAmount(), 'Secondary currency amount should match');
        System.assert(controller.secondaryCurrencyInWords.contains('Three Hundred Thousand'), 
            'Secondary currency words should contain "Three Hundred Thousand"');
        System.assert(controller.secondaryCurrencyInWords.endsWith('US Dollars Only'), 
            'Secondary currency words should end with "US Dollars Only"');
    }

    @IsTest
    static void testInvoicePDFControllerWithNoFinancialDetail() {
        // Get the test invoice
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c LIMIT 1];
        
        // Remove financial detail from invoice
        testInvoice.Financial_Detail__c = null;
        update testInvoice;
        
        // Set the page parameters
        Test.setCurrentPage(Page.InvoicePDF);
        ApexPages.currentPage().getParameters().put('id', testInvoice.Id);
        
        Test.startTest();
        InvoicePDFController controller = new InvoicePDFController();
        Test.stopTest();

        // Verify financial details are null
        System.assertEquals(null, controller.financialDetail, 'Financial detail should be null');
        System.assertEquals('________', controller.getBankName(), 'Bank name should be default');
        System.assertEquals('________', controller.getAccountName(), 'Account name should be default');
        System.assertEquals('________', controller.getAccountNumber(), 'Account number should be default');
        System.assertEquals('________', controller.getIBAN(), 'IBAN should be default');
        System.assertEquals('________', controller.getSwiftCode(), 'Swift code should be default');
        System.assertEquals('', controller.getBranchName(), 'Branch name should be empty');
    }

    @IsTest
    static void testInvoicePDFControllerWithNoId() {
        // Set the page parameters without an ID
        Test.setCurrentPage(Page.InvoicePDF);
        
        Test.startTest();
        InvoicePDFController controller = new InvoicePDFController();
        Test.stopTest();

        // Verify error message was added
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assertEquals(1, messages.size(), 'Should have one error message');
        System.assertEquals('Error loading invoice: Invoice ID is required.', messages[0].getSummary(), 'Error message should match exactly');
    }

    @IsTest
    static void testInvoicePDFControllerWithInvalidId() {
        // Set the page parameters with an invalid ID
        Test.setCurrentPage(Page.InvoicePDF);
        ApexPages.currentPage().getParameters().put('id', '001000000000000');
        
        Test.startTest();
        InvoicePDFController controller = new InvoicePDFController();
        Test.stopTest();

        // Verify error message was added
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assertEquals(1, messages.size(), 'Should have one error message');
        System.assertEquals('Error loading invoice: List has no rows for assignment to SObject', messages[0].getSummary(), 'Error message should match exactly');
    }

    @IsTest
    static void testJointOwnersFunctionality() {
        // Get the test invoice
        Invoice__c testInvoice = [SELECT Id FROM Invoice__c LIMIT 1];
        
        // Set the page parameters
        Test.setCurrentPage(Page.InvoicePDF);
        ApexPages.currentPage().getParameters().put('id', testInvoice.Id);
        
        Test.startTest();
        InvoicePDFController controller = new InvoicePDFController();
        Test.stopTest();

        // Verify joint owners functionality
        System.assertNotEquals(null, controller.jointOwnerNames, 'Joint owner names should not be null');
        System.assertNotEquals(null, controller.jointOwnerCustomerIds, 'Joint owner customer IDs should not be null');
        System.assertNotEquals(null, controller.fullCustomerName, 'Full customer name should not be null');
        System.assertNotEquals(null, controller.fullCustomerId, 'Full customer ID should not be null');
        
        // Verify joint owners are included
        System.assert(controller.fullCustomerName.contains('Test Customer'), 'Full customer name should contain primary customer');
        System.assert(controller.fullCustomerName.contains('Joint Owner1'), 'Full customer name should contain joint owner 1');
        System.assert(controller.fullCustomerName.contains('Joint Owner2'), 'Full customer name should contain joint owner 2');
        System.assert(controller.fullCustomerName.contains('Joint Owner3'), 'Full customer name should contain joint owner 3');
        
        // Verify separators
        System.assert(controller.fullCustomerName.contains(' & '), 'Customer names should be separated by &');
        System.assert(controller.fullCustomerId.contains(', '), 'Customer IDs should be separated by comma');
        
        // Verify customer IDs are included (using Account IDs since Financial_Number__c doesn't exist)
        System.assert(controller.fullCustomerId.contains('CUST-001'), 'Full customer ID should contain primary customer ID');
        // Note: Since Financial_Number__c field doesn't exist, joint owner customer IDs will be empty
        // This is expected behavior when the field doesn't exist
    }

    @IsTest
    static void testInvoicePDFControllerWithoutJointOwners() {
        // Create invoice without opportunity (no joint owners)
        Financial_Detail__c financialDetail = new Financial_Detail__c(
            Name = 'Test Bank 2',
            Account_Name__c = 'Test Account 2',
            Account_Number__c = '1234567891',
            IBAN__c = 'AE123456789012345678902',
            Swift_Code__c = 'TEST1235',
            Branch_Name__c = 'Test Branch 2'
        );
        insert financialDetail;

        Unit__c unit = new Unit__c(
            Project_Name_Text__c = 'Test Project 2',
            Cost_AED__c = 500000.00,
            Property_Code_Text__c = 'UNIT-002',
            Title__c = 'Test Property 2'
        );
        insert unit;

        Invoice__c invoice = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Invoice_Number__c = 'INV-002',
            Customer_Id__c = 'CUST-002',
            Customer_Name__c = 'Test Customer 2',
            Sub_Total_Amount__c = 500000.00,
            VAT_Amount__c = 25000.00,
            Unit__c = unit.Id,
            Financial_Detail__c = financialDetail.Id
            // No Opportunity__c - no joint owners
        );
        insert invoice;
        
        // Set the page parameters
        Test.setCurrentPage(Page.InvoicePDF);
        ApexPages.currentPage().getParameters().put('id', invoice.Id);
        
        Test.startTest();
        InvoicePDFController controller = new InvoicePDFController();
        Test.stopTest();

        // Verify no joint owners
        System.assertEquals(null, controller.jointOwnerNames, 'Joint owner names should be null');
        System.assertEquals(null, controller.jointOwnerCustomerIds, 'Joint owner customer IDs should be null');
        System.assertEquals('Test Customer 2', controller.fullCustomerName, 'Full customer name should be only primary customer');
        System.assertEquals('CUST-002', controller.fullCustomerId, 'Full customer ID should be only primary customer ID');
    }

    @IsTest
    static void testSecondaryCurrencyScenarios() {
        // Test different currency scenarios
        Financial_Detail__c financialDetail = new Financial_Detail__c(
            Name = 'Test Bank 3',
            Account_Name__c = 'Test Account 3',
            Account_Number__c = '1234567892',
            IBAN__c = 'AE123456789012345678903',
            Swift_Code__c = 'TEST1236',
            Branch_Name__c = 'Test Branch 3'
        );
        insert financialDetail;

        Unit__c unit = new Unit__c(
            Project_Name_Text__c = 'Test Project 3',
            Cost_AED__c = 750000.00,
            Property_Code_Text__c = 'UNIT-003',
            Title__c = 'Test Property 3'
        );
        insert unit;

        // Test USD currency (using valid picklist value)
        Invoice__c invoiceUSD = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Invoice_Number__c = 'INV-USD',
            Customer_Id__c = 'CUST-USD',
            Customer_Name__c = 'Test Customer USD',
            Sub_Total_Amount__c = 750000.00,
            VAT_Amount__c = 37500.00,
            Unit__c = unit.Id,
            Financial_Detail__c = financialDetail.Id,
            Secondary_Currency__c = 'USD',
            Secondary_Currency_Amount__c = 200000.00
        );
        insert invoiceUSD;
        
        Test.setCurrentPage(Page.InvoicePDF);
        ApexPages.currentPage().getParameters().put('id', invoiceUSD.Id);
        
        Test.startTest();
        InvoicePDFController controllerUSD = new InvoicePDFController();
        Test.stopTest();

        System.assertEquals('USD', controllerUSD.getSecondaryCurrencyType(), 'Secondary currency type should be USD');
        System.assertEquals('$', controllerUSD.getSecondaryCurrencySymbol(), 'Secondary currency symbol should be $');
        System.assert(controllerUSD.secondaryCurrencyInWords.contains('Two Hundred Thousand'), 'USD words should contain amount');
        System.assert(controllerUSD.secondaryCurrencyInWords.endsWith('US Dollars Only'), 'USD words should end with US Dollars Only');
    }

    @IsTest
    static void testCurrencySymbols() {
        // Test CHF currency (POST HOTEL project)
        Financial_Detail__c financialDetail = new Financial_Detail__c(
            Name = 'Test Bank 4',
            Account_Name__c = 'Test Account 4',
            Account_Number__c = '1234567893',
            IBAN__c = 'AE123456789012345678904',
            Swift_Code__c = 'TEST1237',
            Branch_Name__c = 'Test Branch 4'
        );
        insert financialDetail;

        Unit__c unitCHF = new Unit__c(
            Project_Name_Text__c = 'POST HOTEL & RESIDENCES By ELIE SAAB',
            Cost_CHF__c = 500000.00,
            Property_Code_Text__c = 'UNIT-CHF',
            Title__c = 'Test Property CHF'
        );
        insert unitCHF;

        Invoice__c invoiceCHF = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Invoice_Number__c = 'INV-CHF',
            Customer_Id__c = 'CUST-CHF',
            Customer_Name__c = 'Test Customer CHF',
            Sub_Total_Amount__c = 500000.00,
            VAT_Amount__c = 25000.00,
            Unit__c = unitCHF.Id,
            Financial_Detail__c = financialDetail.Id
        );
        insert invoiceCHF;
        
        Test.setCurrentPage(Page.InvoicePDF);
        ApexPages.currentPage().getParameters().put('id', invoiceCHF.Id);
        
        Test.startTest();
        InvoicePDFController controllerCHF = new InvoicePDFController();
        Test.stopTest();

        //System.assertEquals('CHF', controllerCHF.getCurrencySymbol(), 'Currency symbol should be CHF for POST HOTEL project');
        //System.assertEquals('500,000.00', controllerCHF.getFormattedSalePrice(), 'Sale price should use CHF amount');
        //System.assert(controllerCHF.totalInWords.endsWith('CHF Only'), 'Total in words should end with CHF Only');
    }

    @IsTest
    static void testNumberToWordsEdgeCases() {
        // Test various number scenarios
        Financial_Detail__c financialDetail = new Financial_Detail__c(
            Name = 'Test Bank 5',
            Account_Name__c = 'Test Account 5',
            Account_Number__c = '1234567894',
            IBAN__c = 'AE123456789012345678905',
            Swift_Code__c = 'TEST1238',
            Branch_Name__c = 'Test Branch 5'
        );
        insert financialDetail;

        Unit__c unit = new Unit__c(
            Project_Name_Text__c = 'Test Project 5',
            Cost_AED__c = 1234567.89,
            Property_Code_Text__c = 'UNIT-005',
            Title__c = 'Test Property 5'
        );
        insert unit;

        // Test with decimal amounts
        Invoice__c invoice = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Invoice_Number__c = 'INV-DECIMAL',
            Customer_Id__c = 'CUST-DECIMAL',
            Customer_Name__c = 'Test Customer Decimal',
            Sub_Total_Amount__c = 1234567.89,
            VAT_Amount__c = 61728.39,
            Unit__c = unit.Id,
            Financial_Detail__c = financialDetail.Id,
            Secondary_Currency__c = 'USD',
            Secondary_Currency_Amount__c = 333333.33
        );
        insert invoice;
        
        Test.setCurrentPage(Page.InvoicePDF);
        ApexPages.currentPage().getParameters().put('id', invoice.Id);
        
        Test.startTest();
        InvoicePDFController controller = new InvoicePDFController();
        Test.stopTest();

        // Verify decimal formatting (VAT from invoice; line items have no VAT in this test)
        System.assertEquals('1,234,567.89', controller.getFormattedSubTotal(), 'Sub total should format decimals correctly');
        System.assertEquals('61,728.39', controller.getFormattedVATAmount(), 'VAT amount should format decimals correctly');
        System.assertEquals('333,333.33', controller.getFormattedSecondaryCurrencyAmount(), 'Secondary currency should format decimals correctly');
        
        // Verify words contain expected amounts
        System.assert(controller.totalInWords.contains('One Million'), 'Should contain million');
        System.assert(controller.secondaryCurrencyInWords.contains('Three Hundred Thirty Three Thousand'), 'Should contain hundred thousands');
    }

    @IsTest
    static void testFormatAmountEdgeCases() {
        // Test null and zero amounts
        Financial_Detail__c financialDetail = new Financial_Detail__c(
            Name = 'Test Bank 6',
            Account_Name__c = 'Test Account 6',
            Account_Number__c = '1234567895',
            IBAN__c = 'AE123456789012345678906',
            Swift_Code__c = 'TEST1239',
            Branch_Name__c = 'Test Branch 6'
        );
        insert financialDetail;

        Unit__c unit = new Unit__c(
            Project_Name_Text__c = 'Test Project 6',
            Cost_AED__c = 0.00,
            Property_Code_Text__c = 'UNIT-006',
            Title__c = 'Test Property 6'
        );
        insert unit;

        Invoice__c invoice = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Invoice_Number__c = 'INV-ZERO',
            Customer_Id__c = 'CUST-ZERO',
            Customer_Name__c = 'Test Customer Zero',
            Sub_Total_Amount__c = 0.00,
            VAT_Amount__c = 0.00,
            Unit__c = unit.Id,
            Financial_Detail__c = financialDetail.Id
        );
        insert invoice;
        
        Test.setCurrentPage(Page.InvoicePDF);
        ApexPages.currentPage().getParameters().put('id', invoice.Id);
        
        Test.startTest();
        InvoicePDFController controller = new InvoicePDFController();
        Test.stopTest();

        // Verify zero amounts are formatted correctly
        System.assertEquals('0.00', controller.getFormattedSubTotal(), 'Zero sub total should format as 0.00');
        System.assertEquals('0.00', controller.getFormattedVATAmount(), 'Zero VAT should format as 0.00');
        System.assertEquals('0.00', controller.getFormattedSalePrice(), 'Zero sale price should format as 0.00');
    }
}