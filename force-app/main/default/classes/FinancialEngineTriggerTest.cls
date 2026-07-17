/**
 * End-to-end tests for the self-healing triggers (Step 5b) with the engine flag ON.
 * Verifies totals self-heal on insert / update / delete / cancel of the input records,
 * and that the legacy create path (ReceiptRecordInsert) does NOT double-count when the
 * engine owns the totals.
 */
@IsTest
private class FinancialEngineTriggerTest {

    private static void enableEngine() {
        insert new Financial_Engine_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Engine_Owns_Totals__c = true
        );
    }

    private class Ctx {
        Unit__c u;
        Cash_Flow__c cf;
        Invoice__c inv;
    }

    /** unit + one 1000 cash flow + one 1000 invoice linked to it. No receipts yet. */
    private static Ctx baseCtx(String tag) {
        Ctx c = new Ctx();
        c.u = new Unit__c(Title__c = tag);
        insert c.u;
        Cash_Flow_Sum__c s = new Cash_Flow_Sum__c(Name = 'CFS', Unit__c = c.u.Id);
        insert s;
        c.cf = new Cash_Flow__c(
            Name = 'M1', Unit__c = c.u.Id, Cash_Flow_Sum__c = s.Id,
            Date__c = System.today().addDays(-5), Constant__c = 1000, Received_Amount__c = 0
        );
        insert c.cf;
        c.inv = new Invoice__c(
            Status__c = 'Pending', Invoice_Date__c = System.today(),
            Sub_Total_Amount__c = 1000, Paid_Amount__c = 0, Unit__c = c.u.Id,
            Invoice_Number__c = 'INV-' + tag
        );
        insert c.inv;
        insert new Milestone_Invoice__c(Invoice__c = c.inv.Id, Cash_Flow__c = c.cf.Id);
        return c;
    }

    private static Receipt__c newReceipt(Id unitId, String tag) {
        Receipt__c r = new Receipt__c(
            Description__c = tag, Unit__c = unitId, Payment_Date__c = System.today(),
            Received_Amount__c = 0, Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid'
        );
        insert r;
        return r;
    }

    @IsTest
    static void selfHealsOnInsert() {
        enableEngine();
        Ctx c = baseCtx('ins');
        Receipt__c r = newReceipt(c.u.Id, 'r');

        Test.startTest();
        insert new Receipt_Amount__c(Receipt__c = r.Id, Invoice__c = c.inv.Id, Amount__c = 1000);
        Test.stopTest();

        Invoice__c inv = [SELECT Paid_Amount__c, Status__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals(1000, inv.Paid_Amount__c, 'Invoice paid healed on line insert');
        System.assertEquals('Fully Paid', inv.Status__c, 'Status healed');
        Cash_Flow__c cf = [SELECT Received_Amount__c FROM Cash_Flow__c WHERE Id = :c.cf.Id];
        System.assertEquals(1000, cf.Received_Amount__c, 'Cash flow received healed');
        System.assertEquals(1, [SELECT COUNT() FROM Milestone_Receipt__c WHERE Receipt__c = :r.Id], 'Ledger row built');
    }

    @IsTest
    static void selfHealsOnUpdate() {
        enableEngine();
        Ctx c = baseCtx('upd');
        Receipt__c r = newReceipt(c.u.Id, 'r');
        Receipt_Amount__c ra = new Receipt_Amount__c(Receipt__c = r.Id, Invoice__c = c.inv.Id, Amount__c = 1000);
        insert ra;

        Test.startTest();
        update new Receipt_Amount__c(Id = ra.Id, Amount__c = 600); // reduce
        Test.stopTest();

        Invoice__c inv = [SELECT Paid_Amount__c, Status__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals(600, inv.Paid_Amount__c, 'Invoice paid re-derived down to 600');
        System.assertEquals('Partially Paid', inv.Status__c, 'Status back to Partially Paid');
        Cash_Flow__c cf = [SELECT Received_Amount__c FROM Cash_Flow__c WHERE Id = :c.cf.Id];
        System.assertEquals(600, cf.Received_Amount__c, 'Cash flow received re-derived down to 600');
    }

    @IsTest
    static void selfHealsOnDelete() {
        enableEngine();
        Ctx c = baseCtx('del');
        Receipt__c r = newReceipt(c.u.Id, 'r');
        Receipt_Amount__c ra = new Receipt_Amount__c(Receipt__c = r.Id, Invoice__c = c.inv.Id, Amount__c = 1000);
        insert ra;

        Test.startTest();
        delete ra;
        Test.stopTest();

        Invoice__c inv = [SELECT Paid_Amount__c, Status__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals(0, inv.Paid_Amount__c, 'Invoice paid reverted to 0 on delete');
        System.assertEquals('Pending', inv.Status__c, 'Status reverted to Pending');
        Cash_Flow__c cf = [SELECT Received_Amount__c FROM Cash_Flow__c WHERE Id = :c.cf.Id];
        System.assertEquals(0, cf.Received_Amount__c, 'Cash flow received reverted to 0');
        System.assertEquals(0, [SELECT COUNT() FROM Milestone_Receipt__c WHERE Receipt__c = :r.Id], 'Ledger rows removed');
    }

    @IsTest
    static void cancelReceiptExcludesIt() {
        enableEngine();
        Ctx c = baseCtx('can');
        Receipt__c r = newReceipt(c.u.Id, 'r');
        insert new Receipt_Amount__c(Receipt__c = r.Id, Invoice__c = c.inv.Id, Amount__c = 1000);

        Test.startTest();
        update new Receipt__c(Id = r.Id, Payment_Status__c = 'Cancelled'); // soft-cancel
        Test.stopTest();

        Invoice__c inv = [SELECT Paid_Amount__c, Status__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals(0, inv.Paid_Amount__c, 'Cancelled receipt no longer counts');
        System.assertEquals('Pending', inv.Status__c, 'Status reverted to Pending');
        Cash_Flow__c cf = [SELECT Received_Amount__c FROM Cash_Flow__c WHERE Id = :c.cf.Id];
        System.assertEquals(0, cf.Received_Amount__c, 'Cash flow excludes cancelled receipt');
    }

    @IsTest
    static void legacyCreatePathDoesNotDoubleCount() {
        // With the flag ON, ReceiptRecordInsert must defer totals to the engine (via triggers)
        // and skip its own incremental math, so the cash flow receives 1000, not 2000.
        enableEngine();
        Ctx c = baseCtx('legacy');

        Receipt__c receipt = new Receipt__c(
            Description__c = 'legacy', Unit__c = c.u.Id, Payment_Date__c = System.today(),
            Received_Amount__c = 1000, Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid'
        );
        ReceiptRecordInsert.RequestWrapper req = new ReceiptRecordInsert.RequestWrapper();
        req.receiptRecordAll = new List<Receipt__c>{ receipt };
        req.receiptAmountAll = new List<Receipt_Amount__c>{
            new Receipt_Amount__c(Invoice__c = c.inv.Id, Amount__c = 1000)
        };

        Test.startTest();
        ReceiptRecordInsert.processReceipts(new List<ReceiptRecordInsert.RequestWrapper>{ req });
        Test.stopTest();

        Cash_Flow__c cf = [SELECT Received_Amount__c FROM Cash_Flow__c WHERE Id = :c.cf.Id];
        System.assertEquals(1000, cf.Received_Amount__c, 'No double count: cash flow = 1000, not 2000');
        Invoice__c inv = [SELECT Paid_Amount__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals(1000, inv.Paid_Amount__c, 'Invoice paid = 1000');
    }
}
