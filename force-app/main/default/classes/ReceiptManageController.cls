/**
 * ReceiptManageController — backend for the "Manage Receipt" LWC panel (Step 6).
 *
 * Guided, sanctioned edit path for finance to reduce, remove, REASSIGN, or add a receipt's
 * allocations, or soft-cancel a whole receipt. The four stored totals + the Milestone_Receipt
 * ledger are maintained automatically by the self-healing engine triggers; this controller only
 * mutates the FACTS (Receipt_Amount__c lines / Receipt.Payment_Status__c) and keeps the parallel
 * Receipt_Invoice__c link (read by the receipt PDF) in sync with the remaining lines.
 *
 * Removing an allocation does NOT destroy money — the receipt's Received_Amount is unchanged, the
 * money simply becomes "unapplied" and can be reassigned or added to another invoice on the unit.
 */
public with sharing class ReceiptManageController {

    public class ReceiptView {
        @AuraEnabled public Id receiptId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String paymentStatus;
        @AuraEnabled public Decimal receivedAmount;
        @AuraEnabled public Decimal allocatedAmount;
        @AuraEnabled public Decimal unappliedAmount;
        @AuraEnabled public Boolean cancelled;
        @AuraEnabled public List<AllocationView> allocations;
        @AuraEnabled public List<ComboOption> invoiceOptions; // invoices on the receipt's unit
        @AuraEnabled public List<ComboOption> modeOptions;    // Mode_of_Payment picklist values
    }

    public class AllocationView {
        @AuraEnabled public Id lineId;
        @AuraEnabled public Id invoiceId;
        @AuraEnabled public String invoiceLabel;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String modeOfPayment;
    }

    public class ComboOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public ComboOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /** Load a receipt, its allocation lines, unapplied balance, and the unit's invoice options. */
    @AuraEnabled(cacheable=true)
    public static ReceiptView getReceipt(Id receiptId) {
        if (receiptId == null) {
            throw new AuraHandledException('No receipt specified.');
        }
        List<Receipt__c> recs = [
            SELECT Id, Name, Status__c, Payment_Status__c, Received_Amount__c, Unit__c
            FROM Receipt__c WHERE Id = :receiptId LIMIT 1
        ];
        if (recs.isEmpty()) {
            throw new AuraHandledException('Receipt not found.');
        }
        Receipt__c r = recs[0];

        ReceiptView v = new ReceiptView();
        v.receiptId = r.Id;
        v.name = r.Name;
        v.status = r.Status__c;
        v.paymentStatus = r.Payment_Status__c;
        v.receivedAmount = r.Received_Amount__c == null ? 0 : r.Received_Amount__c;
        v.cancelled = (r.Payment_Status__c == 'Cancelled');
        v.allocations = new List<AllocationView>();

        Decimal allocated = 0;
        for (Receipt_Amount__c ra : [
            SELECT Id, Invoice__c, Invoice__r.Invoice_Number__c, Invoice__r.Name,
                   Amount__c, Mode_of_Payment__c
            FROM Receipt_Amount__c
            WHERE Receipt__c = :receiptId
            ORDER BY CreatedDate ASC
        ]) {
            AllocationView a = new AllocationView();
            a.lineId = ra.Id;
            a.invoiceId = ra.Invoice__c;
            a.invoiceLabel = invoiceLabel(ra.Invoice__r);
            a.amount = ra.Amount__c;
            a.modeOfPayment = ra.Mode_of_Payment__c;
            v.allocations.add(a);
            allocated += (ra.Amount__c == null ? 0 : ra.Amount__c);
        }
        v.allocatedAmount = allocated;
        v.unappliedAmount = v.receivedAmount - allocated;

        v.invoiceOptions = new List<ComboOption>();
        if (r.Unit__c != null) {
            for (Invoice__c inv : [
                SELECT Id, Invoice_Number__c, Name FROM Invoice__c
                WHERE Unit__c = :r.Unit__c ORDER BY Invoice_Date__c ASC NULLS LAST, Name ASC
            ]) {
                v.invoiceOptions.add(new ComboOption(invoiceLabelFor(inv.Invoice_Number__c, inv.Name), inv.Id));
            }
        }
        v.modeOptions = modeOptions();
        return v;
    }

    /** Active Mode_of_Payment picklist values, fetched from the schema so they match the org. */
    private static List<ComboOption> modeOptions() {
        List<ComboOption> opts = new List<ComboOption>();
        for (Schema.PicklistEntry e : Receipt_Amount__c.Mode_of_Payment__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) opts.add(new ComboOption(e.getLabel(), e.getValue()));
        }
        return opts;
    }

    /** Save an allocation line's invoice, mode and amount together (single row Save in the panel). */
    @AuraEnabled
    public static void saveAllocation(Id lineId, Id invoiceId, String modeOfPayment, Decimal amount) {
        if (lineId == null || invoiceId == null) throw new AuraHandledException('Line and invoice are required.');
        if (amount == null || amount < 0) throw new AuraHandledException('Amount must be zero or greater.');
        try {
            Receipt_Amount__c line = [
                SELECT Id, Receipt__c, Receipt__r.Unit__c, Invoice__c FROM Receipt_Amount__c WHERE Id = :lineId LIMIT 1
            ];
            Id oldInvoiceId = line.Invoice__c;
            Boolean invoiceChanged = (invoiceId != oldInvoiceId);
            if (invoiceChanged) assertSameUnit(line.Receipt__r.Unit__c, invoiceId);

            update new Receipt_Amount__c(
                Id = lineId, Invoice__c = invoiceId, Mode_of_Payment__c = modeOfPayment, Amount__c = amount
            );
            syncReceiptInvoice(line.Receipt__c, oldInvoiceId);
            if (invoiceChanged) syncReceiptInvoice(line.Receipt__c, invoiceId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not save the allocation: ' + e.getMessage());
        }
    }

    /** Change the amount a receipt line applies to its invoice. */
    @AuraEnabled
    public static void updateAllocationAmount(Id lineId, Decimal newAmount) {
        if (lineId == null) throw new AuraHandledException('No allocation specified.');
        if (newAmount == null || newAmount < 0) throw new AuraHandledException('Amount must be zero or greater.');
        try {
            Receipt_Amount__c line = [SELECT Id, Receipt__c, Invoice__c FROM Receipt_Amount__c WHERE Id = :lineId LIMIT 1];
            update new Receipt_Amount__c(Id = lineId, Amount__c = newAmount);
            syncReceiptInvoice(line.Receipt__c, line.Invoice__c);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not update the amount: ' + e.getMessage());
        }
    }

    /** Re-point an existing allocation line to a different invoice on the same unit. */
    @AuraEnabled
    public static void reassignAllocation(Id lineId, Id newInvoiceId) {
        if (lineId == null || newInvoiceId == null) throw new AuraHandledException('Line and target invoice are required.');
        try {
            Receipt_Amount__c line = [
                SELECT Id, Receipt__c, Receipt__r.Unit__c, Invoice__c FROM Receipt_Amount__c WHERE Id = :lineId LIMIT 1
            ];
            Id oldInvoiceId = line.Invoice__c;
            if (oldInvoiceId == newInvoiceId) return;
            assertSameUnit(line.Receipt__r.Unit__c, newInvoiceId);

            update new Receipt_Amount__c(Id = lineId, Invoice__c = newInvoiceId);
            syncReceiptInvoice(line.Receipt__c, oldInvoiceId);
            syncReceiptInvoice(line.Receipt__c, newInvoiceId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not reassign the allocation: ' + e.getMessage());
        }
    }

    /** Apply money from this receipt to another invoice on the same unit (splits / uses unapplied cash). */
    @AuraEnabled
    public static void addAllocation(Id receiptId, Id invoiceId, Decimal amount, String modeOfPayment) {
        if (receiptId == null || invoiceId == null) throw new AuraHandledException('Receipt and invoice are required.');
        if (amount == null || amount <= 0) throw new AuraHandledException('Amount must be greater than zero.');
        try {
            Receipt__c r = [SELECT Id, Unit__c FROM Receipt__c WHERE Id = :receiptId LIMIT 1];
            assertSameUnit(r.Unit__c, invoiceId);
            insert new Receipt_Amount__c(
                Receipt__c = receiptId, Invoice__c = invoiceId, Amount__c = amount, Mode_of_Payment__c = modeOfPayment
            );
            syncReceiptInvoice(receiptId, invoiceId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not add the allocation: ' + e.getMessage());
        }
    }

    /** Remove an allocation entirely (money returns to the receipt as unapplied). */
    @AuraEnabled
    public static void removeAllocation(Id lineId) {
        if (lineId == null) throw new AuraHandledException('No allocation specified.');
        try {
            Receipt_Amount__c line = [SELECT Id, Receipt__c, Invoice__c FROM Receipt_Amount__c WHERE Id = :lineId LIMIT 1];
            Id receiptId = line.Receipt__c;
            Id invoiceId = line.Invoice__c;
            delete line;
            syncReceiptInvoice(receiptId, invoiceId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not remove the allocation: ' + e.getMessage());
        }
    }

    /** Soft-cancel a whole receipt: it drops out of every total but the record + number are kept. */
    @AuraEnabled
    public static void cancelReceipt(Id receiptId) {
        if (receiptId == null) throw new AuraHandledException('No receipt specified.');
        try {
            update new Receipt__c(Id = receiptId, Payment_Status__c = 'Cancelled');
        } catch (Exception e) {
            throw new AuraHandledException('Could not cancel the receipt: ' + e.getMessage());
        }
    }

    // ---- helpers -------------------------------------------------------------

    private static String invoiceLabel(Invoice__c inv) {
        if (inv == null) return null;
        return invoiceLabelFor(inv.Invoice_Number__c, inv.Name);
    }

    private static String invoiceLabelFor(String num, String name) {
        return String.isNotBlank(num) ? num : name;
    }

    private static void assertSameUnit(Id receiptUnitId, Id invoiceId) {
        Invoice__c inv = [SELECT Unit__c FROM Invoice__c WHERE Id = :invoiceId LIMIT 1];
        if (receiptUnitId == null || inv.Unit__c != receiptUnitId) {
            throw new AuraHandledException('The invoice must belong to the same unit as the receipt.');
        }
    }

    /**
     * Keep the Receipt_Invoice__c link (read by the receipt PDF) consistent with the remaining
     * Receipt_Amount__c lines for a given receipt+invoice pair: set its Amount to their sum, or
     * delete the link when no lines remain.
     */
    private static void syncReceiptInvoice(Id receiptId, Id invoiceId) {
        if (receiptId == null || invoiceId == null) return;

        Decimal total = 0;
        Boolean anyLine = false;
        for (Receipt_Amount__c ra : [
            SELECT Amount__c FROM Receipt_Amount__c
            WHERE Receipt__c = :receiptId AND Invoice__c = :invoiceId
        ]) {
            anyLine = true;
            total += (ra.Amount__c == null ? 0 : ra.Amount__c);
        }

        List<Receipt_Invoice__c> links = [
            SELECT Id, Amount__c FROM Receipt_Invoice__c
            WHERE Receipt__c = :receiptId AND Invoice__c = :invoiceId
        ];

        if (!anyLine) {
            if (!links.isEmpty()) delete links;
            return;
        }
        if (links.isEmpty()) {
            insert new Receipt_Invoice__c(Receipt__c = receiptId, Invoice__c = invoiceId, Amount__c = total);
        } else {
            List<Receipt_Invoice__c> toUpdate = new List<Receipt_Invoice__c>();
            for (Receipt_Invoice__c ri : links) {
                if (ri.Amount__c != total) {
                    toUpdate.add(new Receipt_Invoice__c(Id = ri.Id, Amount__c = total));
                }
            }
            if (!toUpdate.isEmpty()) update toUpdate;
        }
    }
}
