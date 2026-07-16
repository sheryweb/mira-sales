/**
 * Read-only history of Unit Price Change and Payment Plan Change approval requests
 * for a given Opportunity, for display on the Opportunity record page.
 *
 * The approval requests are anchored to the Opportunity's Unit (via Parent_Record_Id__c),
 * and the decision timeline is sourced from the native Salesforce approval process
 * (ProcessInstance / ProcessInstanceStep), which permanently records who submitted /
 * approved / rejected each request, when, and with what comment.
 *
 * Access is gated by the "View_Approval_History" custom permission so only authorised
 * users (e.g. System Administrators) can see the history, enforced server-side here in
 * addition to any Lightning page component-visibility filter.
 *
 * Deliberately keyed on Parent_Record_Id__c and built only from fields common to every
 * version of Approval_Request__c, so it works regardless of schema drift between orgs.
 */
// 'without sharing': this is a read-only, custom-permission-gated audit view. Approval_Request__c
// has a Private org-wide default, so 'with sharing' would hide requests the viewer doesn't own and
// leave the component empty for authorised users (admins, sales admins). The View_Approval_History
// custom permission is the access control here, not record sharing.
public without sharing class OpportunityApprovalHistoryController {

    @TestVisible
    private static final String VIEW_PERMISSION = 'View_Approval_History';

    private static final Set<String> TRACKED_TYPES = new Set<String>{
        'Unit Price Change',
        'Payment Plan Change'
    };

    @AuraEnabled(cacheable=true)
    public static List<RequestHistory> getApprovalHistory(Id opportunityId) {
        if (!FeatureManagement.checkPermission(VIEW_PERMISSION)) {
            throw new AuraHandledException(
                'You do not have permission to view approval history.'
            );
        }
        if (opportunityId == null) {
            return new List<RequestHistory>();
        }

        // 1. Resolve the Opportunity's Unit.
        List<Opportunity> opps = [
            SELECT Id, Unit__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (opps.isEmpty() || opps[0].Unit__c == null) {
            return new List<RequestHistory>();
        }
        String unitId = String.valueOf(opps[0].Unit__c);

        // 2. Approval requests of the tracked types anchored to that Unit.
        List<Approval_Request__c> requests = [
            SELECT Id, Name, Request_Type__c, Status__c, Current_Value__c,
                   Requested_Value__c, Field_To_Update__c, Justification__c,
                   Requester__r.Name, CreatedDate
            FROM Approval_Request__c
            WHERE Parent_Record_Id__c = :unitId
              AND Request_Type__c IN :TRACKED_TYPES
            ORDER BY CreatedDate DESC
        ];
        if (requests.isEmpty()) {
            return new List<RequestHistory>();
        }

        // 3. Native approval step history, grouped by the request they belong to.
        Set<Id> requestIds = new Map<Id, Approval_Request__c>(requests).keySet();
        Map<Id, List<StepInfo>> stepsByRequest = new Map<Id, List<StepInfo>>();
        for (ProcessInstance pi : [
            SELECT TargetObjectId,
                   (SELECT StepStatus, Actor.Name, Comments, CreatedDate
                    FROM Steps
                    ORDER BY CreatedDate ASC)
            FROM ProcessInstance
            WHERE TargetObjectId IN :requestIds
            ORDER BY CreatedDate ASC
        ]) {
            List<StepInfo> steps = stepsByRequest.get(pi.TargetObjectId);
            if (steps == null) {
                steps = new List<StepInfo>();
                stepsByRequest.put(pi.TargetObjectId, steps);
            }
            for (ProcessInstanceStep step : pi.Steps) {
                steps.add(new StepInfo(step));
            }
        }

        // 4. Assemble the response.
        List<RequestHistory> result = new List<RequestHistory>();
        for (Approval_Request__c req : requests) {
            result.add(new RequestHistory(req, stepsByRequest.get(req.Id)));
        }
        return result;
    }

    public class RequestHistory {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String requestType;
        @AuraEnabled public String status;
        @AuraEnabled public String currentValue;
        @AuraEnabled public String requestedValue;
        @AuraEnabled public String fieldToUpdate;
        @AuraEnabled public String justification;
        @AuraEnabled public String requesterName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public List<StepInfo> steps;

        public RequestHistory(Approval_Request__c req, List<StepInfo> steps) {
            this.id = req.Id;
            this.name = req.Name;
            this.requestType = req.Request_Type__c;
            this.status = req.Status__c;
            this.currentValue = req.Current_Value__c;
            this.requestedValue = req.Requested_Value__c;
            this.fieldToUpdate = req.Field_To_Update__c;
            this.justification = req.Justification__c;
            this.requesterName = req.Requester__r != null ? req.Requester__r.Name : null;
            this.createdDate = req.CreatedDate;
            this.steps = steps != null ? steps : new List<StepInfo>();
        }
    }

    public class StepInfo {
        @AuraEnabled public String action;     // StepStatus: Started / Approved / Rejected / ...
        @AuraEnabled public String actorName;
        @AuraEnabled public String comments;
        @AuraEnabled public Datetime actionDate;

        public StepInfo(ProcessInstanceStep step) {
            this.action = step.StepStatus;
            this.actorName = step.Actor != null ? step.Actor.Name : null;
            this.comments = step.Comments;
            this.actionDate = step.CreatedDate;
        }
    }
}