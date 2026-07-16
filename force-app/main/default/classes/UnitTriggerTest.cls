@isTest
private class UnitTriggerTest {

    // Helper method to create test data
    private static List<Unit__c> createTestData() {
        List<Project__c> projects = new List<Project__c>();
        projects.add(new Project__c (
            Name = 'test project', 
            Description__c = 'description', 
            District__c = 'Meydan', 
            Coordinates_Latitude__c = 2, 
            Coordinates_Longitude__c = 1, 
            Handover__c = Date.today(), 
            Minimum_Cost__c = 2,
            Publish_Project__c = 'Draft',
            Project_Code__c = 'Test Code'
        ));
        insert projects;

        List<Unit__c> units = new List<Unit__c>();
        units.add(new Unit__c(
            Title__c = 'Test Unit',
            Cost_AED__c = 1000000,
            Cost_CHF__c = 250000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Additional_Area__c = 200,
            Floor__c = 5,
            Number_of_Bedrooms__c = 0,
            Number_of_Bathrooms__c = 2,
            Status__c = 'Draft',
            Building__c = 'Test Building',
            Panorama_Link__c = 'Test Link',
            Project__c = projects[0].Id
        ));
        units.add(new Unit__c(
            Title__c = 'Test Unit 2',
            Cost_AED__c = 1000000,
            Cost_CHF__c = 250000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Additional_Area__c = 200,
            Floor__c = 5,
            Number_of_Bedrooms__c = 1,
            Number_of_Bathrooms__c = 2,
            Status__c = 'Draft',
            Building__c = 'Test Building',
            Panorama_Link__c = 'Test Link',
            Project__c = projects[0].Id
        ));
        insert units;
        
        setupTestData(units, projects[0]);
        return units;
    }
    
    private static void setupTestData(List<Unit__c> units, Project__c project) {
        // Create and insert payment plans
        List<Payment_Plan__c> paymentPlans = new List<Payment_Plan__c>();
        paymentPlans.add(new Payment_Plan__c(Project__c = project.Id, Date__c = Date.today(), Percent__c = 50));
        paymentPlans.add(new Payment_Plan__c(Project__c = project.Id, Date__c = Date.today().addYears(1), Percent__c = 50));
        insert paymentPlans;

        // Create and insert additional payments
        List<Additional_Payment__c> additionalPlans = new List<Additional_Payment__c>();
        additionalPlans.add(new Additional_Payment__c(Project__c = project.Id, Percent__c = 25));
        additionalPlans.add(new Additional_Payment__c(Project__c = project.Id, Percent__c = 15));
        insert additionalPlans;
    }

    @isTest
    static void testHandleUnitsAfterUpdate() {
        List<Unit__c> units = createTestData();
        
        Test.startTest();
        units[0].Status__c = 'Draft';
        update units;
        Test.stopTest();

        // Verify no cash flows were created since cost fields didn't change
        List<Cash_Flow_Sum__c> cashFlowSums = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c = :units[0].Id];
        System.assertEquals(0, cashFlowSums.size(), 'No cash flow sums should be created when cost fields are not changed');

        List<Cash_Flow__c> cashFlows = [SELECT Id FROM Cash_Flow__c WHERE Unit__c = :units[0].Id];
        System.assertEquals(0, cashFlows.size(), 'No cash flows should be created when cost fields are not changed');
    }
    
    @isTest
    static void testHandleUnitsAfterCostUpdate() {
        List<Unit__c> units = createTestData();
        
        Test.startTest();
        // Update Cost_AED__c
        units[0].Cost_AED__c = 1500000;  // Change AED cost
        update units[0];
        
        // Verify cash flows were created for AED cost change
        List<Cash_Flow_Sum__c> cashFlowSumsAED = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c = :units[0].Id];
        System.assertEquals(2, cashFlowSumsAED.size(), 'Cash flow sums should be created when Cost_AED__c is changed');
        
        List<Cash_Flow__c> cashFlowsAED = [SELECT Id FROM Cash_Flow__c WHERE Unit__c = :units[0].Id];
        System.assertEquals(4, cashFlowsAED.size(), 'Cash flows should be created when Cost_AED__c is changed');
        
        // Delete existing cash flows for next test
        delete [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c = :units[0].Id];
        delete [SELECT Id FROM Cash_Flow__c WHERE Unit__c = :units[0].Id];
        
        // Update Cost_CHF__c
        units[0].Cost_CHF__c = 300000;  // Change CHF cost
        update units[0];
        
        // Verify cash flows were created for CHF cost change
        List<Cash_Flow_Sum__c> cashFlowSumsCHF = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c = :units[0].Id];
        System.assertEquals(2, cashFlowSumsCHF.size(), 'Cash flow sums should be created when Cost_CHF__c is changed');
        
        List<Cash_Flow__c> cashFlowsCHF = [SELECT Id FROM Cash_Flow__c WHERE Unit__c = :units[0].Id];
        System.assertEquals(4, cashFlowsCHF.size(), 'Cash flows should be created when Cost_CHF__c is changed');
        Test.stopTest();
    }
}