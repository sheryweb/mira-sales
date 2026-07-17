/**
 * ReceiptManageController — backend for the "Manage Receipt" LWC panel (Step 6).
 *
 * Guided, sanctioned edit path for finance to reduce/remove a receipt's allocations or
 * soft-cancel a whole receipt. The four stored totals + the Milestone_Receipt ledger are
 * maintained automatically by the self-healing engine triggers; this controller only mutates
 * the FACTS (Receipt_Amount__c lines / Receipt.Payment_Status__c) and keeps the parallel
 * Receipt_Invoice__c link (read by the receipt PDF) in sync with the remaining lines.
 */
public with sharing class ReceiptManageController {

    public class ReceiptView {
        @AuraEnabled public Id receiptId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String paymentStatus;
        @AuraEnabled public Decimal receivedAmount;
        @AuraEnabled public Boolean cancelled;
        @AuraEnabled public List<AllocationView> allocations;
    }

    public class AllocationView {
        @AuraEnabled public Id lineId;
        @AuraEnabled public Id invoiceId;
        @AuraEnabled public String invoiceNumber;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String modeOfPayment;
    }

    /** Load a receipt and its allocation lines for the panel. */
    @AuraEnabled(cacheable=true)
    public static ReceiptView getReceipt(Id receiptId) {
        if (receiptId == null) {
            throw new AuraHandledException('No receipt specified.');
        }
        List<Receipt__c> recs = [
            SELECT Id, Name, Status__c, Payment_Status__c, Received_Amount__c
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
        v.receivedAmount = r.Received_Amount__c;
        v.cancelled = (r.Payment_Status__c == 'Cancelled');
        v.allocations = new List<AllocationView>();

        for (Receipt_Amount__c ra : [
            SELECT Id, Invoice__c, Invoice__r.Invoice_Number__c, Amount__c, Mode_of_Payment__c
            FROM Receipt_Amount__c
            WHERE Receipt__c = :receiptId
            ORDER BY CreatedDate ASC
        ]) {
            AllocationView a = new AllocationView();
            a.lineId = ra.Id;
            a.invoiceId = ra.Invoice__c;
            a.invoiceNumber = ra.Invoice__r != null ? ra.Invoice__r.Invoice_Number__c : null;
            a.amount = ra.Amount__c;
            a.modeOfPayment = ra.Mode_of_Payment__c;
            v.allocations.add(a);
        }
        return v;
    }

    /** Change the amount a receipt line applies to its invoice. Totals self-heal via triggers. */
    @AuraEnabled
    public static void updateAllocationAmount(Id lineId, Decimal newAmount) {
        if (lineId == null) {
            throw new AuraHandledException('No allocation specified.');
        }
        if (newAmount == null || newAmount < 0) {
            throw new AuraHandledException('Amount must be zero or greater.');
        }
        try {
            Receipt_Amount__c line = [
                SELECT Id, Receipt__c, Invoice__c FROM Receipt_Amount__c WHERE Id = :lineId LIMIT 1
            ];
            update new Receipt_Amount__c(Id = lineId, Amount__c = newAmount);
            syncReceiptInvoice(line.Receipt__c, line.Invoice__c);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not update the amount: ' + e.getMessage());
        }
    }

    /** Remove an allocation entirely (un-allocate the invoice line from the receipt). */
    @AuraEnabled
    public static void removeAllocation(Id lineId) {
        if (lineId == null) {
            throw new AuraHandledException('No allocation specified.');
        }
        try {
            Receipt_Amount__c line = [
                SELECT Id, Receipt__c, Invoice__c FROM Receipt_Amount__c WHERE Id = :lineId LIMIT 1
            ];
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
        if (receiptId == null) {
            throw new AuraHandledException('No receipt specified.');
        }
        try {
            update new Receipt__c(Id = receiptId, Payment_Status__c = 'Cancelled');
        } catch (Exception e) {
            throw new AuraHandledException('Could not cancel the receipt: ' + e.getMessage());
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
            if (!links.isEmpty()) delete links; // fully un-allocated -> drop the link
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
