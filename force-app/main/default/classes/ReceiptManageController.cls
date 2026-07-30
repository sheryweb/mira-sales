/**
 * ReceiptManageController — backend for the "Manage Receipt" LWC panel (Step 6).
 *
 * Guided edit path for finance to reduce, remove, reassign, or add a receipt's allocations, or
 * soft-cancel a receipt. Totals + the Milestone_Receipt ledger self-heal via the engine triggers;
 * this controller mutates facts and keeps the parallel Receipt_Invoice__c link (read by the PDF)
 * in sync. Each allocation carries payment-instrument detail (reference / cheque / bank / POS)
 * mirroring the create flow's mode-conditional fields.
 */
public with sharing class ReceiptManageController {

    private static final String TYPE_COMMISSION = 'Commission';

    public class ReceiptView {
        @AuraEnabled public Id receiptId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String paymentStatus;
        @AuraEnabled public Decimal receivedAmount;
        @AuraEnabled public Decimal allocatedAmount;
        @AuraEnabled public Decimal unappliedAmount;
        @AuraEnabled public Boolean cancelled;
        @AuraEnabled public String cancellationReason;
        @AuraEnabled public List<AllocationView> allocations;
        @AuraEnabled public List<ComboOption> invoiceOptions;
        @AuraEnabled public List<ComboOption> modeOptions;
        @AuraEnabled public List<ComboOption> bankNameOptions;
    }

    public class AllocationView {
        @AuraEnabled public Id lineId;
        @AuraEnabled public Id invoiceId;
        @AuraEnabled public String invoiceLabel;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String modeOfPayment;
        @AuraEnabled public String referenceNumber;
        @AuraEnabled public String chequeNumber;
        @AuraEnabled public Date chequeDate;
        @AuraEnabled public String bankName;
        @AuraEnabled public String posReceiptNumber;
    }

    /** Input for add / save of an allocation line, including mode-conditional payment detail. */
    public class AllocationInput {
        @AuraEnabled public Id lineId;
        @AuraEnabled public Id invoiceId;
        @AuraEnabled public String modeOfPayment;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String referenceNumber;
        @AuraEnabled public String chequeNumber;
        @AuraEnabled public Date chequeDate;
        @AuraEnabled public String bankName;
        @AuraEnabled public String posReceiptNumber;
    }

    public class ComboOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public ComboOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    // Not cacheable: the panel calls this imperatively after every mutation (save/add/remove/reassign
    // allocation) and must get freshly re-derived amounts/status, not a stale client cache.
    // Read-only, so deliberately NOT engine-gated: the panel must still render when the switch is
    // off. Every mutation below calls FinancialEngine.requireEnabled() instead.
    @AuraEnabled
    public static ReceiptView getReceipt(Id receiptId) {
        if (receiptId == null) throw new AuraHandledException('No receipt specified.');
        List<Receipt__c> recs = [
            SELECT Id, Name, Status__c, Payment_Status__c, Received_Amount__c, Unit__c,
                   Cancellation_Reason__c
            FROM Receipt__c WHERE Id = :receiptId LIMIT 1
        ];
        if (recs.isEmpty()) throw new AuraHandledException('Receipt not found.');
        Receipt__c r = recs[0];

        ReceiptView v = new ReceiptView();
        v.receiptId = r.Id;
        v.name = r.Name;
        v.status = r.Status__c;
        v.paymentStatus = r.Payment_Status__c;
        v.receivedAmount = r.Received_Amount__c == null ? 0 : r.Received_Amount__c;
        v.cancelled = (r.Payment_Status__c == 'Cancelled');
        v.cancellationReason = r.Cancellation_Reason__c;
        v.allocations = new List<AllocationView>();

        Decimal allocated = 0;
        Set<Id> allocatedInvoiceIds = new Set<Id>();
        for (Receipt_Amount__c ra : [
            SELECT Id, Invoice__c, Invoice__r.Invoice_Number__c, Invoice__r.Name, Amount__c,
                   Mode_of_Payment__c, Reference_Number__c, Cheque_Number__c, Cheque_Date__c,
                   Bank_Name__c, POS_Receipt_Number__c
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
            a.referenceNumber = ra.Reference_Number__c;
            a.chequeNumber = ra.Cheque_Number__c;
            a.chequeDate = ra.Cheque_Date__c;
            a.bankName = ra.Bank_Name__c;
            a.posReceiptNumber = ra.POS_Receipt_Number__c;
            v.allocations.add(a);
            allocated += (ra.Amount__c == null ? 0 : ra.Amount__c);
            if (ra.Invoice__c != null) allocatedInvoiceIds.add(ra.Invoice__c);
        }
        v.allocatedAmount = allocated;
        v.unappliedAmount = v.receivedAmount - allocated;

        v.invoiceOptions = new List<ComboOption>();
        if (r.Unit__c != null) {
            // Commission invoices are not receiptable. Any already carrying an allocation on this
            // receipt still appears, so an existing line keeps showing its invoice in the picker.
            for (Invoice__c inv : [
                SELECT Id, Invoice_Number__c, Name FROM Invoice__c
                WHERE Unit__c = :r.Unit__c
                  AND (Type__c != :TYPE_COMMISSION OR Id IN :allocatedInvoiceIds)
                ORDER BY Invoice_Date__c ASC NULLS LAST, Name ASC
            ]) {
                v.invoiceOptions.add(new ComboOption(invoiceLabelFor(inv.Invoice_Number__c, inv.Name), inv.Id));
            }
        }
        v.modeOptions = picklistOptions(Receipt_Amount__c.Mode_of_Payment__c);
        v.bankNameOptions = picklistOptions(Receipt_Amount__c.Bank_Name__c);
        return v;
    }

    @AuraEnabled
    public static void updateAllocationAmount(Id lineId, Decimal newAmount) {
        FinancialEngine.requireEnabled();
        if (lineId == null) throw new AuraHandledException('No allocation specified.');
        if (newAmount == null || newAmount < 0) throw new AuraHandledException('Amount must be zero or greater.');
        try {
            Receipt_Amount__c line = [SELECT Id, Receipt__c, Invoice__c FROM Receipt_Amount__c WHERE Id = :lineId LIMIT 1];
            update new Receipt_Amount__c(
                Id = lineId,
                Amount__c = newAmount,
                Amount_Text__c = newAmount.setScale(2).format()
            );
            syncReceiptInvoice(line.Receipt__c, line.Invoice__c);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not update the amount: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void reassignAllocation(Id lineId, Id newInvoiceId) {
        FinancialEngine.requireEnabled();
        if (lineId == null || newInvoiceId == null) throw new AuraHandledException('Line and target invoice are required.');
        try {
            Receipt_Amount__c line = [
                SELECT Id, Receipt__c, Receipt__r.Unit__c, Invoice__c FROM Receipt_Amount__c WHERE Id = :lineId LIMIT 1
            ];
            Id oldInvoiceId = line.Invoice__c;
            if (oldInvoiceId == newInvoiceId) return;
            assertAllocatable(line.Receipt__r.Unit__c, newInvoiceId);
            update new Receipt_Amount__c(Id = lineId, Invoice__c = newInvoiceId);
            syncReceiptInvoice(line.Receipt__c, oldInvoiceId);
            syncReceiptInvoice(line.Receipt__c, newInvoiceId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not reassign the allocation: ' + e.getMessage());
        }
    }

    /**
     * Save an allocation line's invoice, mode, amount, and payment-instrument detail together.
     * The payload is a JSON string (an Apex-class wrapper parameter does not reliably receive its
     * field values from an LWC imperative call).
     */
    @AuraEnabled
    public static void saveAllocation(String payload) {
        FinancialEngine.requireEnabled();
        AllocationInput input = parseInput(payload);
        if (input == null || input.lineId == null || input.invoiceId == null) throw new AuraHandledException('Line and invoice are required.');
        if (input.amount == null || input.amount < 0) throw new AuraHandledException('Amount must be zero or greater.');
        try {
            Receipt_Amount__c line = [
                SELECT Id, Receipt__c, Receipt__r.Unit__c, Invoice__c FROM Receipt_Amount__c WHERE Id = :input.lineId LIMIT 1
            ];
            Id oldInvoiceId = line.Invoice__c;
            Boolean invoiceChanged = (input.invoiceId != oldInvoiceId);
            if (invoiceChanged) assertAllocatable(line.Receipt__r.Unit__c, input.invoiceId);
            update toReceiptAmount(input.lineId, input);
            syncReceiptInvoice(line.Receipt__c, oldInvoiceId);
            if (invoiceChanged) syncReceiptInvoice(line.Receipt__c, input.invoiceId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not save the allocation: ' + e.getMessage());
        }
    }

    /** Apply money from this receipt to another invoice on the same unit. Payload is a JSON string. */
    @AuraEnabled
    public static void addAllocation(Id receiptId, String payload) {
        FinancialEngine.requireEnabled();
        AllocationInput input = parseInput(payload);
        if (receiptId == null || input == null || input.invoiceId == null) throw new AuraHandledException('Receipt and invoice are required.');
        if (input.amount == null || input.amount <= 0) throw new AuraHandledException('Amount must be greater than zero.');
        try {
            Receipt__c r = [SELECT Id, Unit__c FROM Receipt__c WHERE Id = :receiptId LIMIT 1];
            assertAllocatable(r.Unit__c, input.invoiceId);
            Receipt_Amount__c ra = toReceiptAmount(null, input);
            ra.Receipt__c = receiptId;
            insert ra;
            syncReceiptInvoice(receiptId, input.invoiceId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not add the allocation: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void removeAllocation(Id lineId) {
        FinancialEngine.requireEnabled();
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

    @AuraEnabled
    public static void cancelReceipt(Id receiptId, String reason) {
        FinancialEngine.requireEnabled();
        if (receiptId == null) throw new AuraHandledException('No receipt specified.');
        // A cancellation reason is mandatory — enforced here so the rule holds even if the
        // client is bypassed (direct Apex/API call).
        if (String.isBlank(reason)) throw new AuraHandledException('A cancellation reason is required.');
        try {
            update new Receipt__c(
                Id = receiptId,
                Payment_Status__c = 'Cancelled',
                Cancellation_Reason__c = reason.trim()
            );
        } catch (Exception e) {
            throw new AuraHandledException('Could not cancel the receipt: ' + e.getMessage());
        }
    }

    // ---- helpers ----

    private static Receipt_Amount__c toReceiptAmount(Id lineId, AllocationInput input) {
        return new Receipt_Amount__c(
            Id = lineId,
            Invoice__c = input.invoiceId,
            Amount__c = input.amount,
            // Keep the formatted text in lockstep with the amount — the Receipt PDF renders
            // Amount_Text__c directly, so a null/stale value breaks or misprints the PDF.
            Amount_Text__c = (input.amount != null) ? input.amount.setScale(2).format() : null,
            Mode_of_Payment__c = input.modeOfPayment,
            Reference_Number__c = input.referenceNumber,
            Cheque_Number__c = input.chequeNumber,
            Cheque_Date__c = input.chequeDate,
            Bank_Name__c = input.bankName,
            POS_Receipt_Number__c = input.posReceiptNumber
        );
    }

    private static List<ComboOption> picklistOptions(Schema.SObjectField field) {
        List<ComboOption> opts = new List<ComboOption>();
        for (Schema.PicklistEntry e : field.getDescribe().getPicklistValues()) {
            if (e.isActive()) opts.add(new ComboOption(e.getLabel(), e.getValue()));
        }
        return opts;
    }

    private static String invoiceLabel(Invoice__c inv) {
        if (inv == null) return null;
        return invoiceLabelFor(inv.Invoice_Number__c, inv.Name);
    }

    private static String invoiceLabelFor(String num, String name) {
        return String.isNotBlank(num) ? num : name;
    }

    /** Called wherever a line is newly pointed at an invoice (add / reassign / save-with-change). */
    private static void assertAllocatable(Id receiptUnitId, Id invoiceId) {
        Invoice__c inv = [SELECT Unit__c, Type__c FROM Invoice__c WHERE Id = :invoiceId LIMIT 1];
        if (receiptUnitId == null || inv.Unit__c != receiptUnitId) {
            throw new AuraHandledException('The invoice must belong to the same unit as the receipt.');
        }
        if (inv.Type__c == TYPE_COMMISSION) {
            throw new AuraHandledException('Commission invoices cannot be receipted.');
        }
    }

    private static AllocationInput parseInput(String payload) {
        if (String.isBlank(payload)) throw new AuraHandledException('No allocation data supplied.');
        try {
            return (AllocationInput) JSON.deserialize(payload, AllocationInput.class);
        } catch (Exception e) {
            throw new AuraHandledException('Could not read the allocation data: ' + e.getMessage());
        }
    }

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
