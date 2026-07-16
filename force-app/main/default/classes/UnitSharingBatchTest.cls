@isTest
public class UnitSharingBatchTest {
    
    @isTest
    public static void testBatchProcess() {
        // Step 1: Create test users
        User testUser1 = new User(
            Alias = 'fors',
            LastName = 'tu',
            Email = 'forsand@example.com',
            Username = 'forsand@example.com',
            ProfileId = UserInfo.getProfileId(), 
            TimeZoneSidKey = 'America/Los_Angeles', 
            LocaleSidKey = 'en_US', 
            EmailEncodingKey = 'UTF-8', 
            LanguageLocaleKey = 'en_US'
        );
        insert testUser1;

        User testUser2 = new User(
            Alias = 'osrf',
            LastName = 'osf',
            Email = 'osrf@example.com',
            Username = 'osrf@example.com',
            ProfileId = UserInfo.getProfileId(), 
            TimeZoneSidKey = 'America/Los_Angeles', 
            LocaleSidKey = 'en_US', 
            EmailEncodingKey = 'UTF-8', 
            LanguageLocaleKey = 'en_US'
        );
        insert testUser2;
        
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

        // Step 2: Create test Unit__c records (always in Draft status)
        Unit__c unit1 = new Unit__c(Status__c = 'Draft', Project__c = pro.Id);
        Unit__c unit2 = new Unit__c(Status__c = 'Draft', Project__c = pro.Id);
        Unit__c unit3 = new Unit__c(Status__c = 'Draft', Project__c = pro.Id);
        insert new List<Unit__c>{unit1, unit2, unit3};
            
        //Insert Payment Plan
        List<Payment_Plan__c> paymentPlans = new List<Payment_Plan__c>();
        paymentPlans.add(new Payment_Plan__c(Project__c = pro.Id, Date__c = Date.today(), Percent__c = 50));
        paymentPlans.add(new Payment_Plan__c(Project__c = pro.Id, Date__c = Date.today().addYears(1), Percent__c = 50));
        insert paymentPlans;

        List<Additional_Payment__c> additionalPlans = new List<Additional_Payment__c>();
        additionalPlans.add(new Additional_Payment__c(Project__c = pro.Id, Percent__c = 25));
        additionalPlans.add(new Additional_Payment__c(Project__c = pro.Id, Percent__c = 15));
        insert additionalPlans;

        // Step 3: Create Opportunity records associated with the Unit__c records
        Opportunity opp1 = new Opportunity(
            Name = 'Test Opportunity 1',
            StageName = 'Booked',
            CloseDate = System.today(),
            OwnerId = testUser1.Id,
            Unit__c = unit1.Id
        );
        
        Opportunity opp2 = new Opportunity(
            Name = 'Test Opportunity 2',
            StageName = 'Sold',
            CloseDate = System.today(),
            OwnerId = testUser2.Id,
            Unit__c = unit2.Id
        );
        
        insert new List<Opportunity>{opp1, opp2};

        // Step 4: Modify Unit__c status to trigger sharing logic
        unit1.Status__c = 'Booked';
        unit2.Status__c = 'Sold';
        update new List<Unit__c>{unit1, unit2};

        // Step 5: Create a map of old units for comparison during status change
        Map<Id, Unit__c> oldUnits = new Map<Id, Unit__c>();
        oldUnits.put(unit1.Id, new Unit__c(Status__c = 'Draft')); 
        oldUnits.put(unit2.Id, new Unit__c(Status__c = 'Draft')); 

        // Step 6: Execute the batch process
        Test.startTest();

        // Execute the batch process
        UnitSharingBatch batch = new UnitSharingBatch();
        Database.executeBatch(batch, 200);  // Use a batch size that fits your needs

        Test.stopTest();

        // Step 7: Verify that exactly 2 Unit__Share records with RowCause 'Manual' were created
        List<Unit__Share> shares = [SELECT Id, ParentId, UserOrGroupId, RowCause, AccessLevel 
                                    FROM Unit__Share 
                                    WHERE ParentId IN :new List<Id>{unit1.Id, unit2.Id} 
                                    AND RowCause = 'Manual'];

        System.debug('Shares: ' + shares);

        System.assertEquals(2, shares.size(), 'There should be exactly 2 Unit__Share records with RowCause "Manual"');
        
        // Verify that shares are correctly assigned to Opportunity owners
        for (Unit__Share share : shares) {
            System.debug('Checking share for Unit ' + share.ParentId + ' assigned to User ' + share.UserOrGroupId);
            if (share.ParentId == unit1.Id) {
                System.assertEquals(testUser1.Id, share.UserOrGroupId, 'Share should be assigned to testUser1 for Unit1');
            } else if (share.ParentId == unit2.Id) {
                System.assertEquals(testUser2.Id, share.UserOrGroupId, 'Share should be assigned to testUser2 for Unit2');
            }
        }

        // Step 8: Modify unit status to remove sharing (away from target status)
        unit1.Status__c = 'Draft';  // Change unit1's status back to Draft to trigger share removal
        oldUnits.put(unit1.Id, new Unit__c(Id = unit1.Id, Status__c = 'Booked'));  // Set old status as 'Booked'

        // Step 9: Run the sharing logic again to simulate status change away from target status
        update new List<Unit__c>{unit1};

        UnitSharingHelper.manageUnitSharing(new List<Unit__c>{unit1}, oldUnits); // Manually invoke the sharing method again

        // Step 10: Verify that the Unit__Share record for unit1 was deleted (as status changed away from target)
        List<Unit__Share> remainingShares = [SELECT Id, ParentId 
                                             FROM Unit__Share 
                                             WHERE ParentId = :unit1.Id 
                                             AND RowCause = 'Manual'];
        System.assertEquals(0, remainingShares.size(), 'There should be no shares for Unit1 as status moved away from target');
    }
}