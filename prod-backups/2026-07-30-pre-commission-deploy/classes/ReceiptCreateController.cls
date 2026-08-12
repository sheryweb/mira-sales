/**
 * ReceiptCreateController — backend for the "Generate Receipt" popup wizard (LWC).
 *
 * Replaces the Add_New_Payment_Screen_Flow. Two entry points:
 *   getContext(unitId)   — booking guard + the unit's payable invoices + picklists + context.
 *   createReceipt(payload)— inserts the Receipt, its Receipt_Amount__c payment lines and the
 *                           Receipt_Invoice__c junctions.
 *
 * Amounts are FACTS. The financial engine (fired by the inserts) derives Receipt.Received_Amount,
 * each Invoice's Paid/Status, Cash_Flow Received, and Receipt_Amount.Cumulative from the payment
 * lines — so this controller never writes those. Payload is a JSON string (an Apex wrapper param
 * does not reliably receive its field values from an LWC imperative call).
 *
 * Unlike Create Invoice there is NO DLD-setup guard; only an active booking is required.
 */
public with sharing class ReceiptCreateController {

    private static final String STAGE_NEW = 'New';
    private static final String STAGE_CANCELLED = 'Cancelled';
    private static final String STAGE_TRANSFERRED = 'Transferred';
    private static final String MODE_CHEQUE = 'Cheque';
    private static final String MODE_POS = 'POS Machine';
    private static final String MSG_NO_BOOKING =
        'There is no active booking for this unit. Please make sure an active booking exists before generating a receipt.';

    // ---- context returned to the wizard ----------------------------------------------------------
    public class CreateContext {
        @AuraEnabled public Boolean canProceed;
        @AuraEnabled public String blockReason;
        @AuraEnabled public Id unitId;
        @AuraEnabled public String unitName;
        @AuraEnabled public String projectName;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String customerName;
        @AuraEnabled public Date defaultPaymentDate;
        @AuraEnabled public List<InvoiceOption> invoices;
        @AuraEnabled public List<ComboOption> depositToOptions;
        @AuraEnabled public List<ComboOption> modeOfPaymentOptions;
        @AuraEnabled public List<ComboOption> bankOptions;
        @AuraEnabled public List<ComboOption> statusOptions;
    }

    public class InvoiceOption {
        @AuraEnabled public Id invoiceId;
        @AuraEnabled public String label;      // Invoice number (or Name)
        @AuraEnabled public Date invoiceDate;
        @AuraEnabled public Decimal grandTotal;
        @AuraEnabled public Decimal paid;
        @AuraEnabled public Decimal pending;
        @AuraEnabled public String status;
    }

    public class ComboOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public ComboOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    // ---- request payload (JSON) ------------------------------------------------------------------
    // Ids are String (Id-typed wrapper fields do not populate from an LWC call).
    public class CreateRequest {
        @AuraEnabled public String unitId;
        @AuraEnabled public Date paymentDate;
        @AuraEnabled public String depositedTo;
        @AuraEnabled public String status;          // Reconciled / Unreconciled
        @AuraEnabled public String description;
        @AuraEnabled public List<PaymentLine> lines;
    }

    public class PaymentLine {
        @AuraEnabled public String invoiceId;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String modeOfPayment;
        @AuraEnabled public String referenceNumber;
        @AuraEnabled public String chequeNumber;
        @AuraEnabled public Date chequeDate;
        @AuraEnabled public String bankName;
        @AuraEnabled public String posReceiptNumber;
    }

    @AuraEnabled(cacheable=false)
    public static CreateContext getContext(Id unitId) {
        FinancialEngine.requireEnabled();
        if (unitId == null) throw new AuraHandledException('No unit specified.');

        List<Unit__c> units = [
            SELECT Id, Title__c, Building__c, Project__r.Name FROM Unit__c WHERE Id = :unitId LIMIT 1
        ];
        if (units.isEmpty()) throw new AuraHandledException('Unit not found.');
        Unit__c unit = units[0];

        CreateContext ctx = new CreateContext();
        ctx.unitId = unit.Id;
        ctx.unitName = unit.Title__c;
        ctx.projectName = (unit.Project__r != null) ? unit.Project__r.Name : null;
        ctx.defaultPaymentDate = Date.today();
        ctx.invoices = new List<InvoiceOption>();
        ctx.depositToOptions = picklistOptions(Receipt__c.Deposited_To__c);
        ctx.modeOfPaymentOptions = picklistOptions(Receipt_Amount__c.Mode_of_Payment__c);
        ctx.bankOptions = picklistOptions(Receipt_Amount__c.Bank_Name__c);
        ctx.statusOptions = picklistOptions(Receipt__c.Status__c);

        // Guard — an active booking Opportunity must exist.
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

        for (Invoice__c inv : queryPayableInvoices(unitId)) {
            InvoiceOption o = new InvoiceOption();
            o.invoiceId = inv.Id;
            o.label = String.isNotBlank(inv.Invoice_Number__c) ? inv.Invoice_Number__c : inv.Name;
            o.invoiceDate = inv.Invoice_Date__c;
            o.grandTotal = inv.Grand_Total_Amount__c;
            o.paid = inv.Paid_Amount__c;
            o.pending = inv.Pending_Amount__c;
            o.status = inv.Status__c;
            ctx.invoices.add(o);
        }

        ctx.canProceed = true;
        return ctx;
    }

    @AuraEnabled
    public static Id createReceipt(String payload) {
        FinancialEngine.requireEnabled();
        if (String.isBlank(payload)) throw new AuraHandledException('No data supplied.');
        CreateRequest req;
        try {
            req = (CreateRequest) JSON.deserialize(payload, CreateRequest.class);
        } catch (Exception e) {
            throw new AuraHandledException('Could not read the receipt data: ' + e.getMessage());
        }
        if (req == null) throw new AuraHandledException('No data supplied.');
        if (String.isBlank(req.unitId)) throw new AuraHandledException('No unit specified.');
        if (req.paymentDate == null) throw new AuraHandledException('Payment date is required.');
        if (String.isBlank(req.depositedTo)) throw new AuraHandledException('Deposited-to account is required.');
        if (String.isBlank(req.status)) throw new AuraHandledException('Receipt status is required.');
        if (String.isBlank(req.description)) throw new AuraHandledException('Description is required.');
        if (req.lines == null || req.lines.isEmpty()) {
            throw new AuraHandledException('Add at least one payment line.');
        }

        Id unitId = (Id) req.unitId;

        Opportunity opp = findBooking(unitId);
        if (opp == null) throw new AuraHandledException(MSG_NO_BOOKING);

        // Payable invoices for this unit, keyed by Id (server truth for amounts).
        Map<Id, Invoice__c> payable = new Map<Id, Invoice__c>();
        for (Invoice__c inv : queryPayableInvoices(unitId)) {
            payable.put(inv.Id, inv);
        }

        // Validate each line + tally per-invoice amount and total received.
        Decimal received = 0;
        Map<Id, Decimal> paidByInvoice = new Map<Id, Decimal>();
        for (PaymentLine ln : req.lines) {
            if (String.isBlank(ln.invoiceId)) throw new AuraHandledException('Each payment line must be linked to an invoice.');
            if (ln.amount == null || ln.amount <= 0) throw new AuraHandledException('Each payment line must have an amount greater than zero.');
            if (String.isBlank(ln.modeOfPayment)) throw new AuraHandledException('Each payment line needs a mode of payment.');
            if (ln.modeOfPayment == MODE_CHEQUE) {
                if (String.isBlank(ln.chequeNumber)) throw new AuraHandledException('Cheque number is required for cheque payments.');
                if (ln.chequeDate == null) throw new AuraHandledException('Cheque date is required for cheque payments.');
                if (String.isBlank(ln.bankName)) throw new AuraHandledException('Bank name is required for cheque payments.');
            } else if (ln.modeOfPayment == MODE_POS) {
                if (String.isBlank(ln.posReceiptNumber)) throw new AuraHandledException('POS receipt number is required for POS payments.');
            }
            Id invId = (Id) ln.invoiceId;
            if (!payable.containsKey(invId)) {
                throw new AuraHandledException('One of the selected invoices is no longer payable. Please reopen and try again.');
            }
            received += ln.amount;
            paidByInvoice.put(invId, nz(paidByInvoice.get(invId)) + ln.amount);
        }

        // Payable = sum of the covered invoices' current pending amount.
        Decimal payableTotal = 0;
        for (Id invId : paidByInvoice.keySet()) {
            payableTotal += nz(payable.get(invId).Pending_Amount__c);
        }
        String paymentStatus = (received >= payableTotal) ? 'Fully Paid' : 'Partially Paid';

        Unit__c u = queryUnit(unitId);
        try {
            Receipt__c rec = new Receipt__c(
                Unit__c = unitId,
                Opportunity__c = opp.Id,
                Account__c = opp.AccountId,
                Customer_Name__c = opp.Account_Name__c,
                Project_Name__c = (u != null && u.Project__r != null) ? u.Project__r.Name : null,
                Unit_No__c = (u != null) ? u.Title__c : null,
                Unit_Building__c = (u != null) ? u.Building__c : null,
                Description__c = req.description,
                Deposited_To__c = req.depositedTo,
                Payment_Date__c = req.paymentDate,
                Receipt_Added_Date__c = Date.today(),
                Status__c = req.status,
                Payment_Status__c = paymentStatus,
                Payable_Amount__c = payableTotal
            );
            insert rec;

            List<Receipt_Amount__c> lines = new List<Receipt_Amount__c>();
            for (PaymentLine ln : req.lines) {
                lines.add(new Receipt_Amount__c(
                    Receipt__c = rec.Id,
                    Invoice__c = (Id) ln.invoiceId,
                    Amount__c = ln.amount,
                    Amount_Text__c = ln.amount.setScale(2).format(),
                    Mode_of_Payment__c = ln.modeOfPayment,
                    Reference_Number__c = ln.referenceNumber,
                    Cheque_Number__c = (ln.modeOfPayment == MODE_CHEQUE) ? ln.chequeNumber : null,
                    Cheque_Date__c = (ln.modeOfPayment == MODE_CHEQUE) ? ln.chequeDate : null,
                    Bank_Name__c = (ln.modeOfPayment == MODE_CHEQUE) ? ln.bankName : null,
                    POS_Receipt_Number__c = (ln.modeOfPayment == MODE_POS) ? ln.posReceiptNumber : null
                ));
            }
            insert lines;

            List<Receipt_Invoice__c> junctions = new List<Receipt_Invoice__c>();
            for (Id invId : paidByInvoice.keySet()) {
                Invoice__c inv = payable.get(invId);
                Decimal paidHere = paidByInvoice.get(invId);
                String label = String.isNotBlank(inv.Invoice_Number__c) ? inv.Invoice_Number__c : inv.Name;
                junctions.add(new Receipt_Invoice__c(
                    Receipt__c = rec.Id,
                    Invoice__c = invId,
                    Amount__c = paidHere,
                    Name = label,
                    Status__c = (paidHere >= nz(inv.Pending_Amount__c)) ? 'Fully Paid' : 'Partially Paid'
                ));
            }
            insert junctions;

            return rec.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not generate the receipt: ' + e.getMessage());
        }
    }

    // ---- helpers ---------------------------------------------------------------------------------

    private static Opportunity findBooking(Id unitId) {
        List<Opportunity> opps = [
            SELECT Id, Name, AccountId, Account_Name__c
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

    private static List<Invoice__c> queryPayableInvoices(Id unitId) {
        return [
            SELECT Id, Name, Invoice_Number__c, Invoice_Date__c, Grand_Total_Amount__c,
                   Paid_Amount__c, Pending_Amount__c, Status__c
            FROM Invoice__c
            WHERE Unit__c = :unitId AND Pending_Amount__c > 0 AND Status__c != 'Cancelled'
            ORDER BY Invoice_Date__c ASC NULLS LAST, Name ASC
        ];
    }

    private static Unit__c queryUnit(Id unitId) {
        List<Unit__c> us = [SELECT Id, Title__c, Building__c, Project__r.Name FROM Unit__c WHERE Id = :unitId LIMIT 1];
        return us.isEmpty() ? null : us[0];
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
}