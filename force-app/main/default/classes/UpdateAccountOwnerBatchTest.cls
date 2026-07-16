@isTest
public class UpdateAccountOwnerBatchTest {

    @testSetup
    static void setup() {
        // Create test users with different first names
        User user1 = new User(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'johndoe@example.com',
            Username = 'johndoee@example.com.test',
            Alias = 'jdoe',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert user1;
        
        User user2 = new User(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'janesmith@example.com',
            Username = 'janesmithh@example.com.test',
            Alias = 'jsmith',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert user2;
        
        // Create test accounts with various Assigned_RM__c values and status
        Account acc1 = new Account(
            Name = 'Test Account 1',
            RecordTypeId = '012Hp000001yUTAIA2',
            Type = 'Agency',
            Status__c = 'Completed',
            Assigned_RM__c = 'John Doe',
            OwnerId = user2.Id // Owner is initially not 'John'
        );
        
        Account acc2 = new Account(
            Name = 'Test Account 2',
            RecordTypeId = '012Hp000001yUTAIA2',
            Type = 'Agency',
            Status__c = 'Completed',
            Assigned_RM__c = 'Jane Smith',
            OwnerId = user1.Id // Owner is initially not 'Jane'
        );

        Account acc3 = new Account(
            Name = 'Test Account 3',
            RecordTypeId = '012Hp000001yUTAIA2',
            Type = 'Agency',
            Status__c = 'Completed',
            Assigned_RM__c = 'Ali', // Should be excluded
            OwnerId = user1.Id
        );

        Account acc4 = new Account(
            Name = 'Test Account 4',
            RecordTypeId = '012Hp000001yUTAIA2',
            Type = 'Agency',
            Status__c = 'Completed',
            Assigned_RM__c = 'John / Doe', // Should be excluded
            OwnerId = user2.Id
        );
        
        insert new List<Account>{acc1, acc2, acc3, acc4};
    }

    @isTest
    static void testBatchExecution() {
        // Start Test and execute the batch
        Test.startTest();
        
        // Execute the batch with a batch size of 200 (or any reasonable batch size)
        UpdateAccountOwnerBatch batch = new UpdateAccountOwnerBatch();
        Database.executeBatch(batch, 200); // Use a large enough batch size

        Test.stopTest();
        
        // Verify the results
        // Fetch the accounts again to check if ownership was updated
        List<Account> updatedAccounts = [SELECT Id, Assigned_RM__c, Owner.FirstName, Owner.LastName 
                                         FROM Account WHERE Assigned_RM__c IN ('John Doe', 'Jane Smith')];
        
        for (Account acc : updatedAccounts) {
            if (acc.Assigned_RM__c == 'John Doe') {
                System.assertEquals('John Doe', acc.Owner.FirstName+' '+acc.Owner.LastName, 
                    'The owner should be updated to John for accounts with Assigned_RM__c = John Doe');
            } else if (acc.Assigned_RM__c == 'Jane Smith') {
                System.assertEquals('Jane Smith', acc.Owner.FirstName+' '+acc.Owner.LastName, 
                    'The owner should be updated to Jane Smith for accounts with Assigned_RM__c = Jane Smith');
            }
        }

        // Verify excluded accounts
        Account excludedAcc1 = [SELECT Id, Assigned_RM__c, OwnerId 
                                FROM Account WHERE Assigned_RM__c = 'Ali' LIMIT 1];
        System.assertNotEquals('John Doe', excludedAcc1.OwnerId, 
            'Account with Assigned_RM__c = Ali should not be updated');

        Account excludedAcc2 = [SELECT Id, Assigned_RM__c, OwnerId 
                                FROM Account WHERE Assigned_RM__c LIKE '%/%' LIMIT 1];
        System.assertNotEquals('John Doe', excludedAcc2.OwnerId, 
            'Account with Assigned_RM__c containing "/" should not be updated');
    }
}