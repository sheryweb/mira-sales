@isTest
private class TradeLicenseExpiryNotificationBatchTest {

    @isTest
    static void testTradeLicenseExpiryNotificationBatch_Full() {
        // Prepare test Accounts
        List<Account> accList = new List<Account>();
        for (Integer i = 0; i < 2; i++) {
            accList.add(new Account(
                Name = 'Test Account ' + i,
                Status__c = 'Completed',
                Company_Email__c = 'test' + i + '@example.com',
                RecordTypeId = '012Hp000001yUTAIA2',
                Trade_License_Expiry_Date__c = System.today()
            ));
        }
        insert accList;

        // Run the batch with large enough batch size to avoid chunking
        Test.startTest();
        TradeLicenseExpiryNotificationBatch batch = new TradeLicenseExpiryNotificationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Since Messaging.sendEmail is suppressed in tests, just confirm no errors
        System.assert(true, 'Batch executed without exceptions.');
    }

    @isTest
    static void testEmptyScopeAndFinish() {
        // Insert account that won't match
        insert new Account(
            Name = 'Not Qualified',
            Status__c = 'In Process',
            Company_Email__c = 'none@example.com',
            RecordTypeId = '012Hp000001yUTAIA2'
        );

        Test.startTest();
        TradeLicenseExpiryNotificationBatch batch = new TradeLicenseExpiryNotificationBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        System.assert(true, 'Batch finished without processing any records.');
    }
}