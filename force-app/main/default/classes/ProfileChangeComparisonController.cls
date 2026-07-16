/**
 * Supplies the "before vs after" data for an Agency Profile Update approval request so the
 * approver sees exactly which fields changed (only changed fields are stored in the JSON).
 * Brand-new component for the Broker Portal; does not touch the existing approval comparison classes.
 */
public with sharing class ProfileChangeComparisonController {

    private static final String TYPE_PROFILE = 'Agency Profile Update';

    public class ChangeRow {
        @AuraEnabled public String label;
        @AuraEnabled public String oldValue;
        @AuraEnabled public String newValue;
    }

    public class Comparison {
        @AuraEnabled public Boolean notApplicable = false;
        @AuraEnabled public String notApplicableReason;
        @AuraEnabled public String requestName;
        @AuraEnabled public String status;
        @AuraEnabled public String agencyName;
        @AuraEnabled public String justification;
        @AuraEnabled public String submittedBy;
        @AuraEnabled public String submittedDate;
        @AuraEnabled public List<ChangeRow> changes = new List<ChangeRow>();
    }

    @AuraEnabled(cacheable=true)
    public static Comparison getProfileComparison(Id recordId) {
        Comparison c = new Comparison();

        // The viewer can sit on the Approval_Request__c record page OR the approval work-item
        // page (ProcessInstanceWorkitem). Resolve either to the underlying Approval_Request__c id.
        Id resolvedId = PaymentPlanComparisonReader.resolveApprovalRequestId(recordId);
        if (resolvedId == null) {
            c.notApplicable = true;
            c.notApplicableReason = 'No approval request found for this record.';
            return c;
        }

        List<Approval_Request__c> reqs = [
            SELECT Name, Status__c, Justification__c, Request_Type__c,
                   Related_Record_Id__c, Profile_Changes_JSON__c,
                   CreatedDate, CreatedBy.Name
            FROM Approval_Request__c
            WHERE Id = :resolvedId
            LIMIT 1
        ];
        if (reqs.isEmpty() || reqs[0].Request_Type__c != TYPE_PROFILE) {
            c.notApplicable = true;
            c.notApplicableReason = 'This request is not an Agency Profile Update.';
            return c;
        }

        Approval_Request__c req = reqs[0];
        c.requestName  = req.Name;
        c.status       = req.Status__c;
        c.justification = req.Justification__c;
        c.submittedBy  = (req.CreatedBy != null) ? req.CreatedBy.Name : null;
        c.submittedDate = (req.CreatedDate != null) ? req.CreatedDate.format('dd MMM yyyy, h:mm a') : null;
        c.agencyName   = resolveAgencyName(req.Related_Record_Id__c);
        c.changes      = parseChanges(req.Profile_Changes_JSON__c);

        if (c.changes.isEmpty()) {
            c.notApplicable = true;
            c.notApplicableReason = 'No field changes were recorded on this request.';
        }
        return c;
    }

    private static String resolveAgencyName(String relatedId) {
        if (String.isBlank(relatedId)) return null;
        Id acctId;
        try { acctId = Id.valueOf(relatedId); } catch (Exception e) { return null; }
        List<Account> accts = [SELECT Name FROM Account WHERE Id = :acctId LIMIT 1];
        return accts.isEmpty() ? null : accts[0].Name;
    }

    private static List<ChangeRow> parseChanges(String changesJson) {
        List<ChangeRow> rows = new List<ChangeRow>();
        if (String.isBlank(changesJson)) return rows;

        List<Object> items;
        try { items = (List<Object>) JSON.deserializeUntyped(changesJson); } catch (Exception e) { return rows; }

        for (Object o : items) {
            if (!(o instanceof Map<String, Object>)) continue;
            Map<String, Object> m = (Map<String, Object>) o;
            ChangeRow r = new ChangeRow();
            r.label    = display(m.get('label'));
            r.oldValue = displayValue(m.get('oldValue'));
            r.newValue = displayValue(m.get('newValue'));
            rows.add(r);
        }
        return rows;
    }

    private static String display(Object o) {
        return (o == null) ? '' : String.valueOf(o);
    }

    // Blank before/after values render as an em dash so the approver can see "was empty".
    private static String displayValue(Object o) {
        String s = (o == null) ? '' : String.valueOf(o).trim();
        return String.isBlank(s) ? '—' : s;
    }
}