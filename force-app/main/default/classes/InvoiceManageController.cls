/**
 * InvoiceManageController — backend for the "Manage Invoice" LWC panel (Step 7).
 *
 * Guided edit path for finance to manage which Cash Flow installments the invoice covers (its
 * Milestone_Invoice__c rows) and its secondary-currency detail. The four stored totals + status are
 * maintained by the self-healing engine triggers; this controller only mutates facts.
 *
 * The invoice amount is NOT user-editable: Sub-Total / VAT / Grand-Total are derived from the covered
 * cash-flow installments (recomputeInvoiceAmounts) and re-derive whenever installments change. An
 * installment's amount is likewise derived from the Cash Flow's Amount_on_Invoice__c (computed from
 * the installment's percentage). Re-parenting an invoice to a different unit is intentionally NOT
 * handled here (separate step).
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
        @AuraEnabled public Boolean otherCurrency;
        @AuraEnabled public String secondaryCurrency;
        @AuraEnabled public Decimal conversionRate;
        @AuraEnabled public List<InstallmentView> installments;
        @AuraEnabled public List<CashFlowOption> cashFlowOptions;      // cash flows on the invoice's unit
        @AuraEnabled public List<ComboOption> secondaryCurrencyOptions;
    }

    public class ComboOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public ComboOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
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
            // Percent__c holds the display number (10 for 10%); the LWC percent formatter
            // expects a fraction, so send it as 0.10.
            this.percent = asFraction(cf.Percent__c);
            this.installmentDate = cf.Date__c;
            this.amount = cf.Amount_on_Invoice__c;
        }
    }

    // Not cacheable: the panel calls this imperatively after every mutation (add/remove installment,
    // currency change) and must get freshly re-derived totals/status, not a stale client cache.
    @AuraEnabled
    public static InvoiceView getInvoice(Id invoiceId) {
        if (invoiceId == null) throw new AuraHandledException('No invoice specified.');
        List<Invoice__c> invs = [
            SELECT Id, Name, Invoice_Number__c, Unit__c, Unit__r.Name,
                   Sub_Total_Amount__c, VAT_Amount__c, Paid_Amount__c, Pending_Amount__c, Status__c,
                   Secondary_Currency__c, Conversion_Rate__c
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
        v.secondaryCurrency = inv.Secondary_Currency__c;
        v.conversionRate = inv.Conversion_Rate__c;
        v.otherCurrency = String.isNotBlank(inv.Secondary_Currency__c);
        v.secondaryCurrencyOptions = picklistOptions(Invoice__c.Secondary_Currency__c);

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
                iv.percent = asFraction(mi.Cash_Flow__r.Percent__c);
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

    /**
     * Set (optionally) the invoice's secondary-currency detail. Sub-Total / VAT / Grand-Total are
     * NOT editable here: they are derived from the covered cash-flow installments (see
     * recomputeInvoiceAmounts) and re-derive whenever installments change. When otherCurrency is off,
     * the secondary-currency fields are cleared; when on, Secondary_Currency_Amount__c is set to the
     * current (derived) Grand Total x rate.
     */
    @AuraEnabled
    public static void updateCurrency(Id invoiceId,
            Boolean otherCurrency, String secondaryCurrency, Decimal conversionRate) {
        if (invoiceId == null) throw new AuraHandledException('No invoice specified.');

        Boolean useOther = (otherCurrency == true);
        if (useOther) {
            if (String.isBlank(secondaryCurrency)) throw new AuraHandledException('Select a secondary currency.');
            if (conversionRate == null || conversionRate <= 0) throw new AuraHandledException('Conversion rate must be greater than zero.');
        }
        try {
            Invoice__c u = new Invoice__c(Id = invoiceId);
            if (useOther) {
                Invoice__c inv = [
                    SELECT Sub_Total_Amount__c, VAT_Amount__c FROM Invoice__c WHERE Id = :invoiceId LIMIT 1
                ];
                Decimal grand = nz(inv.Sub_Total_Amount__c) + nz(inv.VAT_Amount__c);
                u.Secondary_Currency__c = secondaryCurrency;
                u.Conversion_Rate__c = conversionRate;
                u.Secondary_Currency_Amount__c = grand * conversionRate;
            } else {
                u.Secondary_Currency__c = null;
                u.Conversion_Rate__c = null;
                u.Secondary_Currency_Amount__c = null;
            }
            update u;
        } catch (Exception e) {
            throw new AuraHandledException('Could not update the currency: ' + e.getMessage());
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
            recomputeInvoiceAmounts(invoiceId);
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
            List<Milestone_Invoice__c> rows = [SELECT Id, Invoice__c FROM Milestone_Invoice__c WHERE Id = :milestoneId];
            if (rows.isEmpty()) return;
            Id invoiceId = rows[0].Invoice__c;
            delete rows;
            recomputeInvoiceAmounts(invoiceId);
        } catch (Exception e) {
            throw new AuraHandledException('Could not remove the installment: ' + e.getMessage());
        }
    }

    // ---- helpers ----

    /**
     * Recompute the invoice's Sub-Total / VAT / Grand-Total as the sum of the cash-flow items it
     * covers, so the invoice amount always reflects its installments. Firing the update also lets
     * the engine re-derive paid/pending/status.
     */
    private static void recomputeInvoiceAmounts(Id invoiceId) {
        if (invoiceId == null) return;
        Decimal subTotal = 0;
        Decimal vat = 0;
        for (Milestone_Invoice__c mi : [
            SELECT Cash_Flow__r.Amount_on_Invoice__c, Cash_Flow__r.VAT_Amount__c
            FROM Milestone_Invoice__c
            WHERE Invoice__c = :invoiceId AND Cash_Flow__c != null
        ]) {
            subTotal += nz(mi.Cash_Flow__r.Amount_on_Invoice__c);
            vat += nz(mi.Cash_Flow__r.VAT_Amount__c);
        }
        update new Invoice__c(
            Id = invoiceId, Sub_Total_Amount__c = subTotal, VAT_Amount__c = vat,
            Grand_Total_Amount__c = subTotal + vat
        );
    }

    private static void assertSameUnit(Id invoiceId, Id cashFlowId) {
        Invoice__c inv = [SELECT Unit__c FROM Invoice__c WHERE Id = :invoiceId LIMIT 1];
        Cash_Flow__c cf = [SELECT Unit__c FROM Cash_Flow__c WHERE Id = :cashFlowId LIMIT 1];
        if (inv.Unit__c == null || cf.Unit__c != inv.Unit__c) {
            throw new AuraHandledException('The installment must belong to the same unit as the invoice.');
        }
    }

    private static List<ComboOption> picklistOptions(Schema.SObjectField field) {
        List<ComboOption> opts = new List<ComboOption>();
        for (Schema.PicklistEntry e : field.getDescribe().getPicklistValues()) {
            if (e.isActive()) opts.add(new ComboOption(e.getLabel(), e.getValue()));
        }
        return opts;
    }

    private static Decimal nz(Decimal d) {
        return d == null ? 0 : d;
    }

    /** Convert a Salesforce Percent value (10 for 10%) to the fraction the UI formatter expects. */
    private static Decimal asFraction(Decimal percentValue) {
        return percentValue == null ? null : percentValue / 100;
    }
}
