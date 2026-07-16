public without sharing class PaymentPlanApprovalDetailController {

    public Boolean hasError    { get; private set; }
    public Boolean isPaymentPlan { get; private set; }
    public String  errorMessage  { get; private set; }

    // Request header
    public String requestName   { get; private set; }
    public String requestStatus { get; private set; }
    public String requesterName { get; private set; }
    public String justification { get; private set; }

    // Unit info
    public String unitTitle     { get; private set; }
    public String projectName   { get; private set; }
    public String building      { get; private set; }
    public String accountName   { get; private set; }

    // Row lists
    public List<ComparisonRow> currentRows  { get; private set; }
    public List<ComparisonRow> proposedRows { get; private set; }
    public Boolean changesOnly { get; private set; }
    public String  changesOnlyNote { get; private set; }

    public PaymentPlanApprovalDetailController() {
        hasError     = false;
        isPaymentPlan = false;
        currentRows  = new List<ComparisonRow>();
        proposedRows = new List<ComparisonRow>();

        Id recordId = ApexPages.currentPage().getParameters().get('id');
        if (recordId == null) {
            hasError = true;
            errorMessage = 'No record ID provided.';
            return;
        }

        try {
            Id approvalRequestId;
            String objType = String.valueOf(recordId.getSObjectType());

            if (objType == 'Approval_Request__c') {
                approvalRequestId = recordId;
            } else {
                ProcessInstanceWorkitem wi = [
                    SELECT ProcessInstance.TargetObjectId
                    FROM ProcessInstanceWorkitem
                    WHERE Id = :recordId
                    LIMIT 1
                ];
                approvalRequestId = wi.ProcessInstance.TargetObjectId;
            }

            PaymentPlanApprovalService.PaymentPlanComparisonDTO dto =
                PaymentPlanApprovalService.getPaymentPlanComparison(approvalRequestId);

            if (dto == null) {
                hasError = true;
                errorMessage = 'This approval request is not a Payment Plan Change request.';
                return;
            }

            // Populate header
            requestName   = dto.requestName;
            requestStatus = dto.status;
            requesterName = dto.requesterName;
            justification = dto.justification;

            // Populate unit info
            if (dto.unitInfo != null) {
                unitTitle   = dto.unitInfo.title;
                projectName = dto.unitInfo.projectName;
                building    = dto.unitInfo.building;
                accountName = dto.unitInfo.accountName;
            }

            // Build rows
            for (PaymentPlanApprovalService.ComparisonLineDTO line : dto.currentLines) {
                currentRows.add(new ComparisonRow(line));
            }
            for (PaymentPlanApprovalService.ComparisonLineDTO line : dto.proposedLines) {
                proposedRows.add(new ComparisonRow(line));
            }

            changesOnly = dto.changesOnly == true;
            changesOnlyNote = buildChangesOnlyNote(dto);

            isPaymentPlan = true;

        } catch (Exception e) {
            hasError = true;
            errorMessage = 'Error loading comparison: ' + e.getMessage();
        }
    }

    private static String buildChangesOnlyNote(PaymentPlanApprovalService.PaymentPlanComparisonDTO dto) {
        if (dto == null || dto.changesOnly != true) {
            return null;
        }

        Integer added = 0;
        Integer updated = 0;
        Integer deleted = 0;
        if (dto.proposedLines != null) {
            for (PaymentPlanApprovalService.ComparisonLineDTO line : dto.proposedLines) {
                if (line.changeType == 'added') {
                    added++;
                }
            }
        }
        if (dto.currentLines != null) {
            for (PaymentPlanApprovalService.ComparisonLineDTO line : dto.currentLines) {
                if (line.changeType == 'updated') {
                    updated++;
                } else if (line.changeType == 'deleted') {
                    deleted++;
                }
            }
        }

        List<String> parts = new List<String>();
        if (added > 0) {
            parts.add(added + ' added');
        }
        if (updated > 0) {
            parts.add(updated + ' updated');
        }
        if (deleted > 0) {
            parts.add(deleted + ' deleted');
        }
        String summary = parts.isEmpty() ? 'No changes' : String.join(parts, ' \u00b7 ');

        if (dto.totalInstallmentCount != null && dto.totalInstallmentCount > 0) {
            return 'Showing only changed installments (' + summary + '). This unit has ' +
                dto.totalInstallmentCount + ' total installments.';
        }
        return 'Showing only changed installments (' + summary + ').';
    }

    public class ComparisonRow {
        public String milestoneName   { get; private set; }
        public String installmentDate { get; private set; }
        public String percent         { get; private set; }
        public String constantAmount  { get; private set; }
        public String changeType      { get; private set; }
        public String badge           { get; private set; }
        public Boolean hasBadge       { get; private set; }

        public ComparisonRow(PaymentPlanApprovalService.ComparisonLineDTO line) {
            milestoneName   = line.milestoneName   != null ? line.milestoneName   : '\u2014';
            installmentDate = line.installmentDate != null ? line.installmentDate : '\u2014';
            percent         = line.percent         != null ? line.percent + '%'   : '\u2014';
            Decimal displayAmount = line.amount != null ? line.amount : line.constantAmount;
            constantAmount  = displayAmount != null
                ? 'AED ' + formatAmount(displayAmount) : '\u2014';
            changeType = line.changeType;

            if      (changeType == 'deleted') { badge = 'Delete'; hasBadge = true; }
            else if (changeType == 'updated') { badge = 'Update'; hasBadge = true; }
            else if (changeType == 'added')   { badge = 'New';    hasBadge = true; }
            else                              { badge = '';        hasBadge = false; }
        }

        private String formatAmount(Decimal amount) {
            if (amount == null) return '0';
            String raw = String.valueOf(amount.setScale(0));
            String result = '';
            Integer len = raw.length();
            for (Integer i = 0; i < len; i++) {
                if (i > 0 && Math.mod(len - i, 3) == 0) result += ',';
                result += raw.substring(i, i + 1);
            }
            return result;
        }
    }
}