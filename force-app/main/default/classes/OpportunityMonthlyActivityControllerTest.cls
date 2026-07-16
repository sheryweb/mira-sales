@isTest
private class OpportunityMonthlyActivityControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test units first
        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 1; i <= 30; i++) {
            units.add(new Unit__c(
                Title__c = 'Test Unit ' + i,
                Cost_AED__c = 10000 + (i * 1000),
                Status__c = 'Draft'
            ));
        }
        insert units;
        
        // Create test opportunities for current year (with proper stage names and dates)
        List<Opportunity> opportunities = new List<Opportunity>();
        Integer unitIndex = 0;
        
        // Create Booked opportunities for each month of current year
        for (Integer month = 1; month <= 12; month++) {
            opportunities.add(new Opportunity(
                Name = 'Test Booked Opportunity ' + month,
                StageName = 'Booked',
                CloseDate = Date.today().addMonths(month),
                Booking_Date_Time__c = DateTime.newInstance(Date.today().year(), month, 15, 10, 0, 0),
                Unit__c = units[unitIndex].Id
            ));
            unitIndex++;
        }
        
        // Create Sold opportunities for each month of current year
        for (Integer month = 1; month <= 12; month++) {
            opportunities.add(new Opportunity(
                Name = 'Test Sold Opportunity ' + month,
                StageName = 'Sold',
                CloseDate = Date.today().addMonths(month),
                Booking_Date_Time__c = DateTime.newInstance(Date.today().year(), month, 20, 10, 0, 0),
                Unit__c = units[unitIndex].Id
            ));
            unitIndex++;
        }
        
        // Create Booked opportunities for previous year (first 6 months only)
        for (Integer month = 1; month <= 6; month++) {
            opportunities.add(new Opportunity(
                Name = 'Test Previous Year Opportunity ' + month,
                StageName = 'Booked',
                CloseDate = Date.newInstance(Date.today().year() - 1, month, 15),
                Booking_Date_Time__c = DateTime.newInstance(Date.today().year() - 1, month, 15, 10, 0, 0),
                Unit__c = units[unitIndex].Id
            ));
            unitIndex++;
        }
        
        insert opportunities;
        
        // Create test monthly activity records linked to opportunities
        List<Opportunity_Monthly_Activity__c> activities = new List<Opportunity_Monthly_Activity__c>();
        
        // Create activities for current year
        Integer oppIndex = 0;
        for (Integer month = 1; month <= 12; month++) {
            // Booked activities
            activities.add(new Opportunity_Monthly_Activity__c(
                Activity_Type__c = 'Booked',
                Activity_Date__c = Date.newInstance(Date.today().year(), month, 15),
                Opportunity__c = opportunities[oppIndex].Id
            ));
            oppIndex++;
            
            // Sold activities
            activities.add(new Opportunity_Monthly_Activity__c(
                Activity_Type__c = 'Sold',
                Activity_Date__c = Date.newInstance(Date.today().year(), month, 20),
                Opportunity__c = opportunities[oppIndex].Id
            ));
            oppIndex++;
        }
        
        // Create activities for previous year (first 6 months)
        for (Integer month = 1; month <= 6; month++) {
            activities.add(new Opportunity_Monthly_Activity__c(
                Activity_Type__c = 'Booked',
                Activity_Date__c = Date.newInstance(Date.today().year() - 1, month, 15),
                Opportunity__c = opportunities[oppIndex].Id
            ));
            oppIndex++;
        }
        
        insert activities;
    }
    
    @isTest
    static void testGetMonthlyActivityDataCurrentYear() {
        Test.startTest();
        List<OpportunityMonthlyActivityController.MonthlyActivityData> result = 
            OpportunityMonthlyActivityController.getMonthlyActivityData(Date.today().year());
        Test.stopTest();
        
        System.assertEquals(12, result.size(), 'Should return 12 months of data');
        
        // Check that we have data for each month
        for (OpportunityMonthlyActivityController.MonthlyActivityData monthData : result) {
            System.assertNotEquals(null, monthData.monthName, 'Month name should not be null');
            System.assert(monthData.totalCount > 0, 'Should have total count for each month');
            // Values are set to 0 since we're not using value fields
        }
    }
    
    @isTest
    static void testGetMonthlyActivityDataPreviousYear() {
        Test.startTest();
        List<OpportunityMonthlyActivityController.MonthlyActivityData> result = 
            OpportunityMonthlyActivityController.getMonthlyActivityData(Date.today().year() - 1);
        Test.stopTest();
        
        System.assertEquals(12, result.size(), 'Should return 12 months of data');
        
        // Check that we have data for first 6 months only
        for (Integer i = 0; i < 6; i++) {
            System.assert(result[i].totalCount > 0, 'Should have total count for first 6 months');
        }
        
        // Check that last 6 months have no data
        for (Integer i = 6; i < 12; i++) {
            System.assertEquals(0, result[i].totalCount, 'Should have no total count for last 6 months');
        }
    }
    
    @isTest
    static void testGetMonthlyActivityDataNullYear() {
        Test.startTest();
        List<OpportunityMonthlyActivityController.MonthlyActivityData> result = 
            OpportunityMonthlyActivityController.getMonthlyActivityData(null);
        Test.stopTest();
        
        System.assertEquals(12, result.size(), 'Should return 12 months of data for current year');
    }
    
    @isTest
    static void testGetAvailableYears() {
        Test.startTest();
        List<Integer> years = OpportunityMonthlyActivityController.getAvailableYears();
        Test.stopTest();
        
        System.assert(years.size() >= 1, 'Should return at least one year');
        System.assert(years.contains(Date.today().year()), 'Should contain current year');
        System.assert(years.contains(Date.today().year() - 1), 'Should contain previous year');
    }
    
    @isTest
    static void testGetAvailableYearsNoData() {
        // Delete all activities
        delete [SELECT Id FROM Opportunity_Monthly_Activity__c];
        
        Test.startTest();
        List<Integer> years = OpportunityMonthlyActivityController.getAvailableYears();
        Test.stopTest();
        
        System.assertEquals(1, years.size(), 'Should return current year when no data exists');
        System.assertEquals(Date.today().year(), years[0], 'Should return current year');
    }
    
    @isTest
    static void testMonthlyActivityDataClass() {
        OpportunityMonthlyActivityController.MonthlyActivityData data = 
            new OpportunityMonthlyActivityController.MonthlyActivityData(6, 2024);
        
        System.assertEquals(6, data.month, 'Month should be 6');
        System.assertEquals(2024, data.year, 'Year should be 2024');
        System.assertEquals('Jun', data.monthName, 'Month name should be Jun');
        System.assertEquals(0, data.bookedCount, 'Initial booked count should be 0');
        System.assertEquals(0, data.soldCount, 'Initial sold count should be 0');
        
        // Test calculateTotals
        data.bookedCount = 5;
        data.bookedValue = 100000;
        data.soldCount = 3;
        data.soldValue = 150000;
        data.calculateTotals();
        
        System.assertEquals(8, data.totalCount, 'Total count should be 8');
        System.assertEquals(250000, data.totalValue, 'Total value should be 250000');
    }
}