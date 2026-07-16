@isTest
public class AccountSerialHandlerTest {
    
    @isTest
    static void testSetSerialNumbers() {
        // Query for RecordTypeId based on DeveloperName
        //Id testRecordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Your_RecordType_DeveloperName' LIMIT 1].Id;
		Id testRecordTypeId = '012Hp000001yUTAIA2';
        // Create new Accounts for the test, ensuring no Serial__c value is set
        Account acc1 = new Account(Name = 'Test Account 1', Company_Email__c = 'test1@test.com', RecordTypeId = testRecordTypeId);
        Account acc2 = new Account(Name = 'Test Account 2', Company_Email__c = 'test2@test.com', RecordTypeId = testRecordTypeId);
        
        insert new List<Account>{acc1, acc2};

        // Simulate pre-existing Accounts in production with Serial__c as null (or not set)
        Account preExistingAcc = new Account(Name = 'Pre-existing Account', Company_Email__c = 'test3@test.com', RecordTypeId = testRecordTypeId, Serial__c = null);
        insert preExistingAcc;

        // Manually set Serial__c for pre-existing record in the test
        preExistingAcc.Serial__c = 100;
        update preExistingAcc;

        // Now call the handler to set serial numbers (this should be triggered by inserting accounts)
        Test.startTest();
        AccountSerialHandler.setSerialNumbers(new List<Account>{acc1, acc2});
        Test.stopTest();

        // Fetch the updated Accounts and assert the serial numbers
        acc1 = [SELECT Serial__c FROM Account WHERE Id = :acc1.Id];
        acc2 = [SELECT Serial__c FROM Account WHERE Id = :acc2.Id];

        // Assert that Serial__c is assigned correctly
        // Assuming Serial__c should be 1 for the first Account and 2 for the second
        System.assertEquals(1, acc1.Serial__c, 'The Serial__c for Account 1 should be 1');
        System.assertEquals(2, acc2.Serial__c, 'The Serial__c for Account 2 should be 2');

        // Also assert that the pre-existing account has Serial__c = 100
        preExistingAcc = [SELECT Serial__c FROM Account WHERE Id = :preExistingAcc.Id];
        System.assertEquals(100, preExistingAcc.Serial__c, 'Pre-existing account should have Serial__c = 100');
    }
}