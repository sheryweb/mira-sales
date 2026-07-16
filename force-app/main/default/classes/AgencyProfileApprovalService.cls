/**
 * Applies an APPROVED "Agency Profile Update" Approval_Request__c to its Account.
 * Invoked by a (new) record-triggered Flow when Status flips to Approved — runs in the
 * approver's (internal) context, so the Account update is not subject to guest limits.
 * Brand-new component; does not touch any existing approval class/trigger.
 */
public without sharing class AgencyProfileApprovalService {

    // Only these Account fields may be changed via a broker profile request (defence-in-depth;
    // the human approval is the primary gate). Kept in sync with BrokerProfileEditController.
    private static final Set<String> ALLOWED_FIELDS = new Set<String>{
        'company_email__c', 'phone', 'landline_number__c', 'contact_email_2__c', 'admin_number__c',
        'billingstreet', 'billingpostalcode', 'vat_trn__c', 'trn_number__c',
        'signatory_name__c', 'signatory_email__c', 'signatory_number__c'
    };

    @InvocableMethod(label='Apply Agency Profile Changes'
                     description='Applies an approved Agency Profile Update request to its Account.')
    public static void applyApproved(List<Id> approvalRequestIds) {
        applyApprovedChanges(new Set<Id>(approvalRequestIds));
    }

    public static void applyApprovedChanges(Set<Id> requestIds) {
        if (requestIds == null || requestIds.isEmpty()) return;

        List<Approval_Request__c> reqs = [
            SELECT Id, Related_Record_Id__c, Profile_Changes_JSON__c, Request_Type__c
            FROM Approval_Request__c WHERE Id IN :requestIds
        ];

        Map<Id, Account> acctUpdates = new Map<Id, Account>();
        List<Approval_Request__c> reqUpdates = new List<Approval_Request__c>();
        Map<Id, String> newCompanyEmailByAccount = new Map<Id, String>();
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Account.fields.getMap();

        for (Approval_Request__c req : reqs) {
            if (req.Request_Type__c != 'Agency Profile Update') continue;
            if (String.isBlank(req.Related_Record_Id__c) || String.isBlank(req.Profile_Changes_JSON__c)) continue;

            Id acctId;
            try { acctId = Id.valueOf(req.Related_Record_Id__c); } catch (Exception e) { continue; }

            List<Object> changes;
            try { changes = (List<Object>) JSON.deserializeUntyped(req.Profile_Changes_JSON__c); } catch (Exception e) { continue; }

            Account acc = acctUpdates.containsKey(acctId) ? acctUpdates.get(acctId) : new Account(Id = acctId);
            for (Object o : changes) {
                Map<String, Object> ch = (Map<String, Object>) o;
                String field = (String) ch.get('field');
                if (String.isBlank(field)) continue;
                String key = field.toLowerCase();
                if (!ALLOWED_FIELDS.contains(key) || !fieldMap.containsKey(key)) continue;

                Schema.DescribeFieldResult dfr = fieldMap.get(key).getDescribe();
                if (!dfr.isUpdateable()) continue;

                Object converted = convert(dfr, ch.get('newValue'));
                acc.put(dfr.getName(), converted);
                if (key == 'company_email__c') {
                    newCompanyEmailByAccount.put(acctId, converted == null ? null : String.valueOf(converted));
                }
            }
            acctUpdates.put(acctId, acc);
            reqUpdates.add(new Approval_Request__c(Id = req.Id, Status__c = 'Applied'));
        }

        if (!acctUpdates.isEmpty()) update acctUpdates.values();   // the critical change

        // Keep the broker's login email in sync with the company email.
        if (!newCompanyEmailByAccount.isEmpty()) syncBrokerUserEmails(newCompanyEmailByAccount);

        if (!reqUpdates.isEmpty()) {
            // Best-effort: the request may still be approval-locked right after approval.
            try { update reqUpdates; } catch (Exception e) {
                System.debug('Could not mark request Applied (likely approval-locked): ' + e.getMessage());
            }
        }
    }

    private static void syncBrokerUserEmails(Map<Id, String> newEmailByAccount) {
        List<Broker_User__c> toUpdate = new List<Broker_User__c>();
        for (Broker_User__c bu : [
            SELECT Id, Account__c, Email__c FROM Broker_User__c WHERE Account__c IN :newEmailByAccount.keySet()
        ]) {
            String newEmail = newEmailByAccount.get(bu.Account__c);
            if (String.isNotBlank(newEmail) && newEmail != bu.Email__c) {
                toUpdate.add(new Broker_User__c(Id = bu.Id, Email__c = newEmail));
            }
        }
        if (!toUpdate.isEmpty()) {
            try { update toUpdate; } catch (Exception e) {
                System.debug('Broker_User email sync failed: ' + e.getMessage());
            }
        }
    }

    private static Object convert(Schema.DescribeFieldResult dfr, Object val) {
        if (val == null) return null;
        String s = String.valueOf(val);
        if (String.isBlank(s)) return null;
        Schema.DisplayType t = dfr.getType();
        if (t == Schema.DisplayType.Boolean)  return s == 'true' || s == '1' || s.equalsIgnoreCase('yes');
        if (t == Schema.DisplayType.Date) {
            return parseDate(s);
        }
        if (t == Schema.DisplayType.DateTime) {
            Date d = parseDate(s);
            return (d == null) ? null : DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0));
        }
        if (t == Schema.DisplayType.Currency || t == Schema.DisplayType.Double || t == Schema.DisplayType.Percent) return Decimal.valueOf(s);
        if (t == Schema.DisplayType.Integer)  return Integer.valueOf(s);
        return s; // text, textarea, picklist, email, phone, url, etc.
    }

    // Accepts ISO yyyy-MM-dd (what the portal stores); falls back to locale parsing just in case.
    private static Date parseDate(String s) {
        if (String.isBlank(s)) return null;
        try { return Date.valueOf(s.trim()); }
        catch (Exception e) {
            try { return Date.parse(s.trim()); } catch (Exception e2) { return null; }
        }
    }
}