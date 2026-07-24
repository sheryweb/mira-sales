@IsTest
private class InvoicePreviewControllerTest {
    @TestSetup
    static void setupTestData() {
        insert new Financial_Engine_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(), Engine_Owns_Totals__c = true);
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

        Invoice__c invoice = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Invoice_Number__c = 'INV-001',
            Customer_Id__c = 'CUST-001',
            Customer_Name__c = 'Test Customer',
            Sub_Total_Amount__c = 1000000.00,
            VAT_Amount__c = 50000.00,
            Unit__c = unit.Id,
            Financial_Detail__c = financialDetail.Id
        );
        insert invoice;

        // Create line items
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
    static void testGetFinancialDetail() {
        // Get the test financial detail
        Financial_Detail__c testFinancialDetail = [SELECT Id FROM Financial_Detail__c LIMIT 1];
        
        Test.startTest();
        Financial_Detail__c result = InvoicePreviewController.getFinancialDetail(testFinancialDetail.Id);
        Test.stopTest();

        // Verify the result
        System.assertNotEquals(null, result, 'Financial detail should not be null');
        System.assertEquals('Test Bank', result.Name, 'Bank name should match');
        System.assertEquals('Test Account', result.Account_Name__c, 'Account name should match');
        System.assertEquals('1234567890', result.Account_Number__c, 'Account number should match');
        System.assertEquals('AE123456789012345678901', result.IBAN__c, 'IBAN should match');
        System.assertEquals('TEST1234', result.Swift_Code__c, 'Swift code should match');
        System.assertEquals('Test Branch', result.Branch_Name__c, 'Branch name should match');
    }

    @IsTest
    static void testGetFinancialDetailWithInvalidId() {
        Test.startTest();
        Financial_Detail__c result = InvoicePreviewController.getFinancialDetail('001000000000000');
        Test.stopTest();

        // Verify the result is null for invalid ID
        System.assertEquals(null, result, 'Result should be null for invalid ID');
    }

    @IsTest
    static void testGetFinancialDetailWithNullId() {
        Test.startTest();
        Financial_Detail__c result = InvoicePreviewController.getFinancialDetail(null);
        Test.stopTest();

        // Verify the result is null for null ID
        System.assertEquals(null, result, 'Result should be null for null ID');
    }

    @IsTest
    static void testGetFinancialDetailWithException() {
        Test.startTest();
        Financial_Detail__c result = InvoicePreviewController.getFinancialDetail('invalid-id');
        Test.stopTest();

        // Verify the result is null for invalid ID format
        System.assertEquals(null, result, 'Result should be null for invalid ID format');
    }
}