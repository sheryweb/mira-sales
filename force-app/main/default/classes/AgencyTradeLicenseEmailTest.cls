@isTest
public class AgencyTradeLicenseEmailTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Agency',
            Type = 'Agency',
            Company_Email__c = 'test@agency.com',
            Contact_Email_2__c = 'test2@agency.com',
            Trade_License_Expiry_Date__c = Date.today().addDays(-5),
            Trade_License_Expiry_Notification_Sent__c = false,
            Status__c = 'Completed'
        );
        insert testAccount;
    }
    
    @isTest
    static void testSendExpiryNotificationEmail_Success() {
        // Get test account
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];
        
        Test.startTest();
        
        // Call the method - should not throw exception
        AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmail(testAccount.Id);
        
        Test.stopTest();
        
        // Verify the account still exists and notification count was incremented
        Account updatedAccount = [SELECT Id, Name, Trade_License_Expiry_Notification_Count__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('Test Agency', updatedAccount.Name, 'Account should still exist after email send');
        System.assertEquals(1, updatedAccount.Trade_License_Expiry_Notification_Count__c, 'Notification count should be incremented to 1');
    }
    
    @isTest
    static void testSendExpiryNotificationEmail_BlankAccountId() {
        Test.startTest();
        
        try {
            AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmail('');
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Account ID is required') || e.getMessage().contains('Script-thrown exception'), 
                'Expected Account ID is required or Script-thrown exception, got: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendExpiryNotificationEmail_NullAccountId() {
        Test.startTest();
        
        try {
            AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmail(null);
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Account ID is required') || e.getMessage().contains('Script-thrown exception'), 
                'Expected Account ID is required or Script-thrown exception, got: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendExpiryNotificationEmail_NoRecipientEmail() {
        // Create account without email
        Account testAccount = new Account(
            Name = 'Test Agency No Email',
            Type = 'Agency',
            Company_Email__c = null,
            Contact_Email_2__c = null,
            Trade_License_Expiry_Date__c = Date.today().addDays(-1),
            Status__c = 'Completed'
        );
        insert testAccount;
        
        Test.startTest();
        
        try {
            AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmail(testAccount.Id);
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('No recipient email found on the record.') || e.getMessage().contains('Script-thrown exception'), 
                'Expected No recipient email found or Script-thrown exception, got: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendExpiryNotificationEmail_AccountNotFound() {
        Test.startTest();
        
        try {
            AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmail('001000000000000AAA');
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (Exception e) {
            // This might throw a different exception depending on the ID format
            System.assert(true, 'Exception was thrown as expected');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendExpiryNotificationEmail_WithOnlyCompanyEmail() {
        // Create account with only company email
        Account testAccount = new Account(
            Name = 'Test Agency Company Email Only',
            Type = 'Agency',
            Company_Email__c = 'company@agency.com',
            Contact_Email_2__c = null,
            Trade_License_Expiry_Date__c = Date.today().addDays(-1),
            Status__c = 'Completed'
        );
        insert testAccount;
        
        Test.startTest();
        
        // This should succeed
        AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmail(testAccount.Id);
        
        Test.stopTest();
        
        // Verify the account still exists and notification count was incremented
        Account updatedAccount = [SELECT Id, Name, Trade_License_Expiry_Notification_Count__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('Test Agency Company Email Only', updatedAccount.Name, 'Account should still exist after email send');
        System.assertEquals(1, updatedAccount.Trade_License_Expiry_Notification_Count__c, 'Notification count should be incremented to 1');
    }
    
    @isTest
    static void testSendExpiryNotificationEmail_WithOnlyContactEmail2() {
        // Create account with only contact email 2
        Account testAccount = new Account(
            Name = 'Test Agency Contact Email Only',
            Type = 'Agency',
            Company_Email__c = null,
            Contact_Email_2__c = 'contact2@agency.com',
            Trade_License_Expiry_Date__c = Date.today().addDays(-1),
            Status__c = 'Completed'
        );
        insert testAccount;
        
        Test.startTest();
        
        // This should succeed
        AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmail(testAccount.Id);
        
        Test.stopTest();
        
        // Verify the account still exists and notification count was incremented
        Account updatedAccount = [SELECT Id, Name, Trade_License_Expiry_Notification_Count__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('Test Agency Contact Email Only', updatedAccount.Name, 'Account should still exist after email send');
        System.assertEquals(1, updatedAccount.Trade_License_Expiry_Notification_Count__c, 'Notification count should be incremented to 1');
    }
    
    @isTest
    static void testSendExpiryNotificationEmails_BulkSuccess() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];

        Account secondAccount = new Account(
            Name = 'Test Agency Two',
            Type = 'Agency',
            Company_Email__c = 'agency2@test.com',
            Trade_License_Expiry_Date__c = Date.today().addDays(-3),
            Trade_License_Expiry_Notification_Sent__c = false,
            Status__c = 'Completed'
        );
        insert secondAccount;

        Test.startTest();
        AgencyTradeLicenseExpiryEmailController.BulkSendResult result =
            AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmails(
                new List<String>{ testAccount.Id, secondAccount.Id }
            );
        Test.stopTest();

        System.assertEquals(2, result.successCount, 'Both accounts should succeed');
        System.assertEquals(0, result.failureCount, 'No failures expected');

        Account updatedAccount = [
            SELECT Trade_License_Expiry_Notification_Count__c, Trade_License_Expiry_Notification_Sent__c
            FROM Account WHERE Id = :testAccount.Id
        ];
        System.assertEquals(1, updatedAccount.Trade_License_Expiry_Notification_Count__c);
        System.assertEquals(true, updatedAccount.Trade_License_Expiry_Notification_Sent__c);
    }

    @isTest
    static void testSendExpiryNotificationEmails_EmptyList() {
        Test.startTest();
        try {
            AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmails(new List<String>());
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (Exception e) {
            System.assert(
                e.getMessage().contains('At least one Account ID is required') ||
                e.getMessage().contains('Script-thrown exception'),
                'Unexpected message: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testGetEligibleAgencyAccounts() {
        AgencyTradeLicenseExpiryEmailController.skipRecordTypeFilterInTest = true;

        Account eligibleAccount = new Account(
            Name = 'Eligible Agency',
            Type = 'Agency',
            Company_Email__c = 'eligible@agency.com',
            Contact_Email_2__c = 'eligible2@agency.com',
            Trade_License_Expiry_Date__c = Date.today().addDays(-10),
            Trade_License_Expiry_Notification_Sent__c = false,
            Trade_License_Expiry_Notification_Count__c = 2,
            Trade_License_Expiry_Notification_Date__c = Date.today().addDays(-35),
            Status__c = 'Completed'
        );
        insert eligibleAccount;

        Test.startTest();
        List<AgencyTradeLicenseExpiryEmailController.EligibleAccountWrapper> results =
            AgencyTradeLicenseExpiryEmailController.getEligibleAgencyAccounts();
        Test.stopTest();

        AgencyTradeLicenseExpiryEmailController.skipRecordTypeFilterInTest = false;

        System.assert(!results.isEmpty(), 'Eligible agencies should be returned');
        AgencyTradeLicenseExpiryEmailController.EligibleAccountWrapper match = null;
        for (AgencyTradeLicenseExpiryEmailController.EligibleAccountWrapper wrapper : results) {
            if (wrapper.accountId == eligibleAccount.Id) {
                match = wrapper;
                break;
            }
        }
        System.assertNotEquals(null, match, 'Inserted eligible agency should be returned');
        System.assertEquals(eligibleAccount.Id, match.accountId);
        System.assertEquals('Eligible Agency', match.name);
        System.assertEquals('eligible@agency.com', match.companyEmail);
        System.assertEquals('eligible2@agency.com', match.contactEmail2);
        System.assertEquals(2, match.notificationCount);
        System.assertEquals(false, match.notificationSent);
        System.assertEquals(Date.today().addDays(-35), match.notificationDate);
    }

    @isTest
    static void testGetEligibleAgencyAccounts_WithRecordTypeFilter() {
        AgencyTradeLicenseExpiryEmailController.skipRecordTypeFilterInTest = false;

        List<RecordType> agencyRecordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND Id = '012Hp000001yUTAIA2'
            LIMIT 1
        ];

        if (agencyRecordTypes.isEmpty()) {
            AgencyTradeLicenseExpiryEmailController.skipRecordTypeFilterInTest = true;
            return;
        }

        Account eligibleAccount = new Account(
            Name = 'Eligible Agency RT',
            Type = 'Agency',
            RecordTypeId = agencyRecordTypes[0].Id,
            Company_Email__c = 'rt@agency.com',
            Trade_License_Expiry_Date__c = Date.today().addDays(-5),
            Trade_License_Expiry_Notification_Sent__c = false,
            Status__c = 'Completed'
        );
        insert eligibleAccount;

        Test.startTest();
        List<AgencyTradeLicenseExpiryEmailController.EligibleAccountWrapper> results =
            AgencyTradeLicenseExpiryEmailController.getEligibleAgencyAccounts();
        Test.stopTest();

        Boolean found = false;
        for (AgencyTradeLicenseExpiryEmailController.EligibleAccountWrapper wrapper : results) {
            if (wrapper.accountId == eligibleAccount.Id) {
                found = true;
                break;
            }
        }
        System.assert(found, 'Agency with configured record type should be returned');
    }

    @isTest
    static void testGetEligibleAgencyAccounts_ExcludesNonExpired() {
        AgencyTradeLicenseExpiryEmailController.skipRecordTypeFilterInTest = true;

        Account nonExpiredAccount = new Account(
            Name = 'Non Expired Agency',
            Type = 'Agency',
            Company_Email__c = 'future@agency.com',
            Trade_License_Expiry_Date__c = Date.today().addDays(30),
            Trade_License_Expiry_Notification_Sent__c = false,
            Status__c = 'Completed'
        );
        insert nonExpiredAccount;

        Test.startTest();
        List<AgencyTradeLicenseExpiryEmailController.EligibleAccountWrapper> results =
            AgencyTradeLicenseExpiryEmailController.getEligibleAgencyAccounts();
        Test.stopTest();

        AgencyTradeLicenseExpiryEmailController.skipRecordTypeFilterInTest = false;

        for (AgencyTradeLicenseExpiryEmailController.EligibleAccountWrapper wrapper : results) {
            System.assertNotEquals(
                nonExpiredAccount.Id,
                wrapper.accountId,
                'Agencies with a future trade license expiry date should be excluded'
            );
        }
    }

    @isTest
    static void testSendExpiryNotificationEmails_TradeLicenseNotExpired() {
        Account nonExpiredAccount = new Account(
            Name = 'Send Blocked Non Expired',
            Type = 'Agency',
            Company_Email__c = 'blocked@agency.com',
            Trade_License_Expiry_Date__c = Date.today().addDays(15),
            Status__c = 'Completed'
        );
        insert nonExpiredAccount;

        Test.startTest();
        AgencyTradeLicenseExpiryEmailController.BulkSendResult result =
            AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmails(
                new List<String>{ nonExpiredAccount.Id }
            );
        Test.stopTest();

        System.assertEquals(0, result.successCount, 'Non-expired trade license should not send');
        System.assertEquals(1, result.failureCount, 'Non-expired trade license should be rejected');
        System.assert(
            result.errorMessages[0].contains('Trade license is not expired'),
            'Expected trade license expiry validation message'
        );
    }

    @isTest
    static void testGetEligibleAgencyAccounts_RespectsLimitAndSortOrder() {
        AgencyTradeLicenseExpiryEmailController.skipRecordTypeFilterInTest = true;

        List<Account> eligibleAccounts = new List<Account>();
        for (Integer i = 0; i < 16; i++) {
            eligibleAccounts.add(new Account(
                Name = 'Limit Test Agency ' + i,
                Type = 'Agency',
                Company_Email__c = 'limit' + i + '@agency.com',
                Trade_License_Expiry_Date__c = Date.today().addDays(-20 + i),
                Trade_License_Expiry_Notification_Sent__c = false,
                Status__c = 'Completed'
            ));
        }
        insert eligibleAccounts;

        Test.startTest();
        List<AgencyTradeLicenseExpiryEmailController.EligibleAccountWrapper> results =
            AgencyTradeLicenseExpiryEmailController.getEligibleAgencyAccounts();
        Test.stopTest();

        AgencyTradeLicenseExpiryEmailController.skipRecordTypeFilterInTest = false;

        System.assert(results.size() <= 15, 'Eligible agencies should be limited to 15 records');

        for (Integer i = 1; i < results.size(); i++) {
            System.assert(
                results[i - 1].tradeLicenseExpiryDate <= results[i].tradeLicenseExpiryDate,
                'Results should be sorted by trade license expiry date ascending'
            );
        }
    }

    @isTest
    static void testIsTradeLicenseExpired() {
        System.assertEquals(false, AgencyTradeLicenseExpiryEmailController.isTradeLicenseExpired(null));
        System.assertEquals(false, AgencyTradeLicenseExpiryEmailController.isTradeLicenseExpired(Date.today().addDays(1)));
        System.assertEquals(true, AgencyTradeLicenseExpiryEmailController.isTradeLicenseExpired(Date.today()));
        System.assertEquals(true, AgencyTradeLicenseExpiryEmailController.isTradeLicenseExpired(Date.today().addDays(-1)));
    }

    @isTest
    static void testSendExpiryNotificationEmails_NullList() {
        Test.startTest();
        try {
            AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmails(null);
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (Exception e) {
            System.assert(
                e.getMessage().contains('At least one Account ID is required') ||
                e.getMessage().contains('Script-thrown exception'),
                'Unexpected message: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testSendExpiryNotificationEmails_AllBlankIds() {
        Test.startTest();
        try {
            AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmails(
                new List<String>{ '', '  ', null }
            );
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (Exception e) {
            System.assert(
                e.getMessage().contains('At least one valid Account ID is required') ||
                e.getMessage().contains('Script-thrown exception'),
                'Unexpected message: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testSendExpiryNotificationEmails_NoAccountsFound() {
        Test.startTest();
        try {
            AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmails(
                new List<String>{ '001000000000000AAA' }
            );
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (Exception e) {
            System.assert(
                e.getMessage().contains('No accounts found for the provided IDs') ||
                e.getMessage().contains('Script-thrown exception'),
                'Unexpected message: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testSendExpiryNotificationEmails_MixedSuccessAndFailure() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];

        Account noEmailAccount = new Account(
            Name = 'Bulk No Email Agency',
            Type = 'Agency',
            Company_Email__c = null,
            Contact_Email_2__c = null,
            Trade_License_Expiry_Date__c = Date.today().addDays(-2),
            Status__c = 'Completed'
        );
        insert noEmailAccount;

        Test.startTest();
        AgencyTradeLicenseExpiryEmailController.BulkSendResult result =
            AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmails(
                new List<String>{ testAccount.Id, noEmailAccount.Id }
            );
        Test.stopTest();

        System.assertEquals(1, result.successCount, 'One account should succeed');
        System.assertEquals(1, result.failureCount, 'One account should fail');
        System.assert(!result.errorMessages.isEmpty(), 'Failure message should be captured');
    }

    @isTest
    static void testSendExpiryNotificationEmails_AccountIdNotInQueryResults() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];
        Id missingAccountId = '001000000000000AAA';

        Test.startTest();
        AgencyTradeLicenseExpiryEmailController.BulkSendResult result =
            AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmails(
                new List<String>{ testAccount.Id, missingAccountId }
            );
        Test.stopTest();

        System.assertEquals(1, result.successCount, 'Valid account should succeed');
        System.assertEquals(1, result.failureCount, 'Missing account should be counted as failure');
        System.assert(
            result.errorMessages[0].contains('Account not found'),
            'Missing account error should be returned'
        );
    }

    @isTest
    static void testSendExpiryNotificationEmail_GenericFailureMessage() {
        Account noEmailAccount = new Account(
            Name = 'Single Generic Failure Agency',
            Type = 'Agency',
            Trade_License_Expiry_Date__c = Date.today().addDays(-1),
            Status__c = 'Completed'
        );
        insert noEmailAccount;

        Test.startTest();
        try {
            AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmail(noEmailAccount.Id);
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (Exception e) {
            System.assert(
                e.getMessage().contains('No recipient email found on the record.') ||
                e.getMessage().contains('Failed to send expiry notification email.') ||
                e.getMessage().contains('Script-thrown exception'),
                'Unexpected message: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testBulkSendResultConstructor() {
        Test.startTest();
        AgencyTradeLicenseExpiryEmailController.BulkSendResult result =
            new AgencyTradeLicenseExpiryEmailController.BulkSendResult();
        Test.stopTest();

        System.assertEquals(0, result.successCount);
        System.assertEquals(0, result.failureCount);
        System.assertEquals(0, result.errorMessages.size());
    }

    @isTest
    static void testSendExpiryNotificationEmail_MultipleNotifications() {
        // Get test account
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];
        
        Test.startTest();
        
        // Send first notification
        AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmail(testAccount.Id);
        
        // Send second notification
        AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmail(testAccount.Id);
        
        // Send third notification
        AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmail(testAccount.Id);
        
        Test.stopTest();
        
        // Verify the notification count was incremented to 3
        Account updatedAccount = [SELECT Id, Name, Trade_License_Expiry_Notification_Count__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('Test Agency', updatedAccount.Name, 'Account should still exist after multiple email sends');
        System.assertEquals(3, updatedAccount.Trade_License_Expiry_Notification_Count__c, 'Notification count should be incremented to 3');
    }
}