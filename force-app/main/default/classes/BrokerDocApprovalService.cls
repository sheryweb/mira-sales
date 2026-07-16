/**
 * Applies the decision on a "Document Re-upload" Approval_Request__c. Invoked by a record-triggered
 * Flow when Status flips to Approved or Rejected — runs in the approver's (internal) context.
 *
 * Payload (Profile_Changes_JSON__c):
 *   { "category":"Trade License", "newContentDocumentId":"069...",
 *     "oldContentDocumentId":"069...", "fileName":"new_tl.pdf" }
 *
 * Approved -> delete the old file, promote the pending file to the official category (Description),
 * mark the request Applied. Rejected -> delete the pending file (cleanup), leave it Rejected.
 * Brand-new component; does not touch any existing approval class/trigger.
 */
public without sharing class BrokerDocApprovalService {

    private static final String TYPE_DOC = 'Document Re-upload';

    @InvocableMethod(label='Apply Document Re-upload Decision'
                     description='Applies an approved/rejected Document Re-upload request to the Account files.')
    public static void applyDecision(List<Id> approvalRequestIds) {
        processDecisions(new Set<Id>(approvalRequestIds));
    }

    public static void processDecisions(Set<Id> requestIds) {
        if (requestIds == null || requestIds.isEmpty()) return;

        List<Approval_Request__c> reqs = [
            SELECT Id, Status__c, Related_Record_Id__c, Profile_Changes_JSON__c, Request_Type__c
            FROM Approval_Request__c WHERE Id IN :requestIds
        ];

        Set<Id> docIdsToDelete = new Set<Id>();
        Map<Id, String> promoteToDescription = new Map<Id, String>();   // newDocId -> official category
        Map<Id, Id> promoteDocToAccount = new Map<Id, Id>();         // newDocId -> account (for link visibility)
        List<Approval_Request__c> reqUpdates = new List<Approval_Request__c>();

        for (Approval_Request__c req : reqs) {
            if (req.Request_Type__c != TYPE_DOC) continue;
            if (String.isBlank(req.Related_Record_Id__c) || String.isBlank(req.Profile_Changes_JSON__c)) continue;

            Id acctId;
            try { acctId = Id.valueOf(req.Related_Record_Id__c); } catch (Exception e) { continue; }

            // Only this account's files may be touched (defence-in-depth).
            Set<Id> ownDocIds = new Set<Id>();
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :acctId
            ]) ownDocIds.add(cdl.ContentDocumentId);

            // Payload is an ARRAY of {oldContentDocumentId, newContentDocumentId, restoreDescription, ...}.
            for (Object o : parseDocs(req.Profile_Changes_JSON__c)) {
                if (!(o instanceof Map<String, Object>)) continue;
                Map<String, Object> d = (Map<String, Object>) o;
                String restoreDescription = str(d.get('restoreDescription'));
                Id newDocId = parseId(str(d.get('newContentDocumentId')));
                Id oldDocId = parseId(str(d.get('oldContentDocumentId')));

                if (req.Status__c == 'Approved') {
                    if (oldDocId != null && ownDocIds.contains(oldDocId)) docIdsToDelete.add(oldDocId);
                    if (newDocId != null && ownDocIds.contains(newDocId)) {
                        promoteToDescription.put(newDocId, restoreDescription);   // '' is valid (no original description)
                        promoteDocToAccount.put(newDocId, acctId);
                    }
                } else if (req.Status__c == 'Rejected') {
                    // Discard the staged upload; leave the official file untouched.
                    if (newDocId != null && ownDocIds.contains(newDocId)) docIdsToDelete.add(newDocId);
                }
            }
            if (req.Status__c == 'Approved') {
                reqUpdates.add(new Approval_Request__c(Id = req.Id, Status__c = 'Applied'));
            }
        }

        // Promote pending files: rename their latest version Description to the official category.
        if (!promoteToDescription.isEmpty()) {
            List<ContentVersion> toUpdate = new List<ContentVersion>();
            for (ContentVersion cv : [
                SELECT Id, ContentDocumentId, Description
                FROM ContentVersion
                WHERE ContentDocumentId IN :promoteToDescription.keySet() AND IsLatest = true
            ]) {
                cv.Description = promoteToDescription.get(cv.ContentDocumentId);
                toUpdate.add(cv);
            }
            if (!toUpdate.isEmpty()) update toUpdate;

            // Make the promoted file visible to the broker portal (external/guest) via its account link.
            List<ContentDocumentLink> linkUpdates = new List<ContentDocumentLink>();
            for (ContentDocumentLink l : [
                SELECT Id, ContentDocumentId, LinkedEntityId, Visibility
                FROM ContentDocumentLink WHERE ContentDocumentId IN :promoteDocToAccount.keySet()
            ]) {
                if (l.LinkedEntityId == promoteDocToAccount.get(l.ContentDocumentId) && l.Visibility != 'AllUsers') {
                    l.Visibility = 'AllUsers';
                    linkUpdates.add(l);
                }
            }
            if (!linkUpdates.isEmpty()) update linkUpdates;
        }

        if (!docIdsToDelete.isEmpty()) {
            List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE Id IN :docIdsToDelete];
            if (!docs.isEmpty()) delete docs;
        }

        if (!reqUpdates.isEmpty()) {
            try { update reqUpdates; } catch (Exception e) {
                System.debug('Could not mark doc request Applied (likely approval-locked): ' + e.getMessage());
            }
        }
    }

    // Payload is a JSON array of doc entries; tolerate a legacy single-object payload too.
    private static List<Object> parseDocs(String js) {
        List<Object> out = new List<Object>();
        if (String.isBlank(js)) return out;
        try {
            Object parsed = JSON.deserializeUntyped(js);
            if (parsed instanceof List<Object>) return (List<Object>) parsed;
            if (parsed instanceof Map<String, Object>) { out.add(parsed); return out; }   // legacy single-object
        } catch (Exception e) { /* ignore */ }
        return out;
    }

    private static String str(Object o) { return (o == null) ? '' : String.valueOf(o).trim(); }

    private static Id parseId(String s) {
        if (String.isBlank(s)) return null;
        try { return Id.valueOf(s); } catch (Exception e) { return null; }
    }
}