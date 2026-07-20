/**
 * Tests for ReceiptCreateController (Generate Receipt popup wizard backend). Engine flag ON so we
 * confirm Received/Paid/Status derive after the Receipt + payment lines are inserted.
 */
@IsTest
private class ReceiptCreateControllerTest {

    private class Ctx {
        Unit__c unit;
        Account acc;
        Opportunity opp;
        Cash_Flow__c cf1;
        Invoice__c inv;
    }

    private static String pickBookingStage() {
        for (Schema.PicklistEntry e : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                String v = e.getValue();
                if (v != 'New' && v != 'Cancelled' && v != 'Transferred') return v;
            }
        }
        return null;
    }

    private static String pickDepositTo() {
        for (Schema.PicklistEntry e : Receipt__c.Deposited_To__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) return e.getValue();
        }
        return null;
    }

    /** First active mode of payment that isn't Cheque/POS (so conditional fields aren't required). */
    private static String pickSimpleMode() {
        String fallback;
        for (Schema.PicklistEntry e : Receipt_Amount__c.Mode_of_Payment__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                if (fallback == null) fallback = e.getValue();
                if (e.getValue() != 'Cheque' && e.getValue() != 'POS Machine') return e.getValue();
            }
        }
        return fallback;
    }

    private static Ctx build(Boolean withBooking) {
        insert new Financial_Engine_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(), Engine_Owns_Totals__c = true
        );
        Ctx c = new Ctx();
        c.unit = new Unit__c(Title__c = 'rcpt-unit', Building__c = 'B1');
        insert c.unit;

        Cash_Flow_Sum__c s = new Cash_Flow_Sum__c(Name = 'CFS', Unit__c = c.unit.Id);
        insert s;
        c.cf1 = new Cash_Flow__c(Name = 'Down Payment', Unit__c = c.unit.Id, Cash_Flow_Sum__c = s.Id,
            Date__c = Date.today().addMonths(-1), Constant__c = 1000, Received_Amount__c = 0,
            Installment_Milestone__c = '1st Installment', Percent__c = 10);
        insert c.cf1;

        c.inv = new Invoice__c(Status__c = 'Pending', Invoice_Date__c = Date.today(),
            Sub_Total_Amount__c = 1000, VAT_Amount__c = 0, Paid_Amount__c = 0, Unit__c = c.unit.Id);
        insert c.inv;
        insert new Milestone_Invoice__c(Invoice__c = c.inv.Id, Cash_Flow__c = c.cf1.Id, Amount__c = 1000);

        if (withBooking) {
            c.acc = new Account(Name = 'Test Client');
            insert c.acc;
            c.opp = new Opportunity(Name = 'Booking Opp', StageName = pickBookingStage(),
                CloseDate = Date.today().addDays(30), AccountId = c.acc.Id, Unit__c = c.unit.Id);
            insert c.opp;
            c.opp.StageName = 'Booked';
            update c.opp;
        }
        return c;
    }

    private static ReceiptCreateController.CreateRequest baseRequest(Ctx c) {
        ReceiptCreateController.CreateRequest req = new ReceiptCreateController.CreateRequest();
        req.unitId = c.unit.Id;
        req.paymentDate = Date.today();
        req.depositedTo = pickDepositTo();
        req.status = 'Reconciled';
        req.description = 'Test receipt';
        req.lines = new List<ReceiptCreateController.PaymentLine>();
        return req;
    }

    private static ReceiptCreateController.PaymentLine line(Ctx c, Decimal amount) {
        ReceiptCreateController.PaymentLine ln = new ReceiptCreateController.PaymentLine();
        ln.invoiceId = c.inv.Id;
        ln.amount = amount;
        ln.modeOfPayment = pickSimpleMode();
        ln.referenceNumber = 'REF-1';
        return ln;
    }

    // ---- guard / validation ----------------------------------------------------------------------

    @IsTest
    static void getContextBlocksWhenNoBooking() {
        Ctx c = build(false);
        Test.startTest();
        ReceiptCreateController.CreateContext ctx = ReceiptCreateController.getContext(c.unit.Id);
        Test.stopTest();
        System.assertEquals(false, ctx.canProceed, 'Blocked without a booking');
        System.assert(ctx.blockReason != null && ctx.blockReason.containsIgnoreCase('booking'), ctx.blockReason);
    }

    @IsTest
    static void createReceiptRejectsNoLines() {
        Ctx c = build(true);
        Boolean threw = false;
        Test.startTest();
        try {
            ReceiptCreateController.createReceipt(JSON.serialize(baseRequest(c)));
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'No payment lines should throw');
    }

    @IsTest
    static void createReceiptRejectsChequeWithoutNumber() {
        Ctx c = build(true);
        ReceiptCreateController.CreateRequest req = baseRequest(c);
        ReceiptCreateController.PaymentLine ln = line(c, 500);
        ln.modeOfPayment = 'Cheque'; // but no cheque number/date/bank
        req.lines.add(ln);
        Boolean threw = false;
        Test.startTest();
        try {
            ReceiptCreateController.createReceipt(JSON.serialize(req));
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Cheque line without cheque details should throw');
    }

    // ---- happy path ------------------------------------------------------------------------------

    @IsTest
    static void getContextReturnsPayableInvoicesAndPicklists() {
        Ctx c = build(true);
        Test.startTest();
        ReceiptCreateController.CreateContext ctx = ReceiptCreateController.getContext(c.unit.Id);
        Test.stopTest();
        System.assertEquals(true, ctx.canProceed, 'Should proceed with booking');
        System.assertEquals(c.opp.Id, ctx.opportunityId, 'Booking resolved');
        System.assertEquals(1, ctx.invoices.size(), 'One payable invoice');
        System.assertEquals(1000, ctx.invoices[0].pending, 'Pending reflects the invoice');
        System.assert(ctx.depositToOptions.size() > 0 && ctx.modeOfPaymentOptions.size() > 0, 'Picklists provided');
    }

    @IsTest
    static void createReceiptFullyPaid() {
        Ctx c = build(true);
        ReceiptCreateController.CreateRequest req = baseRequest(c);
        req.lines.add(line(c, 1000)); // pays the full pending
        Test.startTest();
        Id recId = ReceiptCreateController.createReceipt(JSON.serialize(req));
        Test.stopTest();

        System.assertNotEquals(null, recId, 'Receipt created');
        Receipt__c rec = [
            SELECT Unit__c, Opportunity__c, Account__c, Status__c, Payment_Status__c,
                   Payable_Amount__c, Received_Amount__c
            FROM Receipt__c WHERE Id = :recId
        ];
        System.assertEquals(c.unit.Id, rec.Unit__c, 'Unit set');
        System.assertEquals('Reconciled', rec.Status__c, 'Status set');
        System.assertEquals('Fully Paid', rec.Payment_Status__c, 'Fully paid (received >= payable)');
        System.assertEquals(1000, rec.Payable_Amount__c, 'Payable = invoice pending');
        System.assertEquals(1000, rec.Received_Amount__c, 'Received derived by engine from the line');

        System.assertEquals(1, [SELECT COUNT() FROM Receipt_Amount__c WHERE Receipt__c = :recId],
            'One payment line');
        System.assertEquals(1, [SELECT COUNT() FROM Receipt_Invoice__c WHERE Receipt__c = :recId],
            'One receipt-invoice junction');

        Invoice__c inv = [SELECT Paid_Amount__c, Status__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals(1000, inv.Paid_Amount__c, 'Engine derived invoice paid');
        System.assertEquals('Fully Paid', inv.Status__c, 'Engine derived invoice status');
    }

    @IsTest
    static void createReceiptPartiallyPaid() {
        Ctx c = build(true);
        ReceiptCreateController.CreateRequest req = baseRequest(c);
        req.lines.add(line(c, 400)); // less than the 1000 pending
        Test.startTest();
        Id recId = ReceiptCreateController.createReceipt(JSON.serialize(req));
        Test.stopTest();

        Receipt__c rec = [SELECT Payment_Status__c, Payable_Amount__c FROM Receipt__c WHERE Id = :recId];
        System.assertEquals('Partially Paid', rec.Payment_Status__c, 'Partially paid (received < payable)');

        Receipt_Invoice__c ri = [SELECT Amount__c, Status__c FROM Receipt_Invoice__c WHERE Receipt__c = :recId LIMIT 1];
        System.assertEquals(400, ri.Amount__c, 'Junction amount = amount paid to this invoice');
        System.assertEquals('Partially Paid', ri.Status__c, 'Junction status reflects partial coverage');

        Invoice__c inv = [SELECT Paid_Amount__c, Status__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals(400, inv.Paid_Amount__c, 'Engine derived partial paid');
        System.assertEquals('Partially Paid', inv.Status__c, 'Engine derived partial status');
    }
}
