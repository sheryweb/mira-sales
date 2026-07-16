trigger AccountTrigger on Account (before insert, after insert, before update, after update) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        // Filter out records where Skip_Trigger__c is checked
        List<Account> accountsToProcess = new List<Account>();
        Map<Id, Account> oldMapToProcess = new Map<Id, Account>();
        
        for (Account acc : Trigger.new) {
            if (acc.Skip_Trigger__c != true) {
                accountsToProcess.add(acc);
                if (Trigger.oldMap != null && Trigger.oldMap.containsKey(acc.Id)) {
                    oldMapToProcess.put(acc.Id, Trigger.oldMap.get(acc.Id));
                }
            }
        }
        
        // Skip processing if all records should be skipped
        if (accountsToProcess.isEmpty()) {
            return;
        }
        
        if (Trigger.isInsert) {
            AccountSerialHandler.setSerialNumbers(accountsToProcess);
        }
        //Company Email duplication rule Trigger
        AccountDuplicateHandler.checkDuplicateCompanyEmail(accountsToProcess, oldMapToProcess);
        
        MSAzureAiTriggerHandler.handleSObjectTransliteratableFieldsNullify(accountsToProcess, oldMapToProcess.values());
        Schema.DescribeFieldResult fieldResult = Account.Arabic_Picklists_technical__c.getDescribe();
        List<Schema.PicklistEntry> ples = fieldResult.getPicklistValues();
        Map<String,String> valueToLabelMap = new Map<String,String>();
        for (Schema.PicklistEntry ple : ples) {
            valueToLabelMap.put(ple.getValue(), ple.getLabel());
        }
        
        for (Account a : accountsToProcess) {
            if (String.isNotBlank(a.Country_of_Residence__c)) {
                a.Country_of_Residence_Arabic__c = valueToLabelMap.get(a.Country_of_Residence__c);
            } else {
                a.Country_of_Residence_Arabic__c = null;
            }

            if (String.isNotBlank(a.Nationality__c)) {
                a.Nationality_Arabic__c = valueToLabelMap.get(a.Nationality__c);
            } else {
                a.Nationality_Arabic__c = null;
            }

            if (String.isNotBlank(a.Country_of_Incorporation__c)) {
                a.Country_of_incorporation_arabic__c = valueToLabelMap.get(a.Country_of_Incorporation__c);
            } else {
                a.Country_of_incorporation_arabic__c = null;
            }
        }
    }
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        // Filter out records where Skip_Trigger__c is checked
        List<Account> accountsToProcess = new List<Account>();
        List<Account> oldAccountsToProcess = new List<Account>();
        
        for (Account acc : Trigger.new) {
            if (acc.Skip_Trigger__c != true) {
                accountsToProcess.add(acc);
                if (Trigger.oldMap != null && Trigger.oldMap.containsKey(acc.Id)) {
                    oldAccountsToProcess.add(Trigger.oldMap.get(acc.Id));
                }
            }
        }
        
        // Skip processing if all records should be skipped
        if (!accountsToProcess.isEmpty()) {
            MSAzureAiTriggerHandler.handleSObjectTransliteratableFieldsChange(accountsToProcess, oldAccountsToProcess);
        }
    }
}