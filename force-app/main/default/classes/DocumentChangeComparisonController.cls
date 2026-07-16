/**
 * Supplies the data for a "Document Re-upload" approval request so the approver (Agency RM) can
 * compare each existing document against the re-uploaded one before approving. The LWC opens each
 * file in the native viewer using the ContentDocumentIds returned here.
 * Brand-new component; does not touch any existing approval comparison class.
 */
public with sharing class DocumentChangeComparisonController {

    private static final String TYPE_DOC = 'Document Re-upload';

    public class DocPair {
        @AuraEnabled public String oldFileName;
        @AuraEnabled public String oldDocId;
        @AuraEnabled public String newFileName;
        @AuraEnabled public String newDocId;
    }

    public class Comparison {
        @AuraEnabled public Boolean notApplicable = false;
        @AuraEnabled public String notApplicableReason;
        @AuraEnabled public String requestName;
        @AuraEnabled public String status;
        @AuraEnabled public String agencyName;
        @AuraEnabled public String justification;
        @AuraEnabled public String submittedDate;
        @AuraEnabled public List<DocPair> docs = new List<DocPair>();
    }

    @AuraEnabled(cacheable=true)
    public static Comparison getDocComparison(Id recordId) {
        Comparison c = new Comparison();

        Id resolvedId = PaymentPlanComparisonReader.resolveApprovalRequestId(recordId);
        if (resolvedId == null) {
            c.notApplicable = true;
            c.notApplicableReason = 'No approval request found for this record.';
            return c;
        }

        List<Approval_Request__c> reqs = [
            SELECT Name, Status__c, Justification__c, Request_Type__c,
                   Related_Record_Id__c, Profile_Changes_JSON__c, CreatedDate
            FROM Approval_Request__c WHERE Id = :resolvedId LIMIT 1
        ];
        if (reqs.isEmpty() || reqs[0].Request_Type__c != TYPE_DOC) {
            c.notApplicable = true;
            c.notApplicableReason = 'This request is not a Document Re-upload.';
            return c;
        }

        Approval_Request__c req = reqs[0];
        c.requestName   = req.Name;
        c.status        = req.Status__c;
        c.justification = req.Justification__c;
        c.submittedDate = (req.CreatedDate != null) ? req.CreatedDate.format('dd MMM yyyy, h:mm a') : null;
        c.agencyName    = resolveAgencyName(req.Related_Record_Id__c);
        c.docs          = parsePairs(req.Profile_Changes_JSON__c);

        if (c.docs.isEmpty()) {
            c.notApplicable = true;
            c.notApplicableReason = 'No document changes were recorded on this request.';
        }
        return c;
    }

    private static List<DocPair> parsePairs(String js) {
        List<DocPair> out = new List<DocPair>();
        if (String.isBlank(js)) return out;
        List<Object> entries;
        try {
            Object parsed = JSON.deserializeUntyped(js);
            entries = (parsed instanceof List<Object>) ? (List<Object>) parsed : new List<Object>{ parsed };
        } catch (Exception e) { return out; }

        for (Object o : entries) {
            if (!(o instanceof Map<String, Object>)) continue;
            Map<String, Object> m = (Map<String, Object>) o;
            DocPair p = new DocPair();
            p.oldFileName = str(m.get('oldFileName'));
            p.oldDocId    = str(m.get('oldContentDocumentId'));
            p.newFileName = str(m.get('newFileName'));
            if (String.isBlank(p.newFileName)) p.newFileName = str(m.get('fileName'));   // legacy key
            p.newDocId    = str(m.get('newContentDocumentId'));
            out.add(p);
        }
        return out;
    }

    private static String resolveAgencyName(String relatedId) {
        if (String.isBlank(relatedId)) return null;
        Id acctId;
        try { acctId = Id.valueOf(relatedId); } catch (Exception e) { return null; }
        List<Account> accts = [SELECT Name FROM Account WHERE Id = :acctId LIMIT 1];
        return accts.isEmpty() ? null : accts[0].Name;
    }

    private static String str(Object o) { return (o == null) ? '' : String.valueOf(o); }
}