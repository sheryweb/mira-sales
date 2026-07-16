public with sharing class AccountTradeLicenseExpiryController {
    public class AccountWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Type;
        @AuraEnabled public Date tradeLicenseExpiryDate;
        @AuraEnabled public Integer daysUntilExpiry;
        @AuraEnabled public Integer notificationCount;
        
        public AccountWrapper(Account acc, Integer daysToExpiry) {
            this.Id = acc.Id;
            this.Name = acc.Name;
            this.Type = acc.Type;
            this.tradeLicenseExpiryDate = acc.Trade_License_Expiry_Date__c;
            this.daysUntilExpiry = daysToExpiry;
            this.notificationCount = (acc.Trade_License_Expiry_Notification_Count__c != null) ? 
                                   Integer.valueOf(acc.Trade_License_Expiry_Notification_Count__c) : 0;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<AccountWrapper> getExpiringAccounts() {
        Date tenDaysFromNow = Date.today().addDays(10);
        Date today = Date.today();
        
        List<Account> accounts = [
            SELECT Id, Name, Type, Trade_License_Expiry_Date__c, Trade_License_Expiry_Notification_Count__c
            FROM Account 
            WHERE Type = 'Agency'
            AND Trade_License_Expiry_Date__c <= :tenDaysFromNow
            AND Trade_License_Expiry_Date__c != null
            AND Trade_License_Expiry_Notification_Sent__c = false
            ORDER BY Trade_License_Expiry_Date__c ASC
        ];

        List<AccountWrapper> wrappers = new List<AccountWrapper>();
        for(Account acc : accounts) {
            Integer daysToExpiry = acc.Trade_License_Expiry_Date__c.daysBetween(today) * -1;
            wrappers.add(new AccountWrapper(acc, daysToExpiry));
        }
        
        return wrappers;
    }

    @AuraEnabled
    public static void updateNotificationStatus(List<String> accountIds) {
        List<Account> accountsToUpdate = new List<Account>();
        
        for(String accId : accountIds) {
            accountsToUpdate.add(new Account(
                Id = accId,
                Trade_License_Expiry_Notification_Sent__c = true
            ));
        }
        
        if(!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }

    @AuraEnabled(cacheable=true)
    public static AccountWrapper getAccountTradeLicenseData(String accountId) {
        if (String.isBlank(accountId)) {
            throw new AuraHandledException('Account ID is required');
        }

        List<Account> accounts = [
            SELECT Id, Name, Type, Trade_License_Expiry_Date__c, Trade_License_Expiry_Notification_Count__c
            FROM Account 
            WHERE Id = :accountId
            AND Type = 'Agency'
            AND Trade_License_Expiry_Date__c != null
            LIMIT 1
        ];

        if (accounts.isEmpty()) {
            return null;
        }

        Account acc = accounts[0];
        Date today = Date.today();
        Integer daysToExpiry = acc.Trade_License_Expiry_Date__c.daysBetween(today) * -1;
        
        return new AccountWrapper(acc, daysToExpiry);
    }

}