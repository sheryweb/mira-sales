/**
 * FinancialReconciliation — read-only dry-run report (Step 4c).
 *
 * Wraps FinancialEngine.deriveForUnits() and compares the engine's DERIVED state against the
 * values currently STORED on the records, producing a list of differences (old -> new).
 * Performs ZERO DML. This is the report the user reviews/approves before any production cutover,
 * and the harness used to validate the engine against real data.
 *
 * A field is reported as a diff only when stored and derived differ by more than TOLERANCE
 * (numeric) or are not equal (text), so scale/rounding noise is ignored.
 */
public without sharing class FinancialReconciliation {

    /** Amounts within this absolute delta are treated as equal (currency rounding noise). */
    public static final Decimal TOLERANCE = 0.005;

    public class Diff {
        public String objectName;
        public Id recordId;
        public String label;      // human-friendly identifier (number / name)
        public String field;
        public Boolean isText;
        public Decimal storedNum;
        public Decimal derivedNum;
        public String storedText;
        public String derivedText;

        public Decimal delta {
            get { return isText ? null : (derivedNum - storedNum); }
        }

        public override String toString() {
            if (isText) {
                return objectName + ' ' + label + ' ' + field + ': "'
                    + storedText + '" -> "' + derivedText + '"';
            }
            String sign = delta >= 0 ? '+' : '';
            return objectName + ' ' + label + ' ' + field + ': '
                + storedNum + ' -> ' + derivedNum + ' (' + String.valueOf('Δ') + ' ' + sign + delta + ')';
        }
    }

    public class Report {
        public Integer unitsScanned = 0;
        public Integer recordsCompared = 0;
        public List<Diff> diffs = new List<Diff>();

        public Integer diffCount() { return diffs.size(); }

        /** Multi-line, human-readable summary for anonymous-apex / log review. */
        public String toText() {
            String s = '=== Financial reconciliation (DRY RUN, no data changed) ===\n'
                + 'Units scanned: ' + unitsScanned + '\n'
                + 'Records compared: ' + recordsCompared + '\n'
                + 'Differences: ' + diffs.size() + '\n';
            for (Diff d : diffs) {
                s += '  - ' + d.toString() + '\n';
            }
            if (diffs.isEmpty()) {
                s += '  (stored values already match the engine — nothing to correct)\n';
            }
            return s;
        }
    }

    /** Compare stored vs engine-derived for every record belonging to the given units. No DML. */
    public Report reconcileUnits(Set<Id> unitIds) {
        Report rep = new Report();
        if (unitIds == null || unitIds.isEmpty()) {
            return rep;
        }
        rep.unitsScanned = unitIds.size();
        FinancialEngine.DerivationResult d = new FinancialEngine().deriveForUnits(unitIds);

        for (Invoice__c inv : [
            SELECT Id, Name, Invoice_Number__c, Paid_Amount__c, Status__c
            FROM Invoice__c WHERE Unit__c IN :unitIds
        ]) {
            rep.recordsCompared++;
            String lbl = String.isNotBlank(inv.Invoice_Number__c) ? inv.Invoice_Number__c : inv.Name;
            if (d.invoicePaidAmount.containsKey(inv.Id)) {
                addNum(rep, 'Invoice__c', inv.Id, lbl, 'Paid_Amount__c', inv.Paid_Amount__c, d.invoicePaidAmount.get(inv.Id));
            }
            if (d.invoiceStatus.containsKey(inv.Id)) {
                addText(rep, 'Invoice__c', inv.Id, lbl, 'Status__c', inv.Status__c, d.invoiceStatus.get(inv.Id));
            }
        }

        for (Receipt__c r : [
            SELECT Id, Name, Received_Amount__c FROM Receipt__c WHERE Unit__c IN :unitIds
        ]) {
            rep.recordsCompared++;
            if (d.receiptReceived.containsKey(r.Id)) {
                addNum(rep, 'Receipt__c', r.Id, r.Name, 'Received_Amount__c', r.Received_Amount__c, d.receiptReceived.get(r.Id));
            }
        }

        for (Receipt_Amount__c ra : [
            SELECT Id, Cumulative_Paid_Amount__c, Receipt__r.Name
            FROM Receipt_Amount__c WHERE Receipt__r.Unit__c IN :unitIds
        ]) {
            rep.recordsCompared++;
            if (d.lineCumulative.containsKey(ra.Id)) {
                addNum(rep, 'Receipt_Amount__c', ra.Id, ra.Receipt__r.Name, 'Cumulative_Paid_Amount__c',
                    ra.Cumulative_Paid_Amount__c, d.lineCumulative.get(ra.Id));
            }
        }

        for (Cash_Flow__c cf : [
            SELECT Id, Name, Received_Amount__c FROM Cash_Flow__c WHERE Unit__c IN :unitIds
        ]) {
            rep.recordsCompared++;
            if (d.cashFlowReceived.containsKey(cf.Id)) {
                addNum(rep, 'Cash_Flow__c', cf.Id, cf.Name, 'Received_Amount__c', cf.Received_Amount__c, d.cashFlowReceived.get(cf.Id));
            }
        }

        return rep;
    }

    /**
     * Convenience: reconcile up to maxUnits units that actually have receipt activity.
     * For quick validation against real data; full-org runs should be batched (Phase 4).
     */
    public Report reconcileSample(Integer maxUnits) {
        Set<Id> unitIds = new Set<Id>();
        Integer lim = (maxUnits == null || maxUnits <= 0) ? 50 : maxUnits;
        for (Receipt__c r : [
            SELECT Unit__c FROM Receipt__c WHERE Unit__c != null LIMIT 5000
        ]) {
            unitIds.add(r.Unit__c);
            if (unitIds.size() >= lim) break;
        }
        return reconcileUnits(unitIds);
    }

    private void addNum(Report rep, String obj, Id recId, String label, String field, Decimal stored, Decimal derived) {
        Decimal s = (stored == null) ? 0 : stored;
        Decimal v = (derived == null) ? 0 : derived;
        if (Math.abs(v - s) <= TOLERANCE) {
            return;
        }
        Diff df = new Diff();
        df.objectName = obj; df.recordId = recId; df.label = label; df.field = field;
        df.isText = false; df.storedNum = s; df.derivedNum = v;
        rep.diffs.add(df);
    }

    private void addText(Report rep, String obj, Id recId, String label, String field, String stored, String derived) {
        String s = (stored == null) ? '' : stored;
        String v = (derived == null) ? '' : derived;
        if (s == v) {
            return;
        }
        Diff df = new Diff();
        df.objectName = obj; df.recordId = recId; df.label = label; df.field = field;
        df.isText = true; df.storedText = s; df.derivedText = v;
        rep.diffs.add(df);
    }
}
