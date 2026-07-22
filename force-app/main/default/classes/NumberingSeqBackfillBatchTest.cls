@IsTest
private class NumberingSeqBackfillBatchTest {

    private static Unit__c makeUnit(String projectName, String code) {
        Project__c p = new Project__c(
            Name = projectName,
            Description__c = 'Backfill test project',
            District__c = 'Meydan',
            Coordinates_Latitude__c = 1.0,
            Coordinates_Longitude__c = 1.0,
            Handover__c = Date.today(),
            Minimum_Cost__c = 1000000,
            Publish_Project__c = 'Published',
            Project_Code__c = code,
            Voucher_Code__c = 'BTL'
        );
        insert p;
        Unit__c u = new Unit__c(
            Project__c = p.Id,
            Building__c = 'B1',
            Title__c = 'Unit 1',
            Property_Code_Text__c = code + '-U1'
        );
        insert u;
        return u;
    }

    @IsTest
    static void backfillsInvoiceSeqFromLegacyCounter() {
        Unit__c u = makeUnit('MIRA Villas Designed by Bentley Home', 'BF-INV-001');

        // Seed a legacy invoice with the old counter set and the new field empty.
        InvoiceTriggerHelper.skipTrigger = true;
        Invoice__c inv = new Invoice__c(
            Unit__c = u.Id,
            Invoice_Number_To_Process_Bentley__c = 42,
            Invoice_Number__c = 'INV-BTL-42'
        );
        insert inv;
        InvoiceTriggerHelper.skipTrigger = false;

        System.assertEquals(null,
            [SELECT Invoice_Seq__c FROM Invoice__c WHERE Id = :inv.Id].Invoice_Seq__c,
            'Precondition: new sequence field should start empty');

        Test.startTest();
        Database.executeBatch(NumberingSeqBackfillBatch.forInvoices(), 200);
        Test.stopTest();

        System.assertEquals(42,
            [SELECT Invoice_Seq__c FROM Invoice__c WHERE Id = :inv.Id].Invoice_Seq__c,
            'Invoice_Seq__c should be backfilled from the legacy Bentley counter');
    }

    @IsTest
    static void backfillsVoucherSeqFromLegacyCounter() {
        Unit__c u = makeUnit('MIRA Villas Designed by Bentley Home', 'BF-RCT-001');

        ReceiptTriggerHelper.skipTrigger = true;
        Receipt__c rec = new Receipt__c(
            Unit__c = u.Id,
            Voucher_Number_To_Process_Bentley__c = 17,
            Description__c = 'Legacy receipt',
            Payment_Date__c = Date.today(),
            Payable_Amount__c = 1000,
            Status__c = 'Reconciled'
        );
        insert rec;
        ReceiptTriggerHelper.skipTrigger = false;

        System.assertEquals(null,
            [SELECT Voucher_Seq__c FROM Receipt__c WHERE Id = :rec.Id].Voucher_Seq__c,
            'Precondition: new sequence field should start empty');

        Test.startTest();
        Database.executeBatch(NumberingSeqBackfillBatch.forReceipts(), 200);
        Test.stopTest();

        System.assertEquals(17,
            [SELECT Voucher_Seq__c FROM Receipt__c WHERE Id = :rec.Id].Voucher_Seq__c,
            'Voucher_Seq__c should be backfilled from the legacy Bentley counter');
    }

    @IsTest
    static void backfillUsesOwnProjectCounterDespiteStrayCounter() {
        // Regression: a John Richmond receipt that also carries a stray Gianfranco counter must
        // be backfilled from its OWN project's (Richmond) counter, not the first non-null one.
        Unit__c u = makeUnit('John Richmond Residences', 'BF-JRD-001');

        ReceiptTriggerHelper.skipTrigger = true;
        Receipt__c rec = new Receipt__c(
            Unit__c = u.Id,
            Voucher_Number_To_Process_Gianfranco__c = 1,   // stray value from bad legacy data
            Voucher_Number_To_Process_Richmond__c = 143,   // the real, project-specific counter
            Description__c = 'JRD receipt with stray counter',
            Payment_Date__c = Date.today(),
            Payable_Amount__c = 1000,
            Status__c = 'Reconciled'
        );
        insert rec;
        ReceiptTriggerHelper.skipTrigger = false;

        Test.startTest();
        Database.executeBatch(NumberingSeqBackfillBatch.forReceipts(), 200);
        Test.stopTest();

        System.assertEquals(143,
            [SELECT Voucher_Seq__c FROM Receipt__c WHERE Id = :rec.Id].Voucher_Seq__c,
            'Must use the John Richmond counter (143), not the stray Gianfranco counter (1)');
    }
}
