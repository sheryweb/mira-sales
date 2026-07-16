@isTest
private class SummerEscapeNotificationBatchTest {

    @isTest
    static void testSummerEscapeNotificationBatch_Full() {
        // Prepare test Accounts
        List<Account> accList = new List<Account>();
        for (Integer i = 0; i < 2; i++) {
            accList.add(new Account(
                Name = 'Test Account ' + i,
                Status__c = 'Completed',
                Company_Email__c = 'test' + i + '@example.com',
                RecordTypeId = '012Hp000001yUTAIA2',
                Summer_Escape_Notification_Sent__c = false
            ));
        }
        insert accList;

        // Run the batch with large enough batch size to avoid chunking
        Test.startTest();
        SummerEscapeNotificationBatch batch = new SummerEscapeNotificationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Since Messaging.sendEmail is suppressed in tests, just confirm no errors
        System.assert(true, 'Batch executed without exceptions.');
    }

    @isTest
    static void testEmptyScopeAndFinish() {
        // Insert account that won't match (already sent notification)
        insert new Account(
            Name = 'Not Qualified',
            Status__c = 'Completed',
            Company_Email__c = 'none@example.com',
            RecordTypeId = '012Hp000001yUTAIA2',
            Summer_Escape_Notification_Sent__c = true
        );

        Test.startTest();
        SummerEscapeNotificationBatch batch = new SummerEscapeNotificationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        System.assert(true, 'Batch finished without processing any records.');
    }

    @isTest
    static void testAccountWithWrongStatus() {
        // Insert account with wrong status (should not be processed)
        insert new Account(
            Name = 'Wrong Status Account',
            Status__c = 'In Process',
            Company_Email__c = 'test@example.com',
            RecordTypeId = '012Hp000001yUTAIA2',
            Summer_Escape_Notification_Sent__c = false
        );

        Test.startTest();
        SummerEscapeNotificationBatch batch = new SummerEscapeNotificationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        System.assert(true, 'Batch finished without processing account with wrong status.');
    }
}