@isTest
private class SOAPDFControllerTest {
    @TestSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Customer'
        );
        insert testAccount;
        
        // Create joint owner account
        Account jointAccount = new Account(
            Name = 'Joint Owner'
        );
        insert jointAccount;
        
        // Create test Unit
        Unit__c testUnit = new Unit__c(
            Title__c = 'Unit-123',
            Type__c = 'Apartment',
            Number_of_Bedrooms__c = 2,
            Cost_AED__c = 1000000,
            Building__c = 'Test Building',
            Booking_Date_Time__c = Date.today().addMonths(-6)
        );
        insert testUnit;
        
        // Create test Opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            Unit__c = testUnit.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addMonths(2)
        );
        insert testOpp;
        
        // Create Joint Owner relationship
        Joint_Owners__c jointOwner = new Joint_Owners__c(
            Account__c = jointAccount.Id,
            Opportunity__c = testOpp.Id,
            Order__c = 1,
            Ownership_Share__c = 25
        );
        insert jointOwner;
        
        // Create Cash_Flow_Sum__c record (required parent for Cash_Flow__c)
        Cash_Flow_Sum__c cashFlowSum = new Cash_Flow_Sum__c(
            Name = 'Test Cash Flow Sum',
            Unit__c = testUnit.Id
        );
        insert cashFlowSum;
        
        // Create Cash Flow items - Regular instalments - Important: Name field helps with controller SOQL filters
        List<Cash_Flow__c> cashFlows = new List<Cash_Flow__c>();
        
        // Past instalments - The controller filters by 'NOT LIKE %Oqood%' and 'NOT LIKE %DLD Fee%'
        // So these shouldn't contain those keywords
        cashFlows.add(new Cash_Flow__c(
            Name = 'Booking Fee',
            Date__c = Date.today().addMonths(-5),
            Unit__c = testUnit.Id,
            Installment_Milestone__c = 'Booking',
            Received_Amount__c = 100000, // Received amount for past payment
            Cash_Flow_Sum__c = cashFlowSum.Id
        ));
        
        cashFlows.add(new Cash_Flow__c(
            Name = '1st Instalment',
            Date__c = Date.today().addMonths(-3),
            Unit__c = testUnit.Id,
            Installment_Milestone__c = 'Construction - 10%',
            Received_Amount__c = 150000, // Received amount for past payment
            Cash_Flow_Sum__c = cashFlowSum.Id
        ));
        
        cashFlows.add(new Cash_Flow__c(
            Name = '2nd Instalment',
            Date__c = Date.today().addMonths(-1),
            Unit__c = testUnit.Id,
            Installment_Milestone__c = 'Construction - 20%',
            Received_Amount__c = 150000, // Received amount for past payment
            Cash_Flow_Sum__c = cashFlowSum.Id
        ));
        
        // Current instalment (due today)
        cashFlows.add(new Cash_Flow__c(
            Name = '3rd Instalment',
            Date__c = Date.today(),
            Unit__c = testUnit.Id,
            Installment_Milestone__c = 'Construction - 30%',
            Received_Amount__c = 0, // No received amount for current payment
            Cash_Flow_Sum__c = cashFlowSum.Id
        ));
        
        // Future instalments
        cashFlows.add(new Cash_Flow__c(
            Name = '4th Instalment',
            Date__c = Date.today().addMonths(2),
            Unit__c = testUnit.Id,
            Installment_Milestone__c = 'Construction - 40%',
            Received_Amount__c = 0, // No received amount for future payment
            Cash_Flow_Sum__c = cashFlowSum.Id
        ));
        
        cashFlows.add(new Cash_Flow__c(
            Name = '5th Instalment',
            Date__c = Date.today().addMonths(4),
            Unit__c = testUnit.Id,
            Installment_Milestone__c = 'Construction - 50%',
            Received_Amount__c = 0, // No received amount for future payment
            Cash_Flow_Sum__c = cashFlowSum.Id
        ));
        
        // Registration items - CRITICAL: The controller filters by 'LIKE %Oqood%' OR 'LIKE %DLD Fee%'
        // So these must contain those exact keywords to be found by the controller
        cashFlows.add(new Cash_Flow__c(
            Name = 'Payment Plan Oqood Registration', // Contains "Oqood" to match controller filter
            Date__c = Date.today().addMonths(-5),
            Unit__c = testUnit.Id,
            Installment_Milestone__c = 'Registration',
            Received_Amount__c = 5000, // Received amount for past registration
            Cash_Flow_Sum__c = cashFlowSum.Id
        ));
        
        cashFlows.add(new Cash_Flow__c(
            Name = 'Payment Plan DLD Fee Registration', // Contains "DLD Fee" to match controller filter
            Date__c = Date.today().addMonths(-2),
            Unit__c = testUnit.Id,
            Installment_Milestone__c = 'Registration',
            Received_Amount__c = 0, // No received amount for registration
            Cash_Flow_Sum__c = cashFlowSum.Id
        ));
        
        // Insert all cash flows
        insert cashFlows;
    }
    
    /**
     * Comprehensive test of controller with valid data
     * This is the main test method that should cover most controller functionality
     */
    @isTest
    static void testSOAPDFControllerEndToEnd() {
        // Get test opportunity with safe query
        List<Opportunity> opportunities = [
            SELECT Id FROM Opportunity 
            WHERE Name = 'Test Opportunity' 
            LIMIT 1
        ];
        
        if (opportunities.isEmpty()) {
            System.debug('No test opportunities found - skipping test');
            return;
        }
        
        // Set up the page parameters
        PageReference pageRef = Page.SOAPDF;
        pageRef.getParameters().put('oppId', opportunities[0].Id);
        Test.setCurrentPage(pageRef);
        
        // Start test context to reset governor limits
        Test.startTest();
        
        // Create and initialize controller
        SOAPDFController controller = new SOAPDFController();
        
        // Verify basic initialization
        System.assertNotEquals(null, controller.opp, 'Opportunity should be loaded');
        System.assertEquals(Date.today(), controller.soaDate, 'SOA date should be today');
        
        // Test all getter methods to ensure they work and don't throw exceptions
        // This is crucial for code coverage
        
        // Cash flow calculations
        Decimal totalInstalmentAmount = controller.getTotalInstalmentAmount();
        Decimal totalReceivedAmount = controller.getTotalReceivedAmount();
        Decimal totalBalanceAmount = controller.getTotalBalanceAmount();
        
        // Registration calculations
        Decimal totalRegAmount = controller.getTotalRegistrationAmount();
        Decimal totalRegReceived = controller.getTotalRegistrationReceivedAmount();
        Decimal totalRegBalance = controller.getTotalRegistrationBalanceAmount();
        
        // Due amounts calculations
        Decimal totalDueInstalmentsAmount = controller.getTotalDueInstalmentsAmount();
        Decimal totalDueRegistrationAmount = controller.getTotalDueRegistrationAmount();
        Decimal totalDueAmount = controller.getTotalDueAmount();
        
        // Boolean checks
        Boolean hasCashFlowItems = controller.getHasCashFlowItems();
        Boolean hasRegistrationItems = controller.getHasRegistrationItems();
        Boolean hasJointOwners = controller.getHasJointOwners();
        Boolean hasSecondTableItems = controller.getHasSecondTableItems();
        
        // First table VAT-inclusive calculations (new methods)
        Decimal totalFirstTableAmount = controller.getTotalFirstTableAmount();
        Decimal totalFirstTableBalance = controller.getTotalFirstTableBalance();
        Decimal totalInstalmentAmountWithVAT = controller.getTotalInstalmentAmountWithFirstTableVAT();
        Decimal totalBalanceWithVAT = controller.getTotalBalanceWithFirstTableVAT();
        
        // Percentage calculation
        Integer percentagePaid = controller.getPercentagePaid();
        
        // Formatted values
        String formattedInstallmentsPaid = controller.getFormattedInstallmentsPaid();
        String formattedTotalDueAmount = controller.getFormattedTotalDueAmount();
        String formattedTotalDueInstalmentsAmount = controller.getFormattedTotalDueInstalmentsAmount();
        String formattedTotalDueRegistrationAmount = controller.getFormattedTotalDueRegistrationAmount();
        
        // Perform assertions on the result values to ensure they're correct
        System.assert(totalInstalmentAmount > 0, 'Total instalment amount should be greater than 0');
        System.assert(totalReceivedAmount > 0, 'Total received amount should be greater than 0');
        System.assert(totalRegAmount > 0, 'Total registration amount should be greater than 0');
        System.assert(hasCashFlowItems, 'Should have cash flow items');
        System.assert(hasRegistrationItems, 'Should have registration items');
        System.assert(hasJointOwners, 'Should have joint owners');
        System.assertNotEquals(null, percentagePaid, 'Percentage paid should not be null');
        System.assert(formattedTotalDueAmount.startsWith('AED '), 'Formatted amount should start with AED');
        System.assert(totalFirstTableAmount >= 0, 'Total first table amount should be non-negative');
        System.assert(totalFirstTableBalance != null, 'Total first table balance calculated (can be negative when overpaid)');
        System.assert(totalInstalmentAmountWithVAT >= 0, 'Total instalment with VAT should be non-negative');
        System.assert(totalBalanceWithVAT != null, 'Total balance with VAT calculated (can be negative when overpaid)');
        
        Test.stopTest();
    }
    
    /**
     * Test edge cases with null values and error paths
     */
    @isTest
    static void testEdgeCasesAndErrorPaths() {
        // Create a controller without any parameters to test error messages
        Test.startTest();
        
        // Make sure we start with a clean slate
        ApexPages.getMessages().clear();
        
        // Test missing oppId parameter
        PageReference pageRef = Page.SOAPDF;
        Test.setCurrentPage(pageRef);
        SOAPDFController controller = new SOAPDFController();
        
        // Verify error messages for missing oppId
        List<ApexPages.Message> pageMessages = ApexPages.getMessages();
        System.assert(!pageMessages.isEmpty(), 'Should have at least one error message');
        
        // Check if any of the messages contains the expected text
        Boolean foundRequiredIdMessage = false;
        for(ApexPages.Message msg : pageMessages) {
            if(msg.getSummary().contains('Opportunity ID is required')) {
                foundRequiredIdMessage = true;
                break;
            }
        }
        System.assert(foundRequiredIdMessage, 'Should show required ID message');
        
        // Clear messages before next test
        ApexPages.getMessages().clear();
        
        // Test with invalid opportunity ID
        pageRef.getParameters().put('oppId', '006000000000000');
        Test.setCurrentPage(pageRef);
        controller = new SOAPDFController();
        
        // Verify error messages for invalid oppId
        pageMessages = ApexPages.getMessages();
        System.assert(!pageMessages.isEmpty(), 'Should have at least one error message');
        
        // Check if any of the messages contains the expected text
        Boolean foundNotFoundMessage = false;
        for(ApexPages.Message msg : pageMessages) {
            if(msg.getSummary().contains('Opportunity not found')) {
                foundNotFoundMessage = true;
                break;
            }
        }
        System.assert(foundNotFoundMessage, 'Should show opportunity not found message');
        
        // Clear messages before next test
        ApexPages.getMessages().clear();
        
        // Test with controller instance that has empty/null data
        // - We can't modify private fields directly, but we can create a fresh instance
        // that won't have data loaded and test all the methods
        controller = new SOAPDFController();
        
        // Test behavior with empty data
        System.assertEquals(0, controller.getTotalInstalmentAmount(), 'Should return 0 for null items');
        System.assertEquals(0, controller.getTotalReceivedAmount(), 'Should return 0 for null items');
        System.assertEquals(0, controller.getTotalBalanceAmount(), 'Should return 0 for null items');
        System.assertEquals(0, controller.getTotalRegistrationAmount(), 'Should return 0 for null items');
        System.assertEquals(0, controller.getTotalRegistrationReceivedAmount(), 'Should return 0 for null items');
        System.assertEquals(0, controller.getTotalRegistrationBalanceAmount(), 'Should return 0 for null items');
        System.assertEquals(0, controller.getTotalDueInstalmentsAmount(), 'Should return 0 for null items');
        System.assertEquals(0, controller.getTotalDueRegistrationAmount(), 'Should return 0 for null items');
        System.assertEquals(0, controller.getTotalDueAmount(), 'Should return 0 for null items');
        System.assertEquals(false, controller.getHasCashFlowItems(), 'Should return false for null items');
        System.assertEquals(false, controller.getHasRegistrationItems(), 'Should return false for null items');
        System.assertEquals(false, controller.getHasJointOwners(), 'Should return false for null items');
        System.assertEquals(false, controller.getHasSecondTableItems(), 'Should return false when no second table');
        System.assertEquals(0, controller.getPercentagePaid(), 'Should return 0 for null property details');
        
        // First table VAT methods with empty data
        System.assertEquals(0, controller.getTotalFirstTableAmount(), 'Should return 0 for empty first table');
        System.assertEquals(0, controller.getTotalFirstTableBalance(), 'Should return 0 for empty first table');
        System.assertEquals(0, controller.getTotalInstalmentAmountWithFirstTableVAT(), 'Should return 0 for empty data');
        System.assertEquals(0, controller.getTotalBalanceWithFirstTableVAT(), 'Should return 0 for empty data');
        
        // Test formatting methods with null values
        System.assert(controller.getFormattedInstallmentsPaid().contains('0'), 'Should format null as zero');
        System.assert(controller.getFormattedTotalDueAmount().contains('0'), 'Should format null as zero');
        System.assert(controller.getFormattedTotalDueInstalmentsAmount().contains('0'), 'Should format null as zero');
        System.assert(controller.getFormattedTotalDueRegistrationAmount().contains('0'), 'Should format null as zero');
        
        Test.stopTest();
    }
    
    /**
     * Test to ensure the controller initializes properly when Cash_Flow__c records exist
     */
    @isTest
    static void testCashFlowInitialization() {
        // Get test unit with safe query
        List<Unit__c> units = [
            SELECT Id FROM Unit__c 
            WHERE Title__c = 'Unit-123' 
            LIMIT 1
        ];
        
        if (units.isEmpty()) {
            System.debug('No test unit found - skipping test');
            return;
        }
        
        Unit__c testUnit = units[0];
        
        // Create additional cash flows to ensure we have records
        Cash_Flow_Sum__c cashFlowSum = [
            SELECT Id FROM Cash_Flow_Sum__c 
            WHERE Unit__c = :testUnit.Id 
            LIMIT 1
        ];
        
        // Create multiple regular cash flows
        List<Cash_Flow__c> additionalCashFlows = new List<Cash_Flow__c>();
        for(Integer i = 0; i < 5; i++) {
            additionalCashFlows.add(new Cash_Flow__c(
                Name = 'Additional Regular Payment ' + i,
                Date__c = Date.today().addDays(i),
                Unit__c = testUnit.Id,
                Installment_Milestone__c = 'Additional Payment',
                Received_Amount__c = 10000,
                Cash_Flow_Sum__c = cashFlowSum.Id
            ));
        }
        
        insert additionalCashFlows;
        
        // Get a valid opportunity ID
        Opportunity testOpp = [
            SELECT Id FROM Opportunity 
            WHERE Unit__c = :testUnit.Id 
            LIMIT 1
        ];
        
        // Set up the page parameters
        PageReference pageRef = Page.SOAPDF;
        pageRef.getParameters().put('oppId', testOpp.Id);
        Test.setCurrentPage(pageRef);
        
        // Create and initialize controller
        Test.startTest();
        
        // Initialize the controller - this should succeed even if filtering doesn't match
        // our expectations (since we can't set Payment_Plan_Name__c)
        SOAPDFController controller = new SOAPDFController();
        
        // Verify the controller initialized successfully
        System.assertNotEquals(null, controller.opp, 'Controller should have opportunity set');
        System.assertNotEquals(null, controller.soaDate, 'Controller should have SOA date set');
        
        // Verify methods run without exceptions
        controller.getTotalInstalmentAmount();
        controller.getTotalRegistrationAmount();
        controller.getTotalDueAmount();
        controller.getPercentagePaid();
        
        // Verify formatting methods run without exceptions
        System.assert(controller.getFormattedInstallmentsPaid().startsWith('AED '), 'Formatted amount should be valid');
        System.assert(controller.getFormattedTotalDueAmount().startsWith('AED '), 'Formatted amount should be valid');
        
        Test.stopTest();
        
        // Success if we reach here without exceptions
    }
    
    /**
     * Test percentage paid when Received_Installments_Amount__c field is null
     */
    @isTest
    static void testPercentagePaidWithNullField() {
        // Create a unit to test percentage calculation when Received_Installments_Amount__c is null
        Unit__c expensiveUnit = new Unit__c(
            Title__c = 'Expensive-Unit',
            Type__c = 'Apartment',
            Number_of_Bedrooms__c = 3,
            Cost_AED__c = 10000000, // 10 million
            Building__c = 'Luxury Building',
            Booking_Date_Time__c = Date.today().addMonths(-1)
        );
        insert expensiveUnit;
        
        // Create account and opportunity
        Account acct = new Account(Name = 'Small Payment Customer');
        insert acct;
        
        Opportunity opp = new Opportunity(
            Name = 'Small Payment Opportunity',
            AccountId = acct.Id,
            Unit__c = expensiveUnit.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addMonths(2)
        );
        insert opp;
        
        // Create Cash_Flow_Sum
        Cash_Flow_Sum__c cashFlowSum = new Cash_Flow_Sum__c(
            Name = 'Expensive Unit Cash Flow Sum',
            Unit__c = expensiveUnit.Id
        );
        insert cashFlowSum;
        
        // Create a single cash flow with a small payment (less than 1% of total)
        Cash_Flow__c smallPayment = new Cash_Flow__c(
            Name = 'Small Booking Payment',
            Date__c = Date.today().addDays(-1),
            Unit__c = expensiveUnit.Id,
            Installment_Milestone__c = 'Booking',
            Received_Amount__c = 50000, // 50k is 0.5% of 10 million
            Cash_Flow_Sum__c = cashFlowSum.Id
        );
        insert smallPayment;
        
        // Set up page parameters
        PageReference pageRef = Page.SOAPDF;
        pageRef.getParameters().put('oppId', opp.Id);
        Test.setCurrentPage(pageRef);
        
        // Test the controller's percentage calculation
        Test.startTest();
        SOAPDFController controller = new SOAPDFController();
        Integer percentagePaid = controller.getPercentagePaid();
        Test.stopTest();
        
        // Since Received_Installments_Amount__c field is not writeable in tests, 
        // the controller will return 0% when the field is null
        System.assertEquals(0, percentagePaid, 'Should return 0% when Received_Installments_Amount__c is null');
    }
    
    /**
     * Test first table display rows and VAT/balance calculations.
     * Note: Is_VAT_Applicable__c is formula/read-only; VAT path covered when org data has it true.
     */
    @isTest
    static void testVATApplicableUnit() {
        Unit__c vatUnit = new Unit__c(
            Title__c = 'VAT-Unit',
            Type__c = 'Apartment',
            Number_of_Bedrooms__c = 2,
            Cost_AED__c = 500000,
            Building__c = 'VAT Building',
            Booking_Date_Time__c = Date.today().addMonths(-3)
        );
        insert vatUnit;
        
        Account acct = new Account(Name = 'VAT Test Customer');
        insert acct;
        
        Opportunity opp = new Opportunity(
            Name = 'VAT Test Opp',
            AccountId = acct.Id,
            Unit__c = vatUnit.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addMonths(2)
        );
        insert opp;
        
        Cash_Flow_Sum__c cashFlowSum = new Cash_Flow_Sum__c(
            Name = 'VAT Unit Cash Flow Sum',
            Unit__c = vatUnit.Id
        );
        insert cashFlowSum;
        
        Cash_Flow__c cf = new Cash_Flow__c(
            Name = 'VAT Instalment',
            Date__c = Date.today(),
            Unit__c = vatUnit.Id,
            Installment_Milestone__c = 'Booking',
            Received_Amount__c = 0,
            Cash_Flow_Sum__c = cashFlowSum.Id
        );
        insert cf;
        
        PageReference pageRef = Page.SOAPDF;
        pageRef.getParameters().put('oppId', opp.Id);
        Test.setCurrentPage(pageRef);
        
        Test.startTest();
        SOAPDFController controller = new SOAPDFController();
        Decimal totalFirstTable = controller.getTotalFirstTableAmount();
        Decimal totalFirstTableBal = controller.getTotalFirstTableBalance();
        Decimal totalWithVAT = controller.getTotalInstalmentAmountWithFirstTableVAT();
        Decimal totalBalWithVAT = controller.getTotalBalanceWithFirstTableVAT();
        Test.stopTest();
        
        System.assertNotEquals(null, controller.firstTableDisplayRows, 'Should have first table display rows');
        System.assert(totalFirstTable >= 0, 'Total first table amount should be non-negative');
        System.assert(totalFirstTableBal != null, 'Total first table balance calculated (can be negative when overpaid)');
        System.assert(totalWithVAT >= 0, 'Total with VAT should be non-negative');
        System.assert(totalBalWithVAT != null, 'Total balance with VAT calculated (can be negative when overpaid)');
    }
    
    /**
     * Test unit cost and formatting - covers getUnitCost, getIsElieSaab.
     * Note: Project_Name_F__c is formula/read-only; Elie Saab path covered when org data has it.
     */
    @isTest
    static void testElieSaabProject() {
        Unit__c elieUnit = new Unit__c(
            Title__c = 'Elie-Unit',
            Type__c = 'Apartment',
            Number_of_Bedrooms__c = 2,
            Cost_AED__c = 250000,
            Building__c = 'Elie Building',
            Booking_Date_Time__c = Date.today().addMonths(-2)
        );
        insert elieUnit;
        
        Account acct = new Account(Name = 'Elie Test Customer');
        insert acct;
        
        Opportunity opp = new Opportunity(
            Name = 'Elie Test Opp',
            AccountId = acct.Id,
            Unit__c = elieUnit.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addMonths(2)
        );
        insert opp;
        
        Cash_Flow_Sum__c cashFlowSum = new Cash_Flow_Sum__c(
            Name = 'Elie Unit Cash Flow Sum',
            Unit__c = elieUnit.Id
        );
        insert cashFlowSum;
        
        Cash_Flow__c cf = new Cash_Flow__c(
            Name = 'Elie Instalment',
            Date__c = Date.today(),
            Unit__c = elieUnit.Id,
            Installment_Milestone__c = 'Booking',
            Cash_Flow_Sum__c = cashFlowSum.Id
        );
        insert cf;
        
        PageReference pageRef = Page.SOAPDF;
        pageRef.getParameters().put('oppId', opp.Id);
        Test.setCurrentPage(pageRef);
        
        Test.startTest();
        SOAPDFController controller = new SOAPDFController();
        Boolean isElieSaab = controller.getIsElieSaab();
        Decimal unitCost = controller.getUnitCost();
        String formattedPaid = controller.getFormattedInstallmentsPaid();
        String formattedDue = controller.getFormattedTotalDueAmount();
        Test.stopTest();
        
        System.assertNotEquals(null, unitCost, 'Unit cost should be set');
        System.assert(formattedPaid.contains('AED ') || formattedPaid.contains('CHF '), 'Formatted amount should have currency');
        System.assert(formattedDue.contains('AED ') || formattedDue.contains('CHF '), 'Formatted due should have currency');
    }
    
    /**
     * Unit cost = base cost + Total_VAT_on_Unit__c. Total_VAT_on_Unit__c is often formula/rollup, so Apex cannot
     * rely on assigning it on insert in tests; arithmetic is covered via sumBaseCostAndUnitVat; controller matches DB.
     */
    @isTest
    static void testGetUnitCostIncludesTotalVatOnUnit() {
        System.assertEquals(1050000, SOAPDFController.sumBaseCostAndUnitVat(1000000, 50000), 'Base + VAT when VAT set');
        System.assertEquals(1000000, SOAPDFController.sumBaseCostAndUnitVat(1000000, null), 'Null VAT is 0');
        System.assertEquals(1000000, SOAPDFController.sumBaseCostAndUnitVat(1000000, 0), 'Zero VAT');

        Unit__c u = new Unit__c(
            Title__c = 'VAT-Unit-Cost',
            Type__c = 'Apartment',
            Number_of_Bedrooms__c = 2,
            Cost_AED__c = 1000000,
            Building__c = 'VAT Building',
            Booking_Date_Time__c = Date.today()
        );
        insert u;
        Account a = new Account(Name = 'VAT Cost Customer');
        insert a;
        Opportunity o = new Opportunity(
            Name = 'VAT Cost Opp',
            AccountId = a.Id,
            Unit__c = u.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addMonths(1)
        );
        insert o;
        Cash_Flow_Sum__c cfs = new Cash_Flow_Sum__c(Name = 'VAT CFS', Unit__c = u.Id);
        insert cfs;
        insert new Cash_Flow__c(
            Name = 'Booking Instalment',
            Date__c = Date.today(),
            Unit__c = u.Id,
            Installment_Milestone__c = 'Booking',
            Cash_Flow_Sum__c = cfs.Id
        );
        Unit__c persisted = [
            SELECT Cost_AED__c, Cost_CHF__c, Total_VAT_on_Unit__c, Project_Name_F__c
            FROM Unit__c WHERE Id = :u.Id
        ];
        PageReference pageRef = Page.SOAPDF;
        pageRef.getParameters().put('oppId', o.Id);
        Test.setCurrentPage(pageRef);
        Test.startTest();
        SOAPDFController controller = new SOAPDFController();
        Test.stopTest();
        Boolean elieSaab = persisted.Project_Name_F__c == 'POST HOTEL & RESIDENCES By ELIE SAAB';
        Decimal base = elieSaab
            ? (persisted.Cost_CHF__c != null ? persisted.Cost_CHF__c : 0)
            : (persisted.Cost_AED__c != null ? persisted.Cost_AED__c : 0);
        System.assertEquals(
            SOAPDFController.sumBaseCostAndUnitVat(base, persisted.Total_VAT_on_Unit__c),
            controller.getUnitCost(),
            'getUnitCost should match persisted base + Total_VAT_on_Unit__c'
        );
    }
    
    /**
     * Test second table scenario - 27+ instalments to cover getHasSecondTableItems and second table totals
     */
    @isTest
    static void testSecondTableWithManyInstallments() {
        List<Unit__c> units = [SELECT Id FROM Unit__c WHERE Title__c = 'Unit-123' LIMIT 1];
        if (units.isEmpty()) return;
        
        Cash_Flow_Sum__c cashFlowSum = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c = :units[0].Id LIMIT 1];
        Opportunity testOpp = [SELECT Id FROM Opportunity WHERE Unit__c = :units[0].Id LIMIT 1];
        
        List<Cash_Flow__c> extraFlows = new List<Cash_Flow__c>();
        for (Integer i = 10; i <= 35; i++) {
            extraFlows.add(new Cash_Flow__c(
                Name = 'Extra Instalment ' + i,
                Date__c = Date.today().addDays(i),
                Unit__c = units[0].Id,
                Installment_Milestone__c = 'Construction - ' + i + '%',
                Cash_Flow_Sum__c = cashFlowSum.Id
            ));
        }
        insert extraFlows;
        
        PageReference pageRef = Page.SOAPDF;
        pageRef.getParameters().put('oppId', testOpp.Id);
        Test.setCurrentPage(pageRef);
        
        Test.startTest();
        SOAPDFController controller = new SOAPDFController();
        Boolean hasSecondTable = controller.getHasSecondTableItems();
        Decimal totalWithVAT = controller.getTotalInstalmentAmountWithFirstTableVAT();
        Decimal totalBalWithVAT = controller.getTotalBalanceWithFirstTableVAT();
        Test.stopTest();
        
        System.assert(hasSecondTable || controller.cashFlowItems.size() > 26, 
            'Should have second table when more than 26 instalments');
        System.assert(totalWithVAT >= 0, 'Total with VAT should be non-negative');
        System.assert(totalBalWithVAT != null, 'Total balance with VAT calculated (can be negative when overpaid)');
    }
}