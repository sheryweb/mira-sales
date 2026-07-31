public with sharing class UnitPriceApprovalService {
    public static final String REQUEST_TYPE_UNIT_PRICE = 'Unit Price Change';
    public static final String UNIT_PRICE_APPROVAL_PROCESS = 'Unit_Price_Change';

    // Projects whose price is entered in a foreign currency. Cost_AED__c is
    // always kept in sync via the Currency Management conversion rate.
    private static final String PROJECT_CHF = 'POST HOTEL & RESIDENCES By ELIE SAAB';
    private static final String PROJECT_USD = 'Trussardi Residences MIRA VERDE';

    private static final String CURRENCY_AED = 'AED';
    private static final String CURRENCY_USD = 'USD';
    private static final String CURRENCY_CHF = 'CHF';

    // Safety fallback only if USD is missing from Currency Management (CHF must be configured there).
    private static final Decimal USD_AED_PEG = 3.6725;
    private static final Integer HEADER_FIELD_MAX_LENGTH = 255;

    public class UnitPriceInfoDTO {
        @AuraEnabled public Id unitId;
        @AuraEnabled public String unitTitle;
        @AuraEnabled public String unitStatus;
        @AuraEnabled public String projectName;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public Decimal currentPrice;
        @AuraEnabled public Decimal currentCostAED;
        @AuraEnabled public Decimal conversionRate;
        @AuraEnabled public Boolean eligible;
    }

    public class OpenUnitPriceRequestDTO {
        @AuraEnabled public Id approvalRequestId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String justification;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public Decimal requestedPrice;
        @AuraEnabled public Decimal requestedCostAED;
    }

    public class UnitInfoDTO {
        @AuraEnabled public String title;
        @AuraEnabled public String projectName;
        @AuraEnabled public String building;
        @AuraEnabled public String accountName;
    }

    public class UnitPriceComparisonDTO {
        @AuraEnabled public UnitInfoDTO unitInfo;
        @AuraEnabled public String status;
        @AuraEnabled public String justification;
        @AuraEnabled public String requesterName;
        @AuraEnabled public String requestName;
        @AuraEnabled public String priceCurrency;
        @AuraEnabled public Decimal currentPrice;
        @AuraEnabled public Decimal requestedPrice;
        @AuraEnabled public Decimal currentCostAED;
        @AuraEnabled public Decimal requestedCostAED;
        @AuraEnabled public Decimal conversionRate;
        @AuraEnabled public Decimal priceDifference;
        @AuraEnabled public Decimal costAedDifference;
        @AuraEnabled public Integer discountPercent;
        @AuraEnabled public Boolean notApplicable;
        @AuraEnabled public String notApplicableReason;
    }

    public class UnitPriceApprovalException extends Exception {}

    public static UnitPriceInfoDTO getUnitPriceInfo(Id unitId) {
        Unit__c unit = loadUnit(unitId);

        UnitPriceInfoDTO dto = new UnitPriceInfoDTO();
        dto.unitId = unit.Id;
        dto.unitTitle = unit.Title__c;
        dto.unitStatus = unit.Status__c;
        dto.projectName = unit.Project_Name_F__c;
        dto.currencyCode = resolveCurrency(unit.Project_Name_F__c);
        dto.currentCostAED = unit.Cost_AED__c;
        dto.currentPrice = currentPriceForCurrency(unit, dto.currencyCode);
        dto.conversionRate = dto.currencyCode == CURRENCY_AED
            ? 1
            : getForeignPerAedRate(dto.currencyCode);
        dto.eligible = unit.Status__c == 'Booked';
        return dto;
    }

    public static OpenUnitPriceRequestDTO getOpenUnitPriceRequestForUnit(Id unitId) {
        validateUnitAccess(unitId);

        Approval_Request__c request = findUnitPriceRequestForUnit(
            unitId,
            new Set<String>{ 'Draft', 'Pending' }
        );
        if (request == null) {
            return null;
        }

        String effectiveStatus = resolveEffectiveStatus(request);
        if (effectiveStatus == 'Rejected' || effectiveStatus == 'Approved' || effectiveStatus == 'Applied') {
            // The approval process already finished — nothing is open for this unit,
            // so the user is free to start a new request.
            return null;
        }

        OpenUnitPriceRequestDTO dto = new OpenUnitPriceRequestDTO();
        dto.approvalRequestId = request.Id;
        dto.name = request.Name;
        dto.status = effectiveStatus;
        dto.justification = request.Justification__c;
        dto.currencyCode = request.Price_Currency__c;
        dto.requestedPrice = request.Requested_Price__c;
        dto.requestedCostAED = request.Requested_Cost_AED__c;
        return dto;
    }

    public static Id createDraftRequest(Id unitId, String justification, Decimal requestedPrice) {
        return createDraftRequest(unitId, justification, requestedPrice, null);
    }

    public static Id createDraftRequest(
        Id unitId,
        String justification,
        Decimal requestedPrice,
        Integer discountPercent
    ) {
        Unit__c unit = loadUnit(unitId);
        validateUnitEligible(unit);
        validateJustification(justification);

        Approval_Request__c pendingRequest = findUnitPriceRequestForUnit(
            unitId,
            new Set<String>{ 'Pending' }
        );
        if (pendingRequest != null) {
            if (hasPendingApprovalProcess(pendingRequest.Id)) {
                throw buildOpenRequestException(pendingRequest);
            }
            // Status says Pending but no approval is actually in flight (e.g. the
            // request was rejected and the rejection field update never ran).
            // Sync the stored status with the real outcome and let the user proceed.
            reconcileStaleRequestStatus(pendingRequest);
        }

        Approval_Request__c request = findUnitPriceRequestForUnit(
            unitId,
            new Set<String>{ 'Draft' }
        );
        if (request == null) {
            request = new Approval_Request__c(
                Request_Type__c = REQUEST_TYPE_UNIT_PRICE,
                Unit__c = unitId,
                Status__c = 'Draft',
                Requester__c = UserInfo.getUserId()
            );
        }

        request.Justification__c = justification;
        populateHeaderFields(request, unit, requestedPrice, discountPercent);

        try {
            upsert request;
        } catch (DmlException e) {
            throw new AuraHandledException(formatDmlException(e));
        }
        return request.Id;
    }

    public static Id submitUnitPriceApproval(
        Id unitId,
        String justification,
        Integer discountPercent,
        Id existingRequestId
    ) {
        try {
            validateJustification(justification);
            validateDiscountPercent(discountPercent);

            Unit__c unit = loadUnit(unitId);
            validateUnitEligible(unit);
            Decimal requestedPrice = calculateDiscountedPrice(
                currentPriceForCurrency(unit, resolveCurrency(unit.Project_Name_F__c)),
                discountPercent
            );
            validateRequestedPrice(requestedPrice);

            Id approvalRequestId = existingRequestId;
            if (approvalRequestId == null) {
                approvalRequestId = createDraftRequest(unitId, justification, requestedPrice, discountPercent);
            } else {
                Approval_Request__c existing = getEditableRequest(approvalRequestId);
                unit = loadUnit(existing.Unit__c);
                validateUnitEligible(unit);
                existing.Justification__c = justification;
                populateHeaderFields(existing, unit, requestedPrice, discountPercent);
                update existing;
            }

            submitForApproval(approvalRequestId);
            return approvalRequestId;
        } catch (AuraHandledException e) {
            throw e;
        } catch (DmlException e) {
            throw new AuraHandledException(formatDmlException(e));
        } catch (Exception e) {
            throw new AuraHandledException('Unit price submit failed: ' + getExceptionMessage(e));
        }
    }

    public static Decimal calculateDiscountedPrice(Decimal currentPrice, Integer discountPercent) {
        if (currentPrice == null || discountPercent == null) {
            return null;
        }
        Decimal multiplier = 1 - (Decimal.valueOf(discountPercent) / 100);
        // Whole amounts only — unit prices are not shown or stored with decimals.
        return (currentPrice * multiplier).setScale(0, System.RoundingMode.HALF_UP);
    }

    public static void submitForApproval(Id approvalRequestId) {
        Approval_Request__c request = getEditableRequest(approvalRequestId);
        if (request.Requested_Price__c == null) {
            throw new AuraHandledException('Enter a requested price before submitting for approval.');
        }

        ensureUnitPriceRequestReadyForSubmit(request);
        update request;

        Approval_Request__c submitRecord = [
            SELECT Id, Request_Type__c, Status__c
            FROM Approval_Request__c
            WHERE Id = :approvalRequestId
            LIMIT 1
        ];
        validateUnitPriceSubmitRecord(submitRecord);
        assertNoPendingApprovalInstance(approvalRequestId);

        try {
            Approval.ProcessResult result = submitApprovalProcess(
                approvalRequestId,
                request.Justification__c
            );
            if (result == null || !result.isSuccess()) {
                throw new AuraHandledException(
                    buildSubmitFailureMessage(result, submitRecord)
                );
            }

            setPendingStatusAfterSubmit(approvalRequestId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to submit approval request: ' + getExceptionMessage(e)
            );
        }
    }

    public static void applyApprovedChanges(Id approvalRequestId) {
        Approval_Request__c request = [
            SELECT Id, Status__c, Unit__c, Request_Type__c, Price_Currency__c,
                   Requested_Price__c, Requested_Cost_AED__c
            FROM Approval_Request__c
            WHERE Id = :approvalRequestId
            LIMIT 1
        ];

        if (request.Request_Type__c != REQUEST_TYPE_UNIT_PRICE) {
            return;
        }
        if (request.Status__c == 'Applied') {
            return;
        }
        if (request.Status__c != 'Approved') {
            return;
        }
        if (request.Unit__c == null) {
            throw new UnitPriceApprovalException('Approval request is missing the related unit.');
        }
        if (request.Requested_Cost_AED__c == null) {
            throw new UnitPriceApprovalException('Approval request is missing the requested cost.');
        }

        Unit__c unitRecord = UnitPriceComparisonReader.queryUnitForApplyValidation(request.Unit__c);
        if (unitRecord == null) {
            throw new UnitPriceApprovalException('The linked unit record could not be found.');
        }
        validateUnitEligible(unitRecord);

        Unit__c unit = new Unit__c(Id = request.Unit__c);
        String currencyCode = String.isNotBlank(request.Price_Currency__c)
            ? request.Price_Currency__c
            : CURRENCY_AED;

        if (currencyCode == CURRENCY_CHF) {
            unit.Cost_CHF__c = request.Requested_Price__c;
            unit.Cost_CHF_Number__c = request.Requested_Price__c;
            unit.Cost_AED__c = request.Requested_Cost_AED__c;
        } else if (currencyCode == CURRENCY_USD) {
            unit.Cost_USD__c = request.Requested_Price__c;
            unit.Cost_USD_Number__c = request.Requested_Price__c;
            unit.Cost_AED__c = request.Requested_Cost_AED__c;
        } else {
            unit.Cost_AED__c = request.Requested_Cost_AED__c;
        }

        UnitPriceComparisonReader.applyUnitPriceToUnit(unit);
        UnitPriceComparisonReader.markRequestApplied(approvalRequestId);
        rebuildRmDealCreditsForUnit(request.Unit__c);
    }

    private static void rebuildRmDealCreditsForUnit(Id unitId) {
        if (unitId == null) {
            return;
        }
        Set<Id> opportunityIds = new Set<Id>();
        for (Opportunity opp : [
            SELECT Id
            FROM Opportunity
            WHERE Unit__c = :unitId
        ]) {
            opportunityIds.add(opp.Id);
        }
        RMDealCreditService.rebuildForOpportunityIds(opportunityIds);
    }

    private static void populateHeaderFields(
        Approval_Request__c request,
        Unit__c unit,
        Decimal requestedPrice,
        Integer discountPercent
    ) {
        String currencyCode = resolveCurrency(unit.Project_Name_F__c);
        Decimal currentPrice = currentPriceForCurrency(unit, currencyCode);
        Decimal rate = currencyCode == CURRENCY_AED ? 1 : getForeignPerAedRate(currencyCode);
        Decimal requestedCostAED = computeCostAED(currencyCode, requestedPrice, rate);

        request.Unit__c = unit.Id;
        request.Request_Type__c = REQUEST_TYPE_UNIT_PRICE;
        request.Price_Currency__c = currencyCode;
        request.Current_Price__c = roundWhole(currentPrice);
        request.Current_Cost_AED__c = roundWhole(unit.Cost_AED__c);
        request.Requested_Price__c = roundWhole(requestedPrice);
        request.Requested_Cost_AED__c = requestedCostAED;
        request.Conversion_Rate__c = rate;
        if (discountPercent != null) {
            request.Discount_Percent__c = discountPercent;
        }
        request.Field_To_Update__c = fieldToUpdateFor(currencyCode);

        if (String.isBlank(request.Related_Record_Id__c)) {
            request.Related_Record_Id__c = String.valueOf(unit.Id);
        }
        if (String.isBlank(request.Related_Object_Type__c)) {
            request.Related_Object_Type__c = 'Unit__c';
        }
        setParentReferenceFields(request, 'Unit__c', String.valueOf(unit.Id));

        request.Current_Value__c = truncateField(formatMoney(currencyCode, currentPrice));
        request.Requested_Value__c = truncateField(formatMoney(currencyCode, requestedPrice));
    }

    private static Decimal computeCostAED(String currencyCode, Decimal price, Decimal foreignPerAedRate) {
        if (price == null) {
            return null;
        }
        if (currencyCode == CURRENCY_AED) {
            return price.setScale(0, System.RoundingMode.HALF_UP);
        }
        if (foreignPerAedRate == null || foreignPerAedRate == 0) {
            throw new AuraHandledException(
                'No active Currency Management rate found for ' + currencyCode +
                '. Add ' + currencyCode + ' to Currency Management before submitting.'
            );
        }
        return (price / foreignPerAedRate).setScale(0, System.RoundingMode.HALF_UP);
    }

    // CurrencyType.ConversionRate is "foreign currency units per 1 corporate (AED) unit",
    // the same value returned by the CURRENCYRATE() formula function.
    private static Decimal getForeignPerAedRate(String isoCode) {
        List<CurrencyType> rates = [
            SELECT ConversionRate
            FROM CurrencyType
            WHERE IsoCode = :isoCode AND IsActive = true
            LIMIT 1
        ];
        if (!rates.isEmpty() && rates[0].ConversionRate != null && rates[0].ConversionRate != 0) {
            return rates[0].ConversionRate;
        }
        if (isoCode == CURRENCY_USD) {
            return 1 / USD_AED_PEG;
        }
        return null;
    }

    private static String resolveCurrency(String projectName) {
        if (projectName == PROJECT_CHF) {
            return CURRENCY_CHF;
        }
        if (projectName == PROJECT_USD) {
            return CURRENCY_USD;
        }
        return CURRENCY_AED;
    }

    private static Decimal currentPriceForCurrency(Unit__c unit, String currencyCode) {
        if (currencyCode == CURRENCY_CHF) {
            return unit.Cost_CHF__c;
        }
        if (currencyCode == CURRENCY_USD) {
            return unit.Cost_USD__c;
        }
        return unit.Cost_AED__c;
    }

    private static String fieldToUpdateFor(String currencyCode) {
        if (currencyCode == CURRENCY_CHF) {
            return 'Cost_CHF__c';
        }
        if (currencyCode == CURRENCY_USD) {
            return 'Cost_USD__c';
        }
        return 'Cost_AED__c';
    }

    private static Approval.ProcessResult submitApprovalProcess(Id approvalRequestId, String justification) {
        List<String> processReferences = buildProcessReferenceAttempts();
        List<String> statusesToTry = new List<String>{ 'Draft', 'Pending' };
        Approval.ProcessResult lastResult;

        for (String statusValue : statusesToTry) {
            update new Approval_Request__c(
                Id = approvalRequestId,
                Request_Type__c = REQUEST_TYPE_UNIT_PRICE,
                Status__c = statusValue
            );

            for (String processReference : processReferences) {
                try {
                    lastResult = Approval.process(
                        buildSubmitRequest(approvalRequestId, justification, processReference)
                    );
                    if (lastResult != null && lastResult.isSuccess()) {
                        return lastResult;
                    }
                } catch (Exception attemptEx) {
                    System.debug(LoggingLevel.WARN,
                        'Unit price approval attempt failed for processReference="' + processReference +
                        '", status="' + statusValue + '": ' + attemptEx.getMessage());
                }
            }
        }

        update new Approval_Request__c(
            Id = approvalRequestId,
            Request_Type__c = REQUEST_TYPE_UNIT_PRICE,
            Status__c = 'Draft'
        );
        return lastResult;
    }

    private static List<String> buildProcessReferenceAttempts() {
        List<String> processReferences = new List<String>();

        Id processId = getActiveProcessId();
        if (processId != null) {
            processReferences.add(String.valueOf(processId));
        }

        processReferences.add(UNIT_PRICE_APPROVAL_PROCESS);
        processReferences.add(
            Approval_Request__c.SObjectType.getDescribe().getName() +
                '.' +
                UNIT_PRICE_APPROVAL_PROCESS
        );
        processReferences.add(null);
        return processReferences;
    }

    private static Approval.ProcessSubmitRequest buildSubmitRequest(
        Id approvalRequestId,
        String justification,
        String processDefinitionNameOrId
    ) {
        Approval.ProcessSubmitRequest submitRequest = new Approval.ProcessSubmitRequest();
        submitRequest.setObjectId(approvalRequestId);
        submitRequest.setComments(
            String.isNotBlank(justification)
                ? justification
                : 'Unit price change approval request'
        );
        if (String.isNotBlank(processDefinitionNameOrId)) {
            submitRequest.setProcessDefinitionNameOrId(processDefinitionNameOrId);
        }
        return submitRequest;
    }

    private static void ensureUnitPriceRequestReadyForSubmit(Approval_Request__c request) {
        request.Request_Type__c = REQUEST_TYPE_UNIT_PRICE;
        if (
            request.Status__c == null ||
            request.Status__c == 'Rejected' ||
            request.Status__c == 'Approved' ||
            request.Status__c == 'Applied'
        ) {
            request.Status__c = 'Draft';
        }
    }

    private static void validateUnitPriceSubmitRecord(Approval_Request__c request) {
        if (request.Request_Type__c != REQUEST_TYPE_UNIT_PRICE) {
            throw new AuraHandledException(
                'Request type must be "' +
                    REQUEST_TYPE_UNIT_PRICE +
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

    private static void setPendingStatusAfterSubmit(Id approvalRequestId) {
        try {
            update new Approval_Request__c(
                Id = approvalRequestId,
                Request_Type__c = REQUEST_TYPE_UNIT_PRICE,
                Status__c = 'Pending'
            );
        } catch (DmlException e) {
            if (!hasPendingApprovalProcess(approvalRequestId)) {
                throw new AuraHandledException(formatDmlException(e));
            }
            // Workflow initial submission action (Unit_Price_Pending_Status) already set Pending.
        }
    }

    private static Id getActiveProcessId() {
        return new ProcessDefinitionLookup().resolveActiveProcessId();
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
                'This request is already in an approval process. Recall the existing submission before trying again.'
            );
        }
    }

    private static Approval_Request__c getEditableRequest(Id approvalRequestId) {
        Approval_Request__c request = [
            SELECT Id, Status__c, Request_Type__c, Unit__c, Justification__c,
                   Price_Currency__c, Current_Price__c, Current_Cost_AED__c,
                   Requested_Price__c, Requested_Cost_AED__c, Conversion_Rate__c,
                   Related_Record_Id__c, Related_Object_Type__c, Field_To_Update__c,
                   Current_Value__c, Requested_Value__c
            FROM Approval_Request__c
            WHERE Id = :approvalRequestId
            LIMIT 1
        ];
        if (request.Request_Type__c != REQUEST_TYPE_UNIT_PRICE) {
            throw new AuraHandledException('This action is only supported for unit price approval requests.');
        }
        if (request.Status__c != 'Draft' && request.Status__c != 'Pending') {
            throw new AuraHandledException('Only draft or pending requests can be edited.');
        }
        return request;
    }

    private static Unit__c loadUnit(Id unitId) {
        validateUnitAccess(unitId);
        return [
            SELECT Id, Title__c, Status__c, Project_Name_F__c,
                   Cost_AED__c, Cost_USD__c, Cost_CHF__c
            FROM Unit__c
            WHERE Id = :unitId
            LIMIT 1
        ];
    }

    private static void validateUnitAccess(Id unitId) {
        if (unitId == null) {
            throw new AuraHandledException('Unit is required.');
        }
        if ([SELECT COUNT() FROM Unit__c WHERE Id = :unitId] == 0) {
            throw new AuraHandledException('Unit not found.');
        }
    }

    private static void validateUnitEligible(Unit__c unit) {
        if (unit.Status__c != 'Booked') {
            throw new AuraHandledException('Unit price changes are only allowed for Booked units.');
        }
    }

    private static void validateRequestedPrice(Decimal requestedPrice) {
        if (requestedPrice == null || requestedPrice <= 0) {
            throw new AuraHandledException('Calculated requested price must be greater than zero.');
        }
    }

    private static void validateDiscountPercent(Integer discountPercent) {
        if (discountPercent == null || discountPercent < 1 || discountPercent > 10) {
            throw new AuraHandledException('Select a discount percentage between 1 and 10.');
        }
    }

    private static void validateJustification(String justification) {
        if (String.isBlank(justification) || justification.trim().length() < 10) {
            throw new AuraHandledException('Justification is required and must be at least 10 characters.');
        }
    }

    private static Approval_Request__c findUnitPriceRequestForUnit(Id unitId, Set<String> statuses) {
        if (unitId == null || statuses == null || statuses.isEmpty()) {
            return null;
        }
        String unitIdValue = String.valueOf(unitId);
        List<Approval_Request__c> requests = [
            SELECT Id, Name, Status__c, Justification__c, Unit__c, Price_Currency__c,
                   Current_Price__c, Current_Cost_AED__c, Requested_Price__c,
                   Requested_Cost_AED__c, Conversion_Rate__c, Related_Record_Id__c,
                   Related_Object_Type__c, Field_To_Update__c, Current_Value__c,
                   Requested_Value__c, CreatedDate
            FROM Approval_Request__c
            WHERE Request_Type__c = :REQUEST_TYPE_UNIT_PRICE
            AND Status__c IN :statuses
            AND (Unit__c = :unitId OR Related_Record_Id__c = :unitIdValue)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return requests.isEmpty() ? null : requests[0];
    }

    private static AuraHandledException buildOpenRequestException(Approval_Request__c request) {
        String label = String.isNotBlank(request.Name) ? request.Name : String.valueOf(request.Id);
        return new AuraHandledException(
            'This unit already has a unit price approval in progress (' + label +
            ', status ' + request.Status__c + '). Open that record or recall it before starting a new request.'
        );
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
    }

    private static Decimal roundWhole(Decimal value) {
        return value == null ? null : value.setScale(0, System.RoundingMode.HALF_UP);
    }

    private static String formatMoney(String currencyCode, Decimal value) {
        if (value == null) {
            return currencyCode + ' N/A';
        }
        return currencyCode + ' ' + value.setScale(0, System.RoundingMode.HALF_UP).format();
    }

    private static String truncateField(String value) {
        if (String.isBlank(value)) {
            return 'N/A';
        }
        return value.length() > HEADER_FIELD_MAX_LENGTH
            ? value.substring(0, HEADER_FIELD_MAX_LENGTH)
            : value;
    }

    private static String buildSubmitFailureMessage(
        Approval.ProcessResult result,
        Approval_Request__c request
    ) {
        String message = formatApprovalErrors(result, request);
        if (String.isBlank(message)) {
            message = 'Unable to submit the unit price change for approval.';
        }
        return message;
    }

    private static String formatApprovalErrors(
        Approval.ProcessResult result,
        Approval_Request__c request
    ) {
        String requestType = request == null ? 'unknown' : request.Request_Type__c;
        String requestStatus = request == null ? 'unknown' : request.Status__c;
        String message =
            'Unable to submit approval request using process "' +
            UNIT_PRICE_APPROVAL_PROCESS +
            '". Record values: Request Type=' +
            requestType +
            ', Status=' +
            requestStatus +
            '. Confirm workflow actions Unit_Price_Pending_Status, Unit_Price_Approved_Status, and Unit_Price_Rejected_Status exist and are wired into the approval process.';
        if (result != null && result.getErrors() != null) {
            for (Database.Error err : result.getErrors()) {
                message += ' ' + err.getMessage();
            }
        }
        return message;
    }

    private static String getExceptionMessage(Exception e) {
        if (e == null) {
            return 'Unknown error';
        }
        if (e instanceof DmlException) {
            return formatDmlException((DmlException) e);
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

    public static UnitPriceComparisonDTO getUnitPriceComparison(Id approvalRequestId) {
        if (approvalRequestId == null) {
            return null;
        }

        Id resolvedId = UnitPriceComparisonReader.resolveApprovalRequestId(approvalRequestId);
        if (resolvedId == null) {
            UnitPriceComparisonDTO notFound = new UnitPriceComparisonDTO();
            notFound.notApplicable = true;
            notFound.notApplicableReason =
                'Could not resolve an Approval Request from the provided record ID.';
            return notFound;
        }

        List<Approval_Request__c> requests = UnitPriceComparisonReader.queryRequest(resolvedId);
        if (requests.isEmpty()) {
            UnitPriceComparisonDTO notFound = new UnitPriceComparisonDTO();
            notFound.notApplicable = true;
            notFound.notApplicableReason = 'Approval request record not found (ID: ' + resolvedId + ').';
            return notFound;
        }

        Approval_Request__c request = requests[0];
        if (request.Request_Type__c != REQUEST_TYPE_UNIT_PRICE) {
            UnitPriceComparisonDTO wrongType = new UnitPriceComparisonDTO();
            wrongType.notApplicable = true;
            wrongType.notApplicableReason =
                'This is a "' + request.Request_Type__c +
                '" request — comparison only applies to Unit Price Change requests.';
            return wrongType;
        }

        if (request.Unit__c == null) {
            UnitPriceComparisonDTO noUnit = new UnitPriceComparisonDTO();
            noUnit.notApplicable = true;
            noUnit.notApplicableReason = 'No unit is linked to this approval request.';
            noUnit.requestName = request.Name;
            noUnit.status = request.Status__c;
            return noUnit;
        }

        List<Unit__c> units = UnitPriceComparisonReader.queryUnit(request.Unit__c);
        if (units.isEmpty()) {
            UnitPriceComparisonDTO noUnit = new UnitPriceComparisonDTO();
            noUnit.notApplicable = true;
            noUnit.notApplicableReason = 'The linked unit record could not be found.';
            noUnit.requestName = request.Name;
            noUnit.status = request.Status__c;
            return noUnit;
        }

        Unit__c unit = units[0];
        UnitInfoDTO unitInfo = new UnitInfoDTO();
        unitInfo.title = unit.Title__c;
        unitInfo.projectName = unit.Project_Name_F__c;
        unitInfo.building = unit.Building__c;
        unitInfo.accountName = unit.Account__r != null ? unit.Account__r.Name : null;

        UnitPriceComparisonDTO result = new UnitPriceComparisonDTO();
        result.unitInfo = unitInfo;
        result.status = resolveEffectiveStatus(request);
        result.justification = request.Justification__c;
        result.requesterName = request.Requester__r != null ? request.Requester__r.Name : null;
        result.requestName = request.Name;
        result.priceCurrency = request.Price_Currency__c;
        result.currentPrice = request.Current_Price__c;
        result.requestedPrice = request.Requested_Price__c;
        result.currentCostAED = request.Current_Cost_AED__c;
        result.requestedCostAED = request.Requested_Cost_AED__c;
        result.conversionRate = request.Conversion_Rate__c;
        result.priceDifference = diff(request.Requested_Price__c, request.Current_Price__c);
        result.costAedDifference = diff(request.Requested_Cost_AED__c, request.Current_Cost_AED__c);
        result.discountPercent = resolveDiscountPercent(
            request.Discount_Percent__c,
            request.Current_Price__c,
            request.Requested_Price__c
        );
        result.notApplicable = false;
        return result;
    }

    private static Integer resolveDiscountPercent(
        Decimal storedPercent,
        Decimal currentPrice,
        Decimal requestedPrice
    ) {
        if (storedPercent != null) {
            return storedPercent.intValue();
        }
        if (currentPrice == null || currentPrice == 0 || requestedPrice == null) {
            return null;
        }
        Decimal derived = ((currentPrice - requestedPrice) / currentPrice * 100)
            .setScale(0, System.RoundingMode.HALF_UP);
        Integer percent = derived.intValue();
        if (percent >= 1 && percent <= 10) {
            return percent;
        }
        return null;
    }

    private static String resolveEffectiveStatus(Approval_Request__c request) {
        if (request == null || String.isBlank(request.Status__c)) {
            return 'Draft';
        }
        if (request.Status__c == 'Draft' && hasPendingApprovalProcess(request.Id)) {
            return 'Pending';
        }
        if (request.Status__c == 'Pending' && !hasPendingApprovalProcess(request.Id)) {
            // Stored status is stale: the approval finished (or was recalled) but the
            // field update never ran. Resolve the real outcome from the process instance.
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
            // Record may still be locked from the finished approval. The stale status
            // must not block new requests, so swallow and continue.
            System.debug(LoggingLevel.WARN,
                'Could not reconcile stale unit price request ' + request.Id + ': ' + e.getMessage());
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

    private static Decimal diff(Decimal requested, Decimal current) {
        if (requested == null && current == null) {
            return null;
        }
        Decimal req = requested == null ? 0 : requested;
        Decimal cur = current == null ? 0 : current;
        return req - cur;
    }

    private without sharing class ProcessDefinitionLookup {
        public Id resolveActiveProcessId() {
            List<ProcessDefinition> processes = [
                SELECT Id
                FROM ProcessDefinition
                WHERE DeveloperName = :UNIT_PRICE_APPROVAL_PROCESS
                AND State = 'Active'
                LIMIT 1
            ];
            return processes.isEmpty() ? null : processes[0].Id;
        }
    }
}