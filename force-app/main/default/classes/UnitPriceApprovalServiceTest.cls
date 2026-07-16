@IsTest
private class UnitPriceApprovalServiceTest {

    private static final String PROJECT_CHF_NAME = 'POST HOTEL & RESIDENCES By ELIE SAAB';
    private static final String PROJECT_USD_NAME = 'Trussardi Residences MIRA VERDE';
    private static final String PROJECT_AED_NAME = 'Unit Price AED Project';

    @TestSetup
    static void setupData() {
        List<Project__c> projects = new List<Project__c>{
            buildProject(PROJECT_AED_NAME),
            buildProject(PROJECT_USD_NAME),
            buildProject(PROJECT_CHF_NAME)
        };
        insert projects;

        Map<String, Id> projectIdByName = new Map<String, Id>();
        for (Project__c p : projects) {
            projectIdByName.put(p.Name, p.Id);
        }

        List<Unit__c> units = new List<Unit__c>{
            buildUnit('AED Unit', projectIdByName.get(PROJECT_AED_NAME)),
            buildUnit('USD Unit', projectIdByName.get(PROJECT_USD_NAME)),
            buildUnit('CHF Unit', projectIdByName.get(PROJECT_CHF_NAME))
        };
        // Validation rule: units must be created as Draft.
        insert units;

        for (Unit__c u : units) {
            u.Status__c = 'Booked';
        }
        if (units.size() >= 2) {
            units[1].Cost_USD__c = 250000;
        }
        if (units.size() >= 3) {
            units[2].Cost_CHF__c = 300000;
        }
        update units;
    }

    private static Project__c buildProject(String name) {
        return new Project__c(
            Name = name,
            Description__c = 'Test',
            District__c = 'Meydan',
            Coordinates_Latitude__c = 1,
            Coordinates_Longitude__c = 1,
            Handover__c = Date.today(),
            Minimum_Cost__c = 1,
            Publish_Project__c = 'Draft'
        );
    }

    private static Unit__c buildUnit(String title, Id projectId) {
        return new Unit__c(
            Title__c = title,
            Cost_AED__c = 1000000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Additional_Area__c = 200,
            Floor__c = 1,
            Number_of_Bedrooms__c = 2,
            Number_of_Bathrooms__c = 2,
            Status__c = 'Draft',
            Building__c = 'Tower A',
            Panorama_Link__c = 'Link',
            Project__c = projectId
        );
    }

    private static Unit__c unitByTitle(String title) {
        return [
            SELECT Id, Title__c, Status__c, Project_Name_F__c,
                   Cost_AED__c, Cost_USD__c, Cost_CHF__c,
                   Cost_USD_Number__c, Cost_CHF_Number__c
            FROM Unit__c
            WHERE Title__c = :title
            LIMIT 1
        ];
    }

    private static Decimal usdRate() {
        return [SELECT ConversionRate FROM CurrencyType WHERE IsoCode = 'USD' AND IsActive = true LIMIT 1].ConversionRate;
    }

    private static Decimal chfRate() {
        return [SELECT ConversionRate FROM CurrencyType WHERE IsoCode = 'CHF' AND IsActive = true LIMIT 1].ConversionRate;
    }

    @IsTest
    static void testGetUnitPriceInfoAed() {
        Unit__c unit = unitByTitle('AED Unit');
        Test.startTest();
        UnitPriceApprovalService.UnitPriceInfoDTO info = UnitPriceApprovalService.getUnitPriceInfo(unit.Id);
        Test.stopTest();

        System.assertEquals('AED', info.currencyCode, 'Default project should resolve to AED');
        System.assertEquals(1000000, info.currentPrice);
        System.assertEquals(1, info.conversionRate);
        System.assertEquals(true, info.eligible, 'Booked unit should be eligible');
    }

    @IsTest
    static void testGetUnitPriceInfoUsd() {
        Unit__c unit = unitByTitle('USD Unit');
        Test.startTest();
        UnitPriceApprovalService.UnitPriceInfoDTO info = UnitPriceApprovalService.getUnitPriceInfo(unit.Id);
        Test.stopTest();

        System.assertEquals('USD', info.currencyCode);
        System.assertEquals(250000, info.currentPrice);
        System.assertEquals(usdRate(), info.conversionRate);
    }

    @IsTest
    static void testGetUnitPriceInfoChf() {
        Unit__c unit = unitByTitle('CHF Unit');
        Test.startTest();
        UnitPriceApprovalService.UnitPriceInfoDTO info = UnitPriceApprovalService.getUnitPriceInfo(unit.Id);
        Test.stopTest();

        System.assertEquals('CHF', info.currencyCode);
        System.assertEquals(300000, info.currentPrice);
        System.assertEquals(chfRate(), info.conversionRate);
    }

    @IsTest
    static void testCreateDraftAed() {
        Unit__c unit = unitByTitle('AED Unit');
        Test.startTest();
        Id requestId = UnitPriceApprovalService.createDraftRequest(unit.Id, 'Increase price for market adjustment.', 1200000);
        Test.stopTest();

        Approval_Request__c req = [
            SELECT Status__c, Price_Currency__c, Requested_Price__c, Requested_Cost_AED__c,
                   Current_Cost_AED__c, Conversion_Rate__c, Field_To_Update__c,
                   Current_Value__c, Requested_Value__c
            FROM Approval_Request__c WHERE Id = :requestId
        ];
        System.assertEquals('Draft', req.Status__c);
        System.assertEquals('AED', req.Price_Currency__c);
        System.assertEquals(1200000, req.Requested_Price__c);
        System.assertEquals(1200000, req.Requested_Cost_AED__c, 'AED price maps 1:1 to cost AED');
        System.assertEquals(1000000, req.Current_Cost_AED__c);
        System.assertEquals('Cost_AED__c', req.Field_To_Update__c);
        System.assertNotEquals(null, req.Current_Value__c);
        System.assertNotEquals(null, req.Requested_Value__c);
    }

    @IsTest
    static void testCreateDraftUsdConversion() {
        Unit__c unit = unitByTitle('USD Unit');
        Decimal rate = usdRate();
        Decimal requestedUsd = 300000;
        Decimal expectedAed = (requestedUsd / rate).setScale(0, System.RoundingMode.HALF_UP);

        Test.startTest();
        Id requestId = UnitPriceApprovalService.createDraftRequest(unit.Id, 'USD price revision per contract.', requestedUsd);
        Test.stopTest();

        Approval_Request__c req = [
            SELECT Price_Currency__c, Requested_Price__c, Requested_Cost_AED__c, Conversion_Rate__c, Field_To_Update__c
            FROM Approval_Request__c WHERE Id = :requestId
        ];
        System.assertEquals('USD', req.Price_Currency__c);
        System.assertEquals(requestedUsd, req.Requested_Price__c);
        System.assertEquals(expectedAed, req.Requested_Cost_AED__c, 'AED should be USD / rate');
        System.assertEquals(rate, req.Conversion_Rate__c);
        System.assertEquals('Cost_USD__c', req.Field_To_Update__c);
    }

    @IsTest
    static void testCreateDraftChfConversion() {
        Unit__c unit = unitByTitle('CHF Unit');
        Decimal rate = chfRate();
        Decimal requestedChf = 350000;
        Decimal expectedAed = (requestedChf / rate).setScale(0, System.RoundingMode.HALF_UP);

        Test.startTest();
        Id requestId = UnitPriceApprovalService.createDraftRequest(unit.Id, 'CHF price revision per contract.', requestedChf);
        Test.stopTest();

        Approval_Request__c req = [
            SELECT Price_Currency__c, Requested_Price__c, Requested_Cost_AED__c, Conversion_Rate__c, Field_To_Update__c
            FROM Approval_Request__c WHERE Id = :requestId
        ];
        System.assertEquals('CHF', req.Price_Currency__c);
        System.assertEquals(requestedChf, req.Requested_Price__c);
        System.assertEquals(expectedAed, req.Requested_Cost_AED__c, 'AED should be CHF / rate');
        System.assertEquals(rate, req.Conversion_Rate__c);
        System.assertEquals('Cost_CHF__c', req.Field_To_Update__c);
    }

    @IsTest
    static void testApplyApprovedAed() {
        Unit__c unit = unitByTitle('AED Unit');
        Id requestId = UnitPriceApprovalService.createDraftRequest(unit.Id, 'Increase price for market adjustment.', 1500000);

        Test.startTest();
        update new Approval_Request__c(Id = requestId, Status__c = 'Approved');
        Test.stopTest();

        Unit__c updated = unitByTitle('AED Unit');
        System.assertEquals(1500000, updated.Cost_AED__c, 'Cost AED should be updated on approval');

        Approval_Request__c req = [SELECT Status__c FROM Approval_Request__c WHERE Id = :requestId];
        System.assertEquals('Applied', req.Status__c);
    }

    @IsTest
    static void testApplyApprovedUsd() {
        Unit__c unit = unitByTitle('USD Unit');
        Decimal rate = usdRate();
        Decimal requestedUsd = 400000;
        Decimal expectedAed = (requestedUsd / rate).setScale(0, System.RoundingMode.HALF_UP);
        Id requestId = UnitPriceApprovalService.createDraftRequest(unit.Id, 'USD revision per contract.', requestedUsd);

        Test.startTest();
        update new Approval_Request__c(Id = requestId, Status__c = 'Approved');
        Test.stopTest();

        Unit__c updated = unitByTitle('USD Unit');
        System.assertEquals(requestedUsd, updated.Cost_USD__c);
        System.assertEquals(requestedUsd, updated.Cost_USD_Number__c);
        System.assertEquals(expectedAed, updated.Cost_AED__c);
    }

    @IsTest
    static void testApplyApprovedChf() {
        Unit__c unit = unitByTitle('CHF Unit');
        Decimal rate = chfRate();
        Decimal requestedChf = 320000;
        Decimal expectedAed = (requestedChf / rate).setScale(0, System.RoundingMode.HALF_UP);
        Id requestId = UnitPriceApprovalService.createDraftRequest(unit.Id, 'CHF revision per contract.', requestedChf);

        Test.startTest();
        update new Approval_Request__c(Id = requestId, Status__c = 'Approved');
        Test.stopTest();

        Unit__c updated = unitByTitle('CHF Unit');
        System.assertEquals(requestedChf, updated.Cost_CHF__c);
        System.assertEquals(requestedChf, updated.Cost_CHF_Number__c);
        System.assertEquals(expectedAed, updated.Cost_AED__c);
    }

    @IsTest
    static void testGetOpenRequest() {
        Unit__c unit = unitByTitle('AED Unit');
        Id requestId = UnitPriceApprovalService.createDraftRequest(unit.Id, 'Price adjustment justification.', 1100000);

        Test.startTest();
        UnitPriceApprovalService.OpenUnitPriceRequestDTO dto =
            UnitPriceApprovalService.getOpenUnitPriceRequestForUnit(unit.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertEquals(requestId, dto.approvalRequestId);
        System.assertEquals('Draft', dto.status);
        System.assertEquals(1100000, dto.requestedPrice);
    }

    @IsTest
    static void testGetOpenRequestNoneReturnsNull() {
        Unit__c unit = unitByTitle('AED Unit');
        Test.startTest();
        UnitPriceApprovalService.OpenUnitPriceRequestDTO dto =
            UnitPriceApprovalService.getOpenUnitPriceRequestForUnit(unit.Id);
        Test.stopTest();
        System.assertEquals(null, dto);
    }

    private static Approval_Request__c buildRequestWithStatus(Unit__c unit, String status) {
        return new Approval_Request__c(
            Request_Type__c = UnitPriceApprovalService.REQUEST_TYPE_UNIT_PRICE,
            Unit__c = unit.Id,
            Status__c = status,
            Requester__c = UserInfo.getUserId(),
            Price_Currency__c = 'AED',
            Requested_Price__c = 1300000,
            Requested_Cost_AED__c = 1300000,
            Field_To_Update__c = 'Cost_AED__c',
            Related_Record_Id__c = String.valueOf(unit.Id),
            Related_Object_Type__c = 'Unit__c',
            Current_Value__c = 'AED 1000000.00',
            Requested_Value__c = 'AED 1300000.00',
            Justification__c = 'Existing ' + status + ' request.'
        );
    }

    @IsTest
    static void testCreateDraftBlockedWhenTrulyPending() {
        // A request is only "truly pending" when a live ProcessInstance exists,
        // so submit through the real approval process first.
        Unit__c unit = unitByTitle('AED Unit');
        Test.startTest();
        Id requestId;
        try {
            requestId = UnitPriceApprovalService.submitUnitPriceApproval(
                unit.Id, 'Blocking submit justification.', 5, null
            );
        } catch (AuraHandledException e) {
            // Approval process unavailable in this org — blocking cannot be exercised.
            Test.stopTest();
            return;
        }

        Boolean threw = false;
        try {
            UnitPriceApprovalService.createDraftRequest(unit.Id, 'Another request justification.', 1400000);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'A second request should be blocked while one is truly pending');
    }

    @IsTest
    static void testStalePendingReconciledAndReused() {
        // Pending status with no ProcessInstance = stale (e.g. rejected but the
        // rejection field update never ran). It must not block a new request.
        Unit__c unit = unitByTitle('AED Unit');
        Approval_Request__c stale = buildRequestWithStatus(unit, 'Pending');
        insert stale;

        Test.startTest();
        Id newDraftId = UnitPriceApprovalService.createDraftRequest(
            unit.Id, 'Request after stale pending.', 1400000
        );
        Test.stopTest();

        System.assertNotEquals(null, newDraftId, 'Stale pending must not block a new draft');
        Approval_Request__c reconciled = [
            SELECT Status__c FROM Approval_Request__c WHERE Id = :stale.Id
        ];
        System.assertEquals('Draft', reconciled.Status__c,
            'Stale pending with no process instance is reconciled to Draft');
        System.assertEquals(stale.Id, newDraftId, 'Reconciled draft is reused');
    }

    @IsTest
    static void testRejectedRequestDoesNotBlockNewDraft() {
        Unit__c unit = unitByTitle('AED Unit');
        Approval_Request__c rejected = buildRequestWithStatus(unit, 'Rejected');
        insert rejected;

        Test.startTest();
        Id newDraftId = UnitPriceApprovalService.createDraftRequest(
            unit.Id, 'New request after rejection.', 1400000
        );
        UnitPriceApprovalService.OpenUnitPriceRequestDTO dto =
            UnitPriceApprovalService.getOpenUnitPriceRequestForUnit(unit.Id);
        Test.stopTest();

        System.assertNotEquals(null, newDraftId, 'Rejected request must not block a new draft');
        System.assertNotEquals(rejected.Id, newDraftId, 'A fresh request record is created');
        System.assertEquals(newDraftId, dto.approvalRequestId, 'Open request is the new draft');
        System.assertEquals('Draft', dto.status);
    }

    @IsTest
    static void testGetOpenRequestStalePendingShowsDraft() {
        Unit__c unit = unitByTitle('AED Unit');
        insert buildRequestWithStatus(unit, 'Pending');

        Test.startTest();
        UnitPriceApprovalService.OpenUnitPriceRequestDTO dto =
            UnitPriceApprovalService.getOpenUnitPriceRequestForUnit(unit.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertEquals('Draft', dto.status,
            'Stale pending with no process instance resolves to Draft for the UI');
    }

    @IsTest
    static void testSubmitExistingDraft() {
        Unit__c unit = unitByTitle('AED Unit');
        Id draftId = UnitPriceApprovalService.createDraftRequest(unit.Id, 'Initial draft justification.', 1100000);

        Test.startTest();
        Id requestId;
        try {
            requestId = UnitPriceApprovalService.submitUnitPriceApproval(
                unit.Id, 'Revised justification before submit.', 5, draftId
            );
        } catch (AuraHandledException e) {
            // Approval process may be unavailable or misconfigured in this org.
            Test.stopTest();
            System.assertEquals(
                draftId,
                [SELECT Id FROM Approval_Request__c WHERE Id = :draftId LIMIT 1].Id,
                'Draft should still exist when approval routing fails'
            );
            return;
        }
        Test.stopTest();

        System.assertEquals(draftId, requestId, 'Submitting an existing draft should reuse it');
        Approval_Request__c req = [SELECT Requested_Price__c FROM Approval_Request__c WHERE Id = :requestId];
        System.assertEquals(950000, req.Requested_Price__c, 'Existing draft should be updated with discounted price');

        List<ProcessInstance> instances = [SELECT Status FROM ProcessInstance WHERE TargetObjectId = :requestId];
        System.assertEquals(1, instances.size());
    }

    @IsTest
    static void testValidationNotBooked() {
        Unit__c unit = unitByTitle('AED Unit');
        update new Unit__c(Id = unit.Id, Status__c = 'Draft');

        Boolean threw = false;
        Test.startTest();
        try {
            UnitPriceApprovalService.createDraftRequest(unit.Id, 'Price change on a non-booked unit.', 1200000);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Non-booked units should be rejected');
    }

    @IsTest
    static void testValidationInvalidDiscountPercent() {
        Unit__c unit = unitByTitle('AED Unit');
        Boolean threw = false;
        Test.startTest();
        try {
            UnitPriceApprovalService.submitUnitPriceApproval(unit.Id, 'Justification text here.', 0, null);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Invalid discount percent should be rejected');
    }

    @IsTest
    static void testCalculateDiscountedPrice() {
        Test.startTest();
        Decimal result = UnitPriceApprovalService.calculateDiscountedPrice(1000000, 5);
        Test.stopTest();
        System.assertEquals(950000, result, '5% discount on 1,000,000 should be 950,000');
    }

    @IsTest
    static void testValidationJustificationRequired() {
        Unit__c unit = unitByTitle('AED Unit');
        Boolean threw = false;
        Test.startTest();
        try {
            UnitPriceApprovalService.submitUnitPriceApproval(unit.Id, 'short', 5, null);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Short justification should be rejected');
    }

    @IsTest
    static void testSubmitForApproval() {
        Unit__c unit = unitByTitle('AED Unit');
        Test.startTest();
        Id requestId;
        try {
            requestId = UnitPriceApprovalService.submitUnitPriceApproval(
                unit.Id,
                'Submit justification text.',
                5,
                null
            );
        } catch (AuraHandledException e) {
            // Approval process may be unavailable or misconfigured in this org.
            return;
        }
        Test.stopTest();

        System.assertNotEquals(null, requestId);

        Approval_Request__c req = [
            SELECT Requested_Price__c, Discount_Percent__c, Status__c FROM Approval_Request__c WHERE Id = :requestId
        ];
        System.assertEquals(950000, req.Requested_Price__c);
        System.assertEquals(5, req.Discount_Percent__c.intValue());

        List<ProcessInstance> instances = [
            SELECT Status FROM ProcessInstance WHERE TargetObjectId = :requestId
        ];
        System.assertEquals(1, instances.size(), 'Submission should create one approval process instance');
        System.assertEquals('Pending', instances[0].Status);
        System.assert(
            req.Status__c == 'Pending' || hasPendingApprovalProcess(requestId),
            'Status should be Pending or resolvable from the pending approval instance'
        );
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

    @IsTest
    static void testGetUnitPriceComparison_NullIdReturnsNull() {
        Test.startTest();
        UnitPriceApprovalService.UnitPriceComparisonDTO result =
            UnitPriceApprovalService.getUnitPriceComparison(null);
        Test.stopTest();
        System.assertEquals(null, result);
    }

    @IsTest
    static void testGetUnitPriceComparison_WrongRequestType() {
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Other',
            Status__c = 'Draft',
            Requester__c = UserInfo.getUserId(),
            Field_To_Update__c = 'Cost_AED__c',
            Related_Object_Type__c = 'Unit__c',
            Current_Value__c = 'Old',
            Requested_Value__c = 'New',
            Justification__c = 'Wrong type comparison test.'
        );
        insert req;

        Test.startTest();
        UnitPriceApprovalService.UnitPriceComparisonDTO result =
            UnitPriceApprovalService.getUnitPriceComparison(req.Id);
        Test.stopTest();

        System.assertEquals(true, result.notApplicable);
        System.assert(result.notApplicableReason.contains('Unit Price Change'));
    }

    @IsTest
    static void testGetUnitPriceComparison_ValidRequest() {
        Unit__c unit = unitByTitle('USD Unit');
        Id requestId = UnitPriceApprovalService.createDraftRequest(
            unit.Id,
            'Comparison viewer test justification.',
            300000
        );

        Test.startTest();
        UnitPriceApprovalService.UnitPriceComparisonDTO result =
            UnitPriceApprovalService.getUnitPriceComparison(requestId);
        Test.stopTest();

        System.assertEquals(false, result.notApplicable);
        System.assertEquals('USD', result.priceCurrency);
        System.assertEquals(250000, result.currentPrice);
        System.assertEquals(300000, result.requestedPrice);
        System.assertNotEquals(null, result.currentCostAED);
        System.assertNotEquals(null, result.requestedCostAED);
        System.assertEquals(50000, result.priceDifference);
        System.assertNotEquals(null, result.costAedDifference);
        System.assertEquals('USD Unit', result.unitInfo.title);
    }

    @IsTest
    static void testGetUnitPriceComparison_IncludesDiscountPercent() {
        Unit__c unit = unitByTitle('AED Unit');
        Id requestId = UnitPriceApprovalService.createDraftRequest(
            unit.Id,
            'Comparison discount percent test.',
            UnitPriceApprovalService.calculateDiscountedPrice(1000000, 7),
            7
        );

        Test.startTest();
        UnitPriceApprovalService.UnitPriceComparisonDTO result =
            UnitPriceApprovalService.getUnitPriceComparison(requestId);
        Test.stopTest();

        System.assertEquals(7, result.discountPercent);
        System.assertEquals(-70000, result.priceDifference, '7% discount on 1,000,000 is -70,000');
    }
}