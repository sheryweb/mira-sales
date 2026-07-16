@isTest
private class PaymentPlanListingServiceTest {

    @TestSetup
    static void setupTestData() {
        // Create test project
        Project__c testProject = new Project__c(
            Name = 'Test Project',
            Publish_Project__c = 'Published',
            Coordinates_Latitude__c = 25.0,
            Coordinates_Longitude__c = 55.0,
            Handover__c = Date.today().addMonths(6)
        );
        insert testProject;

        // Create test unit
        Unit__c testUnit = new Unit__c(
            Title__c = 'Test Unit',
            Project__c = testProject.Id,
            Status__c = 'Draft'
        );
        insert testUnit;
        
        // Update status to Published after creation
        testUnit.Status__c = 'Published';
        update testUnit;

        // Create Cash_Flow_Sum__c record (required parent for Cash_Flow__c)
        Cash_Flow_Sum__c cashFlowSum = new Cash_Flow_Sum__c(
            Name = 'Test Cash Flow Sum',
            Unit__c = testUnit.Id
        );
        insert cashFlowSum;

        // Create test cash flow records
        List<Cash_Flow__c> cashFlows = new List<Cash_Flow__c>();
        
        // Create test cash flow records with basic fields
        // Note: Price_CHF__c and Price_Formula__c are formula fields and will be calculated automatically
        cashFlows.add(new Cash_Flow__c(
            Name = 'Booking Fee',
            Date__c = Date.today().addMonths(1),
            Unit__c = testUnit.Id,
            Installment_Milestone__c = 'Booking Fee',
            Percent__c = 10,
            Cash_Flow_Sum__c = cashFlowSum.Id
        ));

        cashFlows.add(new Cash_Flow__c(
            Name = '1st Installment',
            Date__c = Date.today().addMonths(3),
            Unit__c = testUnit.Id,
            Installment_Milestone__c = 'Construction - 20%',
            Percent__c = 20,
            Cash_Flow_Sum__c = cashFlowSum.Id
        ));

        cashFlows.add(new Cash_Flow__c(
            Name = '2nd Installment',
            Date__c = Date.today().addMonths(6),
            Unit__c = testUnit.Id,
            Installment_Milestone__c = 'Construction - 30%',
            Percent__c = 30,
            Cash_Flow_Sum__c = cashFlowSum.Id
        ));

        cashFlows.add(new Cash_Flow__c(
            Name = 'Final Payment',
            Date__c = Date.today().addMonths(12),
            Unit__c = testUnit.Id,
            Installment_Milestone__c = 'Handover',
            Percent__c = 40,
            Cash_Flow_Sum__c = cashFlowSum.Id
        ));

        insert cashFlows;
    }

    @isTest
    static void testGetPaymentPlanSuccess() {
        // Get test unit
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];
        
        // Set up REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/PaymentPlan/';
        req.addParameter('unitId', testUnit.Id);
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        // Call the service method
        Test.startTest();
        PaymentPlanListingService.PaymentPlanResponseWrapper response = PaymentPlanListingService.getPaymentPlan();
        Test.stopTest();

        // Assertions
        System.assertEquals(true, response.success, 'Response should be successful');
        System.assertEquals('Payment plan retrieved successfully', response.message);
        System.assertEquals(4, response.paymentPlanItems.size(), 'Should return 4 payment plan items');

        // Verify the items are ordered by date
        for (Integer i = 1; i < response.paymentPlanItems.size(); i++) {
            System.assert(response.paymentPlanItems[i-1].installmentDate <= response.paymentPlanItems[i].installmentDate, 
                         'Items should be ordered by date');
        }

        // Verify that all items have the expected fields populated
        for (PaymentPlanListingService.PaymentPlanItem item : response.paymentPlanItems) {
            System.assertNotEquals(null, item.installmentName, 'Installment name should not be null');
            System.assertNotEquals(null, item.installmentDate, 'Installment date should not be null');
            System.assertNotEquals(null, item.percentage, 'Percentage should not be null');
            // Amount will be calculated by formula fields, so we just verify it's not null
            System.assertNotEquals(null, item.amount, 'Amount should not be null');
        }
    }

    @isTest
    static void testGetPaymentPlanMissingUnitId() {
        // Set up REST context without unitId
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/PaymentPlan/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        // Call the service method
        Test.startTest();
        PaymentPlanListingService.PaymentPlanResponseWrapper response = PaymentPlanListingService.getPaymentPlan();
        Test.stopTest();

        // Assertions
        System.assertEquals(false, response.success, 'Response should fail');
        System.assertEquals('UnitId parameter is required', response.message);
        System.assertEquals(0, response.paymentPlanItems.size(), 'Should return empty list');
    }

    @isTest
    static void testGetPaymentPlanEmptyUnitId() {
        // Set up REST context with empty unitId
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/PaymentPlan/';
        req.addParameter('unitId', '');
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        // Call the service method
        Test.startTest();
        PaymentPlanListingService.PaymentPlanResponseWrapper response = PaymentPlanListingService.getPaymentPlan();
        Test.stopTest();

        // Assertions
        System.assertEquals(false, response.success, 'Response should fail');
        System.assertEquals('UnitId parameter is required', response.message);
        System.assertEquals(0, response.paymentPlanItems.size(), 'Should return empty list');
    }

    @isTest
    static void testGetPaymentPlanNoCashFlows() {
        // Create a unit without cash flows
        Project__c testProject = new Project__c(
            Name = 'Test Project 2',
            Publish_Project__c = 'Published',
            Coordinates_Latitude__c = 25.1,
            Coordinates_Longitude__c = 55.1,
            Handover__c = Date.today().addMonths(6)
        );
        insert testProject;

        Unit__c testUnit = new Unit__c(
            Title__c = 'Test Unit 2',
            Project__c = testProject.Id,
            Status__c = 'Draft'
        );
        insert testUnit;
        
        // Update status to Published after creation
        testUnit.Status__c = 'Published';
        update testUnit;

        // Set up REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/PaymentPlan/';
        req.addParameter('unitId', testUnit.Id);
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        // Call the service method
        Test.startTest();
        PaymentPlanListingService.PaymentPlanResponseWrapper response = PaymentPlanListingService.getPaymentPlan();
        Test.stopTest();

        // Assertions
        System.assertEquals(false, response.success, 'Response should fail');
        System.assertEquals('No payment plan found for the specified unit', response.message);
        System.assertEquals(0, response.paymentPlanItems.size(), 'Should return empty list');
    }

    @isTest
    static void testGetPaymentPlanInvalidUnitId() {
        // Set up REST context with invalid unitId
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/PaymentPlan/';
        req.addParameter('unitId', 'a01U900000000000AAA');
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        // Call the service method
        Test.startTest();
        PaymentPlanListingService.PaymentPlanResponseWrapper response = PaymentPlanListingService.getPaymentPlan();
        Test.stopTest();

        // Assertions
        System.assertEquals(false, response.success, 'Response should fail');
        System.assertEquals('No payment plan found for the specified unit', response.message);
        System.assertEquals(0, response.paymentPlanItems.size(), 'Should return empty list');
    }
}