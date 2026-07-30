public with sharing class CommissionInvoiceController {

    @AuraEnabled(cacheable=true)
    public static CommissionContext getCommissionContext(Id recordId) {
        CommissionContext ctx = new CommissionContext();
        ctx.canGenerate = false;

        if (recordId == null) {
            return ctx;
        }
        String objType = recordId.getSObjectType().getDescribe().getName();

        Id commissionId = null;
        if (objType == 'Commission__c') {
            commissionId = recordId;
        } else if (objType == 'Unit__c') {
            // A blank Commission_Status__c means the unit is at the start of the
            // eligibility process (e.g. its sale was cancelled and tracking was reset),
            // so commissions from a previous sale cycle are not surfaced on the card.
            List<Unit__c> units = [
                SELECT Commission_Status__c FROM Unit__c WHERE Id = :recordId LIMIT 1
            ];
            if (units.isEmpty() || String.isBlank(units[0].Commission_Status__c)) {
                ctx.ineligibilityReasons = computeIneligibilityReasonsForUnit(recordId);
                return ctx;
            }
            List<Commission__c> matches = [
                SELECT Id FROM Commission__c
                WHERE Unit__c = :recordId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!matches.isEmpty()) {
                commissionId = matches[0].Id;
            } else {
                ctx.ineligibilityReasons = computeIneligibilityReasonsForUnit(recordId);
            }
        }

        if (commissionId == null) {
            return ctx;
        }

        List<Commission__c> commissions = [
            SELECT Id, Name, Status__c, Commission_Amount__c, Commission_Rate__c,
                   Paid_Amount__c, VAT_Amount__c, Total_Commission_Amount__c, Remaining_Amount__c,
                   Payment_Method__c, Invoice__c, Agency__r.Name, Agency__r.VAT_TRN__c
            FROM Commission__c
            WHERE Id = :commissionId
            LIMIT 1
        ];
        if (commissions.isEmpty()) {
            return ctx;
        }
        Commission__c c = commissions[0];

        Boolean isVatRegistered = (
            c.Agency__r != null
            && c.Agency__r.VAT_TRN__c != null
            && c.Agency__r.VAT_TRN__c.equalsIgnoreCase('Yes')
        );
        Boolean hasAmount = (c.Commission_Amount__c != null && c.Commission_Amount__c > 0);

        ctx.commissionId = c.Id;
        ctx.commissionName = c.Name;
        ctx.agencyName = (c.Agency__r != null) ? c.Agency__r.Name : null;
        ctx.commissionRate = c.Commission_Rate__c;
        ctx.commissionAmount = c.Commission_Amount__c;
        ctx.vatAmount = c.VAT_Amount__c;
        ctx.totalCommissionAmount = c.Total_Commission_Amount__c;
        ctx.paidAmount = c.Paid_Amount__c;
        ctx.remainingAmount = c.Remaining_Amount__c;
        ctx.paymentMethod = c.Payment_Method__c;
        ctx.status = c.Status__c;
        ctx.existingInvoiceId = c.Invoice__c;
        ctx.isVatRegistered = isVatRegistered;

        ctx.canGenerate = (
            isVatRegistered
            && c.Invoice__c == null
            && hasAmount
            && c.Status__c != 'Cancelled'
            && c.Status__c != 'On Hold'
        );

        ctx.canMarkPaid = (
            hasAmount
            && c.Status__c != 'Cancelled'
            && c.Status__c != 'On Hold'
            && c.Status__c != 'Fully Paid'
        );

        return ctx;
    }

    private static List<String> computeIneligibilityReasonsForUnit(Id unitId) {
        List<String> reasons = new List<String>();

        List<Unit__c> units = [
            SELECT Id, Commission_Status__c FROM Unit__c WHERE Id = :unitId LIMIT 1
        ];
        if (!units.isEmpty()) {
            String unitStatus = units[0].Commission_Status__c;
            if (unitStatus == 'Paid') {
                reasons.add('Commission has already been paid for this Unit.');
                return reasons;
            }
            if (unitStatus == 'Unpaid') {
                reasons.add('Commission has been generated for this Unit (status: Unpaid).');
                return reasons;
            }
        }

        List<Opportunity> opps = [
            SELECT Id, Name, StageName, Agency__c,
                   SPA_Signed__c, Is_20_Paid__c, Is_DLD_Registration_Paid__c
            FROM Opportunity
            WHERE Unit__c = :unitId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (opps.isEmpty()) {
            reasons.add('No Opportunity is linked to this Unit.');
            return reasons;
        }

        Opportunity opp = opps[0];

        if (opp.Agency__c == null) {
            reasons.add('No Agency is assigned to the Opportunity.');
        }
        if (opp.StageName != 'Sold') {
            reasons.add('Opportunity Stage is "' + opp.StageName + '" — must be "Sold".');
        }
        if (opp.SPA_Signed__c != true) {
            reasons.add('SPA has not been signed.');
        }
        if (opp.Is_20_Paid__c != true) {
            reasons.add('20% payment has not been received.');
        }
        if (opp.Is_DLD_Registration_Paid__c != true) {
            reasons.add('DLD/Registration fee has not been paid.');
        }

        if (reasons.isEmpty()) {
            reasons.add('All conditions appear met. Unit will become eligible after the next nightly batch run.');
        }

        return reasons;
    }

    @AuraEnabled
    public static String generateInvoiceForCommission(Id commissionId, Id financialDetailId) {
        try {
            return CommissionInvoiceService.generateInvoice(commissionId, financialDetailId);
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void markCommissionPaid(Id commissionId, Date paymentDate, Decimal paidAmount, String paymentMethod) {
        try {
            CommissionInvoiceService.markPaid(commissionId, paymentDate, paidAmount, paymentMethod);
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }

    // Active Payment Method picklist values (shared with Receipts via the Payment Method global value set).
    // Uses Schema describe so the modal dropdown works regardless of the running user's field-level security.
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPaymentMethodOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (Schema.PicklistEntry entry : Commission__c.Payment_Method__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{ 'label' => entry.getLabel(), 'value' => entry.getValue() });
            }
        }
        return options;
    }

    public class CommissionContext {
        @AuraEnabled public Id commissionId;
        @AuraEnabled public String commissionName;
        @AuraEnabled public String agencyName;
        @AuraEnabled public Decimal commissionRate;
        @AuraEnabled public Decimal commissionAmount;
        @AuraEnabled public Decimal vatAmount;
        @AuraEnabled public Decimal totalCommissionAmount;
        @AuraEnabled public Decimal paidAmount;
        @AuraEnabled public Decimal remainingAmount;
        @AuraEnabled public String paymentMethod;
        @AuraEnabled public String status;
        @AuraEnabled public Id existingInvoiceId;
        @AuraEnabled public Boolean canGenerate;
        @AuraEnabled public Boolean canMarkPaid;
        @AuraEnabled public Boolean isVatRegistered;
        @AuraEnabled public List<String> ineligibilityReasons;
    }
}