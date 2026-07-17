/**
 * InvoiceManageController — backend for the "Manage Invoice" LWC panel (Step 7).
 *
 * Guided edit path for finance to correct an invoice's amount (Sub-Total / VAT) and manage which
 * Cash Flow installments the invoice covers (its Milestone_Invoice__c rows). The four stored totals
 * + status are maintained by the self-healing engine triggers; this controller only mutates facts.
 *
 * An installment's amount is NOT user-editable: it is derived from the Cash Flow's
 * Amount_on_Invoice__c (which is computed from the installment's percentage). Re-parenting an
 * invoice to a different unit is intentionally NOT handled here (separate step).
 */
public with sharing class InvoiceManageController {

    public class InvoiceView {
        @AuraEnabled public Id invoiceId;
        @AuraEnabled public String label;
        @AuraEnabled public String unitName;
        @AuraEnabled public Decimal subTotal;
        @AuraEnabled public Decimal vat;
        @AuraEnabled public Decimal grandTotal;
        @AuraEnabled public Decimal paid;
        @AuraEnabled public Decimal pending;
        @AuraEnabled public String status;
        @AuraEnabled public List<InstallmentView> installments;
        @AuraEnabled public List<CashFlowOption> cashFlowOptions; // cash flows on the invoice's unit
    }

    public class InstallmentView {
        @AuraEnabled public Id milestoneId;
        @AuraEnabled public Id cashFlowId;
        @AuraEnabled public String cashFlowLabel;
        @AuraEnabled public Decimal percent;
        @AuraEnabled public Date installmentDate;
        @AuraEnabled public Decimal amount;
    }

    public class CashFlowOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Decimal percent;
        @AuraEnabled public Date installmentDate;
        @AuraEnabled public Decimal amount;
        public CashFlowOption(Cash_Flow__c cf) {
            this.label = cf.Name;
            this.value = cf.Id;
            this.percent = cf.Percent__c;
            this.installmentDate = cf.Date__c;
            this.amount = cf.Amount_on_Invoice__c;
        }
    }

    @AuraEnabled(cacheable=true)
    public static InvoiceView getInvoice(Id invoiceId) {
        if (invoiceId == null) throw new AuraHandledException('No invoice specified.');
        List<Invoice__c> invs = [
            SELECT Id, Name, Invoice_Number__c, Unit__c, Unit__r.Name,
                   Sub_Total_Amount__c, VAT_Amount__c, Paid_Amount__c, Pending_Amount__c, Status__c
            FROM Invoice__c WHERE Id = :invoiceId LIMIT 1
        ];
        if (invs.isEmpty()) throw new AuraHandledException('Invoice not found.');
        Invoice__c inv = invs[0];

        InvoiceView v = new InvoiceView();
        v.invoiceId = inv.Id;
        v.label = String.isNotBlank(inv.Invoice_Number__c) ? inv.Invoice_Number__c : inv.Name;
        v.unitName = inv.Unit__r != null ? inv.Unit__r.Name : null;
        v.subTotal = nz(inv.Sub_Total_Amount__c);
        v.vat = nz(inv.VAT_Amount__c);
        v.grandTotal = v.subTotal + v.vat;
        v.paid = nz(inv.Paid_Amount__c);
        v.pending = nz(inv.Pending_Amount__c);
        v.status = inv.Status__c;

        v.installments = new List<InstallmentView>();
        for (Milestone_Invoice__c mi : [
            SELECT Id, Cash_Flow__c, Cash_Flow__r.Name, Cash_Flow__r.Percent__c,
                   Cash_Flow__r.Date__c, Cash_Flow__r.Amount_on_Invoice__c, Amount__c
            FROM Milestone_Invoice__c
            WHERE Invoice__c = :invoiceId
            ORDER BY Cash_Flow__r.Date__c ASC NULLS LAST, Id ASC
        ]) {
            InstallmentView iv = new InstallmentView();
            iv.milestoneId = mi.Id;
            iv.cashFlowId = mi.Cash_Flow__c;
            if (mi.Cash_Flow__r != null) {
                iv.cashFlowLabel = mi.Cash_Flow__r.Name;
                iv.percent = mi.Cash_Flow__r.Percent__c;
                iv.installmentDate = mi.Cash_Flow__r.Date__c;
                iv.amount = mi.Cash_Flow__r.Amount_on_Invoice__c;
            } else {
                iv.amount = mi.Amount__c;
            }
            v.installments.add(iv);
        }

        v.cashFlowOptions = new List<CashFlowOption>();
        if (inv.Unit__c != null) {
            for (Cash_Flow__c cf : [
                SELECT Id, Name, Percent__c, Date__c, Amount_on_Invoice__c FROM Cash_Flow__c
                WHERE Unit__c = :inv.Unit__c ORDER BY Date__c ASC NULLS LAST, Name ASC
            ]) {
                v.cashFlowOptions.add(new CashFlowOption(cf));
            }
        }
        return v;
    }

    /** Correct the invoice's Sub-Total and VAT. Pending + status re-derive via the engine. */
    @AuraEnabled
    public static void updateAmounts(Id invoiceId, Decimal subTotal, Decimal vat) {
        if (invoiceId == null) throw new AuraHandledException('No invoice specified.');
        if (subTotal == null || subTotal < 0) throw new AuraHandledException('Sub-total must be zero or greater.');
        if (vat == null || vat < 0) throw new AuraHandledException('VAT must be zero or greater.');
        try {
            update new Invoice__c(
                Id = invoiceId, Sub_Total_Amount__c = subTotal, VAT_Amount__c = vat,
                Grand_Total_Amount__c = subTotal + vat
            );
        } catch (Exception e) {
            throw new AuraHandledException('Could not update the amounts: ' + e.getMessage());
        }
    }

    /** Add a cash-flow installment the invoice covers. Amount is taken from the cash flow. */
    @AuraEnabled
    public static void addInstallment(Id invoiceId, Id cashFlowId) {
        if (invoiceId == null || cashFlowId == null) throw new AuraHandledException('Invoice and installment are required.');
        try {
            assertSameUnit(invoiceId, cashFlowId);
            Cash_Flow__c cf = [SELECT Amount_on_Invoice__c FROM Cash_Flow__c WHERE Id = :cashFlowId LIMIT 1];
            insert new Milestone_Invoice__c(
                Invoice__c = invoiceId, Cash_Flow__c = cashFlowId, Amount__c = cf.Amount_on_Invoice__c
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not add the installment: ' + e.getMessage());
        }
    }

    /** Remove an installment the invoice covers. */
    @AuraEnabled
    public static void removeInstallment(Id milestoneId) {
        if (milestoneId == null) throw new AuraHandledException('No installment specified.');
        try {
            delete [SELECT Id FROM Milestone_Invoice__c WHERE Id = :milestoneId];
        } catch (Exception e) {
            throw new AuraHandledException('Could not remove the installment: ' + e.getMessage());
        }
    }

    // ---- helpers ----

    private static void assertSameUnit(Id invoiceId, Id cashFlowId) {
        Invoice__c inv = [SELECT Unit__c FROM Invoice__c WHERE Id = :invoiceId LIMIT 1];
        Cash_Flow__c cf = [SELECT Unit__c FROM Cash_Flow__c WHERE Id = :cashFlowId LIMIT 1];
        if (inv.Unit__c == null || cf.Unit__c != inv.Unit__c) {
            throw new AuraHandledException('The installment must belong to the same unit as the invoice.');
        }
    }

    private static Decimal nz(Decimal d) {
        return d == null ? 0 : d;
    }
}
