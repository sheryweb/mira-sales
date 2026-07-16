@isTest
private class PlanCollectorTriggerHandlerTest {
    @TestSetup
    static void setupTestData() {
        // Create test Project
        Project__c project = new Project__c(
            Name = 'test project', 
            Description__c = 'description', 
            District__c = 'Meydan', 
            Coordinates_Latitude__c = 2, 
            Coordinates_Longitude__c = 1, 
            Handover__c = Date.today(), 
            Minimum_Cost__c = 2,
            Publish_Project__c = 'Draft'
        );
        insert project;

        // Create test Payment Plans Collector
        Payment_Plans_Collector__c collector = new Payment_Plans_Collector__c(
            Name = 'Test Collector',
            Status__c = 'Draft',
            Project__c = project.Id
        );
        insert collector;
        
        // Create test Unit
        Unit__c unit = new Unit__c(
            Status__c = 'Draft',
            Project__c = project.Id,
            Payment_Plans_Collector__c = collector.Id
        );
        insert unit;
        
        // Create test Payment Plans
        List<Payment_Plan__c> paymentPlans = new List<Payment_Plan__c>();
        Date startDate = Date.today();
        
        // Create payment plans for different years to test year grouping
        paymentPlans.add(new Payment_Plan__c(
            Name = 'Payment 1',
            Date__c = startDate,
            Percent__c = 20,
            Project__c = project.Id,
            Payment_Plans_Collector__c = collector.Id
        ));
        
        paymentPlans.add(new Payment_Plan__c(
            Name = 'Payment 2',
            Date__c = startDate.addYears(1),
            Percent__c = 30,
            Project__c = project.Id,
            Payment_Plans_Collector__c = collector.Id
        ));
        
        insert paymentPlans;
        
        // Create test Additional Payment
        Additional_Payment__c additionalPayment = new Additional_Payment__c(
            Name = 'Additional Payment 1',
            Percent__c = 10,
            Constant__c = 1000,
            Project__c = project.Id,
            Payment_Plans_Collector__c = collector.Id
        );
        insert additionalPayment;
        
        // Create existing Cash Flow Sum to test deletion
        Cash_Flow_Sum__c existingCashFlowSum = new Cash_Flow_Sum__c(
            Name = String.valueOf(startDate.year()),
            Unit__c = unit.Id
        );
        insert existingCashFlowSum;
    }
    
    @isTest
    static void testHandlePlanCollectorAfterUpdate() {
        // Get the test data
        Payment_Plans_Collector__c collector = [SELECT Id, Status__c FROM Payment_Plans_Collector__c WHERE Name = 'Test Collector' LIMIT 1];
        
        // Start the test
        Test.startTest();
        
        // Update collector to Published
        collector.Status__c = 'Published';
        update collector;
        
        // Stop the test
        Test.stopTest();
        
        // Verify results
        
        // 1. Verify old Cash Flow Sums were deleted
        List<Cash_Flow_Sum__c> oldCashFlowSums = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c IN (SELECT Id FROM Unit__c WHERE Payment_Plans_Collector__c = :collector.Id)];
        System.assertEquals(2, oldCashFlowSums.size(), 'Should have created new Cash Flow Sums for each year');
        
        // 2. Verify new Cash Flow Sums were created
        List<Cash_Flow_Sum__c> newCashFlowSums = [SELECT Id, Name FROM Cash_Flow_Sum__c WHERE Unit__c IN (SELECT Id FROM Unit__c WHERE Payment_Plans_Collector__c = :collector.Id)];
        System.assertEquals(2, newCashFlowSums.size(), 'Should have created Cash Flow Sums for each year');
    }
    
    @isTest
    static void testHandlePlanCollectorNoChangeInStatus() {
        // Get the test data
        Payment_Plans_Collector__c collector = [SELECT Id, Status__c FROM Payment_Plans_Collector__c WHERE Name = 'Test Collector' LIMIT 1];
        
        // Start the test
        Test.startTest();
        
        // Update collector without changing status
        collector.Name = 'Updated Name';
        update collector;
        
        // Stop the test
        Test.stopTest();
        
        // Verify no new Cash Flow Sums were created
        List<Cash_Flow_Sum__c> cashFlowSums = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c IN (SELECT Id FROM Unit__c WHERE Payment_Plans_Collector__c = :collector.Id)];
        System.assertEquals(1, cashFlowSums.size(), 'Should not have created new Cash Flow Sums');
    }
    
    @isTest
    static void testHandlePlanCollectorWithNoUnits() {
        // Create a new project for this test
        Project__c project = new Project__c(
            Name = 'test project 2', 
            Description__c = 'description', 
            District__c = 'Meydan', 
            Coordinates_Latitude__c = 2, 
            Coordinates_Longitude__c = 1, 
            Handover__c = Date.today(), 
            Minimum_Cost__c = 2,
            Publish_Project__c = 'Draft'
        );
        insert project;

        // Create a new collector without any units
        Payment_Plans_Collector__c collector = new Payment_Plans_Collector__c(
            Name = 'Collector Without Units',
            Status__c = 'Draft',
            Project__c = project.Id
        );
        insert collector;
        
        // Create payment plan
        Payment_Plan__c paymentPlan = new Payment_Plan__c(
            Name = 'Payment 1',
            Date__c = Date.today(),
            Percent__c = 20,
            Project__c = project.Id,
            Payment_Plans_Collector__c = collector.Id
        );
        insert paymentPlan;
        
        // Start the test
        Test.startTest();
        
        // Update to Published
        collector.Status__c = 'Published';
        update collector;
        
        // Stop the test
        Test.stopTest();
        
        // Verify no Cash Flow Sums were created
        List<Cash_Flow_Sum__c> cashFlowSums = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c IN (SELECT Id FROM Unit__c WHERE Payment_Plans_Collector__c = :collector.Id)];
        System.assertEquals(0, cashFlowSums.size(), 'Should not have created any Cash Flow Sums');
    }
}