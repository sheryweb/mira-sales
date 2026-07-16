@isTest
public class CashFlowUpdateBatchTest {
    @isTest
    static void testCashFlowUpdateBatch() {
        // Step 1: Set up test data
        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 0; i < 3; i++) {
            units.add(new Unit__c(Title__c = 'Unit ' + i));
        }
        insert units;
        
        Cash_Flow_Sum__c cfm = new Cash_Flow_Sum__c();
        cfm.Unit__c = units[0].Id;
        cfm.Name = 'Test CFM';
        insert cfm;

        // Create Cash_Flow__c records
        List<Cash_Flow__c> cashFlows = new List<Cash_Flow__c>();

        // Records without Installment_Milestone__c (should be updated)
        for (Integer i = 0; i < 5; i++) {
            cashFlows.add(new Cash_Flow__c(
                Unit__c = units[Math.mod(i, units.size())].Id,
                Cash_Flow_Sum__c = cfm.Id,
                Date__c = Date.today().addDays(i),
                Installment_Milestone__c = null
            ));
        }

        // Records with Installment_Milestone__c (should not be updated)
        for (Integer i = 0; i < 3; i++) {
            cashFlows.add(new Cash_Flow__c(
                Unit__c = units[Math.mod(i, units.size())].Id,
                Cash_Flow_Sum__c = cfm.Id,
                Date__c = Date.today().addDays(i + 5),
                Installment_Milestone__c = 'Pre-Set Milestone ' + i
            ));
        }

        insert cashFlows;

        // Step 2: Execute the batch
        Test.startTest();
        CashFlowUpdateBatch batch = new CashFlowUpdateBatch();
        Database.executeBatch(batch, 2); // Smaller batch size for testing
        Test.stopTest();

        // Step 3: Validate the batch's impact
        // Query records to verify updates
        List<Cash_Flow__c> updatedCashFlows = [
            SELECT Installment_Milestone__c 
            FROM Cash_Flow__c 
            WHERE Installment_Milestone__c != NULL
        ];

        // Ensure only initially null records were updated
        System.assertEquals(8, updatedCashFlows.size(), '5 new updates + 3 pre-existing records.');

        // Verify records with null milestones were updated
        List<Cash_Flow__c> nullMilestones = [
            SELECT Id 
            FROM Cash_Flow__c 
            WHERE Installment_Milestone__c = NULL
        ];
        System.assertEquals(0, nullMilestones.size(), 'All records without milestones should be updated.');
    }

    @isTest
    static void testEmptyBatch() {
        // Test with no records matching the query
        Test.startTest();
        CashFlowUpdateBatch emptyBatch = new CashFlowUpdateBatch();
        Database.executeBatch(emptyBatch, 1);
        Test.stopTest();
        // If no exceptions, test passes
    }

    @isTest
    static void testBatchWithEdgeCases() {
        // Step 1: Create test data with edge cases
        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 0; i < 2; i++) {
            units.add(new Unit__c(Title__c = 'Unit ' + i));
        }
        insert units;

        Cash_Flow_Sum__c cfm = new Cash_Flow_Sum__c();
        cfm.Unit__c = units[0].Id;
        cfm.Name = 'Edge Test CFM';
        insert cfm;

        // Create records with null Installment_Milestone__c (should be updated) and non-null (should not be updated)
        List<Cash_Flow__c> cashFlows = new List<Cash_Flow__c>();
        for (Integer i = 0; i < 5; i++) {
            cashFlows.add(new Cash_Flow__c(
                Unit__c = units[Math.mod(i, units.size())].Id,
                Cash_Flow_Sum__c = cfm.Id,
                Date__c = Date.today().addDays(i),
                Installment_Milestone__c = null
            ));
        }

        // Adding some with milestones
        for (Integer i = 0; i < 3; i++) {
            cashFlows.add(new Cash_Flow__c(
                Unit__c = units[Math.mod(i, units.size())].Id,
                Cash_Flow_Sum__c = cfm.Id,
                Date__c = Date.today().addDays(i + 5),
                Installment_Milestone__c = 'Pre-Set Milestone ' + i
            ));
        }
        insert cashFlows;

        // Step 2: Test the batch with non-empty scope
        Test.startTest();
        CashFlowUpdateBatch batch = new CashFlowUpdateBatch();
        Database.executeBatch(batch, 2); // Execute batch with non-empty scope
        Test.stopTest();

        // Step 3: Validate batch execution
        List<Cash_Flow__c> updatedCashFlows = [
            SELECT Installment_Milestone__c 
            FROM Cash_Flow__c 
            WHERE Installment_Milestone__c != NULL
        ];

        // Verify that only records that previously had null Installment_Milestone__c were updated
        System.assertEquals(8, updatedCashFlows.size(), 'Expecting 8 records to have non-null milestones after the update.');

        // Verify no records with null Installment_Milestone__c
        List<Cash_Flow__c> nullMilestones = [
            SELECT Id 
            FROM Cash_Flow__c 
            WHERE Installment_Milestone__c = NULL
        ];
        System.assertEquals(0, nullMilestones.size(), 'All records should now have an Installment_Milestone__c populated.');
    }

    @isTest
    static void testBatchEmptyScope() {
        // Test case where scope is empty (no records to update)
        Test.startTest();
        CashFlowUpdateBatch batch = new CashFlowUpdateBatch();
        List<Cash_Flow__c> scope = new List<Cash_Flow__c>(); // Empty scope
        batch.execute(null, scope);  // Manually invoke execute with empty scope
        Test.stopTest();

        // No assertion needed, just confirming no error occurs
    }

    @isTest
    static void testAssignInstallmentMilestonesMethod() {
        // Test for direct call to assignInstallmentMilestones method
        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 0; i < 3; i++) {
            units.add(new Unit__c(Title__c = 'Unit ' + i));
        }
        insert units;

        Cash_Flow_Sum__c cfm = new Cash_Flow_Sum__c();
        cfm.Unit__c = units[0].Id;
        cfm.Name = 'Installment Test CFM';
        insert cfm;

        // Create records without milestones (should be updated)
        List<Cash_Flow__c> cashFlows = new List<Cash_Flow__c>();
        for (Integer i = 0; i < 3; i++) {
            cashFlows.add(new Cash_Flow__c(
                Unit__c = units[Math.mod(i, units.size())].Id,
                Cash_Flow_Sum__c = cfm.Id,
                Date__c = Date.today().addDays(i),
                Installment_Milestone__c = null
            ));
        }
        insert cashFlows;

        // Directly call the method
        Test.startTest();
        CashFlowTriggerHandler.assignInstallmentMilestones(cashFlows);
        Test.stopTest();

        // Verify updates
        List<Cash_Flow__c> updatedCashFlows = [
            SELECT Installment_Milestone__c 
            FROM Cash_Flow__c 
            WHERE Installment_Milestone__c != NULL
        ];
        System.assertEquals(3, updatedCashFlows.size(), 'All records should have been updated with milestones.');
    }
}