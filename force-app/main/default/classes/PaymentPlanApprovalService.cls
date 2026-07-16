public with sharing class PaymentPlanApprovalService {
    public static final String REQUEST_TYPE_PAYMENT_PLAN = 'Payment Plan Change';
    public static final String PAYMENT_PLAN_APPROVAL_PROCESS = 'Payment_Plan_Change';
    private static final String PAYMENT_PLAN_FIELD_TO_UPDATE = 'Cash_Flow__c';
    private static final Integer HEADER_FIELD_MAX_LENGTH = 255;
    private static final Set<String> EXCLUDED_MILESTONES = new Set<String>{
        'Oqood', 'DLD Fee', 'Registration Fee', 'Purchase Taxes'
    };
    private static final String PAYMENT_PLAN_APPROVER_PROFILE_NAME = 'Sales Director MIRA';
    private static final Integer SOQL_IN_CHUNK_SIZE = 200;
    private static final Integer DML_CHUNK_SIZE = 200;
    private static final Integer MAX_UNIT_PAYMENT_PLAN_QUERY_ROWS = 5000;

    public class LineInput {
        @AuraEnabled public String clientKey;
        @AuraEnabled public Id cashFlowId;
        @AuraEnabled public String action;
        @AuraEnabled public String milestoneName;
        @AuraEnabled public Date installmentDate;
        @AuraEnabled public Decimal percent;
        @AuraEnabled public Decimal constantAmount;
        @AuraEnabled public Id cashFlowSumId;
        @AuraEnabled public Boolean isAdditionalPayment;
        @AuraEnabled public Integer sortOrder;
    }

    public class PaymentPlanLinesResultDTO {
        @AuraEnabled public List<PaymentPlanLineDTO> lines;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Boolean truncated;
    }

    public class PaymentPlanLineDTO {
        @AuraEnabled public Id cashFlowId;
        @AuraEnabled public String milestoneName;
        @AuraEnabled public String installmentMilestone;
        @AuraEnabled public Date installmentDate;
        @AuraEnabled public Decimal percent;
        @AuraEnabled public Decimal constantAmount;
        @AuraEnabled public Id cashFlowSumId;
        @AuraEnabled public String cashFlowSumName;
        @AuraEnabled public Boolean isAdditionalPayment;
        @AuraEnabled public Decimal receivedAmount;
        @AuraEnabled public Boolean isExcludedFee;
    }

    public class CashFlowSumOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }

    public class ApproverOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }

    public class UnitInfoDTO {
        @AuraEnabled public String title;
        @AuraEnabled public String projectName;
        @AuraEnabled public String building;
        @AuraEnabled public String accountName;
    }

    public class ComparisonLineDTO {
        @AuraEnabled public String cashFlowId;
        @AuraEnabled public String milestoneName;
        @AuraEnabled public String installmentDate;
        @AuraEnabled public Decimal percent;
        @AuraEnabled public Decimal constantAmount;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Boolean hasPayments;
        @AuraEnabled public String changeType; // unchanged | updated | deleted | added
    }

    public class PaymentPlanComparisonDTO {
        @AuraEnabled public UnitInfoDTO unitInfo;
        @AuraEnabled public List<ComparisonLineDTO> currentLines;
        @AuraEnabled public List<ComparisonLineDTO> proposedLines;
        @AuraEnabled public String status;
        @AuraEnabled public String justification;
        @AuraEnabled public String requesterName;
        @AuraEnabled public String requestName;
        @AuraEnabled public Boolean notApplicable;
        @AuraEnabled public String notApplicableReason;
        @AuraEnabled public Integer totalInstallmentCount;
        @AuraEnabled public Boolean changesOnly;
    }

    public static List<PaymentPlanLineDTO> getUnitPaymentPlanLines(Id unitId) {
        return getUnitPaymentPlanLinesResult(unitId).lines;
    }

    public static PaymentPlanLinesResultDTO getUnitPaymentPlanLinesResult(Id unitId) {
        validateUnitAccess(unitId);

        Integer totalCount = [
            SELECT COUNT()
            FROM Cash_Flow__c
            WHERE Unit__c = :unitId
            AND Name NOT IN :EXCLUDED_MILESTONES
        ];

        List<Cash_Flow__c> cashFlows = [
            SELECT Id, Name, Installment_Milestone__c, Date__c, Percent__c, Constant__c,
                   Cash_Flow_Sum__c, Cash_Flow_Sum__r.Name,
                   Is_Additional_Payment__c, Received_Amount__c
            FROM Cash_Flow__c
            WHERE Unit__c = :unitId
            AND Name NOT IN :EXCLUDED_MILESTONES
            ORDER BY Date__c ASC NULLS LAST, Name ASC
            LIMIT :MAX_UNIT_PAYMENT_PLAN_QUERY_ROWS
        ];

        List<PaymentPlanLineDTO> lines = new List<PaymentPlanLineDTO>();
        for (Cash_Flow__c cf : cashFlows) {
            PaymentPlanLineDTO dto = new PaymentPlanLineDTO();
            dto.cashFlowId = cf.Id;
            dto.milestoneName = cf.Name;
            dto.installmentMilestone = cf.Installment_Milestone__c;
            dto.installmentDate = cf.Date__c;
            dto.percent = cf.Percent__c;
            dto.constantAmount = cf.Constant__c;
            dto.cashFlowSumId = cf.Cash_Flow_Sum__c;
            dto.cashFlowSumName = cf.Cash_Flow_Sum__r == null ? null : cf.Cash_Flow_Sum__r.Name;
            dto.isAdditionalPayment = cf.Is_Additional_Payment__c;
            dto.receivedAmount = cf.Received_Amount__c;
            dto.isExcludedFee = EXCLUDED_MILESTONES.contains(cf.Name);
            lines.add(dto);
        }

        PaymentPlanLinesResultDTO result = new PaymentPlanLinesResultDTO();
        result.lines = lines;
        result.totalCount = totalCount;
        result.truncated = totalCount > lines.size();
        return result;
    }

    public static List<CashFlowSumOptionDTO> getUnitCashFlowSums(Id unitId) {
        validateUnitAccess(unitId);

        List<CashFlowSumOptionDTO> options = new List<CashFlowSumOptionDTO>();
        for (Cash_Flow_Sum__c sum : [
            SELECT Id, Name
            FROM Cash_Flow_Sum__c
            WHERE Unit__c = :unitId
            ORDER BY Name ASC
        ]) {
            CashFlowSumOptionDTO option = new CashFlowSumOptionDTO();
            option.id = sum.Id;
            option.name = sum.Name;
            options.add(option);
        }
        return options;
    }

    public static Id createUnitCashFlowSum(Id unitId, String yearName) {
        validateUnitAccess(unitId);

        String normalizedYear = yearName == null ? '' : yearName.trim();
        if (String.isBlank(normalizedYear)) {
            throw new AuraHandledException('Cash Flow Sum year is required.');
        }
        if (!Pattern.matches('^\\d{4}$', normalizedYear)) {
            throw new AuraHandledException('Cash Flow Sum must be a four-digit year (for example 2026).');
        }

        List<Cash_Flow_Sum__c> existing = [
            SELECT Id
            FROM Cash_Flow_Sum__c
            WHERE Unit__c = :unitId
            AND Name = :normalizedYear
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }

        Cash_Flow_Sum__c sum = new Cash_Flow_Sum__c(
            Unit__c = unitId,
            Name = normalizedYear
        );
        try {
            insert sum;
        } catch (DmlException e) {
            throw new AuraHandledException(formatDmlException(e));
        }
        return sum.Id;
    }

    public static Id createDraftRequest(Id unitId, String justification) {
        validateUnitAccess(unitId);

        Approval_Request__c existingDraft = findPaymentPlanRequestForUnit(
            unitId,
            new Set<String>{ 'Draft' }
        );
        if (existingDraft != null) {
            existingDraft.Justification__c = justification;
            update existingDraft;
            return existingDraft.Id;
        }

        Approval_Request__c inFlightRequest = findPaymentPlanRequestForUnit(
            unitId,
            new Set<String>{ 'Draft', 'Pending', 'Approved' }
        );
        if (inFlightRequest != null && isPaymentPlanRequestBlockingNewDraft(inFlightRequest)) {
            throw buildOpenRequestException(inFlightRequest);
        }

        // Status says Pending but no approval is actually in flight (e.g. the request
        // was rejected and the rejection field update never ran). Sync the stored
        // status with the real outcome instead of blocking the user forever.
        if (inFlightRequest != null
            && inFlightRequest.Status__c == 'Pending'
            && !hasPendingApprovalProcess(inFlightRequest.Id)) {
            String outcome = resolveLatestPaymentPlanProcessOutcome(inFlightRequest.Id);
            String reconciledStatus = (outcome == 'Rejected' || outcome == 'Approved')
                ? outcome
                : 'Draft';
            try {
                if (reconciledStatus == 'Draft') {
                    inFlightRequest.Status__c = 'Draft';
                    inFlightRequest.Justification__c = justification;
                    update inFlightRequest;
                    return inFlightRequest.Id;
                }
                update new Approval_Request__c(
                    Id = inFlightRequest.Id,
                    Status__c = reconciledStatus
                );
            } catch (Exception e) {
                // Record may still be locked from the finished approval. The stale
                // status must not block new requests, so swallow and continue.
                System.debug(LoggingLevel.WARN,
                    'Could not reconcile stale payment plan request ' +
                    inFlightRequest.Id + ': ' + e.getMessage());
            }
        }

        Unit__c unit = [
            SELECT Id, Title__c, Status__c
            FROM Unit__c
            WHERE Id = :unitId
            LIMIT 1
        ];
        validateUnitEligible(unit);

        Approval_Request__c request = new Approval_Request__c(
            Request_Type__c = REQUEST_TYPE_PAYMENT_PLAN,
            Unit__c = unitId,
            Justification__c = justification,
            Status__c = 'Draft',
            Requester__c = UserInfo.getUserId()
        );
        populatePaymentPlanHeaderFields(request, unit, null);
        try {
            insert request;
        } catch (DmlException e) {
            throw new AuraHandledException(formatDmlException(e));
        }
        return request.Id;
    }

    public static List<ApproverOptionDTO> getPaymentPlanApproverOptions() {
        List<ApproverOptionDTO> options = new List<ApproverOptionDTO>();

        for (User approver : [
            SELECT Id, Name
            FROM User
            WHERE IsActive = TRUE
            AND Profile.Name = :PAYMENT_PLAN_APPROVER_PROFILE_NAME
            ORDER BY Name ASC
        ]) {
            ApproverOptionDTO option = new ApproverOptionDTO();
            option.id = approver.Id;
            option.name = approver.Name;
            options.add(option);
        }
        return options;
    }

    public static Id submitPaymentPlanApproval(
        Id unitId,
        String justification,
        String linesJson,
        Id existingRequestId,
        Id approverUserId
    ) {
        try {
            List<LineInput> lineInputs = parseLineInputs(linesJson);
            Id approvalRequestId = existingRequestId;

            if (approvalRequestId == null) {
                approvalRequestId = createDraftRequest(unitId, justification);
            } else {
                Approval_Request__c existing = getEditablePaymentPlanRequest(approvalRequestId);
                existing.Justification__c = justification;
                update existing;
            }

            saveApprovalLines(approvalRequestId, lineInputs);
            submitForApproval(approvalRequestId, approverUserId);
            return approvalRequestId;
        } catch (AuraHandledException e) {
            throw e;
        } catch (DmlException e) {
            throw new AuraHandledException(formatDmlException(e));
        } catch (Exception e) {
            throw new AuraHandledException(
                'Payment plan submit failed: ' + getExceptionMessage(e)
            );
        }
    }

    public static List<LineInput> parseLineInputs(String linesJson) {
        if (String.isBlank(linesJson)) {
            throw new AuraHandledException('Payment plan lines are required.');
        }

        List<LineInput> lineInputs = new List<LineInput>();
        List<Object> rawLines;
        try {
            rawLines = (List<Object>) JSON.deserializeUntyped(linesJson);
        } catch (Exception e) {
            throw new AuraHandledException(
                'Invalid payment plan line data: ' + getExceptionMessage(e)
            );
        }

        if (rawLines == null || rawLines.isEmpty()) {
            throw new AuraHandledException('At least one payment plan change is required.');
        }

        for (Object rawLine : rawLines) {
            Map<String, Object> row = (Map<String, Object>) rawLine;
            LineInput input = new LineInput();
            input.clientKey = (String) row.get('clientKey');
            input.action = (String) row.get('action');
            input.milestoneName = (String) row.get('milestoneName');
            input.installmentDate = parseDateValue(row.get('installmentDate'));
            input.percent = toDecimal(row.get('percent'));
            input.constantAmount = toDecimal(row.get('constantAmount'));
            input.isAdditionalPayment = toBoolean(row.get('isAdditionalPayment'));
            input.sortOrder = toInteger(row.get('sortOrder'));

            Object cashFlowIdValue = row.get('cashFlowId');
            if (cashFlowIdValue != null && String.isNotBlank(String.valueOf(cashFlowIdValue))) {
                input.cashFlowId = (Id) String.valueOf(cashFlowIdValue);
            }

            Object cashFlowSumIdValue = row.get('cashFlowSumId');
            if (cashFlowSumIdValue != null && String.isNotBlank(String.valueOf(cashFlowSumIdValue))) {
                input.cashFlowSumId = (Id) String.valueOf(cashFlowSumIdValue);
            }

            lineInputs.add(input);
        }

        return lineInputs;
    }

    public static void saveApprovalLines(Id approvalRequestId, List<LineInput> lineInputs) {
        Approval_Request__c request = getEditablePaymentPlanRequest(approvalRequestId);
        validateLineInputs(request.Unit__c, lineInputs);

        delete [
            SELECT Id
            FROM Payment_Plan_Approval_Line__c
            WHERE Approval_Request__c = :approvalRequestId
        ];

        List<Payment_Plan_Approval_Line__c> linesToInsert = new List<Payment_Plan_Approval_Line__c>();
        Integer sortOrder = 1;
        for (LineInput input : lineInputs) {
            if (String.isBlank(input.action) || input.action == 'Unchanged') {
                continue;
            }
            linesToInsert.add(buildApprovalLine(approvalRequestId, input, sortOrder++));
        }

        if (linesToInsert.isEmpty()) {
            throw new AuraHandledException('At least one payment plan change is required.');
        }

        try {
            executeInsertInChunks(linesToInsert);
        } catch (DmlException e) {
            throw new AuraHandledException(formatDmlException(e));
        }

        Unit__c unit = [
            SELECT Id, Title__c
            FROM Unit__c
            WHERE Id = :request.Unit__c
            LIMIT 1
        ];
        populatePaymentPlanHeaderFields(request, unit, lineInputs);
        update request;
    }

    public static void submitForApproval(Id approvalRequestId) {
        submitForApproval(approvalRequestId, null);
    }

    public static void submitForApproval(Id approvalRequestId, Id approverUserId) {
        Approval_Request__c request = getEditablePaymentPlanRequest(approvalRequestId);

        Integer lineCount = [
            SELECT COUNT()
            FROM Payment_Plan_Approval_Line__c
            WHERE Approval_Request__c = :approvalRequestId
        ];
        if (lineCount == 0) {
            throw new AuraHandledException('Save payment plan changes before submitting for approval.');
        }

        List<Payment_Plan_Approval_Line__c> savedLines = [
            SELECT Action__c
            FROM Payment_Plan_Approval_Line__c
            WHERE Approval_Request__c = :approvalRequestId
        ];
        Unit__c unit = [
            SELECT Id, Title__c
            FROM Unit__c
            WHERE Id = :request.Unit__c
            LIMIT 1
        ];
        populatePaymentPlanHeaderFields(request, unit, convertLinesToInputs(savedLines));
        ensurePaymentPlanRequestReadyForSubmit(request, approverUserId);
        update request;

        Approval_Request__c submitRecord = [
            SELECT Id, Request_Type__c, Status__c
            FROM Approval_Request__c
            WHERE Id = :approvalRequestId
            LIMIT 1
        ];
        validatePaymentPlanSubmitRecord(submitRecord);
        assertNoPendingApprovalInstance(approvalRequestId);

        try {
            Approval.ProcessResult result = submitApprovalProcess(
                approvalRequestId,
                request.Justification__c,
                approverUserId
            );
            if (!result.isSuccess()) {
                throw new AuraHandledException(
                    formatApprovalErrors(result, submitRecord)
                );
            }

            update new Approval_Request__c(
                Id = approvalRequestId,
                Request_Type__c = REQUEST_TYPE_PAYMENT_PLAN,
                Status__c = 'Pending'
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to submit approval request: ' + getExceptionMessage(e)
            );
        }
    }

    private static Approval.ProcessResult submitApprovalProcess(
        Id approvalRequestId,
        String justification,
        Id approverUserId
    ) {
        List<String> processReferences = buildProcessReferenceAttempts();
        List<String> statusesToTry = new List<String>{ 'Draft', 'Pending' };
        Approval.ProcessResult lastResult;

        for (String statusValue : statusesToTry) {
            update new Approval_Request__c(
                Id = approvalRequestId,
                Request_Type__c = REQUEST_TYPE_PAYMENT_PLAN,
                Status__c = statusValue
            );

            for (String processReference : processReferences) {
                try {
                    lastResult = Approval.process(
                        buildSubmitRequest(
                            approvalRequestId,
                            justification,
                            approverUserId,
                            processReference
                        )
                    );
                    if (lastResult != null && lastResult.isSuccess()) {
                        return lastResult;
                    }
                } catch (Exception attemptEx) {
                    // This process reference didn't match; continue trying the next one.
                    System.debug(LoggingLevel.WARN,
                        'Approval attempt failed for processReference="' + processReference +
                        '", status="' + statusValue + '": ' + attemptEx.getMessage());
                }
            }
        }

        update new Approval_Request__c(
            Id = approvalRequestId,
            Request_Type__c = REQUEST_TYPE_PAYMENT_PLAN,
            Status__c = 'Draft'
        );
        return lastResult;
    }

    private static List<String> buildProcessReferenceAttempts() {
        List<String> processReferences = new List<String>();

        Id processId = getActivePaymentPlanProcessId();
        if (processId != null) {
            processReferences.add(String.valueOf(processId));
        }

        processReferences.add(PAYMENT_PLAN_APPROVAL_PROCESS);
        processReferences.add(
            Approval_Request__c.SObjectType.getDescribe().getName() +
                '.' +
                PAYMENT_PLAN_APPROVAL_PROCESS
        );
        processReferences.add(null);
        return processReferences;
    }

    private static void assertNoPendingApprovalInstance(Id approvalRequestId) {
        List<ProcessInstance> pendingInstances = [
            SELECT Id
            FROM ProcessInstance
            WHERE TargetObjectId = :approvalRequestId
            AND Status = 'Pending'
            LIMIT 1
        ];
        if (!pendingInstances.isEmpty()) {
            throw new AuraHandledException(
                'This approval request is already in an approval process. Recall the existing submission before trying again.'
            );
        }
    }

    public static void applyApprovedChanges(Id approvalRequestId) {
        Approval_Request__c request = [
            SELECT Id, Status__c, Unit__c, Request_Type__c
            FROM Approval_Request__c
            WHERE Id = :approvalRequestId
            LIMIT 1
        ];

        if (request.Request_Type__c != REQUEST_TYPE_PAYMENT_PLAN) {
            return;
        }
        if (request.Status__c == 'Applied') {
            return;
        }
        if (request.Status__c != 'Approved') {
            return;
        }
        if (request.Unit__c == null) {
            throw new PaymentPlanApprovalException('Approval request is missing the related unit.');
        }

        validateUnitEligible([
            SELECT Id, Status__c
            FROM Unit__c
            WHERE Id = :request.Unit__c
            LIMIT 1
        ]);

        List<Payment_Plan_Approval_Line__c> lines = [
            SELECT Id, Action__c, Cash_Flow__c, Cash_Flow_Sum__c, Milestone_Name__c,
                   Date__c, Percent__c, Constant__c, Is_Additional_Payment__c
            FROM Payment_Plan_Approval_Line__c
            WHERE Approval_Request__c = :approvalRequestId
            ORDER BY Sort_Order__c ASC NULLS LAST
        ];
        if (lines.isEmpty()) {
            throw new PaymentPlanApprovalException('No payment plan changes found on the approval request.');
        }

        Set<Id> cashFlowIds = new Set<Id>();
        for (Payment_Plan_Approval_Line__c line : lines) {
            if (line.Cash_Flow__c != null) {
                cashFlowIds.add(line.Cash_Flow__c);
            }
        }

        Map<Id, Cash_Flow__c> existingCashFlows = new Map<Id, Cash_Flow__c>();
        for (Cash_Flow__c cashFlow : queryCashFlowsByIds(cashFlowIds)) {
            existingCashFlows.put(cashFlow.Id, cashFlow);
        }

        List<Cash_Flow__c> toDelete = new List<Cash_Flow__c>();
        List<Cash_Flow__c> toUpdate = new List<Cash_Flow__c>();
        List<Cash_Flow__c> toInsert = new List<Cash_Flow__c>();
        Set<Id> cashFlowSumIdsToValidate = new Set<Id>();

        for (Payment_Plan_Approval_Line__c line : lines) {
            if (line.Action__c == 'Delete') {
                if (line.Cash_Flow__c == null) {
                    // Cash flow was deleted externally (SetNull constraint); desired state already achieved.
                    continue;
                }
                Cash_Flow__c existing = existingCashFlows.get(line.Cash_Flow__c);
                if (existing == null) {
                    // Record no longer exists in the database — already deleted, skip.
                    continue;
                }
                validateCashFlowBelongsToUnit(existing, request.Unit__c);
                validateNoReceivedPayments(existing);
                toDelete.add(existing);
            } else if (line.Action__c == 'Update') {
                if (line.Cash_Flow__c == null) {
                    throw new PaymentPlanApprovalException(
                        'An installment scheduled for update (milestone: ' +
                        line.Milestone_Name__c +
                        ') was deleted after this request was created. Recall this request and raise a new one.'
                    );
                }
                Cash_Flow__c existing = existingCashFlows.get(line.Cash_Flow__c);
                if (existing == null) {
                    throw new PaymentPlanApprovalException(
                        'Installment "' + line.Milestone_Name__c +
                        '" no longer exists. Recall this request and raise a new one.'
                    );
                }
                validateCashFlowBelongsToUnit(existing, request.Unit__c);
                validateNoReceivedPayments(existing);
                Id cashFlowSumId = line.Cash_Flow_Sum__c != null
                    ? line.Cash_Flow_Sum__c
                    : existing.Cash_Flow_Sum__c;
                if (cashFlowSumId != null) {
                    cashFlowSumIdsToValidate.add(cashFlowSumId);
                }
                toUpdate.add(buildCashFlowFromLine(line, request.Unit__c, existing.Id, cashFlowSumId));
            } else if (line.Action__c == 'Insert') {
                if (line.Cash_Flow_Sum__c != null) {
                    cashFlowSumIdsToValidate.add(line.Cash_Flow_Sum__c);
                }
                toInsert.add(buildCashFlowFromLine(line, request.Unit__c, null, line.Cash_Flow_Sum__c));
            }
        }

        validateCashFlowSumsBelongToUnit(cashFlowSumIdsToValidate, request.Unit__c);

        if (!toDelete.isEmpty()) {
            executeDeleteInChunks(toDelete);
        }
        if (!toUpdate.isEmpty()) {
            executeUpdateInChunks(toUpdate);
        }
        if (!toInsert.isEmpty()) {
            resolveCashFlowSumsForInserts(request.Unit__c, toInsert);
            executeInsertInChunks(toInsert);
        }

        request.Status__c = 'Applied';
        update request;
    }

    private static Payment_Plan_Approval_Line__c buildApprovalLine(
        Id approvalRequestId,
        LineInput input,
        Integer sortOrder
    ) {
        return new Payment_Plan_Approval_Line__c(
            Approval_Request__c = approvalRequestId,
            Action__c = input.action,
            Cash_Flow__c = input.cashFlowId,
            Cash_Flow_Sum__c = input.cashFlowSumId,
            Milestone_Name__c = input.milestoneName,
            Date__c = input.installmentDate,
            Percent__c = input.percent,
            Constant__c = input.constantAmount,
            Is_Additional_Payment__c = input.isAdditionalPayment == true,
            Sort_Order__c = sortOrder
        );
    }

    private static Cash_Flow__c buildCashFlowFromLine(
        Payment_Plan_Approval_Line__c line,
        Id unitId,
        Id cashFlowId,
        Id cashFlowSumId
    ) {
        Cash_Flow__c cf = new Cash_Flow__c(
            Id = cashFlowId,
            Unit__c = unitId,
            Name = line.Milestone_Name__c,
            Date__c = line.Date__c,
            Percent__c = line.Percent__c,
            Constant__c = line.Constant__c,
            Is_Additional_Payment__c = line.Is_Additional_Payment__c,
            Cash_Flow_Sum__c = cashFlowSumId
        );
        return cf;
    }

    private static void resolveCashFlowSumsForInserts(Id unitId, List<Cash_Flow__c> inserts) {
        Set<String> yearsNeeded = new Set<String>();
        for (Cash_Flow__c cf : inserts) {
            if (cf.Cash_Flow_Sum__c == null && cf.Date__c != null) {
                yearsNeeded.add(String.valueOf(cf.Date__c.year()));
            }
        }
        if (yearsNeeded.isEmpty()) {
            return;
        }

        Map<String, Id> yearToSumId = new Map<String, Id>();
        for (Cash_Flow_Sum__c sum : [
            SELECT Id, Name
            FROM Cash_Flow_Sum__c
            WHERE Unit__c = :unitId
            AND Name IN :yearsNeeded
        ]) {
            yearToSumId.put(sum.Name, sum.Id);
        }

        List<Cash_Flow_Sum__c> sumsToCreate = new List<Cash_Flow_Sum__c>();
        for (String year : yearsNeeded) {
            if (!yearToSumId.containsKey(year)) {
                sumsToCreate.add(new Cash_Flow_Sum__c(Unit__c = unitId, Name = year));
            }
        }
        if (!sumsToCreate.isEmpty()) {
            insert sumsToCreate;
            for (Cash_Flow_Sum__c sum : sumsToCreate) {
                yearToSumId.put(sum.Name, sum.Id);
            }
        }

        for (Cash_Flow__c cf : inserts) {
            if (cf.Cash_Flow_Sum__c == null && cf.Date__c != null) {
                cf.Cash_Flow_Sum__c = yearToSumId.get(String.valueOf(cf.Date__c.year()));
            }
        }
    }

    private static Approval.ProcessSubmitRequest buildSubmitRequest(
        Id approvalRequestId,
        String justification,
        Id approverUserId,
        String processDefinitionNameOrId
    ) {
        Approval.ProcessSubmitRequest submitRequest = new Approval.ProcessSubmitRequest();
        submitRequest.setObjectId(approvalRequestId);
        submitRequest.setComments(
            String.isNotBlank(justification)
                ? justification
                : 'Payment plan change approval request'
        );
        if (String.isNotBlank(processDefinitionNameOrId)) {
            submitRequest.setProcessDefinitionNameOrId(processDefinitionNameOrId);
        }

        List<Id> nextApproverIds = resolveSubmitApproverIds(approverUserId);
        submitRequest.setNextApproverIds(nextApproverIds);

        return submitRequest;
    }

    private static void ensurePaymentPlanRequestReadyForSubmit(
        Approval_Request__c request,
        Id approverUserId
    ) {
        request.Request_Type__c = REQUEST_TYPE_PAYMENT_PLAN;
        if (
            request.Status__c == null ||
            request.Status__c == 'Rejected' ||
            request.Status__c == 'Approved' ||
            request.Status__c == 'Applied'
        ) {
            request.Status__c = 'Draft';
        }
        if (request.Status__c == 'Pending' && !hasPendingApprovalProcess(request.Id)) {
            // Stale Pending (approval already finished or was recalled) — allow resubmission.
            request.Status__c = 'Draft';
        }
        request.Approver__c = approverUserId;
    }

    private static void validatePaymentPlanSubmitRecord(Approval_Request__c request) {
        if (request.Request_Type__c != REQUEST_TYPE_PAYMENT_PLAN) {
            throw new AuraHandledException(
                'Request type must be "' +
                    REQUEST_TYPE_PAYMENT_PLAN +
                    '". Current value: ' +
                    request.Request_Type__c
            );
        }

        if (request.Status__c == 'Pending') {
            throw new AuraHandledException(
                'This request is already pending approval. Recall it before submitting again.'
            );
        }

        if (request.Status__c == 'Approved' || request.Status__c == 'Applied') {
            throw new AuraHandledException(
                'This request has already been approved and cannot be submitted again.'
            );
        }

        if (request.Status__c != 'Draft') {
            throw new AuraHandledException(
                'Only Draft requests can be submitted. Current status: ' + request.Status__c
            );
        }
    }

    private static String formatApprovalErrors(
        Approval.ProcessResult result,
        Approval_Request__c request
    ) {
        String requestType = request == null ? 'unknown' : request.Request_Type__c;
        String requestStatus = request == null ? 'unknown' : request.Status__c;
        String errorMessage =
            'Unable to submit approval request using process "' +
            PAYMENT_PLAN_APPROVAL_PROCESS +
            '". Record values: Request Type=' +
            requestType +
            ', Status=' +
            requestStatus +
            '. Redeploy the approval process metadata and confirm workflow actions Payment_Plan_Pending_Status, Payment_Plan_Approved_Status, and Payment_Plan_Rejected_Status exist.';
        if (result == null || result.getErrors() == null) {
            return errorMessage;
        }
        for (Database.Error err : result.getErrors()) {
            errorMessage += ' ' + err.getMessage();
        }
        return errorMessage;
    }

    private static List<Id> resolveSubmitApproverIds(Id approverUserId) {
        if (approverUserId == null) {
            throw new AuraHandledException(
                'Select an approver before submitting for approval.'
            );
        }

        List<User> approvers = [
            SELECT Id
            FROM User
            WHERE Id = :approverUserId
            AND IsActive = TRUE
            LIMIT 1
        ];
        if (approvers.isEmpty()) {
            throw new AuraHandledException('Selected approver is not active or could not be found.');
        }

        if (!isAllowedPaymentPlanApprover(approverUserId)) {
            throw new AuraHandledException(
                'Selected approver must have the ' + PAYMENT_PLAN_APPROVER_PROFILE_NAME + ' profile.'
            );
        }

        return new List<Id>{ approverUserId };
    }

    private static Boolean isAllowedPaymentPlanApprover(Id approverUserId) {
        for (ApproverOptionDTO option : getPaymentPlanApproverOptions()) {
            if (option.id == approverUserId) {
                return true;
            }
        }
        return false;
    }

    public static void populatePaymentPlanHeaderFields(
        Approval_Request__c request,
        Unit__c unit,
        List<LineInput> lineInputs
    ) {
        if (unit == null || unit.Id == null) {
            throw new AuraHandledException('Unit is required for payment plan approval requests.');
        }

        Integer installmentCount = [
            SELECT COUNT()
            FROM Cash_Flow__c
            WHERE Unit__c = :unit.Id
        ];

        String unitIdValue = String.valueOf(unit.Id);
        String parentObjectApiName = 'Unit__c';

        request.Unit__c = unit.Id;
        setParentReferenceFields(request, parentObjectApiName, unitIdValue);
        if (String.isBlank(request.Related_Record_Id__c)) {
            request.Related_Record_Id__c = unitIdValue;
        }
        if (String.isBlank(request.Related_Object_Type__c)) {
            request.Related_Object_Type__c = parentObjectApiName;
        }
        request.Field_To_Update__c = PAYMENT_PLAN_FIELD_TO_UPDATE;
        request.Current_Value__c = truncateField(
            String.valueOf(unit.Title__c) + ' (' + installmentCount + ' installment(s))'
        );
        request.Requested_Value__c = truncateField(buildChangeSummary(lineInputs));
    }

    private static List<LineInput> convertLinesToInputs(List<Payment_Plan_Approval_Line__c> lines) {
        List<LineInput> inputs = new List<LineInput>();
        for (Payment_Plan_Approval_Line__c line : lines) {
            LineInput input = new LineInput();
            input.action = line.Action__c;
            inputs.add(input);
        }
        return inputs;
    }

    private static String buildChangeSummary(List<LineInput> lineInputs) {
        if (lineInputs == null || lineInputs.isEmpty()) {
            return 'Payment plan changes pending';
        }

        Integer insertCount = 0;
        Integer updateCount = 0;
        Integer deleteCount = 0;

        for (LineInput input : lineInputs) {
            if (input == null || String.isBlank(input.action)) {
                continue;
            }
            if (input.action == 'Insert') {
                insertCount++;
            } else if (input.action == 'Update') {
                updateCount++;
            } else if (input.action == 'Delete') {
                deleteCount++;
            }
        }

        return 'Add: ' + insertCount + ', Update: ' + updateCount + ', Delete: ' + deleteCount;
    }

    private static void setParentReferenceFields(
        Approval_Request__c request,
        String parentObjectApiName,
        String parentRecordId
    ) {
        Map<String, Schema.SObjectField> fieldMap =
            Approval_Request__c.SObjectType.getDescribe().fields.getMap();

        if (fieldMap.containsKey('parent_object__c')) {
            request.put('Parent_Object__c', parentObjectApiName);
        }
        if (fieldMap.containsKey('parent_record_id__c')) {
            request.put('Parent_Record_Id__c', parentRecordId);
        }
        if (fieldMap.containsKey('related_object_type__c')) {
            request.put('Related_Object_Type__c', parentObjectApiName);
        }
        if (fieldMap.containsKey('related_record_id__c')) {
            request.put('Related_Record_Id__c', parentRecordId);
        }
    }

    private static String truncateField(String value) {
        if (String.isBlank(value)) {
            return 'N/A';
        }
        return value.length() > HEADER_FIELD_MAX_LENGTH
            ? value.substring(0, HEADER_FIELD_MAX_LENGTH)
            : value;
    }

    private static Approval_Request__c getEditablePaymentPlanRequest(Id approvalRequestId) {
        Approval_Request__c request = [
            SELECT Id, Status__c, Request_Type__c, Unit__c, Justification__c,
                   Related_Record_Id__c, Related_Object_Type__c, Field_To_Update__c,
                   Current_Value__c, Requested_Value__c
            FROM Approval_Request__c
            WHERE Id = :approvalRequestId
            LIMIT 1
        ];
        if (request.Request_Type__c != REQUEST_TYPE_PAYMENT_PLAN) {
            throw new AuraHandledException('This action is only supported for payment plan approval requests.');
        }
        if (request.Status__c != 'Draft' && request.Status__c != 'Pending') {
            throw new AuraHandledException('Only draft or pending requests can be edited.');
        }
        return request;
    }

    private static void validateLineInputs(Id unitId, List<LineInput> lineInputs) {
        if (lineInputs == null || lineInputs.isEmpty()) {
            throw new AuraHandledException('Payment plan lines are required.');
        }

        Boolean hasChange = false;
        Set<Id> cashFlowSumIdsToValidate = new Set<Id>();
        for (LineInput input : lineInputs) {
            if (input == null || String.isBlank(input.action) || input.action == 'Unchanged') {
                continue;
            }
            hasChange = true;
            if (input.action == 'Insert' || input.action == 'Update') {
                if (String.isBlank(input.milestoneName)) {
                    throw new AuraHandledException('Milestone name is required for new or updated installments.');
                }
                if (input.installmentDate == null) {
                    throw new AuraHandledException('Installment date is required for new or updated installments.');
                }
            }
            if (input.action == 'Insert' && input.cashFlowSumId == null) {
                throw new AuraHandledException('Cash Flow Sum is required for new installments.');
            }
            if (input.cashFlowSumId != null) {
                cashFlowSumIdsToValidate.add(input.cashFlowSumId);
            }
            if ((input.action == 'Update' || input.action == 'Delete') && input.cashFlowId == null) {
                throw new AuraHandledException('Existing cash flow records must be selected for update or delete actions.');
            }
        }

        validateCashFlowSumsBelongToUnit(cashFlowSumIdsToValidate, unitId);

        if (!hasChange) {
            throw new AuraHandledException('At least one payment plan change is required.');
        }
    }

    private static void validateCashFlowSumBelongsToUnit(Id cashFlowSumId, Id unitId) {
        validateCashFlowSumsBelongToUnit(
            cashFlowSumId == null ? new Set<Id>() : new Set<Id>{ cashFlowSumId },
            unitId
        );
    }

    private static void validateCashFlowSumsBelongToUnit(Set<Id> cashFlowSumIds, Id unitId) {
        if (cashFlowSumIds == null || cashFlowSumIds.isEmpty() || unitId == null) {
            return;
        }

        Set<Id> validSumIds = new Set<Id>();
        for (List<Id> chunk : chunkIds(cashFlowSumIds)) {
            for (Cash_Flow_Sum__c sum : [
                SELECT Id
                FROM Cash_Flow_Sum__c
                WHERE Id IN :chunk
                AND Unit__c = :unitId
            ]) {
                validSumIds.add(sum.Id);
            }
        }

        for (Id cashFlowSumId : cashFlowSumIds) {
            if (!validSumIds.contains(cashFlowSumId)) {
                throw new AuraHandledException('Selected Cash Flow Sum does not belong to this unit.');
            }
        }
    }

    private static void validateUnitAccess(Id unitId) {
        if (unitId == null) {
            throw new AuraHandledException('Unit is required.');
        }
        List<Unit__c> units = [SELECT Id FROM Unit__c WHERE Id = :unitId LIMIT 1];
        if (units.isEmpty()) {
            throw new AuraHandledException('Unit not found.');
        }
    }

    public static OpenPaymentPlanRequestDTO getOpenPaymentPlanRequestForUnit(Id unitId) {
        validateUnitAccess(unitId);

        Approval_Request__c request = findPaymentPlanRequestForUnit(
            unitId,
            new Set<String>{ 'Draft', 'Pending', 'Approved', 'Rejected' }
        );
        if (request == null) {
            return null;
        }

        OpenPaymentPlanRequestDTO dto = new OpenPaymentPlanRequestDTO();
        dto.approvalRequestId = request.Id;
        dto.name = request.Name;
        dto.justification = request.Justification__c;
        dto.inApprovalProcess = hasPendingApprovalProcess(request.Id);
        dto.status = resolveEffectivePaymentPlanStatus(request.Id, request.Status__c, dto.inApprovalProcess);
        dto.statusLabel = resolvePaymentPlanStatusLabel(dto.status, dto.inApprovalProcess);
        dto.approvalStageLabel = dto.inApprovalProcess
            ? resolvePaymentPlanApprovalStageLabel(request.Id)
            : null;
        return dto;
    }

    private static Boolean isPaymentPlanRequestBlockingNewDraft(Approval_Request__c request) {
        if (request == null) {
            return false;
        }
        if (request.Status__c == 'Approved') {
            return true;
        }
        if (request.Status__c == 'Pending') {
            // Only block while an approval is actually in flight. A stale Pending
            // (e.g. rejected without the field update running) must not block.
            return hasPendingApprovalProcess(request.Id);
        }
        if (request.Status__c == 'Draft' && hasPendingApprovalProcess(request.Id)) {
            return true;
        }
        return false;
    }

    private static String resolveEffectivePaymentPlanStatus(
        Id requestId,
        String storedStatus,
        Boolean inApprovalProcess
    ) {
        if (String.isBlank(storedStatus)) {
            return inApprovalProcess ? 'Pending' : 'Draft';
        }
        if (storedStatus == 'Draft' && inApprovalProcess) {
            return 'Pending';
        }
        if (storedStatus == 'Pending' && !inApprovalProcess) {
            // Stored status is stale: the approval finished (or was recalled) but the
            // field update never ran. Resolve the real outcome from the process instance.
            String outcome = resolveLatestPaymentPlanProcessOutcome(requestId);
            if (outcome == 'Rejected' || outcome == 'Approved') {
                return outcome;
            }
            return 'Draft';
        }
        return storedStatus;
    }

    private static String resolveLatestPaymentPlanProcessOutcome(Id approvalRequestId) {
        List<ProcessInstance> instances = [
            SELECT Status
            FROM ProcessInstance
            WHERE TargetObjectId = :approvalRequestId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return instances.isEmpty() ? null : instances[0].Status;
    }

    private static String resolvePaymentPlanStatusLabel(
        String effectiveStatus,
        Boolean inApprovalProcess
    ) {
        if (inApprovalProcess || effectiveStatus == 'Pending') {
            return 'Pending Approval';
        }
        if (effectiveStatus == 'Approved') {
            return 'Approved';
        }
        if (effectiveStatus == 'Rejected') {
            return 'Rejected';
        }
        if (effectiveStatus == 'Draft') {
            return 'Draft';
        }
        return effectiveStatus;
    }

    private static String resolvePaymentPlanApprovalStageLabel(Id approvalRequestId) {
        List<ProcessInstance> instances = [
            SELECT Id
            FROM ProcessInstance
            WHERE TargetObjectId = :approvalRequestId
            AND Status = 'Pending'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (instances.isEmpty()) {
            return null;
        }

        Id processInstanceId = instances[0].Id;
        String approverName = resolveCurrentApprovalActorName(processInstanceId, approvalRequestId);
        List<ProcessInstanceNode> approvalSteps = getApprovalSteps(processInstanceId);
        Integer totalSteps = approvalSteps.size();
        Integer currentStep = 0;

        for (Integer index = 0; index < approvalSteps.size(); index++) {
            if (approvalSteps[index].NodeStatus == 'Pending') {
                currentStep = index + 1;
                break;
            }
        }

        return buildPaymentPlanApprovalStageLabel(currentStep, totalSteps, approverName);
    }

    private static String resolveCurrentApprovalActorName(
        Id processInstanceId,
        Id approvalRequestId
    ) {
        List<ProcessInstanceWorkitem> workitems = [
            SELECT Actor.Name
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstanceId = :processInstanceId
            LIMIT 1
        ];
        if (!workitems.isEmpty() && workitems[0].Actor != null) {
            return workitems[0].Actor.Name;
        }

        List<Approval_Request__c> requests = [
            SELECT Approver__r.Name
            FROM Approval_Request__c
            WHERE Id = :approvalRequestId
            LIMIT 1
        ];
        if (!requests.isEmpty() && requests[0].Approver__r != null) {
            return requests[0].Approver__r.Name;
        }
        return null;
    }

    private static List<ProcessInstanceNode> getApprovalSteps(Id processInstanceId) {
        List<ProcessInstanceNode> approvalSteps = new List<ProcessInstanceNode>();
        for (ProcessInstanceNode node : [
            SELECT ProcessNodeName, NodeStatus, CreatedDate
            FROM ProcessInstanceNode
            WHERE ProcessInstanceId = :processInstanceId
            AND NodeStatus != NULL
            ORDER BY CreatedDate ASC
        ]) {
            if (isSubmissionNode(node.ProcessNodeName)) {
                continue;
            }
            approvalSteps.add(node);
        }
        return approvalSteps;
    }

    private static Boolean isSubmissionNode(String processNodeName) {
        if (String.isBlank(processNodeName)) {
            return true;
        }
        String normalizedName = processNodeName.trim().toLowerCase();
        return normalizedName == 'start' ||
            normalizedName.contains('submission') ||
            normalizedName.contains('submit');
    }

    private static String buildPaymentPlanApprovalStageLabel(
        Integer currentStep,
        Integer totalSteps,
        String approverName
    ) {
        String approverLabel = String.isNotBlank(approverName)
            ? approverName
            : 'assigned approver';

        if (totalSteps <= 1) {
            return 'With ' + approverLabel;
        }
        if (currentStep == 1) {
            return 'First approver — ' + approverLabel;
        }
        if (currentStep == totalSteps) {
            return 'Final approver — ' + approverLabel;
        }
        if (currentStep > 0) {
            return 'Approver ' + currentStep + ' of ' + totalSteps + ' — ' + approverLabel;
        }
        return 'With ' + approverLabel;
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

    private static Approval_Request__c findPaymentPlanRequestForUnit(
        Id unitId,
        Set<String> statuses
    ) {
        if (unitId == null || statuses == null || statuses.isEmpty()) {
            return null;
        }

        String unitIdValue = String.valueOf(unitId);
        List<Approval_Request__c> requests = [
            SELECT Id, Name, Status__c, Justification__c, Unit__c, CreatedDate
            FROM Approval_Request__c
            WHERE Request_Type__c = :REQUEST_TYPE_PAYMENT_PLAN
            AND Status__c IN :statuses
            AND (Unit__c = :unitId OR Related_Record_Id__c = :unitIdValue)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return requests.isEmpty() ? null : requests[0];
    }

    private static AuraHandledException buildOpenRequestException(Approval_Request__c request) {
        String requestLabel = String.isNotBlank(request.Name) ? request.Name : String.valueOf(request.Id);
        return new AuraHandledException(
            'This unit already has a payment plan approval in progress (' +
                requestLabel +
                ', status ' +
                request.Status__c +
                '). Open that record or recall it before starting a new request.'
        );
    }

    private static void validateUnitEligible(Unit__c unit) {
        if (unit.Status__c != 'Booked') {
            throw new AuraHandledException('Payment plan changes are only allowed for Booked units.');
        }
    }

    public static Boolean canUserRequestPaymentPlanChange() {
        return [
            SELECT Can_Request_Payment_Plan_Change__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ].Can_Request_Payment_Plan_Change__c == true;
    }

    private static void validateCashFlowBelongsToUnit(Cash_Flow__c existing, Id unitId) {
        if (existing == null) {
            throw new PaymentPlanApprovalException(
                'A cash flow record referenced by this approval request no longer exists.'
            );
        }
        if (existing.Unit__c != unitId) {
            throw new PaymentPlanApprovalException(
                'Cash flow ' + existing.Id + ' belongs to unit ' + existing.Unit__c +
                ' but this approval request is for unit ' + unitId +
                '. Data may have been changed after submission.'
            );
        }
    }

    private static void validateNoReceivedPayments(Cash_Flow__c existing) {
        if (existing != null && existing.Received_Amount__c != null && existing.Received_Amount__c > 0) {
            throw new PaymentPlanApprovalException(
                'Installments with received payments cannot be updated or deleted.'
            );
        }
    }

    private static Date parseDateValue(Object rawValue) {
        if (rawValue == null) {
            return null;
        }
        if (rawValue instanceof Date) {
            return (Date) rawValue;
        }
        if (rawValue instanceof Datetime) {
            return ((Datetime) rawValue).date();
        }

        String dateString = String.valueOf(rawValue).trim();
        if (String.isBlank(dateString)) {
            return null;
        }
        if (dateString.length() >= 10) {
            dateString = dateString.substring(0, 10);
        }
        return Date.valueOf(dateString);
    }

    private static Decimal toDecimal(Object rawValue) {
        if (rawValue == null) {
            return null;
        }
        String value = String.valueOf(rawValue).trim();
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Decimal.valueOf(value);
        } catch (Exception e) {
            return null;
        }
    }

    private static Integer toInteger(Object rawValue) {
        if (rawValue == null) {
            return null;
        }
        String value = String.valueOf(rawValue).trim();
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Integer.valueOf(value);
        } catch (Exception e) {
            return null;
        }
    }

    private static Boolean toBoolean(Object rawValue) {
        if (rawValue == null) {
            return false;
        }
        if (rawValue instanceof Boolean) {
            return (Boolean) rawValue;
        }
        return Boolean.valueOf(String.valueOf(rawValue));
    }

    public static String getExceptionMessage(Exception e) {
        if (e == null) {
            return 'Unknown error';
        }
        if (e instanceof DmlException) {
            return formatDmlException((DmlException) e);
        }
        if (e instanceof AuraHandledException) {
            AuraHandledException auraEx = (AuraHandledException) e;
            if (String.isNotBlank(auraEx.getMessage())) {
                return auraEx.getMessage();
            }
        }
        if (String.isNotBlank(e.getMessage())) {
            return e.getMessage();
        }
        return e.getTypeName();
    }

    private static String formatDmlException(DmlException e) {
        if (e == null) {
            return 'Database error';
        }
        if (e.getNumDml() > 0) {
            return e.getDmlMessage(0);
        }
        if (String.isNotBlank(e.getMessage())) {
            return e.getMessage();
        }
        return 'Database error';
    }

    public static PaymentPlanComparisonDTO getPaymentPlanComparison(Id approvalRequestId) {
        if (approvalRequestId == null) return null;

        // Resolve to Approval_Request__c ID regardless of what record the component is on
        Id resolvedId = PaymentPlanComparisonReader.resolveApprovalRequestId(approvalRequestId);

        if (resolvedId == null) {
            PaymentPlanComparisonDTO notFound = new PaymentPlanComparisonDTO();
            notFound.notApplicable = true;
            notFound.notApplicableReason = 'Could not resolve an Approval Request from the provided record ID.';
            return notFound;
        }

        List<Approval_Request__c> requests = PaymentPlanComparisonReader.queryRequest(resolvedId);
        if (requests.isEmpty()) {
            PaymentPlanComparisonDTO notFound = new PaymentPlanComparisonDTO();
            notFound.notApplicable = true;
            notFound.notApplicableReason = 'Approval request record not found (ID: ' + resolvedId + ').';
            return notFound;
        }
        Approval_Request__c request = requests[0];

        if (request.Request_Type__c != REQUEST_TYPE_PAYMENT_PLAN) {
            PaymentPlanComparisonDTO wrongType = new PaymentPlanComparisonDTO();
            wrongType.notApplicable = true;
            wrongType.notApplicableReason = 'This is a "' + request.Request_Type__c + '" request — comparison only applies to Payment Plan Change requests.';
            return wrongType;
        }

        if (request.Unit__c == null) {
            PaymentPlanComparisonDTO noUnit = new PaymentPlanComparisonDTO();
            noUnit.notApplicable = true;
            noUnit.notApplicableReason = 'No unit is linked to this approval request.';
            noUnit.requestName = request.Name;
            noUnit.status = request.Status__c;
            return noUnit;
        }

        List<Unit__c> units = PaymentPlanComparisonReader.queryUnit(request.Unit__c);
        if (units.isEmpty()) {
            PaymentPlanComparisonDTO noUnit = new PaymentPlanComparisonDTO();
            noUnit.notApplicable = true;
            noUnit.notApplicableReason = 'The linked unit record could not be found.';
            noUnit.requestName = request.Name;
            noUnit.status = request.Status__c;
            return noUnit;
        }
        Unit__c unit = units[0];

        List<Payment_Plan_Approval_Line__c> approvalLines = PaymentPlanComparisonReader.queryApprovalLines(resolvedId);

        Map<Id, Payment_Plan_Approval_Line__c> updateLinesByCfId = new Map<Id, Payment_Plan_Approval_Line__c>();
        Set<Id> deletedCfIds = new Set<Id>();
        List<Payment_Plan_Approval_Line__c> insertLines = new List<Payment_Plan_Approval_Line__c>();

        for (Payment_Plan_Approval_Line__c line : approvalLines) {
            if (line.Action__c == 'Delete' && line.Cash_Flow__c != null) {
                deletedCfIds.add(line.Cash_Flow__c);
            } else if (line.Action__c == 'Update' && line.Cash_Flow__c != null) {
                updateLinesByCfId.put(line.Cash_Flow__c, line);
            } else if (line.Action__c == 'Insert') {
                insertLines.add(line);
            }
        }

        Set<Id> affectedCashFlowIds = new Set<Id>();
        affectedCashFlowIds.addAll(deletedCfIds);
        affectedCashFlowIds.addAll(updateLinesByCfId.keySet());

        List<ComparisonLineDTO> currentLines = new List<ComparisonLineDTO>();
        List<ComparisonLineDTO> proposedLines = new List<ComparisonLineDTO>();

        for (Cash_Flow__c cf : queryCashFlowsForComparison(affectedCashFlowIds)) {
            Boolean isDeleted = deletedCfIds.contains(cf.Id);
            Boolean isUpdated = updateLinesByCfId.containsKey(cf.Id);
            Boolean hasPaid = cf.Received_Amount__c != null && cf.Received_Amount__c > 0;

            ComparisonLineDTO curr = new ComparisonLineDTO();
            curr.cashFlowId = cf.Id;
            curr.milestoneName = cf.Name;
            curr.installmentDate = cf.Date__c != null ? String.valueOf(cf.Date__c) : null;
            curr.percent = cf.Percent__c;
            curr.constantAmount = cf.Constant__c;
            curr.amount = resolveCashFlowComparisonAmount(cf);
            curr.hasPayments = hasPaid;
            curr.changeType = isDeleted ? 'deleted' : 'updated';
            currentLines.add(curr);

            if (!isDeleted && isUpdated) {
                Payment_Plan_Approval_Line__c ul = updateLinesByCfId.get(cf.Id);
                ComparisonLineDTO prop = new ComparisonLineDTO();
                prop.hasPayments = hasPaid;
                prop.cashFlowId = cf.Id;
                prop.milestoneName = ul.Milestone_Name__c;
                prop.installmentDate = ul.Date__c != null ? String.valueOf(ul.Date__c) : null;
                prop.percent = ul.Percent__c;
                prop.constantAmount = ul.Constant__c;
                prop.amount = resolveApprovalLineComparisonAmount(ul, unit);
                prop.changeType = 'updated';
                proposedLines.add(prop);
            }
        }

        for (Payment_Plan_Approval_Line__c line : insertLines) {
            ComparisonLineDTO prop = new ComparisonLineDTO();
            prop.cashFlowId = null;
            prop.milestoneName = line.Milestone_Name__c;
            prop.installmentDate = line.Date__c != null ? String.valueOf(line.Date__c) : null;
            prop.percent = line.Percent__c;
            prop.constantAmount = line.Constant__c;
            prop.amount = resolveApprovalLineComparisonAmount(line, unit);
            prop.hasPayments = false;
            prop.changeType = 'added';
            proposedLines.add(prop);
        }

        sortComparisonLinesByDate(currentLines);
        sortComparisonLinesByDate(proposedLines);

        UnitInfoDTO unitInfo = new UnitInfoDTO();
        unitInfo.title = unit.Title__c;
        unitInfo.projectName = unit.Project_Name_F__c;
        unitInfo.building = unit.Building__c;
        unitInfo.accountName = unit.Account__r != null ? unit.Account__r.Name : null;

        PaymentPlanComparisonDTO result = new PaymentPlanComparisonDTO();
        result.unitInfo = unitInfo;
        result.currentLines = currentLines;
        result.proposedLines = proposedLines;
        result.status = request.Status__c;
        result.justification = request.Justification__c;
        result.requesterName = request.Requester__r != null ? request.Requester__r.Name : null;
        result.requestName = request.Name;
        result.totalInstallmentCount = PaymentPlanComparisonReader.countCashFlows(request.Unit__c);
        result.changesOnly = true;
        return result;
    }

    public class PaymentPlanApprovalException extends Exception {}

    private static List<Cash_Flow__c> queryCashFlowsForComparison(Set<Id> cashFlowIds) {
        List<Cash_Flow__c> cashFlows = queryCashFlowsByIds(cashFlowIds);
        cashFlows.sort(new CashFlowDateComparator());
        return cashFlows;
    }

    private static List<Cash_Flow__c> queryCashFlowsByIds(Set<Id> cashFlowIds) {
        List<Cash_Flow__c> results = new List<Cash_Flow__c>();
        if (cashFlowIds == null || cashFlowIds.isEmpty()) {
            return results;
        }

        for (List<Id> chunk : chunkIds(cashFlowIds)) {
            results.addAll([
                SELECT Id, Name, Date__c, Percent__c, Constant__c, Received_Amount__c,
                       Price_Formula__c, Amount_AED__c, Unit__c, Cash_Flow_Sum__c
                FROM Cash_Flow__c
                WHERE Id IN :chunk
            ]);
        }
        return results;
    }

    private static List<List<Id>> chunkIds(Set<Id> recordIds) {
        List<List<Id>> chunks = new List<List<Id>>();
        if (recordIds == null || recordIds.isEmpty()) {
            return chunks;
        }

        List<Id> idList = new List<Id>(recordIds);
        for (Integer index = 0; index < idList.size(); index += SOQL_IN_CHUNK_SIZE) {
            List<Id> chunk = new List<Id>();
            Integer endIndex = Math.min(index + SOQL_IN_CHUNK_SIZE, idList.size());
            for (Integer chunkIndex = index; chunkIndex < endIndex; chunkIndex++) {
                chunk.add(idList[chunkIndex]);
            }
            chunks.add(chunk);
        }
        return chunks;
    }

    private static void executeDeleteInChunks(List<SObject> records) {
        for (Integer index = 0; index < records.size(); index += DML_CHUNK_SIZE) {
            List<SObject> chunk = new List<SObject>();
            Integer endIndex = Math.min(index + DML_CHUNK_SIZE, records.size());
            for (Integer chunkIndex = index; chunkIndex < endIndex; chunkIndex++) {
                chunk.add(records[chunkIndex]);
            }
            delete chunk;
        }
    }

    private static void executeUpdateInChunks(List<SObject> records) {
        for (Integer index = 0; index < records.size(); index += DML_CHUNK_SIZE) {
            List<SObject> chunk = new List<SObject>();
            Integer endIndex = Math.min(index + DML_CHUNK_SIZE, records.size());
            for (Integer chunkIndex = index; chunkIndex < endIndex; chunkIndex++) {
                chunk.add(records[chunkIndex]);
            }
            update chunk;
        }
    }

    private static void executeInsertInChunks(List<SObject> records) {
        for (Integer index = 0; index < records.size(); index += DML_CHUNK_SIZE) {
            List<SObject> chunk = new List<SObject>();
            Integer endIndex = Math.min(index + DML_CHUNK_SIZE, records.size());
            for (Integer chunkIndex = index; chunkIndex < endIndex; chunkIndex++) {
                chunk.add(records[chunkIndex]);
            }
            insert chunk;
        }
    }

    private class CashFlowDateComparator implements System.Comparator<Cash_Flow__c> {
        public Integer compare(Cash_Flow__c left, Cash_Flow__c right) {
            if (left == null && right == null) {
                return 0;
            }
            if (left == null) {
                return 1;
            }
            if (right == null) {
                return -1;
            }
            if (left.Date__c == null && right.Date__c == null) {
                return 0;
            }
            if (left.Date__c == null) {
                return 1;
            }
            if (right.Date__c == null) {
                return -1;
            }
            if (left.Date__c == right.Date__c) {
                return 0;
            }
            return left.Date__c < right.Date__c ? -1 : 1;
        }
    }

    private static Decimal resolveCashFlowComparisonAmount(Cash_Flow__c cashFlow) {
        if (cashFlow == null) {
            return null;
        }
        if (cashFlow.Constant__c != null && cashFlow.Constant__c != 0) {
            return cashFlow.Constant__c;
        }
        if (cashFlow.Price_Formula__c != null) {
            return cashFlow.Price_Formula__c;
        }
        return cashFlow.Amount_AED__c;
    }

    private static Decimal resolveApprovalLineComparisonAmount(
        Payment_Plan_Approval_Line__c line,
        Unit__c unit
    ) {
        if (line == null) {
            return null;
        }
        if (line.Constant__c != null && line.Constant__c != 0) {
            return line.Constant__c;
        }
        return calculatePercentBasedComparisonAmount(line.Percent__c, unit);
    }

    private static Decimal calculatePercentBasedComparisonAmount(Decimal percent, Unit__c unit) {
        if (percent == null || unit == null) {
            return null;
        }

        Decimal unitCost = unit.Project_Name_F__c == 'Trussardi Residences MIRA VERDE'
            ? unit.Cost_USD__c
            : unit.Cost_AED__c;
        if (unitCost == null) {
            return null;
        }
        return unitCost * percent;
    }

    private static void sortComparisonLinesByDate(List<ComparisonLineDTO> lines) {
        if (lines == null || lines.size() < 2) {
            return;
        }
        lines.sort(new ComparisonLineDateComparator());
    }

    private static Date parseComparisonInstallmentDate(String installmentDate) {
        if (String.isBlank(installmentDate)) {
            return null;
        }
        try {
            return Date.valueOf(installmentDate);
        } catch (Exception e) {
            return null;
        }
    }

    private class ComparisonLineDateComparator implements System.Comparator<ComparisonLineDTO> {
        public Integer compare(ComparisonLineDTO left, ComparisonLineDTO right) {
            Date leftDate = parseComparisonInstallmentDate(
                left == null ? null : left.installmentDate
            );
            Date rightDate = parseComparisonInstallmentDate(
                right == null ? null : right.installmentDate
            );

            if (leftDate == null && rightDate == null) {
                return 0;
            }
            if (leftDate == null) {
                return 1;
            }
            if (rightDate == null) {
                return -1;
            }
            if (leftDate == rightDate) {
                return 0;
            }
            return leftDate < rightDate ? -1 : 1;
        }
    }

    private static Id getActivePaymentPlanProcessId() {
        return new ProcessDefinitionLookup().resolveActiveProcessId();
    }

    // Queries for read-only comparison display — run without sharing so
    // approvers can see the record even if OWD is Private.
    private without sharing class ComparisonQueryHelper {
        public List<Approval_Request__c> queryRequest(Id requestId) {
            return [
                SELECT Id, Name, Status__c, Justification__c, Unit__c, Request_Type__c,
                       Requester__r.Name
                FROM Approval_Request__c
                WHERE Id = :requestId
                LIMIT 1
            ];
        }
        public List<Unit__c> queryUnit(Id unitId) {
            return [
                SELECT Id, Title__c, Project_Name_F__c, Building__c, Account__r.Name,
                       Cost_AED__c, Cost_USD__c
                FROM Unit__c
                WHERE Id = :unitId
                LIMIT 1
            ];
        }
        public List<Cash_Flow__c> queryCashFlows(Id unitId) {
            return [
                SELECT Id, Name, Date__c, Percent__c, Constant__c, Received_Amount__c,
                       Price_Formula__c, Amount_AED__c
                FROM Cash_Flow__c
                WHERE Unit__c = :unitId
                ORDER BY Date__c ASC NULLS LAST, Name ASC
            ];
        }
        public List<Payment_Plan_Approval_Line__c> queryApprovalLines(Id approvalRequestId) {
            return [
                SELECT Id, Action__c, Cash_Flow__c, Milestone_Name__c,
                       Date__c, Percent__c, Constant__c, Sort_Order__c
                FROM Payment_Plan_Approval_Line__c
                WHERE Approval_Request__c = :approvalRequestId
                ORDER BY Sort_Order__c ASC NULLS LAST
            ];
        }
    }

    private without sharing class ProcessDefinitionLookup {
        public Id resolveActiveProcessId() {
            List<ProcessDefinition> processes = [
                SELECT Id
                FROM ProcessDefinition
                WHERE DeveloperName = :PAYMENT_PLAN_APPROVAL_PROCESS
                AND State = 'Active'
                LIMIT 1
            ];
            return processes.isEmpty() ? null : processes[0].Id;
        }
    }
}