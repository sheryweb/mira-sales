/**
 * Tests for FinancialEngine.applyForUnits — the flag-gated, recursion-guarded write side (Step 5a).
 * Verifies it corrects stale totals + builds the ledger when the flag is ON, is a no-op when OFF,
 * and is idempotent (re-running does not duplicate ledger rows).
 */
@IsTest
private class FinancialEngineApplyTest {

    private class Fixture {
        Unit__c u;
        Cash_Flow__c cf;
        Invoice__c inv;
        Receipt__c r;
        Receipt_Amount__c ra;
    }

    private static void enableEngine(Boolean enabled) {
        insert new Financial_Engine_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Engine_Owns_Totals__c = enabled
        );
    }

    /** Build a fully-paid unit whose stored totals are deliberately STALE/wrong. */
    private static Fixture buildStale() {
        Fixture f = new Fixture();
        f.u = new Unit__c(Title__c = 'apply');
        insert f.u;
        Cash_Flow_Sum__c s = new Cash_Flow_Sum__c(Name = 'CFS', Unit__c = f.u.Id);
        insert s;
        f.cf = new Cash_Flow__c(
            Name = 'M1', Unit__c = f.u.Id, Cash_Flow_Sum__c = s.Id,
            Date__c = System.today().addDays(-5), Constant__c = 1000, Received_Amount__c = 0
        );
        insert f.cf;
        f.inv = new Invoice__c(
            Status__c = 'Pending', Invoice_Date__c = System.today(),
            Sub_Total_Amount__c = 1000, Paid_Amount__c = 0, Unit__c = f.u.Id,
            Invoice_Number__c = 'INV-AP1'
        );
        insert f.inv;
        insert new Milestone_Invoice__c(Invoice__c = f.inv.Id, Cash_Flow__c = f.cf.Id);
        f.r = new Receipt__c(
            Description__c = 'R', Unit__c = f.u.Id, Payment_Date__c = System.today(),
            Received_Amount__c = 0, Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid'
        );
        insert f.r;
        f.ra = new Receipt_Amount__c(Receipt__c = f.r.Id, Invoice__c = f.inv.Id, Amount__c = 1000);
        insert f.ra;
        return f;
    }

    @IsTest
    static void appliesCorrectionsWhenEnabled() {
        enableEngine(true);
        Fixture f = buildStale();

        Test.startTest();
        FinancialEngine.applyForUnits(new Set<Id>{ f.u.Id });
        Test.stopTest();

        Invoice__c inv = [SELECT Paid_Amount__c, Status__c FROM Invoice__c WHERE Id = :f.inv.Id];
        System.assertEquals(1000, inv.Paid_Amount__c, 'Invoice paid corrected');
        System.assertEquals('Fully Paid', inv.Status__c, 'Invoice status corrected');
        Cash_Flow__c cf = [SELECT Received_Amount__c FROM Cash_Flow__c WHERE Id = :f.cf.Id];
        System.assertEquals(1000, cf.Received_Amount__c, 'Cash flow received corrected');
        Receipt__c r = [SELECT Received_Amount__c FROM Receipt__c WHERE Id = :f.r.Id];
        System.assertEquals(1000, r.Received_Amount__c, 'Receipt received corrected');
        Receipt_Amount__c ra = [SELECT Cumulative_Paid_Amount__c FROM Receipt_Amount__c WHERE Id = :f.ra.Id];
        System.assertEquals(1000, ra.Cumulative_Paid_Amount__c, 'Cumulative corrected');

        List<Milestone_Receipt__c> ledger = [
            SELECT Receipt__c, Invoice__c, Cash_Flow__c, Amount__c
            FROM Milestone_Receipt__c WHERE Receipt__c = :f.r.Id
        ];
        System.assertEquals(1, ledger.size(), 'One ledger row built');
        System.assertEquals(f.inv.Id, ledger[0].Invoice__c, 'Ledger records source invoice');
        System.assertEquals(f.cf.Id, ledger[0].Cash_Flow__c, 'Ledger records cash flow landing');
        System.assertEquals(1000, ledger[0].Amount__c, 'Ledger records amount');
    }

    @IsTest
    static void noOpWhenDisabled() {
        enableEngine(false);
        Fixture f = buildStale();

        Test.startTest();
        FinancialEngine.applyForUnits(new Set<Id>{ f.u.Id });
        Test.stopTest();

        Invoice__c inv = [SELECT Paid_Amount__c, Status__c FROM Invoice__c WHERE Id = :f.inv.Id];
        System.assertEquals(0, inv.Paid_Amount__c, 'Flag OFF: paid untouched');
        System.assertEquals('Pending', inv.Status__c, 'Flag OFF: status untouched');
        System.assertEquals(0, [SELECT COUNT() FROM Milestone_Receipt__c WHERE Receipt__c = :f.r.Id],
            'Flag OFF: no ledger rows built');
    }

    @IsTest
    static void idempotentNoDuplicateLedger() {
        enableEngine(true);
        Fixture f = buildStale();

        Test.startTest();
        FinancialEngine.applyForUnits(new Set<Id>{ f.u.Id });
        FinancialEngine.applyForUnits(new Set<Id>{ f.u.Id });
        FinancialEngine.applyForUnits(new Set<Id>{ f.u.Id });
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Milestone_Receipt__c WHERE Receipt__c = :f.r.Id],
            'Re-running must not duplicate ledger rows');
        Invoice__c inv = [SELECT Paid_Amount__c FROM Invoice__c WHERE Id = :f.inv.Id];
        System.assertEquals(1000, inv.Paid_Amount__c, 'Paid stable across re-runs');
    }
}
