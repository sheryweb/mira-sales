public with sharing class InvoiceReceiptTransferService {
    public static final String REQUEST_TYPE = 'Invoice Receipt Transfer';
    public static final String APPROVAL_PROCESS = 'Invoice_Receipt_Transfer';

    private static final String STAGE_NEW = 'New';
    private static final String STAGE_CANCELLED = 'Cancelled';
    private static final Integer HEADER_FIELD_MAX_LENGTH = 255;
    private static final Integer SEARCH_LIMIT = 50;

    public class OpportunityOptionDTO {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public String stageName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String financialNumber;
    }

    public class OpenTransferRequestDTO {
        @AuraEnabled public Id approvalRequestId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String justification;
        @AuraEnabled public Id requestedOpportunityId;
        @AuraEnabled public String requestedOpportunityName;
        @AuraEnabled public String requestedAccountName;
    }

    public class TransferContextDTO {
        @AuraEnabled public Id unitId;
        @AuraEnabled public String unitTitle;
        @AuraEnabled public Integer invoiceCount;
        @AuraEnabled public Integer receiptCount;
        @AuraEnabled public OpenTransferRequestDTO openRequest;
        @AuraEnabled public Boolean canSubmit;
        @AuraEnabled public String blockReason;
    }

    public class InvoiceReceiptTransferException extends Exception {}

    public static TransferContextDTO getTransferContext(Id unitId) {
        validateUnitAccess(unitId);
        Unit__c unit = [
            SELECT Id, Title__c
            FROM Unit__c
            WHERE Id = :unitId
            LIMIT 1
        ];

        TransferContextDTO dto = new TransferContextDTO();
        dto.unitId = unit.Id;
        dto.unitTitle = unit.Title__c;
        dto.invoiceCount = [
            SELECT COUNT()
            FROM Invoice__c
            WHERE Unit__c = :unitId
        ];
        dto.receiptCount = [
            SELECT COUNT()
            FROM Receipt__c
            WHERE Unit__c = :unitId
        ];
        dto.openRequest = getOpenTransferRequestForUnit(unitId);

        if (dto.openRequest != null) {
            dto.canSubmit = false;
            dto.blockReason = 'A transfer request is already ' + dto.openRequest.status +
                ' for this unit (' + dto.openRequest.name + ').';
        } else if (dto.invoiceCount == 0 && dto.receiptCount == 0) {
            dto.canSubmit = false;
            dto.blockReason = 'This unit has no invoices or receipts to transfer.';
        } else {
            dto.canSubmit = true;
        }
        return dto;
    }

    public static List<OpportunityOptionDTO> searchOpportunities(Id unitId, String searchTerm) {
        validateUnitAccess(unitId);

        String likeTerm;
        if (String.isNotBlank(searchTerm)) {
            likeTerm = '%' + searchTerm.trim() + '%';
        }

        List<Opportunity> opps;
        if (String.isNotBlank(likeTerm)) {
            opps = [
                SELECT Id, Name, StageName, AccountId,
                       Account.Name, Account.Phone, Account.PersonEmail, Account.Company_Email__c,
                       Account.Financial_Number__c, Account_Name__c
                FROM Opportunity
                WHERE Unit__c = :unitId
                  AND StageName != :STAGE_NEW
                  AND StageName != :STAGE_CANCELLED
                  AND (
                      Name LIKE :likeTerm
                      OR Account.Name LIKE :likeTerm
                      OR Account_Name__c LIKE :likeTerm
                  )
                ORDER BY LastModifiedDate DESC
                LIMIT :SEARCH_LIMIT
            ];
        } else {
            opps = [
                SELECT Id, Name, StageName, AccountId,
                       Account.Name, Account.Phone, Account.PersonEmail, Account.Company_Email__c,
                       Account.Financial_Number__c, Account_Name__c
                FROM Opportunity
                WHERE Unit__c = :unitId
                  AND StageName != :STAGE_NEW
                  AND StageName != :STAGE_CANCELLED
                ORDER BY LastModifiedDate DESC
                LIMIT :SEARCH_LIMIT
            ];
        }

        List<OpportunityOptionDTO> options = new List<OpportunityOptionDTO>();
        for (Opportunity opp : opps) {
            options.add(toOption(opp));
        }
        return options;
    }

    public static OpportunityOptionDTO getAccountPreview(Id opportunityId) {
        if (opportunityId == null) {
            throw auraError('Opportunity is required.');
        }
        List<Opportunity> opps = [
            SELECT Id, Name, StageName, AccountId, Unit__c,
                   Account.Name, Account.Phone, Account.PersonEmail, Account.Company_Email__c,
                   Account.Financial_Number__c, Account_Name__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (opps.isEmpty()) {
            throw auraError('Opportunity not found.');
        }
        Opportunity opp = opps[0];
        if (opp.StageName == STAGE_NEW || opp.StageName == STAGE_CANCELLED) {
            throw auraError('Selected Opportunity must not be New or Cancelled.');
        }
        if (opp.AccountId == null) {
            throw auraError('Selected Opportunity has no Account.');
        }
        return toOption(opp);
    }

    public static OpenTransferRequestDTO getOpenTransferRequestForUnit(Id unitId) {
        validateUnitAccess(unitId);
        Approval_Request__c request = findOpenRequestForUnit(unitId);
        if (request == null) {
            return null;
        }
        String effectiveStatus = resolveEffectiveStatus(request);
        if (effectiveStatus == 'Rejected' || effectiveStatus == 'Approved' || effectiveStatus == 'Applied') {
            return null;
        }

        OpenTransferRequestDTO dto = new OpenTransferRequestDTO();
        dto.approvalRequestId = request.Id;
        dto.name = request.Name;
        dto.status = effectiveStatus;
        dto.justification = request.Justification__c;
        dto.requestedOpportunityId = request.Requested_Opportunity__c;
        dto.requestedOpportunityName = request.Requested_Opportunity__r != null
            ? request.Requested_Opportunity__r.Name
            : null;
        dto.requestedAccountName = request.Requested_Opportunity__r != null
            ? request.Requested_Opportunity__r.Account_Name__c
            : null;
        return dto;
    }

    public static Id submitTransferRequest(Id unitId, Id targetOpportunityId, String justification) {
        validateUnitAccess(unitId);
        validateJustification(justification);

        Opportunity targetOpp = loadEligibleTargetOpportunity(unitId, targetOpportunityId);
        Approval_Request__c openRequest = findOpenRequestForUnit(unitId);
        if (openRequest != null) {
            String effective = resolveEffectiveStatus(openRequest);
            if (effective == 'Draft' || effective == 'Pending') {
                throw auraError(
                    'A transfer request is already ' + effective +
                    ' for this unit. Finish or recall it before submitting another.'
                );
            }
        }

        Integer invoiceCount = [SELECT COUNT() FROM Invoice__c WHERE Unit__c = :unitId];
        Integer receiptCount = [SELECT COUNT() FROM Receipt__c WHERE Unit__c = :unitId];
        if (invoiceCount == 0 && receiptCount == 0) {
            throw auraError('This unit has no invoices or receipts to transfer.');
        }

        String currentSnapshot = buildCurrentSnapshot(unitId, invoiceCount, receiptCount);
        String requestedSnapshot = truncateField(
            targetOpp.Account_Name__c +
            ' / ' + targetOpp.Name +
            ' (FN: ' + nullToDash(targetOpp.Account.Financial_Number__c) + ')'
        );

        Approval_Request__c request = new Approval_Request__c(
            Request_Type__c = REQUEST_TYPE,
            Status__c = 'Draft',
            Requester__c = UserInfo.getUserId(),
            Unit__c = unitId,
            Requested_Opportunity__c = targetOpp.Id,
            Opportunity__c = targetOpp.Id,
            Justification__c = justification.trim(),
            Field_To_Update__c = 'Opportunity__c;Account__c;Customer_Name__c;Customer_Id__c',
            Related_Object_Type__c = 'Unit__c',
            Related_Record_Id__c = String.valueOf(unitId),
            Parent_Object__c = 'Unit__c',
            Parent_Record_Id__c = String.valueOf(unitId),
            Current_Value__c = currentSnapshot,
            Requested_Value__c = requestedSnapshot
        );
        insert request;

        try {
            submitApprovalProcess(request.Id, justification);
        } catch (Exception e) {
            throw auraError('Unable to submit approval request: ' + getExceptionMessage(e));
        }
        return request.Id;
    }

    @InvocableMethod(label='Apply Invoice Receipt Transfer' description='Applies approved Invoice Receipt Transfer changes to Unit invoices and receipts.')
    public static void applyApprovedChangesInvocable(List<Id> approvalRequestIds) {
        if (approvalRequestIds == null) {
            return;
        }
        for (Id requestId : approvalRequestIds) {
            if (requestId != null) {
                applyApprovedChanges(requestId);
            }
        }
    }

    public static void applyApprovedChanges(Id approvalRequestId) {
        Approval_Request__c request = [
            SELECT Id, Status__c, Request_Type__c, Unit__c, Requested_Opportunity__c
            FROM Approval_Request__c
            WHERE Id = :approvalRequestId
            LIMIT 1
        ];

        if (request.Request_Type__c != REQUEST_TYPE) {
            return;
        }
        if (request.Status__c == 'Applied') {
            return;
        }
        if (request.Status__c != 'Approved') {
            return;
        }
        if (request.Unit__c == null) {
            throw new InvoiceReceiptTransferException('Approval request is missing the related unit.');
        }
        if (request.Requested_Opportunity__c == null) {
            throw new InvoiceReceiptTransferException('Approval request is missing the requested Opportunity.');
        }

        Opportunity targetOpp = [
            SELECT Id, AccountId, Account_Name__c, Account.Name, Account.Financial_Number__c, Unit__c, StageName
            FROM Opportunity
            WHERE Id = :request.Requested_Opportunity__c
            LIMIT 1
        ];
        if (targetOpp.Unit__c != request.Unit__c) {
            throw new InvoiceReceiptTransferException(
                'Requested Opportunity is not linked to the approval Unit.'
            );
        }
        if (targetOpp.AccountId == null) {
            throw new InvoiceReceiptTransferException('Requested Opportunity has no Account.');
        }

        String customerName = String.isNotBlank(targetOpp.Account_Name__c)
            ? targetOpp.Account_Name__c
            : targetOpp.Account.Name;
        String customerId = targetOpp.Account.Financial_Number__c;

        List<Invoice__c> invoices = [
            SELECT Id, Opportunity__c, Account__c, Customer_Name__c, Customer_Id__c
            FROM Invoice__c
            WHERE Unit__c = :request.Unit__c
        ];
        for (Invoice__c inv : invoices) {
            inv.Opportunity__c = targetOpp.Id;
            inv.Account__c = targetOpp.AccountId;
            inv.Customer_Name__c = customerName;
            inv.Customer_Id__c = customerId;
        }

        List<Receipt__c> receipts = [
            SELECT Id, Opportunity__c, Account__c, Customer_Name__c
            FROM Receipt__c
            WHERE Unit__c = :request.Unit__c
        ];
        for (Receipt__c rcpt : receipts) {
            rcpt.Opportunity__c = targetOpp.Id;
            rcpt.Account__c = targetOpp.AccountId;
            rcpt.Customer_Name__c = customerName;
        }

        if (!invoices.isEmpty()) {
            update invoices;
        }
        if (!receipts.isEmpty()) {
            update receipts;
        }

        try {
            update new Approval_Request__c(
                Id = approvalRequestId,
                Status__c = 'Applied'
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'Could not mark Invoice Receipt Transfer request Applied (likely approval-locked): ' +
                e.getMessage());
        }
    }

    private static OpportunityOptionDTO toOption(Opportunity opp) {
        OpportunityOptionDTO dto = new OpportunityOptionDTO();
        dto.opportunityId = opp.Id;
        dto.opportunityName = opp.Name;
        dto.stageName = opp.StageName;
        dto.accountId = opp.AccountId;
        dto.accountName = String.isNotBlank(opp.Account_Name__c)
            ? opp.Account_Name__c
            : (opp.Account != null ? opp.Account.Name : null);
        dto.email = resolveEmail(opp.Account);
        dto.phone = opp.Account != null ? opp.Account.Phone : null;
        dto.financialNumber = opp.Account != null ? opp.Account.Financial_Number__c : null;
        return dto;
    }

    private static String resolveEmail(Account acc) {
        if (acc == null) {
            return null;
        }
        if (String.isNotBlank(acc.PersonEmail)) {
            return acc.PersonEmail;
        }
        return acc.Company_Email__c;
    }

    private static Opportunity loadEligibleTargetOpportunity(Id unitId, Id opportunityId) {
        if (opportunityId == null) {
            throw auraError('Please select an Opportunity.');
        }
        List<Opportunity> opps = [
            SELECT Id, Name, StageName, AccountId, Unit__c, Account_Name__c,
                   Account.Name, Account.Financial_Number__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (opps.isEmpty()) {
            throw auraError('Opportunity not found.');
        }
        Opportunity opp = opps[0];
        if (opp.Unit__c != unitId) {
            throw auraError('Selected Opportunity must belong to this Unit.');
        }
        if (opp.StageName == STAGE_NEW || opp.StageName == STAGE_CANCELLED) {
            throw auraError('Selected Opportunity must not be New or Cancelled.');
        }
        if (opp.AccountId == null) {
            throw auraError('Selected Opportunity has no Account.');
        }
        return opp;
    }

    private static String buildCurrentSnapshot(Id unitId, Integer invoiceCount, Integer receiptCount) {
        Set<String> names = new Set<String>();
        for (Invoice__c inv : [
            SELECT Customer_Name__c, Account__r.Name
            FROM Invoice__c
            WHERE Unit__c = :unitId
            LIMIT 200
        ]) {
            if (String.isNotBlank(inv.Customer_Name__c)) {
                names.add(inv.Customer_Name__c);
            } else if (inv.Account__r != null && String.isNotBlank(inv.Account__r.Name)) {
                names.add(inv.Account__r.Name);
            }
        }
        for (Receipt__c rcpt : [
            SELECT Customer_Name__c, Account__r.Name
            FROM Receipt__c
            WHERE Unit__c = :unitId
            LIMIT 200
        ]) {
            if (String.isNotBlank(rcpt.Customer_Name__c)) {
                names.add(rcpt.Customer_Name__c);
            } else if (rcpt.Account__r != null && String.isNotBlank(rcpt.Account__r.Name)) {
                names.add(rcpt.Account__r.Name);
            }
        }

        String customers = names.isEmpty() ? 'Unknown' : String.join(new List<String>(names), ', ');
        return truncateField(
            customers + ' (' + invoiceCount + ' invoice(s), ' + receiptCount + ' receipt(s))'
        );
    }

    private static void submitApprovalProcess(Id approvalRequestId, String justification) {
        assertNoPendingApprovalInstance(approvalRequestId);

        List<String> processReferences = new List<String>{
            APPROVAL_PROCESS,
            Approval_Request__c.SObjectType.getDescribe().getName() + '.' + APPROVAL_PROCESS,
            null
        };

        Approval.ProcessResult lastResult;
        Exception lastError;
        for (String processRef : processReferences) {
            try {
                Approval.ProcessSubmitRequest submitRequest = new Approval.ProcessSubmitRequest();
                submitRequest.setObjectId(approvalRequestId);
                submitRequest.setComments(
                    String.isNotBlank(justification)
                        ? justification
                        : 'Invoice/receipt transfer approval request'
                );
                if (String.isNotBlank(processRef)) {
                    submitRequest.setProcessDefinitionNameOrId(processRef);
                }
                lastResult = Approval.process(submitRequest);
                if (lastResult != null && lastResult.isSuccess()) {
                    setPendingStatusAfterSubmit(approvalRequestId);
                    // Approval_Request__c is Private OWD; assigned approvers do not always
                    // receive platform approval sharing. Without Edit access they hit the
                    // misleading "Another user recalled or responded to this request" error.
                    shareWithCurrentApprovers(approvalRequestId);
                    return;
                }
            } catch (Exception e) {
                lastError = e;
                lastResult = null;
            }
        }

        String detail = lastError != null
            ? getExceptionMessage(lastError)
            : (lastResult == null
                ? 'Unknown approval submit failure.'
                : String.valueOf(lastResult.getErrors()));
        throw auraError(detail);
    }

    private static void setPendingStatusAfterSubmit(Id approvalRequestId) {
        try {
            update new Approval_Request__c(
                Id = approvalRequestId,
                Request_Type__c = REQUEST_TYPE,
                Status__c = 'Pending'
            );
        } catch (DmlException e) {
            if (!hasPendingApprovalProcess(approvalRequestId)) {
                throw auraError(formatDmlException(e));
            }
        }
    }

    @TestVisible
    private static void shareWithCurrentApprovers(Id approvalRequestId) {
        if (approvalRequestId == null) {
            return;
        }

        Set<Id> actorIds = new Set<Id>();
        for (ProcessInstanceWorkitem wi : [
            SELECT ActorId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :approvalRequestId
              AND ProcessInstance.Status = 'Pending'
        ]) {
            if (wi.ActorId != null && String.valueOf(wi.ActorId).startsWith('005')) {
                actorIds.add(wi.ActorId);
            }
        }
        if (actorIds.isEmpty()) {
            return;
        }

        Set<Id> alreadyShared = new Set<Id>();
        for (Approval_Request__Share existing : [
            SELECT UserOrGroupId
            FROM Approval_Request__Share
            WHERE ParentId = :approvalRequestId
              AND UserOrGroupId IN :actorIds
        ]) {
            alreadyShared.add(existing.UserOrGroupId);
        }

        List<Approval_Request__Share> sharesToInsert = new List<Approval_Request__Share>();
        for (Id actorId : actorIds) {
            if (alreadyShared.contains(actorId) || actorId == UserInfo.getUserId()) {
                continue;
            }
            sharesToInsert.add(new Approval_Request__Share(
                ParentId = approvalRequestId,
                UserOrGroupId = actorId,
                AccessLevel = 'Edit',
                RowCause = Schema.Approval_Request__Share.RowCause.Manual
            ));
        }
        if (!sharesToInsert.isEmpty()) {
            Database.insert(sharesToInsert, false);
        }
    }

    private static Approval_Request__c findOpenRequestForUnit(Id unitId) {
        if (unitId == null) {
            return null;
        }
        String unitIdValue = String.valueOf(unitId);
        List<Approval_Request__c> requests = [
            SELECT Id, Name, Status__c, Justification__c, Requested_Opportunity__c,
                   Requested_Opportunity__r.Name, Requested_Opportunity__r.Account_Name__c,
                   CreatedDate
            FROM Approval_Request__c
            WHERE Request_Type__c = :REQUEST_TYPE
              AND Status__c IN ('Draft', 'Pending')
              AND (Unit__c = :unitId OR Related_Record_Id__c = :unitIdValue)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return requests.isEmpty() ? null : requests[0];
    }

    private static String resolveEffectiveStatus(Approval_Request__c request) {
        if (request == null) {
            return null;
        }
        if (hasPendingApprovalProcess(request.Id)) {
            return 'Pending';
        }
        return request.Status__c;
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

    private static void assertNoPendingApprovalInstance(Id approvalRequestId) {
        if (hasPendingApprovalProcess(approvalRequestId)) {
            throw auraError(
                'This request is already in an approval process. Recall it before trying again.'
            );
        }
    }

    private static void validateUnitAccess(Id unitId) {
        if (unitId == null) {
            throw auraError('Unit is required.');
        }
        if ([SELECT COUNT() FROM Unit__c WHERE Id = :unitId] == 0) {
            throw auraError('Unit not found.');
        }
    }

    private static void validateJustification(String justification) {
        if (String.isBlank(justification) || justification.trim().length() < 10) {
            throw auraError('Justification is required and must be at least 10 characters.');
        }
    }

    private static String truncateField(String value) {
        if (String.isBlank(value)) {
            return value;
        }
        return value.length() > HEADER_FIELD_MAX_LENGTH
            ? value.substring(0, HEADER_FIELD_MAX_LENGTH)
            : value;
    }

    private static String nullToDash(String value) {
        return String.isBlank(value) ? '-' : value;
    }

    private static AuraHandledException auraError(String message) {
        return new AuraHandledException(message);
    }

    private static String getExceptionMessage(Exception e) {
        if (e == null) {
            return 'Unknown error';
        }
        return String.isNotBlank(e.getMessage()) ? e.getMessage() : e.getTypeName();
    }

    private static String formatDmlException(DmlException e) {
        if (e == null || e.getNumDml() == 0) {
            return getExceptionMessage(e);
        }
        return e.getDmlMessage(0);
    }
}
