/**
 * FinancialEngine — centralized, idempotent money math for the Invoice/Receipt system.
 *
 * This class is PURE: deriveForUnits() queries facts and returns the DESIRED state of every
 * derived total. It performs NO DML. Both the dry-run reconciliation report (Step 4c) and the
 * self-healing triggers (Step 5) build on it, so all money math lives in exactly one place.
 *
 * Derivation model (per Unit), computed from scratch every time (never incremental):
 *   - Receipt lines (Receipt_Amount__c) are the money source of truth.
 *   - Lines are replayed in chronological order (Receipt_Added_Date, then Payment_Date, then
 *     CreatedDate, then line Id) so running totals and the allocation waterfall are deterministic.
 *   - For each line, the amount fills the invoice's own Cash Flow items oldest-first (phase A),
 *     then spills to the unit's next chronological installments even if unlinked (phase B),
 *     then dumps any true-overpayment leftover on the last installment with a price (phase C).
 *     Every landing is recorded as a ledger row (Receipt -> Invoice -> Cash_Flow -> Amount).
 *   - Cash_Flow.Received_Amount = sum of ledger rows per cash flow.
 *   - Invoice.Paid_Amount = sum of its lines; Status derived from paid vs (Sub_Total + VAT).
 *   - Receipt.Received_Amount = sum of its own lines.
 *   - Receipt_Amount.Cumulative_Paid_Amount = per-invoice running total up to and including
 *     that line (fixes the old create-path bug where sibling lines shared one "previous" value).
 *
 * Receipts with Payment_Status__c = 'Cancelled' or Status__c = 'Unreconciled' are excluded
 * entirely (mirrors the one DLRS rollup filter) — this is how a soft-cancel reverses a receipt.
 */
public without sharing class FinancialEngine {

    @TestVisible static final String STATUS_PENDING = 'Pending';
    @TestVisible static final String STATUS_PARTIAL = 'Partially Paid';
    @TestVisible static final String STATUS_FULL    = 'Fully Paid';

    /** One receipt-to-installment allocation landing. Maps 1:1 to a Milestone_Receipt__c row. */
    public class LedgerRow {
        public Id receiptId;
        public Id invoiceId;
        public Id cashFlowId;
        public Decimal amount;
        public Date installmentDate;
        public LedgerRow(Id r, Id inv, Id cf, Decimal amt, Date d) {
            receiptId = r; invoiceId = inv; cashFlowId = cf; amount = amt; installmentDate = d;
        }
    }

    /** Desired state of every derived value. Nothing here is written by this class. */
    public class DerivationResult {
        public Map<Id, Decimal> invoicePaidAmount = new Map<Id, Decimal>(); // Invoice__c.Id -> Paid_Amount__c
        public Map<Id, String>  invoiceStatus     = new Map<Id, String>();  // Invoice__c.Id -> Status__c
        public Map<Id, Decimal> receiptReceived   = new Map<Id, Decimal>(); // Receipt__c.Id  -> Received_Amount__c
        public Map<Id, Decimal> lineCumulative    = new Map<Id, Decimal>(); // Receipt_Amount__c.Id -> Cumulative_Paid_Amount__c
        public Map<Id, Decimal> cashFlowReceived  = new Map<Id, Decimal>(); // Cash_Flow__c.Id -> Received_Amount__c
        public List<LedgerRow>  ledger            = new List<LedgerRow>();
    }

    /**
     * Derive the desired state for every record belonging to the given units. No DML.
     */
    public DerivationResult deriveForUnits(Set<Id> unitIds) {
        DerivationResult res = new DerivationResult();
        if (unitIds == null || unitIds.isEmpty()) {
            return res;
        }

        // ---- 1. Cash flows for the units (chronological) ----
        Map<Id, List<Cash_Flow__c>> unitCashFlows = new Map<Id, List<Cash_Flow__c>>();
        Map<Id, Cash_Flow__c> cfById = new Map<Id, Cash_Flow__c>();
        Map<Id, Decimal> cfReceived = new Map<Id, Decimal>();
        Map<Id, Date> cfDate = new Map<Id, Date>();
        for (Cash_Flow__c cf : [
            SELECT Id, Unit__c, Price_Formula__c, Date__c
            FROM Cash_Flow__c
            WHERE Unit__c IN :unitIds
            ORDER BY Date__c ASC NULLS LAST, Id ASC
        ]) {
            if (!unitCashFlows.containsKey(cf.Unit__c)) {
                unitCashFlows.put(cf.Unit__c, new List<Cash_Flow__c>());
            }
            unitCashFlows.get(cf.Unit__c).add(cf);
            cfById.put(cf.Id, cf);
            cfReceived.put(cf.Id, 0);
            cfDate.put(cf.Id, cf.Date__c);
        }

        // ---- 2. Invoices for the units + each invoice's own cash flows (via Milestone_Invoice) ----
        Map<Id, Invoice__c> invById = new Map<Id, Invoice__c>([
            SELECT Id, Unit__c, Sub_Total_Amount__c, VAT_Amount__c
            FROM Invoice__c
            WHERE Unit__c IN :unitIds
        ]);
        Map<Id, List<Id>> invoiceOwnCashFlows = new Map<Id, List<Id>>();
        if (!invById.isEmpty()) {
            for (Milestone_Invoice__c mi : [
                SELECT Invoice__c, Cash_Flow__c
                FROM Milestone_Invoice__c
                WHERE Invoice__c IN :invById.keySet() AND Cash_Flow__c != null
                ORDER BY Cash_Flow__r.Date__c ASC NULLS LAST, Cash_Flow__c ASC
            ]) {
                if (!invoiceOwnCashFlows.containsKey(mi.Invoice__c)) {
                    invoiceOwnCashFlows.put(mi.Invoice__c, new List<Id>());
                }
                invoiceOwnCashFlows.get(mi.Invoice__c).add(mi.Cash_Flow__c);
            }
        }

        // ---- 3. Receipts for the units (for received=0 defaults + exclusion) ----
        Map<Id, Receipt__c> recById = new Map<Id, Receipt__c>([
            SELECT Id, Unit__c, Payment_Status__c, Status__c
            FROM Receipt__c
            WHERE Unit__c IN :unitIds
        ]);
        for (Id rId : recById.keySet()) {
            res.receiptReceived.put(rId, 0); // default; excluded receipts stay 0
        }

        // ---- 4. Replay receipt lines in chronological order ----
        Map<Id, Decimal> perInvoiceCumulative = new Map<Id, Decimal>();
        for (Receipt_Amount__c ra : [
            SELECT Id, Receipt__c, Invoice__c, Amount__c,
                   Receipt__r.Unit__c, Receipt__r.Payment_Status__c, Receipt__r.Status__c
            FROM Receipt_Amount__c
            WHERE Receipt__c IN :recById.keySet()
            ORDER BY Receipt__r.Receipt_Added_Date__c ASC NULLS LAST,
                     Receipt__r.Payment_Date__c ASC NULLS LAST,
                     Receipt__r.CreatedDate ASC,
                     Id ASC
        ]) {
            if (isExcluded(ra.Receipt__r.Payment_Status__c, ra.Receipt__r.Status__c)) {
                continue; // cancelled / unreconciled receipt -> ignored entirely
            }
            if (ra.Invoice__c == null || ra.Amount__c == null || ra.Amount__c == 0) {
                continue;
            }

            Id invId = ra.Invoice__c;
            Id recId = ra.Receipt__c;
            Decimal amt = ra.Amount__c;
            Id unitId = (invById.containsKey(invId) && invById.get(invId).Unit__c != null)
                        ? invById.get(invId).Unit__c
                        : ra.Receipt__r.Unit__c;

            // running per-invoice cumulative (up to and including this line)
            Decimal cum = (perInvoiceCumulative.containsKey(invId) ? perInvoiceCumulative.get(invId) : 0) + amt;
            perInvoiceCumulative.put(invId, cum);
            res.lineCumulative.put(ra.Id, cum);

            // invoice paid + receipt received
            addTo(res.invoicePaidAmount, invId, amt);
            addTo(res.receiptReceived, recId, amt);

            // waterfall allocation -> ledger
            Decimal remaining = amt;
            // phase A: invoice's own cash flows, oldest-first
            if (invoiceOwnCashFlows.containsKey(invId)) {
                for (Id cfId : invoiceOwnCashFlows.get(invId)) {
                    if (remaining <= 0) break;
                    remaining = applyToCashFlow(cfId, invId, recId, remaining, cfById, cfReceived, cfDate, res);
                }
            }
            // phase B: unit's cash flows in date order (spill to next installments, even unlinked)
            if (remaining > 0 && unitId != null && unitCashFlows.containsKey(unitId)) {
                for (Cash_Flow__c cf : unitCashFlows.get(unitId)) {
                    if (remaining <= 0) break;
                    remaining = applyToCashFlow(cf.Id, invId, recId, remaining, cfById, cfReceived, cfDate, res);
                }
            }
            // phase C: true overpayment leftover -> last installment with a price
            if (remaining > 0 && unitId != null && unitCashFlows.containsKey(unitId)) {
                Cash_Flow__c last = lastWithPrice(unitCashFlows.get(unitId));
                if (last != null) {
                    cfReceived.put(last.Id, cfReceived.get(last.Id) + remaining);
                    res.ledger.add(new LedgerRow(recId, invId, last.Id, remaining, cfDate.get(last.Id)));
                    remaining = 0;
                }
            }
            // if remaining > 0 here, the unit has no cash flows to absorb it; it stays unallocated.
        }

        // ---- 5. Finalize cash flow received + invoice paid/status ----
        res.cashFlowReceived.putAll(cfReceived);
        for (Id invId : invById.keySet()) {
            Decimal paid = res.invoicePaidAmount.containsKey(invId) ? res.invoicePaidAmount.get(invId) : 0;
            res.invoicePaidAmount.put(invId, paid);
            Invoice__c inv = invById.get(invId);
            Decimal total = nz(inv.Sub_Total_Amount__c) + nz(inv.VAT_Amount__c);
            res.invoiceStatus.put(invId, statusFor(paid, total));
        }
        return res;
    }

    /** Apply as much of `remaining` as this cash flow can absorb (price - already received). */
    private Decimal applyToCashFlow(Id cfId, Id invId, Id recId, Decimal remaining,
            Map<Id, Cash_Flow__c> cfById, Map<Id, Decimal> cfReceived, Map<Id, Date> cfDate,
            DerivationResult res) {
        Cash_Flow__c cf = cfById.get(cfId);
        if (cf == null) return remaining;
        Decimal capacity = nz(cf.Price_Formula__c) - cfReceived.get(cfId);
        if (capacity <= 0) return remaining;
        Decimal applied = (remaining < capacity) ? remaining : capacity;
        if (applied <= 0) return remaining;
        cfReceived.put(cfId, cfReceived.get(cfId) + applied);
        res.ledger.add(new LedgerRow(recId, invId, cfId, applied, cfDate.get(cfId)));
        return remaining - applied;
    }

    private Cash_Flow__c lastWithPrice(List<Cash_Flow__c> cfs) {
        for (Integer i = cfs.size() - 1; i >= 0; i--) {
            if (nz(cfs[i].Price_Formula__c) > 0) return cfs[i];
        }
        return null;
    }

    private static Boolean isExcluded(String paymentStatus, String status) {
        return paymentStatus == 'Cancelled' || status == 'Unreconciled';
    }

    private static String statusFor(Decimal paid, Decimal total) {
        if (paid == null || paid <= 0) return STATUS_PENDING;
        if (total != null && total > 0 && paid >= total) return STATUS_FULL;
        return STATUS_PARTIAL;
    }

    private static void addTo(Map<Id, Decimal> m, Id key, Decimal amt) {
        m.put(key, (m.containsKey(key) ? m.get(key) : 0) + amt);
    }

    private static Decimal nz(Decimal d) {
        return d == null ? 0 : d;
    }
}
