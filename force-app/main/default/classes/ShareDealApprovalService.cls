/**
 * Share Deal approval: Opportunity Owner (or privileged ops users) requests a second RM (always 50/50).
 * Mirrors Unit Price Change: Approval_Request__c → Manager → CSO → apply.
 *
 * Who may raise a request: Opportunity Owner, System Administrator, Sales Admin profile,
 * or active members of public groups Director_of_Operations / Sales_Admin_Special.
 */
public with sharing class ShareDealApprovalService {
    public static final String REQUEST_TYPE_SHARE_DEAL = 'Share Deal';
    public static final String SHARE_DEAL_APPROVAL_PROCESS = 'Share_Deal';
    public static final String SALES_MANAGER_MIRA_PROFILE = 'Sales Manager MIRA';
    private static final Integer MIN_JUSTIFICATION_LENGTH = 10;
    private static final Integer HEADER_FIELD_MAX_LENGTH = 255;

    @TestVisible
    private static final Set<String> PRIVILEGED_REQUESTER_PROFILES = new Set<String>{
        'System Administrator',
        'Sales Admin'
    };
    // Same ops groups as ApprovalRequestNotificationService — maintained in Setup → Public Groups.
    @TestVisible
    private static Set<String> PRIVILEGED_REQUESTER_GROUP_DEV_NAMES = new Set<String>{
        'Director_of_Operations',
        'Sales_Admin_Special'
    };
    // Test hook: when non-null, skips profile/group lookup (null = real check).
    @TestVisible private static Boolean forcePrivilegedRequester = null;
    @TestVisible private static String lastSubmitError;

    public class ShareDealInfoDTO {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public String stageName;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Id ownerId;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Boolean shareDeal;
        @AuraEnabled public Id sharedRmId;
        @AuraEnabled public String sharedRmName;
        @AuraEnabled public String shareDealStatus;
        @AuraEnabled public Boolean eligible;
        @AuraEnabled public String ineligibleReason;
    }

    public class OpenShareDealRequestDTO {
        @AuraEnabled public Id approvalRequestId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String justification;
        @AuraEnabled public Id requestedSharedRmId;
        @AuraEnabled public String requestedSharedRmName;
    }

    public class RmOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }

    public class ShareDealApprovalException extends Exception {}

    public static ShareDealInfoDTO getShareDealInfo(Id opportunityId) {
        Opportunity opp = loadOpportunity(opportunityId);

        ShareDealInfoDTO dto = new ShareDealInfoDTO();
        dto.opportunityId = opp.Id;
        dto.opportunityName = opp.Name;
        dto.stageName = opp.StageName;
        dto.ownerId = opp.OwnerId;
        dto.ownerName = opp.Owner == null ? null : opp.Owner.Name;
        dto.unitPrice = opp.Unit_Price__c;
        dto.shareDeal = opp.Share_Deal__c == true;
        dto.sharedRmId = opp.Shared_RM__c;
        dto.sharedRmName = opp.Shared_RM__r == null ? null : opp.Shared_RM__r.Name;
        dto.shareDealStatus = opp.Share_Deal_Status__c;

        if (opp.StageName != 'Booked') {
            dto.eligible = false;
            dto.ineligibleReason = 'Share Deal requests are only allowed for Booked Opportunities.';
        } else if (!canRaiseShareDeal(opp)) {
            dto.eligible = false;
            dto.ineligibleReason =
                'Only the Opportunity Owner, Sales Admin, or Director of Operations can request a Share Deal.';
        } else {
            dto.eligible = true;
        }
        return dto;
    }

    public static List<RmOptionDTO> getEligibleSharedRmOptions(Id opportunityId) {
        Opportunity opp = loadOpportunity(opportunityId);
        List<User> users = [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
              AND Profile.Name = :SALES_MANAGER_MIRA_PROFILE
              AND Id != :opp.OwnerId
            ORDER BY Name
            LIMIT 200
        ];

        List<RmOptionDTO> options = new List<RmOptionDTO>();
        for (User u : users) {
            RmOptionDTO option = new RmOptionDTO();
            option.id = u.Id;
            option.name = u.Name;
            options.add(option);
        }
        return options;
    }

    public static OpenShareDealRequestDTO getOpenShareDealRequest(Id opportunityId) {
        validateOpportunityAccess(opportunityId);

        Approval_Request__c request = findShareDealRequest(
            opportunityId,
            new Set<String>{ 'Draft', 'Pending' }
        );
        if (request == null) {
            return null;
        }

        String effectiveStatus = resolveEffectiveStatus(request);
        if (effectiveStatus == 'Rejected' || effectiveStatus == 'Approved' || effectiveStatus == 'Applied') {
            return null;
        }

        OpenShareDealRequestDTO dto = new OpenShareDealRequestDTO();
        dto.approvalRequestId = request.Id;
        dto.name = request.Name;
        dto.status = effectiveStatus;
        dto.justification = request.Justification__c;
        dto.requestedSharedRmId = request.Requested_Shared_RM__c;
        dto.requestedSharedRmName = request.Requested_Shared_RM__r == null
            ? null
            : request.Requested_Shared_RM__r.Name;
        return dto;
    }

    public static Id submitShareDealApproval(
        Id opportunityId,
        Id requestedSharedRmId,
        String justification,
        Id existingRequestId
    ) {
        try {
            validateJustification(justification);
            Opportunity opp = loadOpportunity(opportunityId);
            validateEligible(opp);
            validateRequestedSharedRm(opp, requestedSharedRmId);

            Approval_Request__c pendingRequest = findShareDealRequest(
                opportunityId,
                new Set<String>{ 'Pending' }
            );
            if (pendingRequest != null) {
                if (hasPendingApprovalProcess(pendingRequest.Id)) {
                    throw auraError(
                        'A Share Deal request is already pending approval' +
                        (String.isNotBlank(pendingRequest.Name) ? ' (' + pendingRequest.Name + ').' : '.')
                    );
                }
                reconcileStaleRequestStatus(pendingRequest);
            }

            Id approvalRequestId = existingRequestId;
            if (approvalRequestId == null) {
                approvalRequestId = createOrUpdateDraft(opp, requestedSharedRmId, justification, null);
            } else {
                Approval_Request__c existing = getEditableRequest(approvalRequestId);
                populateHeaderFields(existing, opp, requestedSharedRmId);
                existing.Justification__c = justification;
                update existing;
            }

            submitForApproval(approvalRequestId);
            markOpportunityPending(opportunityId);
            return approvalRequestId;
        } catch (AuraHandledException e) {
            lastSubmitError = getExceptionMessage(e);
            throw auraError(lastSubmitError);
        } catch (DmlException e) {
            lastSubmitError = formatDmlException(e);
            throw auraError(lastSubmitError);
        } catch (Exception e) {
            lastSubmitError = 'Share Deal submit failed: ' + getExceptionMessage(e);
            throw auraError(lastSubmitError);
        }
    }

    public static void applyApprovedChanges(Id approvalRequestId) {
        Approval_Request__c request = [
            SELECT Id, Status__c, Request_Type__c, Opportunity__c, Requested_Shared_RM__c,
                   Justification__c
            FROM Approval_Request__c
            WHERE Id = :approvalRequestId
            LIMIT 1
        ];

        if (request.Request_Type__c != REQUEST_TYPE_SHARE_DEAL) {
            return;
        }
        if (request.Status__c == 'Applied') {
            return;
        }
        if (request.Status__c != 'Approved') {
            return;
        }
        if (request.Opportunity__c == null) {
            throw new ShareDealApprovalException('Approval request is missing the related Opportunity.');
        }
        if (request.Requested_Shared_RM__c == null) {
            throw new ShareDealApprovalException('Approval request is missing the requested Shared RM.');
        }

        Opportunity opp = loadOpportunity(request.Opportunity__c);
        validateRequestedSharedRm(opp, request.Requested_Shared_RM__c);

        Opportunity updateOpp = new Opportunity(
            Id = opp.Id,
            Share_Deal__c = true,
            Shared_RM__c = request.Requested_Shared_RM__c,
            Share_Deal_Status__c = 'Approved'
        );
        update updateOpp;
        // RM_Deal_Credit__c rows rebuild via OpportunityTrigger after update.

        // Best-effort: request may still be approval-locked immediately after final approval.
        try {
            update new Approval_Request__c(
                Id = approvalRequestId,
                Status__c = 'Applied'
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'Could not mark Share Deal request Applied (likely approval-locked): ' + e.getMessage());
        }
    }

    public static void handleRejected(Id approvalRequestId) {
        Approval_Request__c request = [
            SELECT Id, Opportunity__c, Request_Type__c, Status__c
            FROM Approval_Request__c
            WHERE Id = :approvalRequestId
            LIMIT 1
        ];
        if (request.Request_Type__c != REQUEST_TYPE_SHARE_DEAL || request.Opportunity__c == null) {
            return;
        }

        Opportunity opp = [
            SELECT Id, Share_Deal__c, Share_Deal_Status__c
            FROM Opportunity
            WHERE Id = :request.Opportunity__c
            LIMIT 1
        ];
        // Only clear Pending; leave an already-approved share deal intact.
        if (opp.Share_Deal_Status__c == 'Pending' && opp.Share_Deal__c != true) {
            update new Opportunity(
                Id = opp.Id,
                Share_Deal_Status__c = 'Rejected'
            );
        }
    }

    private static Id createOrUpdateDraft(
        Opportunity opp,
        Id requestedSharedRmId,
        String justification,
        Id existingDraftId
    ) {
        Approval_Request__c request;
        if (existingDraftId != null) {
            request = getEditableRequest(existingDraftId);
        } else {
            request = findShareDealRequest(opp.Id, new Set<String>{ 'Draft' });
            if (request == null) {
                request = new Approval_Request__c(
                    Request_Type__c = REQUEST_TYPE_SHARE_DEAL,
                    Status__c = 'Draft',
                    Requester__c = UserInfo.getUserId()
                );
            }
        }

        request.Justification__c = justification;
        populateHeaderFields(request, opp, requestedSharedRmId);
        upsert request;
        return request.Id;
    }

    private static void populateHeaderFields(
        Approval_Request__c request,
        Opportunity opp,
        Id requestedSharedRmId
    ) {
        User sharedRm = [
            SELECT Id, Name
            FROM User
            WHERE Id = :requestedSharedRmId
            LIMIT 1
        ];

        request.Request_Type__c = REQUEST_TYPE_SHARE_DEAL;
        request.Opportunity__c = opp.Id;
        request.Requested_Shared_RM__c = requestedSharedRmId;
        request.Unit__c = opp.Unit__c;
        request.Field_To_Update__c = 'Shared_RM__c';
        request.Related_Record_Id__c = String.valueOf(opp.Id);
        request.Related_Object_Type__c = 'Opportunity';
        request.Parent_Object__c = 'Opportunity';
        request.Parent_Record_Id__c = String.valueOf(opp.Id);
        request.Current_Value__c = truncateField(
            opp.Share_Deal__c == true && opp.Shared_RM__r != null
                ? 'Share with ' + opp.Shared_RM__r.Name
                : 'Single deal (Owner: ' + (opp.Owner == null ? '' : opp.Owner.Name) + ')'
        );
        request.Requested_Value__c = truncateField(
            'Share 50/50 with ' + sharedRm.Name
        );
    }

    private static void submitForApproval(Id approvalRequestId) {
        Approval_Request__c request = getEditableRequest(approvalRequestId);
        if (request.Requested_Shared_RM__c == null) {
            throw auraError('Select a Shared RM before submitting for approval.');
        }

        if (
            request.Status__c == null ||
            request.Status__c == 'Rejected' ||
            request.Status__c == 'Approved' ||
            request.Status__c == 'Applied'
        ) {
            request.Status__c = 'Draft';
            update request;
        }

        Approval_Request__c submitRecord = [
            SELECT Id, Request_Type__c, Status__c
            FROM Approval_Request__c
            WHERE Id = :approvalRequestId
            LIMIT 1
        ];
        if (submitRecord.Request_Type__c != REQUEST_TYPE_SHARE_DEAL) {
            throw auraError('Request type must be Share Deal.');
        }
        if (submitRecord.Status__c == 'Pending') {
            throw auraError('This request is already pending approval.');
        }
        if (submitRecord.Status__c != 'Draft') {
            throw auraError(
                'Only Draft requests can be submitted. Current status: ' + submitRecord.Status__c
            );
        }
        if (hasPendingApprovalProcess(approvalRequestId)) {
            throw auraError('An approval process is already pending for this request.');
        }

        List<String> processReferences = new List<String>{
            SHARE_DEAL_APPROVAL_PROCESS,
            Approval_Request__c.SObjectType.getDescribe().getName() + '.' + SHARE_DEAL_APPROVAL_PROCESS,
            null
        };

        Approval.ProcessResult result;
        Exception lastError;
        for (String processRef : processReferences) {
            try {
                Approval.ProcessSubmitRequest submitRequest = new Approval.ProcessSubmitRequest();
                submitRequest.setObjectId(approvalRequestId);
                submitRequest.setComments(
                    String.isNotBlank(request.Justification__c)
                        ? request.Justification__c
                        : 'Share Deal approval request'
                );
                if (String.isNotBlank(processRef)) {
                    submitRequest.setProcessDefinitionNameOrId(processRef);
                }
                result = Approval.process(submitRequest);
                if (result != null && result.isSuccess()) {
                    break;
                }
            } catch (Exception e) {
                lastError = e;
                result = null;
            }
        }

        if (result == null || !result.isSuccess()) {
            String detail = lastError != null
                ? getExceptionMessage(lastError)
                : (result == null ? 'Unknown approval submit failure.' : String.valueOf(result.getErrors()));
            throw auraError('Unable to submit Share Deal approval: ' + detail);
        }

        try {
            update new Approval_Request__c(
                Id = approvalRequestId,
                Request_Type__c = REQUEST_TYPE_SHARE_DEAL,
                Status__c = 'Pending'
            );
        } catch (DmlException e) {
            if (!hasPendingApprovalProcess(approvalRequestId)) {
                throw auraError(formatDmlException(e));
            }
        }
    }

    private static void markOpportunityPending(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, Share_Deal__c, Share_Deal_Status__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (opp.Share_Deal__c == true) {
            // Changing an existing share still shows Pending on the request;
            // keep Approved on the Opportunity until the new request is applied.
            return;
        }
        update new Opportunity(
            Id = opportunityId,
            Share_Deal_Status__c = 'Pending'
        );
    }

    private static Opportunity loadOpportunity(Id opportunityId) {
        if (opportunityId == null) {
            throw auraError('Opportunity Id is required.');
        }
        List<Opportunity> opps = [
            SELECT Id, Name, StageName, OwnerId, Owner.Name, Unit__c, Unit_Price__c,
                   Share_Deal__c, Shared_RM__c, Shared_RM__r.Name, Share_Deal_Status__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (opps.isEmpty()) {
            throw auraError('Opportunity was not found.');
        }
        return opps[0];
    }

    private static void validateOpportunityAccess(Id opportunityId) {
        loadOpportunity(opportunityId);
    }

    private static void validateEligible(Opportunity opp) {
        if (opp.StageName != 'Booked') {
            throw auraError('Share Deal requests are only allowed for Booked Opportunities.');
        }
        if (!canRaiseShareDeal(opp)) {
            throw auraError(
                'Only the Opportunity Owner, Sales Admin, or Director of Operations can request a Share Deal.'
            );
        }
    }

    private static Boolean canRaiseShareDeal(Opportunity opp) {
        if (opp != null && opp.OwnerId == UserInfo.getUserId()) {
            return true;
        }
        return isPrivilegedShareDealRequester();
    }

    private static Boolean isPrivilegedShareDealRequester() {
        if (forcePrivilegedRequester != null) {
            return forcePrivilegedRequester;
        }
        List<Profile> profiles = [
            SELECT Name
            FROM Profile
            WHERE Id = :UserInfo.getProfileId()
            LIMIT 1
        ];
        if (!profiles.isEmpty() && PRIVILEGED_REQUESTER_PROFILES.contains(profiles[0].Name)) {
            return true;
        }
        return isMemberOfPrivilegedRequesterGroups();
    }

    private static Boolean isMemberOfPrivilegedRequesterGroups() {
        if (PRIVILEGED_REQUESTER_GROUP_DEV_NAMES == null || PRIVILEGED_REQUESTER_GROUP_DEV_NAMES.isEmpty()) {
            return false;
        }
        List<Group> groups = [
            SELECT Id
            FROM Group
            WHERE DeveloperName IN :PRIVILEGED_REQUESTER_GROUP_DEV_NAMES
              AND Type = 'Regular'
        ];
        if (groups.isEmpty()) {
            return false;
        }
        Set<Id> groupIds = (new Map<Id, Group>(groups)).keySet();
        return ![
            SELECT Id
            FROM GroupMember
            WHERE GroupId IN :groupIds
              AND UserOrGroupId = :UserInfo.getUserId()
            LIMIT 1
        ].isEmpty();
    }

    private static void validateRequestedSharedRm(Opportunity opp, Id requestedSharedRmId) {
        if (requestedSharedRmId == null) {
            throw auraError('Select a Shared RM.');
        }
        if (requestedSharedRmId == opp.OwnerId) {
            throw auraError('Shared RM cannot be the same as the Opportunity Owner.');
        }

        List<User> users = [
            SELECT Id, IsActive, Profile.Name
            FROM User
            WHERE Id = :requestedSharedRmId
            LIMIT 1
        ];
        if (users.isEmpty()) {
            throw auraError('Selected Shared RM was not found.');
        }
        if (!users[0].IsActive) {
            throw auraError('Selected Shared RM must be an active user.');
        }
        if (users[0].Profile == null || users[0].Profile.Name != SALES_MANAGER_MIRA_PROFILE) {
            throw auraError(
                'Shared RM must have the Sales Manager MIRA profile.'
            );
        }
    }

    private static void validateJustification(String justification) {
        if (String.isBlank(justification) || justification.trim().length() < MIN_JUSTIFICATION_LENGTH) {
            throw auraError(
                'Justification must be at least ' + MIN_JUSTIFICATION_LENGTH + ' characters.'
            );
        }
    }

    private static Approval_Request__c findShareDealRequest(Id opportunityId, Set<String> statuses) {
        List<Approval_Request__c> requests = [
            SELECT Id, Name, Status__c, Justification__c, Requested_Shared_RM__c,
                   Requested_Shared_RM__r.Name, Request_Type__c
            FROM Approval_Request__c
            WHERE Request_Type__c = :REQUEST_TYPE_SHARE_DEAL
              AND Opportunity__c = :opportunityId
              AND Status__c IN :statuses
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return requests.isEmpty() ? null : requests[0];
    }

    private static Approval_Request__c getEditableRequest(Id approvalRequestId) {
        List<Approval_Request__c> requests = [
            SELECT Id, Name, Status__c, Justification__c, Request_Type__c, Opportunity__c,
                   Requested_Shared_RM__c, Unit__c, Related_Record_Id__c
            FROM Approval_Request__c
            WHERE Id = :approvalRequestId
            LIMIT 1
        ];
        if (requests.isEmpty()) {
            throw auraError('Approval request was not found.');
        }
        if (requests[0].Request_Type__c != REQUEST_TYPE_SHARE_DEAL) {
            throw auraError('This is not a Share Deal approval request.');
        }
        return requests[0];
    }

    private static String resolveEffectiveStatus(Approval_Request__c request) {
        if (request == null || String.isBlank(request.Status__c)) {
            return 'Draft';
        }
        if (request.Status__c == 'Draft' && hasPendingApprovalProcess(request.Id)) {
            return 'Pending';
        }
        if (request.Status__c == 'Pending' && !hasPendingApprovalProcess(request.Id)) {
            String outcome = resolveLatestProcessOutcome(request.Id);
            if (outcome == 'Rejected' || outcome == 'Approved') {
                return outcome;
            }
            return 'Draft';
        }
        return request.Status__c;
    }

    private static String resolveLatestProcessOutcome(Id approvalRequestId) {
        List<ProcessInstance> instances = [
            SELECT Status
            FROM ProcessInstance
            WHERE TargetObjectId = :approvalRequestId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return instances.isEmpty() ? null : instances[0].Status;
    }

    private static void reconcileStaleRequestStatus(Approval_Request__c request) {
        String effective = resolveEffectiveStatus(request);
        if (effective == request.Status__c) {
            return;
        }
        try {
            update new Approval_Request__c(Id = request.Id, Status__c = effective);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'Could not reconcile stale Share Deal request ' + request.Id + ': ' + e.getMessage());
        }
    }

    private static Boolean hasPendingApprovalProcess(Id approvalRequestId) {
        return ![
            SELECT Id
            FROM ProcessInstance
            WHERE TargetObjectId = :approvalRequestId
              AND Status = 'Pending'
            LIMIT 1
        ].isEmpty();
    }

    private static String truncateField(String value) {
        if (value == null) {
            return null;
        }
        return value.length() <= HEADER_FIELD_MAX_LENGTH
            ? value
            : value.substring(0, HEADER_FIELD_MAX_LENGTH);
    }

    private static String formatDmlException(DmlException e) {
        return e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage();
    }

    private static String getExceptionMessage(Exception e) {
        return String.isNotBlank(e.getMessage()) ? e.getMessage() : e.getTypeName();
    }

    private static AuraHandledException auraError(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}
