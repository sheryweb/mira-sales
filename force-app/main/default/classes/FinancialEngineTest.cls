/**
 * Tests for FinancialEngine.deriveForUnits — the pure, no-DML derivation core (Step 4b).
 * These assert the engine reproduces current receipt-backed create behavior (including the
 * spill-to-next-installment waterfall), FIXES the old cumulative bug, excludes cancelled
 * receipts, and is idempotent.
 */
@IsTest
private class FinancialEngineTest {

    // ---- helpers -------------------------------------------------------------

    private static Unit__c makeUnit(String title) {
        Unit__c u = new Unit__c(Title__c = title);
        insert u;
        return u;
    }

    private static Cash_Flow_Sum__c makeSum(Id unitId) {
        Cash_Flow_Sum__c s = new Cash_Flow_Sum__c(Name = 'CFS', Unit__c = unitId);
        insert s;
        return s;
    }

    // price = Constant (unit has no project, name is not Oqood/DLD/Registration -> Price_Formula = Constant)
    private static Cash_Flow__c makeCF(Id unitId, Id sumId, String name, Integer daysOffset, Decimal price) {
        return new Cash_Flow__c(
            Name = name,
            Unit__c = unitId,
            Cash_Flow_Sum__c = sumId,
            Date__c = System.today().addDays(daysOffset),
            Constant__c = price,
            Received_Amount__c = 0
        );
    }

    private static Invoice__c makeInvoice(Id unitId, Decimal subTotal, Integer daysOffset) {
        Invoice__c inv = new Invoice__c(
            Status__c = 'Pending',
            Invoice_Date__c = System.today().addDays(daysOffset),
            Sub_Total_Amount__c = subTotal,
            Paid_Amount__c = 0,
            Unit__c = unitId,
            Invoice_Number__c = 'INV-' + name(daysOffset)
        );
        return inv;
    }

    private static String name(Integer i) {
        return String.valueOf(i) + '-' + String.valueOf(Math.abs(i) + 1);
    }

    private static Receipt__c makeReceipt(Id unitId, Integer paymentDayOffset, String paymentStatus) {
        return new Receipt__c(
            Description__c = 'R',
            Unit__c = unitId,
            Payment_Date__c = System.today().addDays(paymentDayOffset),
            Received_Amount__c = 0,
            Status__c = 'Reconciled',
            Payment_Status__c = paymentStatus
        );
    }

    // ---- tests ---------------------------------------------------------------

    @IsTest
    static void fullyPaidSingleInvoice() {
        Unit__c u = makeUnit('u1');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        Cash_Flow__c cf = makeCF(u.Id, s.Id, 'M1', -5, 1000);
        insert cf;
        Invoice__c inv = makeInvoice(u.Id, 1000, 0);
        insert inv;
        insert new Milestone_Invoice__c(Invoice__c = inv.Id, Cash_Flow__c = cf.Id);
        Receipt__c r = makeReceipt(u.Id, 0, 'Fully Paid');
        insert r;
        Receipt_Amount__c ra = new Receipt_Amount__c(Receipt__c = r.Id, Invoice__c = inv.Id, Amount__c = 1000);
        insert ra;

        Test.startTest();
        FinancialEngine.DerivationResult res = new FinancialEngine().deriveForUnits(new Set<Id>{ u.Id });
        Test.stopTest();

        System.assertEquals(1000, res.cashFlowReceived.get(cf.Id), 'Cash flow fully received');
        System.assertEquals(1000, res.invoicePaidAmount.get(inv.Id), 'Invoice fully paid');
        System.assertEquals(FinancialEngine.STATUS_FULL, res.invoiceStatus.get(inv.Id), 'Status Fully Paid');
        System.assertEquals(1000, res.receiptReceived.get(r.Id), 'Receipt received = sum of lines');
        System.assertEquals(1000, res.lineCumulative.get(ra.Id), 'Cumulative = 1000');
        System.assertEquals(1, res.ledger.size(), 'One ledger row');
        System.assertEquals(cf.Id, res.ledger[0].cashFlowId, 'Ledger points at the cash flow');
    }

    @IsTest
    static void partiallyPaid() {
        Unit__c u = makeUnit('u2');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        Cash_Flow__c cf = makeCF(u.Id, s.Id, 'M1', -5, 1000);
        insert cf;
        Invoice__c inv = makeInvoice(u.Id, 1000, 0);
        insert inv;
        insert new Milestone_Invoice__c(Invoice__c = inv.Id, Cash_Flow__c = cf.Id);
        Receipt__c r = makeReceipt(u.Id, 0, 'Fully Paid');
        insert r;
        insert new Receipt_Amount__c(Receipt__c = r.Id, Invoice__c = inv.Id, Amount__c = 400);

        Test.startTest();
        FinancialEngine.DerivationResult res = new FinancialEngine().deriveForUnits(new Set<Id>{ u.Id });
        Test.stopTest();

        System.assertEquals(400, res.cashFlowReceived.get(cf.Id), 'Cash flow partially received');
        System.assertEquals(400, res.invoicePaidAmount.get(inv.Id), 'Invoice partially paid');
        System.assertEquals(FinancialEngine.STATUS_PARTIAL, res.invoiceStatus.get(inv.Id), 'Status Partially Paid');
    }

    @IsTest
    static void spillToNextInstallmentIncludingUnlinked() {
        // Mirrors ReceiptRecordInsertTest.testMultipleInvoicesSameUnitCashFlowDistribution:
        // excess payment on invoice2 spills to the unlinked CF3.
        Unit__c u = makeUnit('u3');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        Cash_Flow__c cf1 = makeCF(u.Id, s.Id, 'CF1', -10, 1500);
        Cash_Flow__c cf2 = makeCF(u.Id, s.Id, 'CF2', 0, 1500);
        Cash_Flow__c cf3 = makeCF(u.Id, s.Id, 'CF3', 10, 2000); // unlinked to any invoice
        insert new List<Cash_Flow__c>{ cf1, cf2, cf3 };

        Invoice__c inv1 = makeInvoice(u.Id, 1500, -5);
        Invoice__c inv2 = makeInvoice(u.Id, 1500, 0);
        insert new List<Invoice__c>{ inv1, inv2 };
        insert new List<Milestone_Invoice__c>{
            new Milestone_Invoice__c(Invoice__c = inv1.Id, Cash_Flow__c = cf1.Id),
            new Milestone_Invoice__c(Invoice__c = inv2.Id, Cash_Flow__c = cf2.Id)
        };

        Receipt__c r = makeReceipt(u.Id, 0, 'Fully Paid');
        insert r;
        insert new List<Receipt_Amount__c>{
            new Receipt_Amount__c(Receipt__c = r.Id, Invoice__c = inv1.Id, Amount__c = 1500),
            new Receipt_Amount__c(Receipt__c = r.Id, Invoice__c = inv2.Id, Amount__c = 2500)
        };

        Test.startTest();
        FinancialEngine.DerivationResult res = new FinancialEngine().deriveForUnits(new Set<Id>{ u.Id });
        Test.stopTest();

        System.assertEquals(1500, res.cashFlowReceived.get(cf1.Id), 'CF1 fully received');
        System.assertEquals(1500, res.cashFlowReceived.get(cf2.Id), 'CF2 fully received');
        System.assertEquals(1000, res.cashFlowReceived.get(cf3.Id), 'CF3 gets the spilled excess');
        System.assertEquals(2500, res.invoicePaidAmount.get(inv2.Id), 'Invoice2 paid = 2500');
        System.assertEquals(FinancialEngine.STATUS_FULL, res.invoiceStatus.get(inv2.Id), 'Invoice2 Fully Paid');
    }

    @IsTest
    static void cumulativeAcrossTwoReceipts() {
        Unit__c u = makeUnit('u4');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        Cash_Flow__c cf = makeCF(u.Id, s.Id, 'M1', -5, 2000);
        insert cf;
        Invoice__c inv = makeInvoice(u.Id, 2000, 0);
        insert inv;
        insert new Milestone_Invoice__c(Invoice__c = inv.Id, Cash_Flow__c = cf.Id);

        Receipt__c r1 = makeReceipt(u.Id, -1, 'Fully Paid'); // earlier
        Receipt__c r2 = makeReceipt(u.Id, 0, 'Fully Paid');  // later
        insert new List<Receipt__c>{ r1, r2 };
        Receipt_Amount__c ra1 = new Receipt_Amount__c(Receipt__c = r1.Id, Invoice__c = inv.Id, Amount__c = 500);
        Receipt_Amount__c ra2 = new Receipt_Amount__c(Receipt__c = r2.Id, Invoice__c = inv.Id, Amount__c = 500);
        insert new List<Receipt_Amount__c>{ ra1, ra2 };

        Test.startTest();
        FinancialEngine.DerivationResult res = new FinancialEngine().deriveForUnits(new Set<Id>{ u.Id });
        Test.stopTest();

        System.assertEquals(500, res.lineCumulative.get(ra1.Id), 'First receipt cumulative = 500');
        System.assertEquals(1000, res.lineCumulative.get(ra2.Id), 'Second receipt cumulative = 500 + 500');
        System.assertEquals(1000, res.invoicePaidAmount.get(inv.Id), 'Invoice paid = 1000');
    }

    @IsTest
    static void multipleLinesSameReceiptCumulativeFixed() {
        // The old create path stamped both sibling lines with the same "previous"; the engine
        // accumulates them correctly: 500 then 1000.
        Unit__c u = makeUnit('u5');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        Cash_Flow__c cf = makeCF(u.Id, s.Id, 'M1', -5, 2000);
        insert cf;
        Invoice__c inv = makeInvoice(u.Id, 2000, 0);
        insert inv;
        insert new Milestone_Invoice__c(Invoice__c = inv.Id, Cash_Flow__c = cf.Id);

        Receipt__c r = makeReceipt(u.Id, 0, 'Fully Paid');
        insert r;
        Receipt_Amount__c ra1 = new Receipt_Amount__c(Receipt__c = r.Id, Invoice__c = inv.Id, Amount__c = 500);
        Receipt_Amount__c ra2 = new Receipt_Amount__c(Receipt__c = r.Id, Invoice__c = inv.Id, Amount__c = 500);
        insert new List<Receipt_Amount__c>{ ra1, ra2 };

        Test.startTest();
        FinancialEngine.DerivationResult res = new FinancialEngine().deriveForUnits(new Set<Id>{ u.Id });
        Test.stopTest();

        Decimal c1 = res.lineCumulative.get(ra1.Id);
        Decimal c2 = res.lineCumulative.get(ra2.Id);
        Decimal lo = (c1 <= c2) ? c1 : c2;
        Decimal hi = (c1 <= c2) ? c2 : c1;
        System.assertEquals(500, lo, 'One sibling line cumulative = 500');
        System.assertEquals(1000, hi, 'Other sibling line cumulative = 1000 (bug fixed)');
        System.assertEquals(1000, res.invoicePaidAmount.get(inv.Id), 'Invoice paid = 1000');
    }

    @IsTest
    static void cancelledReceiptExcluded() {
        Unit__c u = makeUnit('u6');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        Cash_Flow__c cf = makeCF(u.Id, s.Id, 'M1', -5, 1000);
        insert cf;
        Invoice__c inv = makeInvoice(u.Id, 1000, 0);
        insert inv;
        insert new Milestone_Invoice__c(Invoice__c = inv.Id, Cash_Flow__c = cf.Id);

        Receipt__c good = makeReceipt(u.Id, -1, 'Fully Paid');
        Receipt__c cancelled = makeReceipt(u.Id, 0, 'Cancelled');
        insert new List<Receipt__c>{ good, cancelled };
        insert new List<Receipt_Amount__c>{
            new Receipt_Amount__c(Receipt__c = good.Id, Invoice__c = inv.Id, Amount__c = 400),
            new Receipt_Amount__c(Receipt__c = cancelled.Id, Invoice__c = inv.Id, Amount__c = 600)
        };

        Test.startTest();
        FinancialEngine.DerivationResult res = new FinancialEngine().deriveForUnits(new Set<Id>{ u.Id });
        Test.stopTest();

        System.assertEquals(400, res.invoicePaidAmount.get(inv.Id), 'Only the non-cancelled receipt counts');
        System.assertEquals(400, res.cashFlowReceived.get(cf.Id), 'Cash flow reflects only the good receipt');
        System.assertEquals(0, res.receiptReceived.get(cancelled.Id), 'Cancelled receipt received = 0');
    }

    @IsTest
    static void cancelledInvoiceFrozen() {
        // A manually-cancelled invoice must be FROZEN: the engine neither re-derives its
        // Paid_Amount/Status nor lets live overpayments spill onto its installment.
        Unit__c u = makeUnit('u_cancel');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        Cash_Flow__c cfLive = makeCF(u.Id, s.Id, 'M1', -5, 1000);
        Cash_Flow__c cfCancelled = makeCF(u.Id, s.Id, 'M2', 0, 1000);
        insert new List<Cash_Flow__c>{ cfLive, cfCancelled };

        Invoice__c invLive = makeInvoice(u.Id, 1000, 0);
        Invoice__c invCancelled = makeInvoice(u.Id, 1000, 1);
        invCancelled.Status__c = 'Cancelled';
        invCancelled.Paid_Amount__c = 1000; // historical value that must be preserved
        insert new List<Invoice__c>{ invLive, invCancelled };
        insert new List<Milestone_Invoice__c>{
            new Milestone_Invoice__c(Invoice__c = invLive.Id, Cash_Flow__c = cfLive.Id),
            new Milestone_Invoice__c(Invoice__c = invCancelled.Id, Cash_Flow__c = cfCancelled.Id)
        };

        // Live receipt overpays its own installment by 500; the cancelled invoice's receipt is
        // itself Cancelled (mirrors real data).
        Receipt__c good = makeReceipt(u.Id, -1, 'Fully Paid');
        Receipt__c dead = makeReceipt(u.Id, 0, 'Cancelled');
        insert new List<Receipt__c>{ good, dead };
        insert new List<Receipt_Amount__c>{
            new Receipt_Amount__c(Receipt__c = good.Id, Invoice__c = invLive.Id, Amount__c = 1500),
            new Receipt_Amount__c(Receipt__c = dead.Id, Invoice__c = invCancelled.Id, Amount__c = 1000)
        };

        Test.startTest();
        FinancialEngine.DerivationResult res = new FinancialEngine().deriveForUnits(new Set<Id>{ u.Id });
        Test.stopTest();

        // Cancelled invoice frozen: engine returns NO derived Paid/Status for it (writeResults skips it).
        System.assert(!res.invoicePaidAmount.containsKey(invCancelled.Id), 'Cancelled invoice paid must not be re-derived');
        System.assert(!res.invoiceStatus.containsKey(invCancelled.Id), 'Cancelled invoice status must not be re-derived');
        // Its installment is frozen: absent from the derived cash-flow map.
        System.assert(!res.cashFlowReceived.containsKey(cfCancelled.Id), 'Frozen installment must not be re-derived');
        // Live invoice derives normally; the 500 overpayment stays on its own installment, NOT the frozen one.
        System.assertEquals(1500, res.invoicePaidAmount.get(invLive.Id), 'Live invoice paid = 1500');
        System.assertEquals(1500, res.cashFlowReceived.get(cfLive.Id), 'Overpay stays on the live installment');
        System.assertEquals(0, res.receiptReceived.get(dead.Id), 'Cancelled receipt received = 0');
    }

    @IsTest
    static void legacyNoLineInvoiceFrozen() {
        // An invoice with NO Receipt_Amount__c lines (legacy invoices paid via the Receipt_Invoice__c
        // junction, which the engine doesn't read) is frozen: stored Paid_Amount/Status preserved,
        // not zeroed.
        Unit__c u = makeUnit('u_legacy');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        Cash_Flow__c cf = makeCF(u.Id, s.Id, 'M1', -5, 1000);
        insert cf;

        Invoice__c legacy = makeInvoice(u.Id, 1000, 0);
        legacy.Status__c = 'Fully Paid';
        legacy.Paid_Amount__c = 1000;
        insert legacy;
        insert new Milestone_Invoice__c(Invoice__c = legacy.Id, Cash_Flow__c = cf.Id);
        // Legacy payment recorded via the Receipt_Invoice junction, NOT Receipt_Amount lines.
        Receipt__c r = makeReceipt(u.Id, -1, 'Fully Paid');
        insert r;
        insert new Receipt_Invoice__c(Receipt__c = r.Id, Invoice__c = legacy.Id, Amount__c = 1000);

        Test.startTest();
        FinancialEngine.DerivationResult res = new FinancialEngine().deriveForUnits(new Set<Id>{ u.Id });
        Test.stopTest();

        System.assert(!res.invoicePaidAmount.containsKey(legacy.Id), 'No-line invoice must not be re-derived (frozen)');
        System.assert(!res.invoiceStatus.containsKey(legacy.Id), 'No-line invoice status must not be re-derived (frozen)');
        System.assert(!res.cashFlowReceived.containsKey(cf.Id), 'Its installment is frozen (not re-derived)');
    }

    @IsTest
    static void idempotentReRun() {
        Unit__c u = makeUnit('u7');
        Cash_Flow_Sum__c s = makeSum(u.Id);
        Cash_Flow__c cf1 = makeCF(u.Id, s.Id, 'CF1', -10, 1000);
        Cash_Flow__c cf2 = makeCF(u.Id, s.Id, 'CF2', 0, 1000);
        insert new List<Cash_Flow__c>{ cf1, cf2 };
        Invoice__c inv = makeInvoice(u.Id, 1000, 0);
        insert inv;
        insert new Milestone_Invoice__c(Invoice__c = inv.Id, Cash_Flow__c = cf1.Id);
        Receipt__c r = makeReceipt(u.Id, 0, 'Fully Paid');
        insert r;
        insert new Receipt_Amount__c(Receipt__c = r.Id, Invoice__c = inv.Id, Amount__c = 1500); // spills to cf2

        FinancialEngine engine = new FinancialEngine();
        Test.startTest();
        FinancialEngine.DerivationResult a = engine.deriveForUnits(new Set<Id>{ u.Id });
        FinancialEngine.DerivationResult b = engine.deriveForUnits(new Set<Id>{ u.Id });
        Test.stopTest();

        System.assertEquals(a.cashFlowReceived.get(cf1.Id), b.cashFlowReceived.get(cf1.Id), 'CF1 stable across runs');
        System.assertEquals(a.cashFlowReceived.get(cf2.Id), b.cashFlowReceived.get(cf2.Id), 'CF2 stable across runs');
        System.assertEquals(1000, a.cashFlowReceived.get(cf1.Id), 'CF1 filled to capacity');
        System.assertEquals(500, a.cashFlowReceived.get(cf2.Id), 'CF2 got the 500 spill');
        System.assertEquals(a.invoicePaidAmount.get(inv.Id), b.invoicePaidAmount.get(inv.Id), 'Invoice paid stable');
    }
}
