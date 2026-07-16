/**
 * Supplies the "before vs after" data for a Bank Detail Update approval request. Unlike the
 * profile request (which stores a flat changed-field list), the bank payload stores each bank's
 * full requested state, so this controller loads the current Bank__c values and DIFFS them to
 * surface only the fields that actually changed, grouped per bank (and flags new banks).
 * Brand-new component; does not touch any existing approval comparison class.
 */
public with sharing class BankChangeComparisonController {

    private static final String TYPE_BANK = 'Bank Detail Update';

    private static final List<String> FIELD_ORDER = new List<String>{
        'Name', 'Bank_Account_Name__c', 'Bank_Account_Number__c', 'IBAN__c', 'Swift_Code__c', 'Branch_Name__c'
    };
    private static final Map<String, String> LABELS = new Map<String, String>{
        'name' => 'Bank',
        'bank_account_name__c' => 'Account Name',
        'bank_account_number__c' => 'Account Number',
        'iban__c' => 'IBAN',
        'swift_code__c' => 'Swift Code',
        'branch_name__c' => 'Branch'
    };

    public class ChangeRow {
        @AuraEnabled public String label;
        @AuraEnabled public String oldValue;
        @AuraEnabled public String newValue;
    }

    public class BankGroup {
        @AuraEnabled public String bankLabel;
        @AuraEnabled public Boolean isNew = false;
        @AuraEnabled public List<ChangeRow> changes = new List<ChangeRow>();
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
        @AuraEnabled public List<BankGroup> banks = new List<BankGroup>();
    }

    @AuraEnabled(cacheable=true)
    public static Comparison getBankComparison(Id recordId) {
        Comparison c = new Comparison();

        // Works whether placed on the Approval_Request__c record page or the approval work-item page.
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
        if (reqs.isEmpty() || reqs[0].Request_Type__c != TYPE_BANK) {
            c.notApplicable = true;
            c.notApplicableReason = 'This request is not a Bank Detail Update.';
            return c;
        }

        Approval_Request__c req = reqs[0];
        c.requestName   = req.Name;
        c.status        = req.Status__c;
        c.justification = req.Justification__c;
        c.submittedBy   = (req.CreatedBy != null) ? req.CreatedBy.Name : null;
        c.submittedDate = (req.CreatedDate != null) ? req.CreatedDate.format('dd MMM yyyy, h:mm a') : null;

        Id acctId = parseId(req.Related_Record_Id__c);
        c.agencyName = resolveAgencyName(acctId);
        c.banks = buildGroups(req.Profile_Changes_JSON__c, acctId);

        if (c.banks.isEmpty()) {
            c.notApplicable = true;
            c.notApplicableReason = 'No bank changes were recorded on this request.';
        }
        return c;
    }

    private static List<BankGroup> buildGroups(String changesJson, Id acctId) {
        List<BankGroup> groups = new List<BankGroup>();
        if (String.isBlank(changesJson)) return groups;

        List<Object> entries;
        try { entries = (List<Object>) JSON.deserializeUntyped(changesJson); } catch (Exception e) { return groups; }

        // Current bank values for this account, to diff against the requested state.
        Map<Id, Bank__c> currentById = new Map<Id, Bank__c>();
        if (acctId != null) {
            for (Bank__c b : [
                SELECT Id, Name, Bank_Account_Name__c, Bank_Account_Number__c, IBAN__c, Swift_Code__c, Branch_Name__c
                FROM Bank__c WHERE Account__c = :acctId
            ]) {
                currentById.put(b.Id, b);
            }
        }

        for (Object o : entries) {
            if (!(o instanceof Map<String, Object>)) continue;
            Map<String, Object> entry = (Map<String, Object>) o;
            Object fieldsObj = entry.get('fields');
            if (!(fieldsObj instanceof Map<String, Object>)) continue;
            Map<String, Object> flds = (Map<String, Object>) fieldsObj;

            String recId = String.valueOf(entry.get('recordId'));
            Bank__c current = null;
            if (String.isNotBlank(recId) && recId != 'null') {
                Id bId = parseId(recId);
                if (bId != null) current = currentById.get(bId);
            }

            BankGroup g = new BankGroup();
            g.isNew = (current == null);

            for (String api : FIELD_ORDER) {
                String newVal = str(getCaseInsensitive(flds, api));
                String oldVal = (current == null) ? '' : str(current.get(api));
                if (newVal == oldVal) continue;                 // only changed fields
                ChangeRow r = new ChangeRow();
                r.label = LABELS.get(api.toLowerCase());
                r.oldValue = String.isBlank(oldVal) ? '—' : oldVal;
                r.newValue = String.isBlank(newVal) ? '—' : newVal;
                g.changes.add(r);
            }

            if (g.changes.isEmpty()) continue;                  // nothing changed for this bank — skip

            // Label the bank by its current name (or the requested name for a new bank).
            String currentName = (current == null) ? null : current.Name;
            String requestedName = str(getCaseInsensitive(flds, 'Name'));
            g.bankLabel = g.isNew
                ? 'New bank' + (String.isBlank(requestedName) ? '' : ' — ' + requestedName)
                : (String.isBlank(currentName) ? 'Bank account' : currentName);

            groups.add(g);
        }
        return groups;
    }

    private static Object getCaseInsensitive(Map<String, Object> m, String key) {
        if (m.containsKey(key)) return m.get(key);
        for (String k : m.keySet()) {
            if (k.equalsIgnoreCase(key)) return m.get(k);
        }
        return null;
    }

    private static String str(Object o) {
        return (o == null) ? '' : String.valueOf(o).trim();
    }

    private static Id parseId(String s) {
        if (String.isBlank(s)) return null;
        try { return Id.valueOf(s); } catch (Exception e) { return null; }
    }

    private static String resolveAgencyName(Id acctId) {
        if (acctId == null) return null;
        List<Account> accts = [SELECT Name FROM Account WHERE Id = :acctId LIMIT 1];
        return accts.isEmpty() ? null : accts[0].Name;
    }
}