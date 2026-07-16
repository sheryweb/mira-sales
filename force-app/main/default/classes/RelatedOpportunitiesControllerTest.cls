@isTest
private class RelatedOpportunitiesControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(
            Name = 'Test Agency Account',
            Type = 'Agency',
            Company_Email__c = 'test@test.com',
            RecordTypeId = '012Hp000001yUTAIA2'  // Adding the RecordTypeId for Agency Account
        );
        insert testAccount;
        
        // Create a test contact to use as Agent
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Agent',
            AccountId = testAccount.Id
        );
        insert testContact;
        
        // Create test opportunities related to the account
        List<Opportunity> testOpps = new List<Opportunity>();
        for(Integer i = 0; i < 5; i++) {
            testOpps.add(new Opportunity(
                Name = 'Test Opportunity ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(i * 10),
                Agency__c = testAccount.Id,
                Agent__c = testContact.Id,
                Assisted_by_Agent__c = true  // Set to true since we now have an Agent
            ));
        }
        
        // Create an opportunity not related to the test account
        Account otherAccount = new Account(
            Name = 'Other Account', 
            Type = 'Agency',
            Company_Email__c = 'other@test.com',
            RecordTypeId = '012Hp000001yUTAIA2'  // Adding the RecordTypeId for Agency Account
        );
        insert otherAccount;
        
        // Create another contact for the other account
        Contact otherContact = new Contact(
            FirstName = 'Other',
            LastName = 'Agent',
            AccountId = otherAccount.Id
        );
        insert otherContact;
        
        testOpps.add(new Opportunity(
            Name = 'Unrelated Opportunity',
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Agency__c = otherAccount.Id,
            Agent__c = otherContact.Id,
            Assisted_by_Agent__c = true  // Set to true since we now have an Agent
        ));
        
        insert testOpps;
    }
    
    @isTest
    static void testGetRelatedOpportunities() {
        // Get the test account
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Agency Account' LIMIT 1];
        
        // Start test
        Test.startTest();
        
        // Call the method to test
        List<Opportunity> returnedOpps = RelatedOpportunitiesController.getRelatedOpportunities(testAccount.Id);
        
        // Stop test
        Test.stopTest();
        
        // Verify results
        System.assertEquals(5, returnedOpps.size(), 'Should return exactly 5 opportunities');
        
        // Verify we got the right opportunities (all should be related to our test account)
        for(Opportunity opp : returnedOpps) {
            System.assertEquals(testAccount.Id, opp.Agency__c, 'Opportunity should be related to the test account');
        }
        
        // Verify that the opportunities contain the Owner.Name field
        System.assertNotEquals(null, returnedOpps[0].Owner.Name, 'Owner name should be retrieved');
        
        // Verify order (should be sorted by CloseDate DESC)
        Date previousDate = returnedOpps[0].CloseDate;
        for(Integer i = 1; i < returnedOpps.size(); i++) {
            System.assert(previousDate >= returnedOpps[i].CloseDate, 
                         'Opportunities should be sorted by CloseDate in descending order');
            previousDate = returnedOpps[i].CloseDate;
        }
    }
    
    @isTest
    static void testGetRelatedOpportunitiesWithNoResults() {
        // Create a new account with no related opportunities
        Account emptyAccount = new Account(
            Name = 'Empty Account', 
            Type = 'Agency',
            Company_Email__c = 'empty@test.com',
            RecordTypeId = '012Hp000001yUTAIA2'  // Adding the RecordTypeId for Agency Account
        );
        insert emptyAccount;
        
        // Start test
        Test.startTest();
        
        // Call the method with the empty account
        List<Opportunity> returnedOpps = RelatedOpportunitiesController.getRelatedOpportunities(emptyAccount.Id);
        
        // Stop test
        Test.stopTest();
        
        // Verify no results
        System.assertEquals(0, returnedOpps.size(), 'Should return an empty list');
    }
}