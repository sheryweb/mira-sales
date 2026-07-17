/**
 * Tests for ReceiptManageController (Step 6a) — the guided receipt-edit actions.
 * Runs with the engine flag ON so we also confirm totals self-heal through each action,
 * and that the Receipt_Invoice__c link (read by the PDF) stays in sync.
 */
@IsTest
private class ReceiptManageControllerTest {

    private class Ctx {
        Unit__c u;
        Cash_Flow__c cf;
        Invoice__c inv;
        Receipt__c r;
        Receipt_Amount__c ra;
        Receipt_Invoice__c ri;
    }

    private static Ctx build() {
        insert new Financial_Engine_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(), Engine_Owns_Totals__c = true
        );
        Ctx c = new Ctx();
        c.u = new Unit__c(Title__c = 'mng');
        insert c.u;
        Cash_Flow_Sum__c s = new Cash_Flow_Sum__c(Name = 'CFS', Unit__c = c.u.Id);
        insert s;
        c.cf = new Cash_Flow__c(
            Name = 'M1', Unit__c = c.u.Id, Cash_Flow_Sum__c = s.Id,
            Date__c = System.today().addDays(-5), Constant__c = 1000, Received_Amount__c = 0
        );
        insert c.cf;
        c.inv = new Invoice__c(
            Status__c = 'Pending', Invoice_Date__c = System.today(), Sub_Total_Amount__c = 1000,
            Paid_Amount__c = 0, Unit__c = c.u.Id, Invoice_Number__c = 'INV-MNG'
        );
        insert c.inv;
        insert new Milestone_Invoice__c(Invoice__c = c.inv.Id, Cash_Flow__c = c.cf.Id);
        c.r = new Receipt__c(
            Description__c = 'R', Unit__c = c.u.Id, Payment_Date__c = System.today(),
            Received_Amount__c = 1000, Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid'
        );
        insert c.r;
        c.ra = new Receipt_Amount__c(Receipt__c = c.r.Id, Invoice__c = c.inv.Id, Amount__c = 1000, Mode_of_Payment__c = 'Cash');
        insert c.ra;
        c.ri = new Receipt_Invoice__c(Receipt__c = c.r.Id, Invoice__c = c.inv.Id, Amount__c = 1000);
        insert c.ri;
        return c;
    }

    @IsTest
    static void getReceiptReturnsAllocations() {
        Ctx c = build();
        Test.startTest();
        ReceiptManageController.ReceiptView v = ReceiptManageController.getReceipt(c.r.Id);
        Test.stopTest();

        System.assertEquals(c.r.Id, v.receiptId, 'Receipt id');
        System.assertEquals(false, v.cancelled, 'Not cancelled initially');
        System.assertEquals(1, v.allocations.size(), 'One allocation line');
        System.assertEquals(c.inv.Id, v.allocations[0].invoiceId, 'Allocation points at the invoice');
        System.assertEquals(1000, v.allocations[0].amount, 'Line amount shown');
    }

    @IsTest
    static void updateAllocationReducesAndSelfHeals() {
        Ctx c = build();
        Test.startTest();
        ReceiptManageController.updateAllocationAmount(c.ra.Id, 600);
        Test.stopTest();

        Receipt_Amount__c ra = [SELECT Amount__c FROM Receipt_Amount__c WHERE Id = :c.ra.Id];
        System.assertEquals(600, ra.Amount__c, 'Line reduced to 600');
        Receipt_Invoice__c ri = [SELECT Amount__c FROM Receipt_Invoice__c WHERE Id = :c.ri.Id];
        System.assertEquals(600, ri.Amount__c, 'Receipt_Invoice synced to 600 (PDF stays correct)');
        Invoice__c inv = [SELECT Paid_Amount__c, Status__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals(600, inv.Paid_Amount__c, 'Invoice paid re-derived to 600');
        System.assertEquals('Partially Paid', inv.Status__c, 'Status re-derived');
    }

    @IsTest
    static void removeAllocationDropsLinkAndReverts() {
        Ctx c = build();
        Test.startTest();
        ReceiptManageController.removeAllocation(c.ra.Id);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Receipt_Amount__c WHERE Id = :c.ra.Id], 'Line deleted');
        System.assertEquals(0, [SELECT COUNT() FROM Receipt_Invoice__c WHERE Receipt__c = :c.r.Id AND Invoice__c = :c.inv.Id],
            'Receipt_Invoice link removed when no lines remain');
        Invoice__c inv = [SELECT Paid_Amount__c, Status__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals(0, inv.Paid_Amount__c, 'Invoice paid reverted to 0');
        System.assertEquals('Pending', inv.Status__c, 'Status reverted to Pending');
    }

    @IsTest
    static void cancelReceiptExcludesFromTotals() {
        Ctx c = build();
        Test.startTest();
        ReceiptManageController.cancelReceipt(c.r.Id);
        Test.stopTest();

        Receipt__c r = [SELECT Payment_Status__c FROM Receipt__c WHERE Id = :c.r.Id];
        System.assertEquals('Cancelled', r.Payment_Status__c, 'Receipt soft-cancelled');
        Invoice__c inv = [SELECT Paid_Amount__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals(0, inv.Paid_Amount__c, 'Cancelled receipt excluded from invoice paid');
        Cash_Flow__c cf = [SELECT Received_Amount__c FROM Cash_Flow__c WHERE Id = :c.cf.Id];
        System.assertEquals(0, cf.Received_Amount__c, 'Cancelled receipt excluded from cash flow');
    }

    @IsTest
    static void badInputThrows() {
        Ctx c = build();
        Test.startTest();
        try {
            ReceiptManageController.updateAllocationAmount(c.ra.Id, -5);
            System.assert(false, 'Negative amount should throw');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}
