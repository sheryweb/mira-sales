/**
 * Tests for FinancialReconciliation — the read-only dry-run diff report (Step 4c).
 * Verifies: clean data -> no diffs; stale stored values -> reported diffs (numeric + text);
 * and that running the report performs NO DML (records are untouched).
 */
@IsTest
private class FinancialReconciliationTest {

    private class Fixture {
        Unit__c u;
        Cash_Flow__c cf;
        Invoice__c inv;
        Receipt__c r;
        Receipt_Amount__c ra;
    }

    /** Build a single fully-paid unit; stored totals are set CORRECTLY (matching the engine). */
    private static Fixture buildClean() {
        Fixture f = new Fixture();
        f.u = new Unit__c(Title__c = 'recon');
        insert f.u;
        Cash_Flow_Sum__c s = new Cash_Flow_Sum__c(Name = 'CFS', Unit__c = f.u.Id);
        insert s;
        f.cf = new Cash_Flow__c(
            Name = 'M1', Unit__c = f.u.Id, Cash_Flow_Sum__c = s.Id,
            Date__c = System.today().addDays(-5), Constant__c = 1000, Received_Amount__c = 1000
        );
        insert f.cf;
        f.inv = new Invoice__c(
            Status__c = 'Fully Paid', Invoice_Date__c = System.today(),
            Sub_Total_Amount__c = 1000, Paid_Amount__c = 1000, Unit__c = f.u.Id,
            Invoice_Number__c = 'INV-RC1'
        );
        insert f.inv;
        insert new Milestone_Invoice__c(Invoice__c = f.inv.Id, Cash_Flow__c = f.cf.Id);
        f.r = new Receipt__c(
            Description__c = 'R', Unit__c = f.u.Id, Payment_Date__c = System.today(),
            Received_Amount__c = 1000, Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid'
        );
        insert f.r;
        f.ra = new Receipt_Amount__c(
            Receipt__c = f.r.Id, Invoice__c = f.inv.Id, Amount__c = 1000, Cumulative_Paid_Amount__c = 1000
        );
        insert f.ra;
        return f;
    }

    @IsTest
    static void cleanDataYieldsNoDiffs() {
        Fixture f = buildClean();

        Test.startTest();
        FinancialReconciliation.Report rep = new FinancialReconciliation().reconcileUnits(new Set<Id>{ f.u.Id });
        Test.stopTest();

        System.assertEquals(0, rep.diffCount(), 'Correctly-stored data should produce no diffs. Report: ' + rep.toText());
        System.assert(rep.recordsCompared >= 4, 'Should compare invoice, receipt, line and cash flow');
    }

    @IsTest
    static void staleDataYieldsDiffs() {
        Fixture f = buildClean();
        // Corrupt the stored totals to simulate write-once drift.
        update new Invoice__c(Id = f.inv.Id, Paid_Amount__c = 0, Status__c = 'Pending');
        update new Cash_Flow__c(Id = f.cf.Id, Received_Amount__c = 0);
        update new Receipt_Amount__c(Id = f.ra.Id, Cumulative_Paid_Amount__c = 250);

        Test.startTest();
        FinancialReconciliation.Report rep = new FinancialReconciliation().reconcileUnits(new Set<Id>{ f.u.Id });
        Test.stopTest();

        Map<String, FinancialReconciliation.Diff> byField = new Map<String, FinancialReconciliation.Diff>();
        for (FinancialReconciliation.Diff dd : rep.diffs) {
            byField.put(dd.objectName + '.' + dd.field, dd);
        }
        System.assert(byField.containsKey('Invoice__c.Paid_Amount__c'), 'Paid amount diff expected');
        System.assertEquals(1000, byField.get('Invoice__c.Paid_Amount__c').derivedNum, 'Derived paid = 1000');
        System.assertEquals(0, byField.get('Invoice__c.Paid_Amount__c').storedNum, 'Stored paid = 0');
        System.assert(byField.containsKey('Invoice__c.Status__c'), 'Status diff expected');
        System.assertEquals('Fully Paid', byField.get('Invoice__c.Status__c').derivedText, 'Derived status Fully Paid');
        System.assert(byField.containsKey('Cash_Flow__c.Received_Amount__c'), 'Cash flow diff expected');
        System.assert(byField.containsKey('Receipt_Amount__c.Cumulative_Paid_Amount__c'), 'Cumulative diff expected');
    }

    @IsTest
    static void reportPerformsNoDml() {
        Fixture f = buildClean();
        // Make totals stale so the engine WOULD want to change them...
        update new Invoice__c(Id = f.inv.Id, Paid_Amount__c = 0, Status__c = 'Pending');

        Test.startTest();
        FinancialReconciliation.Report rep = new FinancialReconciliation().reconcileUnits(new Set<Id>{ f.u.Id });
        Test.stopTest();

        // ...but the report must NOT have written anything.
        Invoice__c after = [SELECT Paid_Amount__c, Status__c FROM Invoice__c WHERE Id = :f.inv.Id];
        System.assertEquals(0, after.Paid_Amount__c, 'Dry run must not change stored Paid_Amount__c');
        System.assertEquals('Pending', after.Status__c, 'Dry run must not change stored Status__c');
        System.assert(rep.diffCount() > 0, 'But the drift should still be reported');
    }

    @IsTest
    static void emptyInputIsSafe() {
        FinancialReconciliation.Report rep = new FinancialReconciliation().reconcileUnits(new Set<Id>());
        System.assertEquals(0, rep.diffCount(), 'No units -> no diffs');
        System.assertEquals(0, rep.recordsCompared, 'No units -> nothing compared');
    }
}
