@isTest
public class UnitSharingHelperTest {

    @isTest
    public static void testManageUnitSharing() {
        // Step 1: Create test users
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User testUser1 = new User(
            Alias = 'fors',
            Email = 'forsand@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User1',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'forsand@example.com'
        );
        
        User testUser2 = new User(
            Alias = 'offs',
            Email = 'offsand@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User2',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'offsand@example.com'
        );
        
        insert new List<User>{testUser1, testUser2};
            
        //Create a Project
        Project__c pro = new Project__c(
        	Name = 'Test Project',
            Handover__c = System.today(),
            Project_Status__c = 'Completed',
            Description__c = 'Test Description',
            District__c = 'Meydan',
            Coordinates_Latitude__c = 123.00,
            Coordinates_Longitude__c = 432.00,
            Payment_Plan_Title__c = 'Test Payment Plan'
        );
        
        insert pro;
            
        // Step 2: Create test Unit__c records
        Unit__c unit1 = new Unit__c(Status__c = 'Draft', Project__c = pro.Id);
        Unit__c unit2 = new Unit__c(Status__c = 'Draft', Project__c = pro.Id);
        insert new List<Unit__c>{unit1, unit2};
            
        //Insert Payment Plan
        List<Payment_Plan__c> paymentPlans = new List<Payment_Plan__c>();
        paymentPlans.add(new Payment_Plan__c(Project__c = pro.Id, Date__c = Date.today(), Percent__c = 50));
        paymentPlans.add(new Payment_Plan__c(Project__c = pro.Id, Date__c = Date.today().addYears(1), Percent__c = 50));
        insert paymentPlans;

        List<Additional_Payment__c> additionalPlans = new List<Additional_Payment__c>();
        additionalPlans.add(new Additional_Payment__c(Project__c = pro.Id, Percent__c = 25));
        additionalPlans.add(new Additional_Payment__c(Project__c = pro.Id, Percent__c = 15));
        insert additionalPlans;

        // Step 3: Create test Opportunity records with reference to Unit__c
        Opportunity opp1 = new Opportunity(
            Name = 'Test Opportunity 1',
            StageName = 'Prospecting',
            CloseDate = System.today(),
            OwnerId = testUser1.Id,
            Unit__c = unit1.Id  // Ensure this is a valid lookup field in your org
        );
        
        Opportunity opp2 = new Opportunity(
            Name = 'Test Opportunity 2',
            StageName = 'Prospecting',
            CloseDate = System.today(),
            OwnerId = testUser2.Id,
            Unit__c = unit2.Id
        );
        
        insert new List<Opportunity>{opp1, opp2};

        // Step 4: Modify unit status to trigger sharing logic
        unit1.Status__c = 'Booked';
        unit2.Status__c = 'Sold';

        // Step 5: Define a map of old units for the trigger comparison
        Map<Id, Unit__c> oldUnits = new Map<Id, Unit__c>();
        oldUnits.put(unit1.Id, new Unit__c(Status__c = 'Draft')); 
        oldUnits.put(unit2.Id, new Unit__c(Status__c = 'Draft')); 

        // Step 6: Run the sharing logic within a single test execution context
        Test.startTest();
        
        // Update the units to trigger the logic
        update new List<Unit__c>{unit1, unit2};  
        
        // Manually invoke the sharing method (if necessary)
        UnitSharingHelper.manageUnitSharing(new List<Unit__c>{unit1, unit2}, oldUnits);

        // Step 7: Verify that exactly 2 Unit__Share records with RowCause 'Manual' are created
        List<Unit__Share> shares = [SELECT Id, ParentId, UserOrGroupId, RowCause, AccessLevel 
                                    FROM Unit__Share 
                                    WHERE ParentId IN :new List<Id>{unit1.Id, unit2.Id} 
                                    AND RowCause = 'Manual'];

        System.assertEquals(2, shares.size(), 'There should be exactly 2 Unit__Share records with RowCause "Manual"');
        
        // Verify if shares are correctly assigned to Opportunity owners
        for (Unit__Share share : shares) {
            if (share.ParentId == unit1.Id) {
                System.assertEquals(testUser1.Id, share.UserOrGroupId, 'Share should be assigned to testUser1 for Unit1');
            } else if (share.ParentId == unit2.Id) {
                System.assertEquals(testUser2.Id, share.UserOrGroupId, 'Share should be assigned to testUser2 for Unit2');
            }
        }
        
        // Step 8: Modify unit status away from target status to trigger sharing removal
        unit1.Status__c = 'Draft';  // Change away from target status to trigger deletion
        oldUnits.put(unit1.Id, new Unit__c(Id = unit1.Id, Status__c = 'Booked'));  // Set old status as 'Booked'
        
        // Run the sharing logic again to simulate status change away from target status
        update new List<Unit__c>{unit1};
        
        UnitSharingHelper.manageUnitSharing(new List<Unit__c>{unit1}, oldUnits); // Manually invoke sharing method again if needed

        Test.stopTest();
        
        // Step 9: Verify that the Unit__Share record for unit1 was deleted
        List<Unit__Share> remainingShares = [SELECT Id, ParentId FROM Unit__Share 
                                             WHERE ParentId = :unit1.Id 
                                             AND RowCause = 'Manual'];
        System.assertEquals(0, remainingShares.size(), 'There should be no shares for Unit1 as status moved away from target');
    }
}