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

    @TestVisible static final String STATUS_PENDING   = 'Pending';
    @TestVisible static final String STATUS_PARTIAL   = 'Partially Paid';
    @TestVisible static final String STATUS_FULL      = 'Fully Paid';
    @TestVisible static final String STATUS_CANCELLED = 'Cancelled';

    /** Recursion guard: true while the engine is writing its own DML, so triggers don't re-enter. */
    @TestVisible public static Boolean bypass = false;

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
            SELECT Id, Unit__c, Sub_Total_Amount__c, VAT_Amount__c, Status__c
            FROM Invoice__c
            WHERE Unit__c IN :unitIds
        ]);
        // Manually-cancelled invoices are FROZEN: the engine preserves their stored Paid_Amount__c
        // and Status__c and excludes their own cash-flow installments from the allocation waterfall,
        // so live payments never land on a cancelled invoice's installments. (Their funding receipts
        // are separately Payment_Status__c='Cancelled', so they are already excluded in step 4.)
        Set<Id> cancelledInvoiceIds = new Set<Id>();
        for (Invoice__c inv : invById.values()) {
            if (inv.Status__c == STATUS_CANCELLED) cancelledInvoiceIds.add(inv.Id);
        }
        Map<Id, List<Id>> invoiceOwnCashFlows = new Map<Id, List<Id>>();
        Map<Id, Set<Id>> cashFlowOwners = new Map<Id, Set<Id>>(); // cash flow -> invoice ids that own it
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
                if (!cashFlowOwners.containsKey(mi.Cash_Flow__c)) {
                    cashFlowOwners.put(mi.Cash_Flow__c, new Set<Id>());
                }
                cashFlowOwners.get(mi.Cash_Flow__c).add(mi.Invoice__c);
            }
        }

        // Invoices that carry a legacy Receipt_Invoice__c link (the older payment junction the engine
        // does not read). Combined with "no Receipt_Amount line", this marks a legacy-paid invoice to
        // freeze. The Manage panel keeps the two junctions in sync (removing the last line deletes the
        // link), so a modern invoice whose allocation was fully removed has neither and self-heals to 0.
        Set<Id> invoiceIdsWithReceiptInvoice = new Set<Id>();
        if (!invById.isEmpty()) {
            for (Receipt_Invoice__c ri : [
                SELECT Invoice__c FROM Receipt_Invoice__c
                WHERE Invoice__c IN :invById.keySet() AND Invoice__c != null
            ]) {
                invoiceIdsWithReceiptInvoice.add(ri.Invoice__c);
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
        List<Receipt_Amount__c> lines = [
            SELECT Id, Receipt__c, Invoice__c, Amount__c,
                   Receipt__r.Unit__c, Receipt__r.Payment_Status__c, Receipt__r.Status__c
            FROM Receipt_Amount__c
            WHERE Receipt__c IN :recById.keySet()
            ORDER BY Receipt__r.Receipt_Added_Date__c ASC NULLS LAST,
                     Receipt__r.Payment_Date__c ASC NULLS LAST,
                     Receipt__r.CreatedDate ASC,
                     Id ASC
        ];

        // An invoice is FROZEN when it is manually Cancelled OR it was paid the LEGACY way: no
        // Receipt_Amount__c line but a Receipt_Invoice__c link (the older junction the engine does
        // not read). Freezing preserves such an invoice's stored Paid_Amount/Status instead of
        // zeroing it. NOTES: (1) an invoice whose only lines come from cancelled receipts still HAS
        // lines, so it is NOT frozen and correctly derives to 0 (soft-cancel reversal); (2) a modern
        // invoice whose allocation was fully removed has neither junction, so it self-heals to 0.
        Set<Id> invoiceIdsWithLines = new Set<Id>();
        for (Receipt_Amount__c ra : lines) {
            if (ra.Invoice__c != null) invoiceIdsWithLines.add(ra.Invoice__c);
        }
        Set<Id> frozenInvoiceIds = new Set<Id>(cancelledInvoiceIds);
        for (Id invId : invById.keySet()) {
            if (!invoiceIdsWithLines.contains(invId) && invoiceIdsWithReceiptInvoice.contains(invId)) {
                frozenInvoiceIds.add(invId);
            }
        }
        // A cash flow is frozen only if EVERY invoice that owns it is frozen; a shared installment
        // that also serves a live invoice stays in play.
        Set<Id> frozenCashFlowIds = new Set<Id>();
        for (Id cfId : cashFlowOwners.keySet()) {
            Boolean allFrozen = true;
            for (Id ownerInv : cashFlowOwners.get(cfId)) {
                if (!frozenInvoiceIds.contains(ownerInv)) { allFrozen = false; break; }
            }
            if (allFrozen) frozenCashFlowIds.add(cfId);
        }

        Map<Id, Decimal> perInvoiceCumulative = new Map<Id, Decimal>();
        for (Receipt_Amount__c ra : lines) {
            if (isExcluded(ra.Receipt__r.Payment_Status__c, ra.Receipt__r.Status__c)) {
                continue; // cancelled / unreconciled receipt -> ignored entirely
            }
            if (ra.Invoice__c == null || ra.Amount__c == null || ra.Amount__c == 0) {
                continue;
            }
            if (frozenInvoiceIds.contains(ra.Invoice__c)) {
                continue; // frozen invoice -> its money is not re-derived or re-spilled
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
                    if (frozenCashFlowIds.contains(cf.Id)) continue; // never spill onto a frozen installment
                    remaining = applyToCashFlow(cf.Id, invId, recId, remaining, cfById, cfReceived, cfDate, res);
                }
            }
            // phase C: true overpayment leftover -> last installment with a price
            if (remaining > 0 && unitId != null && unitCashFlows.containsKey(unitId)) {
                Cash_Flow__c last = lastWithPrice(unitCashFlows.get(unitId), frozenCashFlowIds);
                if (last != null) {
                    cfReceived.put(last.Id, cfReceived.get(last.Id) + remaining);
                    res.ledger.add(new LedgerRow(recId, invId, last.Id, remaining, cfDate.get(last.Id)));
                    remaining = 0;
                }
            }
            // if remaining > 0 here, the unit has no cash flows to absorb it; it stays unallocated.
        }

        // ---- 5. Finalize cash flow received + invoice paid/status ----
        // Frozen cash flows are omitted so writeResults leaves their stored Received_Amount as-is.
        for (Id cfId : cfReceived.keySet()) {
            if (!frozenCashFlowIds.contains(cfId)) res.cashFlowReceived.put(cfId, cfReceived.get(cfId));
        }
        for (Id invId : invById.keySet()) {
            if (frozenInvoiceIds.contains(invId)) continue; // frozen: leave stored Paid_Amount + Status
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

    private Cash_Flow__c lastWithPrice(List<Cash_Flow__c> cfs, Set<Id> frozenCashFlowIds) {
        for (Integer i = cfs.size() - 1; i >= 0; i--) {
            if (frozenCashFlowIds.contains(cfs[i].Id)) continue; // skip frozen installments
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

    // ==========================================================================================
    // Write side (Step 5). deriveForUnits above is pure; everything below performs DML and is
    // gated by the feature flag + a recursion guard. This is the single entry point the
    // self-healing triggers call.
    // ==========================================================================================

    /** True when Financial_Engine_Settings__c grants the engine authority over the four totals. */
    public static Boolean isEngineEnabled() {
        Financial_Engine_Settings__c s = Financial_Engine_Settings__c.getOrgDefaults();
        return s != null && s.Engine_Owns_Totals__c == true;
    }

    /**
     * Re-derive and WRITE the corrected totals + rebuild the Milestone_Receipt ledger for the
     * given units. No-op unless the feature flag is on. Recursion-guarded so the engine's own
     * DML never re-enters it. Only records whose value actually changed are updated.
     */
    public static void applyForUnits(Set<Id> unitIds) {
        if (unitIds == null || unitIds.isEmpty()) return;
        if (bypass) return;
        if (!isEngineEnabled()) return;
        bypass = true;
        try {
            DerivationResult res = new FinancialEngine().deriveForUnits(unitIds);
            writeResults(unitIds, res);
        } finally {
            bypass = false;
        }
    }

    private static void writeResults(Set<Id> unitIds, DerivationResult res) {
        // --- Invoices: Paid_Amount__c + Status__c ---
        List<Invoice__c> invUpd = new List<Invoice__c>();
        for (Invoice__c inv : [SELECT Id, Paid_Amount__c, Status__c FROM Invoice__c WHERE Unit__c IN :unitIds]) {
            Invoice__c u = new Invoice__c(Id = inv.Id);
            Boolean changed = false;
            if (res.invoicePaidAmount.containsKey(inv.Id) && !eq(inv.Paid_Amount__c, res.invoicePaidAmount.get(inv.Id))) {
                u.Paid_Amount__c = res.invoicePaidAmount.get(inv.Id);
                changed = true;
            }
            if (res.invoiceStatus.containsKey(inv.Id) && inv.Status__c != res.invoiceStatus.get(inv.Id)) {
                u.Status__c = res.invoiceStatus.get(inv.Id);
                changed = true;
            }
            if (changed) invUpd.add(u);
        }
        if (!invUpd.isEmpty()) update invUpd;

        // --- Receipts: Received_Amount__c ---
        List<Receipt__c> recUpd = new List<Receipt__c>();
        for (Receipt__c r : [SELECT Id, Received_Amount__c FROM Receipt__c WHERE Unit__c IN :unitIds]) {
            if (res.receiptReceived.containsKey(r.Id) && !eq(r.Received_Amount__c, res.receiptReceived.get(r.Id))) {
                recUpd.add(new Receipt__c(Id = r.Id, Received_Amount__c = res.receiptReceived.get(r.Id)));
            }
        }
        if (!recUpd.isEmpty()) update recUpd;

        // --- Receipt amount lines: Cumulative_Paid_Amount__c (only non-excluded lines are in the map) ---
        List<Receipt_Amount__c> lineUpd = new List<Receipt_Amount__c>();
        for (Receipt_Amount__c ra : [SELECT Id, Cumulative_Paid_Amount__c FROM Receipt_Amount__c WHERE Receipt__r.Unit__c IN :unitIds]) {
            if (res.lineCumulative.containsKey(ra.Id) && !eq(ra.Cumulative_Paid_Amount__c, res.lineCumulative.get(ra.Id))) {
                lineUpd.add(new Receipt_Amount__c(Id = ra.Id, Cumulative_Paid_Amount__c = res.lineCumulative.get(ra.Id)));
            }
        }
        if (!lineUpd.isEmpty()) update lineUpd;

        // --- Cash flows: Received_Amount__c ---
        List<Cash_Flow__c> cfUpd = new List<Cash_Flow__c>();
        for (Cash_Flow__c cf : [SELECT Id, Received_Amount__c FROM Cash_Flow__c WHERE Unit__c IN :unitIds]) {
            if (res.cashFlowReceived.containsKey(cf.Id) && !eq(cf.Received_Amount__c, res.cashFlowReceived.get(cf.Id))) {
                cfUpd.add(new Cash_Flow__c(Id = cf.Id, Received_Amount__c = res.cashFlowReceived.get(cf.Id)));
            }
        }
        if (!cfUpd.isEmpty()) update cfUpd;

        // --- Rebuild the Milestone_Receipt ledger for these units' receipts ---
        // Delete-and-reinsert keeps it a faithful mirror of the current derivation. Rows for
        // cancelled/unreconciled receipts are not regenerated, so they correctly drop out.
        List<Milestone_Receipt__c> oldRows = [SELECT Id FROM Milestone_Receipt__c WHERE Receipt__r.Unit__c IN :unitIds];
        if (!oldRows.isEmpty()) delete oldRows;
        List<Milestone_Receipt__c> newRows = new List<Milestone_Receipt__c>();
        for (LedgerRow row : res.ledger) {
            newRows.add(new Milestone_Receipt__c(
                Name = ('Allocation ' + String.valueOf(row.amount)).abbreviate(80),
                Receipt__c = row.receiptId,
                Invoice__c = row.invoiceId,
                Cash_Flow__c = row.cashFlowId,
                Amount__c = row.amount,
                Installment_Date__c = row.installmentDate
            ));
        }
        if (!newRows.isEmpty()) insert newRows;
    }

    private static Boolean eq(Decimal a, Decimal b) {
        return Math.abs(nz(a) - nz(b)) <= 0.005;
    }
}
