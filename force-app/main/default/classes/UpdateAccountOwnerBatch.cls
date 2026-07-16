public class UpdateAccountOwnerBatch implements Database.Batchable<SObject>, Database.Stateful {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query Accounts with the specified RecordTypeId, Type, and Status__c = 'Completed', 
        // excluding "Ali" in Assigned_RM__c.
        // We cannot exclude "/" in SOQL, so we'll filter it in the `execute` method.
        return Database.getQueryLocator([
            SELECT Id, OwnerId, Assigned_RM__c, RecordTypeId, Type, 
                   Status__c, Owner.FirstName 
            FROM Account 
            WHERE (RecordTypeId = '012Hp000001yUTAIA2' OR Type = 'Agency')
            AND Status__c = 'Completed'
            AND Assigned_RM__c != NULL
            AND Assigned_RM__c != 'Ali'
        ]);
    }
    
    public void execute(Database.BatchableContext BC, List<Account> scope) {
        // Create a list to hold the accounts that need their Owner updated
        List<Account> accountsToUpdate = new List<Account>();

        // Query for active users based on the Assigned_RM__c field (only active users)
        Map<String, Id> activeUsersMap = new Map<String, Id>();
        List<User> activeUsers = [SELECT Id, FirstName, LastName FROM User WHERE IsActive = TRUE];
        String FullName;
        for (User u : activeUsers) {
            FullName = u.FirstName +' '+ u.LastName;
            activeUsersMap.put(FullName, u.Id);
        }

        // Iterate over the accounts in the current batch
        for (Account acc : scope) {
            if (acc.Assigned_RM__c.contains('/')) {
                continue; // Skip this account
            }
            // Check if the Assigned_RM__c matches a first name of an active user
            if (activeUsersMap.containsKey(acc.Assigned_RM__c)) {
                // If there is a match, update the OwnerId field
                acc.OwnerId = activeUsersMap.get(acc.Assigned_RM__c);
                accountsToUpdate.add(acc);
            }
        }

        // Update the accounts that need their owner updated
        if (!accountsToUpdate.isEmpty()) {
            try {
                update accountsToUpdate;
            } catch (DmlException e) {
                System.debug('Error updating accounts: ' + e.getMessage());
            }
        }
    }


    public void finish(Database.BatchableContext bc) {
        // Optional: Logging or sending a completion message
        System.debug('Account Owner update batch process completed.');
    }
}