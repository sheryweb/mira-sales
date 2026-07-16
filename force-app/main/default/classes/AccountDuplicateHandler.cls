public class AccountDuplicateHandler {
    public static void checkDuplicateCompanyEmail(List<Account> newAccounts, Map<Id, Account> oldAccounts) {
        // Replace this with the RecordTypeId you want to target
        //Id targetRecordTypeId = '012Hp000001yUTAIA2'; //Sandbox
        Id targetRecordTypeId = '012Hp000001yUTAIA2'; //Production

        // Collect emails to check
        Set<String> emailSet = new Set<String>();
        Map<Id, String> accountEmailMap = new Map<Id, String>();

        for (Account acc : newAccounts) {
            if (acc.RecordTypeId == targetRecordTypeId) {
                // Check if the Company Email is empty
                if (String.isBlank(acc.Company_Email__c)) {
                    acc.addError('Company Email is required for this Agencies.');
                }
                
                // Collect email for duplicate checking
                if (acc.Company_Email__c != null) {
                    emailSet.add(acc.Company_Email__c);
                    accountEmailMap.put(acc.Id, acc.Company_Email__c);
                }
            }
        }

        if (!emailSet.isEmpty()) {
            // Query for existing accounts with the same Company_Email__c
            List<Account> duplicateAccounts = [
                SELECT Id, Company_Email__c
                FROM Account
                WHERE Company_Email__c IN :emailSet
                AND RecordTypeId = :targetRecordTypeId
                AND Id NOT IN :accountEmailMap.keySet() // Exclude current records being updated
            ];

            // Create a set of duplicate emails
            Set<String> duplicateEmails = new Set<String>();
            for (Account acc : duplicateAccounts) {
                duplicateEmails.add(acc.Company_Email__c);
            }

            // Add error to new accounts with duplicate emails
            for (Account acc : newAccounts) {
                if (duplicateEmails.contains(acc.Company_Email__c)) {
                    acc.addError('The Company Email is already in use for another Account with this record type.');
                }
            }
        }
    }
}