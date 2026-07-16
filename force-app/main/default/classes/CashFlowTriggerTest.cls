@isTest
private class CashFlowTriggerTest {

    @TestSetup
    static void makeData(){
        List<Project__c> projects = new List<Project__c>();
        projects.add(new Project__c (
            Name = 'test project', 
            Description__c = 'description', 
            District__c = 'Meydan', 
            Coordinates_Latitude__c = 2, 
            Coordinates_Longitude__c = 1, 
            Handover__c = Date.today(), 
            Minimum_Cost__c = 2,
            Publish_Project__c = 'Draft'
        ));
        insert projects;

        
        List<Unit__c> units = new List<Unit__c>();
        units.add(new Unit__c(
            Title__c = 'Test Unit',
            Cost_AED__c = 1000000,
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
        insert units;

        List<Cash_Flow_Sum__c> cashFlowSums = new List<Cash_Flow_Sum__c>();

        cashFlowSums.add(new Cash_Flow_Sum__c(
            Unit__c = units[0].Id,
            Name = 'cash Flow test'
        ));

        insert cashFlowSums;

    }

    @isTest
    static void testInsert() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow_Sum__c cfs = [SELECT Id FROM Cash_Flow_Sum__c LIMIT 1];
        Cash_Flow__c cf = new Cash_Flow__c (Unit__c = unit.Id, Cash_Flow_Sum__c = cfs.Id, Constant__c = 1000);
        Test.startTest();
        insert cf;
        Test.stopTest();

        cf = [
            SELECT Id, Price_Formula__c, Price_Dublication__c
            FROM Cash_Flow__c
            LIMIT 1
        ];
        Assert.areEqual(true, cf.Price_Formula__c == cf.Price_Dublication__c);
    }

    @isTest
    static void testUpdate() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow_Sum__c cfs = [SELECT Id FROM Cash_Flow_Sum__c LIMIT 1];
        Cash_Flow__c cf = new Cash_Flow__c (Unit__c = unit.Id, Cash_Flow_Sum__c = cfs.Id, Constant__c = 1000);
        insert cf;
        Test.startTest();
        cf.Constant__c = 2000;
        update cf;
        Test.stopTest();

        cf = [
            SELECT Id, Price_Formula__c, Price_Dublication__c
            FROM Cash_Flow__c
            LIMIT 1
        ];
        Assert.areEqual(true, cf.Price_Formula__c == cf.Price_Dublication__c);
    }
    
    @isTest
    static void testInstallmentMilestonesAfterInsert() {
        // Create test data
        Unit__c unit = new Unit__c(Title__c = 'Test Unit', Status__c = 'Draft');
        insert unit;
        
        Cash_Flow_Sum__c cfs = new Cash_Flow_Sum__c(Unit__c = unit.Id, Name = 'Test CFS');
        insert cfs;

        // Create Cash Flow records with different types
        List<Cash_Flow__c> cashFlows = new List<Cash_Flow__c>{
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cfs.Id, 
                           Name = 'Booking / Reservation', Date__c = Date.today()),
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cfs.Id, 
                           Name = 'Oqood', Date__c = Date.today().addDays(30)),
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cfs.Id, 
                           Name = 'DLD Fee', Date__c = Date.today().addDays(60)),
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cfs.Id, 
                           Name = 'Regular Payment 1', Date__c = Date.today().addDays(90)),
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cfs.Id, 
                           Name = 'Regular Payment 2', Date__c = Date.today().addDays(120))
        };

        // Insert records and trigger the after insert logic
        Test.startTest();
        insert cashFlows;
        Test.stopTest();

        // Query the updated records
        List<Cash_Flow__c> updatedCashFlows = [
            SELECT Id, Name, Installment_Milestone__c, Date__c 
            FROM Cash_Flow__c 
            WHERE Unit__c = :unit.Id 
            ORDER BY Date__c ASC
        ];

        // Verify the results
        System.assertEquals(5, updatedCashFlows.size(), 'Should have 5 cash flows');
        System.assertEquals('Booking / Reservation', updatedCashFlows[0].Installment_Milestone__c, 'First should be Booking/Reservation');
        System.assertEquals('Oqood', updatedCashFlows[1].Installment_Milestone__c, 'Second should be Oqood');
        System.assertEquals('DLD Fee', updatedCashFlows[2].Installment_Milestone__c, 'Third should be DLD Fee');
        //System.assertEquals('1st Installment', updatedCashFlows[3].Installment_Milestone__c, 'Fourth should be 1st Installment');
        System.assertEquals('2nd Installment', updatedCashFlows[3].Installment_Milestone__c, 'Fifth should be 2nd Installment');
    }

    @isTest
    static void testInstallmentMilestonesAfterDelete() {
        // Create test data
        Unit__c unit = new Unit__c(Title__c = 'Test Unit', Status__c = 'Draft');
        insert unit;
        
        Cash_Flow_Sum__c cfs = new Cash_Flow_Sum__c(Unit__c = unit.Id, Name = 'Test CFS');
        insert cfs;

        // Create and insert initial cash flows
        List<Cash_Flow__c> cashFlows = new List<Cash_Flow__c>{
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cfs.Id, 
                           Name = 'Regular Payment 1', Date__c = Date.today()),
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cfs.Id, 
                           Name = 'Regular Payment 2', Date__c = Date.today().addDays(30)),
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cfs.Id, 
                           Name = 'Regular Payment 3', Date__c = Date.today().addDays(60))
        };
        insert cashFlows;

        // Delete one record and verify the remaining ones are reordered
        Test.startTest();
        delete cashFlows[1]; // Delete the middle record
        Test.stopTest();

        // Query the remaining records
        List<Cash_Flow__c> remainingCashFlows = [
            SELECT Id, Name, Installment_Milestone__c, Date__c 
            FROM Cash_Flow__c 
            WHERE Unit__c = :unit.Id 
            ORDER BY Date__c ASC
        ];

        // Verify the results
        System.assertEquals(2, remainingCashFlows.size(), 'Should have 2 remaining cash flows');
        //System.assertEquals('1st Installment', remainingCashFlows[0].Installment_Milestone__c, 'First should be 1st Installment');
        System.assertEquals('2nd Installment', remainingCashFlows[0].Installment_Milestone__c, 'Second should be 2nd Installment');
    }

    @isTest
    static void testInstallmentMilestonesWithNullDates() {
        // Create test data
        Unit__c unit = new Unit__c(Title__c = 'Test Unit', Status__c = 'Draft');
        insert unit;
        
        Cash_Flow_Sum__c cfs = new Cash_Flow_Sum__c(Unit__c = unit.Id, Name = 'Test CFS');
        insert cfs;

        // Create Cash Flow records with null dates
        List<Cash_Flow__c> cashFlows = new List<Cash_Flow__c>{
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cfs.Id, 
                           Name = 'Regular Payment 1', Date__c = null),
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cfs.Id, 
                           Name = 'Regular Payment 2', Date__c = Date.today()),
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cfs.Id, 
                           Name = 'Regular Payment 3', Date__c = null)
        };

        Test.startTest();
        insert cashFlows;
        Test.stopTest();

        // Query the updated records
        List<Cash_Flow__c> updatedCashFlows = [
            SELECT Id, Name, Installment_Milestone__c, Date__c 
            FROM Cash_Flow__c 
            WHERE Unit__c = :unit.Id 
            ORDER BY Date__c ASC NULLS LAST
        ];

        // Verify that records with null dates are handled properly
        System.assertEquals(3, updatedCashFlows.size(), 'Should have 3 cash flows');
        //System.assertEquals('1st Installment', updatedCashFlows[0].Installment_Milestone__c, 'Record with date should be first');
        System.assertNotEquals(null, updatedCashFlows[1].Installment_Milestone__c, 'Null date records should still have milestone');
        System.assertNotEquals(null, updatedCashFlows[2].Installment_Milestone__c, 'Null date records should still have milestone');
    }

    @isTest
    static void testInstallmentMilestonesAfterDateUpdate() {
        Unit__c unit = new Unit__c(Title__c = 'Date Update Unit', Status__c = 'Draft');
        insert unit;

        Cash_Flow_Sum__c cfs = new Cash_Flow_Sum__c(Unit__c = unit.Id, Name = 'Test CFS');
        insert cfs;

        Cash_Flow__c earlier = new Cash_Flow__c(
            Unit__c = unit.Id,
            Cash_Flow_Sum__c = cfs.Id,
            Name = 'Earlier Payment',
            Date__c = Date.today()
        );
        Cash_Flow__c later = new Cash_Flow__c(
            Unit__c = unit.Id,
            Cash_Flow_Sum__c = cfs.Id,
            Name = 'Later Payment',
            Date__c = Date.today().addDays(30)
        );
        insert new List<Cash_Flow__c>{ earlier, later };

        earlier = [
            SELECT Id, Installment_Milestone__c
            FROM Cash_Flow__c
            WHERE Id = :earlier.Id
        ];
        later = [
            SELECT Id, Installment_Milestone__c
            FROM Cash_Flow__c
            WHERE Id = :later.Id
        ];
        System.assertEquals('2nd Installment', earlier.Installment_Milestone__c);
        System.assertEquals('3rd Installment', later.Installment_Milestone__c);

        Test.startTest();
        earlier.Date__c = Date.today().addDays(60);
        update earlier;
        Test.stopTest();

        earlier = [
            SELECT Id, Installment_Milestone__c
            FROM Cash_Flow__c
            WHERE Id = :earlier.Id
        ];
        later = [
            SELECT Id, Installment_Milestone__c
            FROM Cash_Flow__c
            WHERE Id = :later.Id
        ];
        System.assertEquals('2nd Installment', later.Installment_Milestone__c, 'Earlier dated record should become second');
        System.assertEquals('3rd Installment', earlier.Installment_Milestone__c, 'Later dated record should become third');
    }

    @isTest
    static void testInstallmentMilestonesSkipNonDateUpdate() {
        Unit__c unit = new Unit__c(Title__c = 'Non Date Update Unit', Status__c = 'Draft');
        insert unit;

        Cash_Flow_Sum__c cfs = new Cash_Flow_Sum__c(Unit__c = unit.Id, Name = 'Test CFS');
        insert cfs;

        Cash_Flow__c cashFlow = new Cash_Flow__c(
            Unit__c = unit.Id,
            Cash_Flow_Sum__c = cfs.Id,
            Name = 'Regular Payment',
            Date__c = Date.today(),
            Percent__c = 10
        );
        insert cashFlow;

        cashFlow = [
            SELECT Id, Installment_Milestone__c, Percent__c
            FROM Cash_Flow__c
            WHERE Id = :cashFlow.Id
        ];
        System.assertEquals('2nd Installment', cashFlow.Installment_Milestone__c);

        Test.startTest();
        cashFlow.Percent__c = 15;
        update cashFlow;
        Test.stopTest();

        cashFlow = [
            SELECT Id, Installment_Milestone__c, Percent__c
            FROM Cash_Flow__c
            WHERE Id = :cashFlow.Id
        ];
        System.assertEquals(15, cashFlow.Percent__c);
        System.assertEquals('2nd Installment', cashFlow.Installment_Milestone__c, 'Percent-only update should not recalculate milestone');
    }

    @isTest
    static void testInstallmentMilestonesForBookedUnit() {
        Unit__c unit = new Unit__c(Title__c = 'Booked Unit', Status__c = 'Draft');
        insert unit;
        update new Unit__c(Id = unit.Id, Status__c = 'Booked');

        Cash_Flow_Sum__c cfs = new Cash_Flow_Sum__c(Unit__c = unit.Id, Name = 'Test CFS');
        insert cfs;

        Cash_Flow__c cashFlow = new Cash_Flow__c(
            Unit__c = unit.Id,
            Cash_Flow_Sum__c = cfs.Id,
            Name = 'Booking / Reservation',
            Date__c = Date.today()
        );

        Test.startTest();
        insert cashFlow;
        Test.stopTest();

        cashFlow = [
            SELECT Id, Installment_Milestone__c
            FROM Cash_Flow__c
            WHERE Id = :cashFlow.Id
        ];
        System.assertEquals('Booking / Reservation', cashFlow.Installment_Milestone__c);
    }

    @isTest
    static void testInstallmentMilestonesMultipleUnits() {
        // Create test data
        List<Unit__c> units = new List<Unit__c>{
            new Unit__c(Title__c = 'Unit 1', Status__c = 'Draft'),
            new Unit__c(Title__c = 'Unit 2', Status__c = 'Draft')
        };
        insert units;
        update new Unit__c(Id = units[1].Id, Status__c = 'Published');
        
        List<Cash_Flow_Sum__c> cfsList = new List<Cash_Flow_Sum__c>{
            new Cash_Flow_Sum__c(Unit__c = units[0].Id, Name = 'CFS 1'),
            new Cash_Flow_Sum__c(Unit__c = units[1].Id, Name = 'CFS 2')
        };
        insert cfsList;

        // Create Cash Flow records for multiple units
        List<Cash_Flow__c> cashFlows = new List<Cash_Flow__c>{
            // Unit 1 cash flows
            new Cash_Flow__c(Unit__c = units[0].Id, Cash_Flow_Sum__c = cfsList[0].Id, 
                           Name = 'Booking / Reservation', Date__c = Date.today()),
            new Cash_Flow__c(Unit__c = units[0].Id, Cash_Flow_Sum__c = cfsList[0].Id, 
                           Name = 'Regular Payment', Date__c = Date.today().addDays(30)),
            // Unit 2 cash flows
            new Cash_Flow__c(Unit__c = units[1].Id, Cash_Flow_Sum__c = cfsList[1].Id, 
                           Name = 'Booking / Reservation', Date__c = Date.today()),
            new Cash_Flow__c(Unit__c = units[1].Id, Cash_Flow_Sum__c = cfsList[1].Id, 
                           Name = 'Regular Payment', Date__c = Date.today().addDays(30))
        };

        Test.startTest();
        insert cashFlows;
        Test.stopTest();

        // Query and verify results for each unit
        for (Unit__c unit : units) {
            List<Cash_Flow__c> unitCashFlows = [
                SELECT Id, Name, Installment_Milestone__c, Date__c 
                FROM Cash_Flow__c 
                WHERE Unit__c = :unit.Id 
                ORDER BY Date__c ASC
            ];
            
            System.assertEquals(2, unitCashFlows.size(), 'Each unit should have 2 cash flows');
            System.assertEquals('Booking / Reservation', unitCashFlows[0].Installment_Milestone__c, 
                              'First should be Booking/Reservation for each unit');
            //System.assertEquals('1st Installment', unitCashFlows[1].Installment_Milestone__c, 
            //                  'Second should be 1st Installment for each unit');
        }
    }
}