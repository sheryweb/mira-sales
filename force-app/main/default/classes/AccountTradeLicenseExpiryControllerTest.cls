@isTest
public class AccountTradeLicenseExpiryControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test accounts with different trade license expiry scenarios
        List<Account> testAccounts = new List<Account>();
        
        // Account 1: Expires in 5 days (should be included in getExpiringAccounts)
        testAccounts.add(new Account(
            Name = 'Test Agency 1',
            Type = 'Agency',
            Trade_License_Expiry_Date__c = Date.today().addDays(5),
            Trade_License_Expiry_Notification_Sent__c = false,
            Trade_License_Expiry_Notification_Count__c = 0,
            Company_Email__c = 'test1@agency.com'
        ));
        
        // Account 2: Expires today (should be included in getExpiringAccounts)
        testAccounts.add(new Account(
            Name = 'Test Agency 2',
            Type = 'Agency',
            Trade_License_Expiry_Date__c = Date.today(),
            Trade_License_Expiry_Notification_Sent__c = false,
            Trade_License_Expiry_Notification_Count__c = 2,
            Company_Email__c = 'test2@agency.com'
        ));
        
        // Account 3: Expired 3 days ago (should be included in getExpiringAccounts)
        testAccounts.add(new Account(
            Name = 'Test Agency 3',
            Type = 'Agency',
            Trade_License_Expiry_Date__c = Date.today().addDays(-3),
            Trade_License_Expiry_Notification_Sent__c = false,
            Trade_License_Expiry_Notification_Count__c = 5,
            Company_Email__c = 'test3@agency.com'
        ));
        
        // Account 4: Expires in 15 days (should NOT be included in getExpiringAccounts)
        testAccounts.add(new Account(
            Name = 'Test Agency 4',
            Type = 'Agency',
            Trade_License_Expiry_Date__c = Date.today().addDays(15),
            Trade_License_Expiry_Notification_Sent__c = false,
            Company_Email__c = 'test4@agency.com'
        ));
        
        // Account 5: Already notification sent (should NOT be included in getExpiringAccounts)
        testAccounts.add(new Account(
            Name = 'Test Agency 5',
            Type = 'Agency',
            Trade_License_Expiry_Date__c = Date.today().addDays(2),
            Trade_License_Expiry_Notification_Sent__c = true,
            Company_Email__c = 'test5@agency.com'
        ));
        
        // Account 6: Non-Agency account (should NOT be included in getExpiringAccounts)
        testAccounts.add(new Account(
            Name = 'Test Client 1',
            Type = 'Client',
            Trade_License_Expiry_Date__c = Date.today().addDays(5),
            Trade_License_Expiry_Notification_Sent__c = false,
            Company_Email__c = 'test6@client.com'
        ));
        
        // Account 7: Agency with null expiry date (should NOT be included in getExpiringAccounts)
        testAccounts.add(new Account(
            Name = 'Test Agency 7',
            Type = 'Agency',
            Trade_License_Expiry_Date__c = null,
            Trade_License_Expiry_Notification_Sent__c = false,
            Company_Email__c = 'test7@agency.com'
        ));
        
        insert testAccounts;
    }
    
    @isTest
    static void testGetExpiringAccounts() {
        Test.startTest();
        List<AccountTradeLicenseExpiryController.AccountWrapper> result = 
            AccountTradeLicenseExpiryController.getExpiringAccounts();
        Test.stopTest();
        
        // Should return 3 accounts (expires in 5 days, today, and 3 days ago)
        System.assertEquals(3, result.size(), 'Should return 3 expiring accounts');
        
        // Verify the accounts are ordered by expiry date ASC
        System.assertEquals(Date.today().addDays(-3), result[0].tradeLicenseExpiryDate, 
            'First account should be the one expired 3 days ago');
        System.assertEquals(Date.today(), result[1].tradeLicenseExpiryDate, 
            'Second account should expire today');
        System.assertEquals(Date.today().addDays(5), result[2].tradeLicenseExpiryDate, 
            'Third account should expire in 5 days');
        
        // Verify daysUntilExpiry calculation
        // Note: daysBetween() returns negative for future dates, positive for past dates
        // Controller multiplies by -1, so: future = positive, past = negative
        System.assertEquals(-3, result[0].daysUntilExpiry, 'Expired account should have negative days (-3 days ago)');
        System.assertEquals(0, result[1].daysUntilExpiry, 'Today expiry should have 0 days');
        System.assertEquals(5, result[2].daysUntilExpiry, 'Future expiry should have positive days (5 days)');
        
        // Verify notification counts are properly set
        System.assertEquals(5, result[0].notificationCount, 'Expired account should have notification count of 5');
        System.assertEquals(2, result[1].notificationCount, 'Today expiry should have notification count of 2');
        System.assertEquals(0, result[2].notificationCount, 'Future expiry should have notification count of 0');
    }
    
    @isTest
    static void testGetExpiringAccountsEmpty() {
        // Delete all test accounts to test empty scenario
        delete [SELECT Id FROM Account WHERE Type = 'Agency'];
        
        Test.startTest();
        List<AccountTradeLicenseExpiryController.AccountWrapper> result = 
            AccountTradeLicenseExpiryController.getExpiringAccounts();
        Test.stopTest();
        
        System.assertEquals(0, result.size(), 'Should return empty list when no accounts exist');
    }
    
    @isTest
    static void testUpdateNotificationStatus() {
        List<Account> accounts = [SELECT Id FROM Account WHERE Type = 'Agency' LIMIT 2];
        List<String> accountIds = new List<String>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }
        
        Test.startTest();
        AccountTradeLicenseExpiryController.updateNotificationStatus(accountIds);
        Test.stopTest();
        
        // Verify the notification status was updated
        List<Account> updatedAccounts = [SELECT Id, Trade_License_Expiry_Notification_Sent__c 
                                       FROM Account WHERE Id IN :accountIds];
        
        for (Account acc : updatedAccounts) {
            System.assertEquals(true, acc.Trade_License_Expiry_Notification_Sent__c, 
                'Notification status should be updated to true');
        }
    }
    
    @isTest
    static void testUpdateNotificationStatusEmptyList() {
        Test.startTest();
        AccountTradeLicenseExpiryController.updateNotificationStatus(new List<String>());
        Test.stopTest();
        
        // Should not throw any exception and complete successfully
        System.assert(true, 'Method should handle empty list gracefully');
    }
    
    @isTest
    static void testGetAccountTradeLicenseDataSuccess() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Agency 1' LIMIT 1];
        
        Test.startTest();
        AccountTradeLicenseExpiryController.AccountWrapper result = 
            AccountTradeLicenseExpiryController.getAccountTradeLicenseData(testAccount.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return account wrapper');
        System.assertEquals(testAccount.Id, result.Id, 'Should return correct account ID');
        System.assertEquals('Test Agency 1', result.Name, 'Should return correct account name');
        System.assertEquals('Agency', result.Type, 'Should return correct account type');
        System.assertEquals(Date.today().addDays(5), result.tradeLicenseExpiryDate, 
            'Should return correct expiry date');
        System.assertEquals(5, result.daysUntilExpiry, 'Should calculate correct days until expiry');
    }
    
    @isTest
    static void testGetAccountTradeLicenseDataBlankId() {
        Test.startTest();
        try {
            AccountTradeLicenseExpiryController.getAccountTradeLicenseData('');
            System.assert(false, 'Should throw exception for blank ID');
        } catch (Exception e) {
            System.assert(true, 'Exception thrown as expected: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetAccountTradeLicenseDataNullId() {
        Test.startTest();
        try {
            AccountTradeLicenseExpiryController.getAccountTradeLicenseData(null);
            System.assert(false, 'Should throw exception for null ID');
        } catch (Exception e) {
            System.assert(true, 'Exception thrown as expected: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetAccountTradeLicenseDataNotFound() {
        // Create a non-agency account
        Account nonAgencyAccount = new Account(
            Name = 'Non Agency Account',
            Type = 'Client'
        );
        insert nonAgencyAccount;
        
        Test.startTest();
        AccountTradeLicenseExpiryController.AccountWrapper result = 
            AccountTradeLicenseExpiryController.getAccountTradeLicenseData(nonAgencyAccount.Id);
        Test.stopTest();
        
        System.assertEquals(null, result, 'Should return null for non-agency account');
    }
    
    @isTest
    static void testGetAccountTradeLicenseDataNoExpiryDate() {
        // Create an agency account without expiry date
        Account agencyWithoutExpiry = new Account(
            Name = 'Agency Without Expiry',
            Type = 'Agency',
            Trade_License_Expiry_Date__c = null
        );
        insert agencyWithoutExpiry;
        
        Test.startTest();
        AccountTradeLicenseExpiryController.AccountWrapper result = 
            AccountTradeLicenseExpiryController.getAccountTradeLicenseData(agencyWithoutExpiry.Id);
        Test.stopTest();
        
        System.assertEquals(null, result, 'Should return null for agency without expiry date');
    }
    
    @isTest
    static void testGetAccountTradeLicenseDataWithNotificationCount() {
        Account testAccount = [SELECT Id, Name, Type, Trade_License_Expiry_Date__c, Trade_License_Expiry_Notification_Count__c 
                              FROM Account WHERE Name = 'Test Agency 1' LIMIT 1];
        
        Test.startTest();
        AccountTradeLicenseExpiryController.AccountWrapper result = 
            AccountTradeLicenseExpiryController.getAccountTradeLicenseData(testAccount.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return account wrapper');
        System.assertEquals(testAccount.Id, result.Id, 'Should return correct account ID');
        System.assertEquals('Test Agency 1', result.Name, 'Should return correct account name');
        System.assertEquals('Agency', result.Type, 'Should return correct account type');
        System.assertEquals(Date.today().addDays(5), result.tradeLicenseExpiryDate, 
            'Should return correct expiry date');
        System.assertEquals(5, result.daysUntilExpiry, 'Should calculate correct days until expiry');
        System.assertEquals(0, result.notificationCount, 'Should return correct notification count (0)');
    }
    
    @isTest
    static void testAccountWrapperConstructor() {
        Account testAccount = [SELECT Id, Name, Type, Trade_License_Expiry_Date__c, Trade_License_Expiry_Notification_Count__c 
                              FROM Account WHERE Name = 'Test Agency 1' LIMIT 1];
        
        Test.startTest();
        AccountTradeLicenseExpiryController.AccountWrapper wrapper = 
            new AccountTradeLicenseExpiryController.AccountWrapper(testAccount, 5);
        Test.stopTest();
        
        System.assertEquals(testAccount.Id, wrapper.Id, 'Should set correct ID');
        System.assertEquals(testAccount.Name, wrapper.Name, 'Should set correct Name');
        System.assertEquals(testAccount.Type, wrapper.Type, 'Should set correct Type');
        System.assertEquals(testAccount.Trade_License_Expiry_Date__c, wrapper.tradeLicenseExpiryDate, 
            'Should set correct expiry date');
        System.assertEquals(5, wrapper.daysUntilExpiry, 'Should set correct days until expiry');
        System.assertEquals(0, wrapper.notificationCount, 'Should set correct notification count');
    }
}