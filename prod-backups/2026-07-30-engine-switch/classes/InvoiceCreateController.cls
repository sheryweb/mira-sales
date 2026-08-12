/**
 * InvoiceCreateController — backend for the "Create Invoice" popup wizard (LWC).
 *
 * Replaces the Add_New_Invoice_Screen_Flow. Two entry points:
 *   getContext(unitId)  — runs the guards (DLD setup done + an active booking Opportunity exists)
 *                         and returns the selectable cash-flow installments plus unit/opportunity/
 *                         account context for the wizard header and preview.
 *   createInvoice(req)  — inserts the Invoice + its Milestone_Invoice__c rows and marks the covered
 *                         Cash_Flow__c installments as invoiced.
 *
 * Amounts are FACTS derived from the covered installments: Sub-Total / VAT / Grand-Total are summed
 * from the selected Cash Flows (single source of truth, like the Manage panel's recompute). The
 * financial engine (fired by the Invoice + Milestone inserts) then derives Paid / Status; the
 * Invoice number is auto-assigned by InvoiceTriggerHelper on before-insert.
 */
public with sharing class InvoiceCreateController {

    // ---- context returned to the wizard ----------------------------------------------------------
    public class CreateContext {
        @AuraEnabled public Boolean canProceed;      // false when a guard blocks creation
        @AuraEnabled public String blockReason;      // message to show when canProceed = false
        @AuraEnabled public Id unitId;
        @AuraEnabled public String unitName;
        @AuraEnabled public String projectName;      // for the preview component
        @AuraEnabled public String propertyDetails;  // for the preview component
        @AuraEnabled public Decimal salePrice;       // for the preview component
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String customerName;
        @AuraEnabled public String customerId;       // Account.Financial_Number__c
        @AuraEnabled public Date defaultInvoiceDate;
        @AuraEnabled public Date defaultDueDate;
        @AuraEnabled public List<InstallmentOption> installments;
        @AuraEnabled public List<ComboOption> secondaryCurrencyOptions;
    }

    public class InstallmentOption {
        @AuraEnabled public Id cashFlowId;
        @AuraEnabled public String milestone;        // Installment_Milestone__c
        @AuraEnabled public Date installmentDate;    // Date__c
        @AuraEnabled public Decimal amount;          // Amount_on_Invoice__c
        @AuraEnabled public Decimal vat;             // VAT_Amount__c
        @AuraEnabled public Decimal percent;         // Percent__c as a fraction (0.10 for 10%)
    }

    public class ComboOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public ComboOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    // ---- request payload for createInvoice -------------------------------------------------------
    // Id-typed fields are declared as String: Id-typed properties inside a wrapper class do NOT
    // populate reliably from an LWC imperative call (they arrive null), whereas String fields do.
    public class CreateRequest {
        @AuraEnabled public String unitId;
        @AuraEnabled public List<String> cashFlowIds;
        @AuraEnabled public Date invoiceDate;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public String financialDetailId;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean otherCurrency;
        @AuraEnabled public String secondaryCurrency;
        @AuraEnabled public Decimal conversionRate;
    }

    private static final String STAGE_NEW = 'New';
    private static final String STAGE_CANCELLED = 'Cancelled';
    private static final String STAGE_TRANSFERRED = 'Transferred';

    private static final String MSG_NO_DLD =
        'Please complete the One Time DLD fee setup on this unit before creating an invoice.';
    private static final String MSG_NO_BOOKING =
        'There is no active booking for this unit. Please make sure an active booking exists before creating an invoice.';

    /**
     * Load everything the wizard needs. Never throws for the two business guards — instead returns
     * canProceed = false with a blockReason so the wizard can show the same messages the flow did.
     */
    @AuraEnabled(cacheable=false)
    public static CreateContext getContext(Id unitId) {
        if (unitId == null) throw new AuraHandledException('No unit specified.');

        List<Unit__c> units = [
            SELECT Id, Title__c, DLD_Fee_Setup__c, Project_Name_Text__c,
                   Property_Code_Text__c, Cost_AED__c
            FROM Unit__c WHERE Id = :unitId LIMIT 1
        ];
        if (units.isEmpty()) throw new AuraHandledException('Unit not found.');
        Unit__c unit = units[0];

        CreateContext ctx = new CreateContext();
        ctx.unitId = unit.Id;
        ctx.unitName = unit.Title__c;
        ctx.projectName = unit.Project_Name_Text__c;
        ctx.propertyDetails = unit.Property_Code_Text__c;
        ctx.salePrice = unit.Cost_AED__c;
        ctx.defaultInvoiceDate = Date.today();
        ctx.defaultDueDate = Date.today().addDays(2);
        ctx.installments = new List<InstallmentOption>();
        ctx.secondaryCurrencyOptions = picklistOptions(Invoice__c.Secondary_Currency__c);

        // Guard 1 — DLD fee setup must be done.
        if (unit.DLD_Fee_Setup__c != true) {
            ctx.canProceed = false;
            ctx.blockReason = MSG_NO_DLD;
            return ctx;
        }

        // Guard 2 — an active booking Opportunity must exist.
        Opportunity opp = findBooking(unitId);
        if (opp == null) {
            ctx.canProceed = false;
            ctx.blockReason = MSG_NO_BOOKING;
            return ctx;
        }
        ctx.opportunityId = opp.Id;
        ctx.opportunityName = opp.Name;
        ctx.accountId = opp.AccountId;
        ctx.customerName = opp.Account_Name__c;
        ctx.customerId = (opp.Account != null) ? opp.Account.Financial_Number__c : null;

        // Selectable installments — this unit's cash flows not yet invoiced and not waived off.
        for (Cash_Flow__c cf : queryInstallments(unitId)) {
            InstallmentOption o = new InstallmentOption();
            o.cashFlowId = cf.Id;
            o.milestone = cf.Installment_Milestone__c;
            o.installmentDate = cf.Date__c;
            o.amount = cf.Amount_on_Invoice__c;
            o.vat = cf.VAT_Amount__c;
            o.percent = asFraction(cf.Percent__c);
            ctx.installments.add(o);
        }

        ctx.canProceed = true;
        return ctx;
    }

    /**
     * Create the invoice for the chosen installments. Returns the new Invoice Id.
     * Sub-Total / VAT / Grand-Total are derived from the covered cash flows (not client-supplied).
     *
     * The payload is passed as a JSON string (not a wrapper param): an Apex-class parameter does not
     * reliably receive its field values from an LWC imperative call, so we deserialize here instead.
     */
    @AuraEnabled
    public static Id createInvoice(String payload) {
        if (String.isBlank(payload)) throw new AuraHandledException('No data supplied.');
        CreateRequest req;
        try {
            req = (CreateRequest) JSON.deserialize(payload, CreateRequest.class);
        } catch (Exception e) {
            throw new AuraHandledException('Could not read the invoice data: ' + e.getMessage());
        }
        if (req == null) throw new AuraHandledException('No data supplied.');
        if (String.isBlank(req.unitId)) throw new AuraHandledException('No unit specified.');
        if (req.cashFlowIds == null || req.cashFlowIds.isEmpty()) {
            throw new AuraHandledException('Select at least one installment to invoice.');
        }
        if (req.invoiceDate == null) throw new AuraHandledException('Invoice date is required.');
        if (req.dueDate == null) throw new AuraHandledException('Due date is required.');
        if (String.isBlank(req.financialDetailId)) throw new AuraHandledException('Financial detail is required.');
        if (String.isBlank(req.description)) throw new AuraHandledException('Description is required.');

        Id unitId = (Id) req.unitId;
        Id financialDetailId = (Id) req.financialDetailId;

        Boolean useOther = (req.otherCurrency == true);
        if (useOther) {
            if (String.isBlank(req.secondaryCurrency)) throw new AuraHandledException('Select a secondary currency.');
            if (req.conversionRate == null || req.conversionRate <= 0) {
                throw new AuraHandledException('Conversion rate must be greater than zero.');
            }
        }

        // Guards must still hold at save time.
        Opportunity opp = findBooking(unitId);
        if (opp == null) throw new AuraHandledException(MSG_NO_BOOKING);

        // Re-load the selected installments from the DB (never trust client amounts). They must
        // belong to this unit and still be selectable (not invoiced, not waived).
        Map<Id, Cash_Flow__c> selectable = new Map<Id, Cash_Flow__c>();
        for (Cash_Flow__c cf : queryInstallments(unitId)) {
            selectable.put(cf.Id, cf);
        }
        List<Cash_Flow__c> chosen = new List<Cash_Flow__c>();
        for (String cfIdStr : req.cashFlowIds) {
            Cash_Flow__c cf = selectable.get((Id) cfIdStr);
            if (cf == null) {
                throw new AuraHandledException('One of the selected installments is no longer available. Please reopen and try again.');
            }
            chosen.add(cf);
        }

        Decimal subTotal = 0;
        Decimal vat = 0;
        for (Cash_Flow__c cf : chosen) {
            subTotal += nz(cf.Amount_on_Invoice__c);
            vat += nz(cf.VAT_Amount__c);
        }
        Decimal grand = subTotal + vat;

        try {
            Invoice__c inv = new Invoice__c(
                Unit__c = unitId,
                Opportunity__c = opp.Id,
                Account__c = opp.AccountId,
                Customer_Name__c = opp.Account_Name__c,
                Customer_Id__c = (opp.Account != null) ? opp.Account.Financial_Number__c : null,
                Financial_Detail__c = financialDetailId,
                Description__c = req.description,
                Invoice_Date__c = req.invoiceDate,
                Due_Date__c = req.dueDate,
                Status__c = 'Pending',
                Type__c = 'Proforma Invoice',
                Sub_Total_Amount__c = subTotal,
                VAT_Amount__c = vat,
                Grand_Total_Amount__c = grand
            );
            if (useOther) {
                inv.Secondary_Currency__c = req.secondaryCurrency;
                inv.Conversion_Rate__c = req.conversionRate;
                // Kept identical to the existing flow: Sub-Total / rate.
                inv.Secondary_Currency_Amount__c = subTotal / req.conversionRate;
            } else {
                inv.Secondary_Currency_Amount__c = 0;
            }
            insert inv;

            List<Milestone_Invoice__c> milestones = new List<Milestone_Invoice__c>();
            for (Cash_Flow__c cf : chosen) {
                milestones.add(new Milestone_Invoice__c(
                    Invoice__c = inv.Id,
                    Cash_Flow__c = cf.Id,
                    Amount__c = cf.Amount_on_Invoice__c,
                    Name = String.isBlank(cf.Installment_Milestone__c) ? 'Installment' : cf.Installment_Milestone__c,
                    Installment_Date__c = cf.Date__c
                ));
            }
            insert milestones;

            List<Cash_Flow__c> toInvoice = new List<Cash_Flow__c>();
            for (Cash_Flow__c cf : chosen) {
                toInvoice.add(new Cash_Flow__c(Id = cf.Id, Is_Invoiced__c = true));
            }
            update toInvoice;

            return inv.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not create the invoice: ' + e.getMessage());
        }
    }

    // ---- helpers ---------------------------------------------------------------------------------

    /** First non-New/Cancelled/Transferred Opportunity on the unit (the "booking"), or null. */
    private static Opportunity findBooking(Id unitId) {
        List<Opportunity> opps = [
            SELECT Id, Name, AccountId, Account_Name__c, Account.Financial_Number__c
            FROM Opportunity
            WHERE Unit__c = :unitId
              AND StageName != :STAGE_NEW
              AND StageName != :STAGE_CANCELLED
              AND StageName != :STAGE_TRANSFERRED
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }

    /** This unit's cash-flow installments that are available to invoice. */
    private static List<Cash_Flow__c> queryInstallments(Id unitId) {
        return [
            SELECT Id, Installment_Milestone__c, Date__c, Amount_on_Invoice__c, VAT_Amount__c, Percent__c
            FROM Cash_Flow__c
            WHERE Unit__c = :unitId AND Is_Invoiced__c = false AND Waived_Off__c = false
            ORDER BY Date__c ASC NULLS LAST, Id ASC
        ];
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