/**
 * Applies an APPROVED "Bank Detail Update" Approval_Request__c to its Account's Bank__c records.
 * Invoked by a record-triggered Flow when Status flips to Approved — runs in the approver's
 * (internal) context, so the Bank__c writes are not subject to guest limits.
 *
 * Payload (Profile_Changes_JSON__c) is a JSON array of bank entries:
 *   [ {"recordId":"a0X...","fields":{...}},   // existing bank -> update
 *     {"recordId":"",      "fields":{...}} ]  // blank recordId -> insert a new bank
 *
 * Parallel to AgencyProfileApprovalService; does not touch any existing approval class/trigger.
 */
public without sharing class BrokerBankApprovalService {

    // Only these Bank__c fields may be set via a broker bank request (Name is the bank name).
    private static final Set<String> ALLOWED_FIELDS = new Set<String>{
        'name', 'bank_account_name__c', 'bank_account_number__c',
        'iban__c', 'swift_code__c', 'branch_name__c'
    };

    @InvocableMethod(label='Apply Bank Detail Changes'
                     description='Applies an approved Bank Detail Update request to its Account bank records.')
    public static void applyApproved(List<Id> approvalRequestIds) {
        applyApprovedChanges(new Set<Id>(approvalRequestIds));
    }

    public static void applyApprovedChanges(Set<Id> requestIds) {
        if (requestIds == null || requestIds.isEmpty()) return;

        List<Approval_Request__c> reqs = [
            SELECT Id, Related_Record_Id__c, Profile_Changes_JSON__c, Request_Type__c
            FROM Approval_Request__c WHERE Id IN :requestIds
        ];

        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Bank__c.fields.getMap();
        List<Bank__c> toUpsert = new List<Bank__c>();
        List<Approval_Request__c> reqUpdates = new List<Approval_Request__c>();

        for (Approval_Request__c req : reqs) {
            if (req.Request_Type__c != 'Bank Detail Update') continue;
            if (String.isBlank(req.Related_Record_Id__c) || String.isBlank(req.Profile_Changes_JSON__c)) continue;

            Id acctId;
            try { acctId = Id.valueOf(req.Related_Record_Id__c); } catch (Exception e) { continue; }

            List<Object> entries;
            try { entries = (List<Object>) JSON.deserializeUntyped(req.Profile_Changes_JSON__c); } catch (Exception e) { continue; }

            // Banks that genuinely belong to this Account — a tampered recordId for another
            // agency's bank is ignored (the human approval is the primary gate; this is defence-in-depth).
            Set<Id> ownBankIds = new Set<Id>();
            for (Bank__c b : [SELECT Id FROM Bank__c WHERE Account__c = :acctId]) ownBankIds.add(b.Id);

            for (Object o : entries) {
                Map<String, Object> entry = (Map<String, Object>) o;
                String recordId = String.valueOf(entry.get('recordId'));
                Object fieldsObj = entry.get('fields');
                if (!(fieldsObj instanceof Map<String, Object>)) continue;
                Map<String, Object> flds = (Map<String, Object>) fieldsObj;

                Bank__c bank;
                if (String.isBlank(recordId) || recordId == 'null') {
                    bank = new Bank__c(Account__c = acctId);              // new bank
                } else {
                    Id bId;
                    try { bId = Id.valueOf(recordId); } catch (Exception e) { continue; }
                    if (!ownBankIds.contains(bId)) continue;               // not this account's bank — skip
                    bank = new Bank__c(Id = bId);
                }

                for (String rawKey : flds.keySet()) {
                    String key = rawKey.toLowerCase();
                    if (!ALLOWED_FIELDS.contains(key) || !fieldMap.containsKey(key)) continue;
                    Schema.DescribeFieldResult dfr = fieldMap.get(key).getDescribe();
                    if (!dfr.isUpdateable()) continue;
                    Object val = flds.get(rawKey);
                    bank.put(dfr.getName(), (val == null) ? null : String.valueOf(val));
                }
                toUpsert.add(bank);
            }

            reqUpdates.add(new Approval_Request__c(Id = req.Id, Status__c = 'Applied'));
        }

        if (!toUpsert.isEmpty()) upsert toUpsert;

        if (!reqUpdates.isEmpty()) {
            // Best-effort: the request may still be approval-locked right after approval.
            try { update reqUpdates; } catch (Exception e) {
                System.debug('Could not mark bank request Applied (likely approval-locked): ' + e.getMessage());
            }
        }
    }
}