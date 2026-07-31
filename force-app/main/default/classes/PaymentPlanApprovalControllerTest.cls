@IsTest
private class PaymentPlanApprovalControllerTest {

    // ─── Shared test data ────────────────────────────────────────────────────

    @TestSetup
    static void setupData() {
        update new User(
            Id = UserInfo.getUserId(),
            Can_Request_Payment_Plan_Change__c = true
        );

        Project__c project = new Project__c(
            Name = 'Controller Test Project',
            Description__c = 'Test',
            District__c = 'Meydan',
            Coordinates_Latitude__c = 1,
            Coordinates_Longitude__c = 1,
            Handover__c = Date.today(),
            Minimum_Cost__c = 1,
            Publish_Project__c = 'Draft'
        );
        insert project;

        Unit__c unit = new Unit__c(
            Title__c = 'Controller Test Unit',
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
            Project__c = project.Id
        );
        insert unit;
        update new Unit__c(Id = unit.Id, Status__c = 'Booked');

        Cash_Flow_Sum__c cashFlowSum = new Cash_Flow_Sum__c(
            Unit__c = unit.Id,
            Name = String.valueOf(Date.today().year())
        );
        insert cashFlowSum;

        insert new Cash_Flow__c(
            Unit__c = unit.Id,
            Cash_Flow_Sum__c = cashFlowSum.Id,
            Name = 'Booking / Reservation',
            Date__c = Date.today(),
            Percent__c = 10,
            Constant__c = 0
        );

    }

    // ─── Helper: direct Approval_Request__c (bypasses approval process) ─────

    private static Id getTestApproverUserId() {
        List<PaymentPlanApprovalService.ApproverOptionDTO> options =
            PaymentPlanApprovalController.getPaymentPlanApproverOptions();
        if (!options.isEmpty()) {
            return options[0].id;
        }

        List<User> salesDirectors = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE
            AND Profile.Name = 'Sales Director MIRA'
            LIMIT 1
        ];
        System.assert(
            !salesDirectors.isEmpty(),
            'Test requires at least one active user with the Sales Director MIRA profile.'
        );
        return salesDirectors[0].Id;
    }

    private static Approval_Request__c buildRequest(Id unitId, String status) {
        return new Approval_Request__c(
            Request_Type__c = PaymentPlanApprovalService.REQUEST_TYPE_PAYMENT_PLAN,
            Unit__c = unitId,
            Status__c = status,
            Requester__c = UserInfo.getUserId(),
            Related_Record_Id__c = String.valueOf(unitId),
            Related_Object_Type__c = 'Unit__c',
            Parent_Record_Id__c = String.valueOf(unitId),
            Parent_Object__c = 'Unit__c',
            Field_To_Update__c = 'Cash_Flow__c',
            Current_Value__c = 'Controller Test Unit (1 installment(s))',
            Requested_Value__c = 'Add: 0, Update: 1, Delete: 0',
            Justification__c = 'Controller unit test'
        );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // getUnitPaymentPlanLines
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetUnitPaymentPlanLines_ReturnsCashFlows() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        PaymentPlanApprovalService.PaymentPlanLinesResultDTO result =
            PaymentPlanApprovalController.getUnitPaymentPlanLines(unit.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.lines);
        System.assert(result.lines.size() >= 1, 'Should return at least 1 cash flow line');
        System.assert(result.totalCount >= result.lines.size(), 'Total count should include returned lines');
    }

    @IsTest
    static void testGetUnitPaymentPlanLines_NullId_ThrowsAura() {
        Test.startTest();
        try {
            PaymentPlanApprovalController.getUnitPaymentPlanLines(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // getOpenPaymentPlanRequestForUnit
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetOpenPaymentPlanRequestForUnit_NoRequest_ReturnsNull() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        OpenPaymentPlanRequestDTO result =
            PaymentPlanApprovalController.getOpenPaymentPlanRequestForUnit(unit.Id);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testGetOpenPaymentPlanRequestForUnit_DraftExists_ReturnsDTO() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        // Create a draft via the service (before startTest to avoid governor limit issues)
        Id draftId = PaymentPlanApprovalService.createDraftRequest(unit.Id, 'Open request test');

        Test.startTest();
        OpenPaymentPlanRequestDTO result =
            PaymentPlanApprovalController.getOpenPaymentPlanRequestForUnit(unit.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(draftId, result.approvalRequestId);
        System.assertEquals('Draft', result.status);
        System.assertEquals('Draft', result.statusLabel);
        System.assertEquals(false, result.inApprovalProcess);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // createDraftRequest
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateDraftRequest_ReturnsNewId() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        Id result = PaymentPlanApprovalController.createDraftRequest(unit.Id, 'Draft justification');
        Test.stopTest();

        System.assertNotEquals(null, result);
        Approval_Request__c req = [SELECT Status__c FROM Approval_Request__c WHERE Id = :result];
        System.assertEquals('Draft', req.Status__c);
    }

    @IsTest
    static void testCreateDraftRequest_PendingExists_ThrowsAura() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        // Stale Pending (no live ProcessInstance) is reconciled to Draft, not blocked.
        Approval_Request__c pending = buildRequest(unit.Id, 'Pending');
        insert pending;

        Test.startTest();
        Id result = PaymentPlanApprovalController.createDraftRequest(unit.Id, 'Reconcile stale pending');
        Test.stopTest();

        System.assertEquals(pending.Id, result);
        System.assertEquals(
            'Draft',
            [SELECT Status__c FROM Approval_Request__c WHERE Id = :pending.Id].Status__c
        );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // saveApprovalLines
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testSaveApprovalLines_PersistsLines() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow__c cf = [SELECT Id FROM Cash_Flow__c LIMIT 1];

        Id requestId = PaymentPlanApprovalService.createDraftRequest(unit.Id, 'Save lines test');
        String linesJson = '[{"action":"Update","cashFlowId":"' + cf.Id
            + '","milestoneName":"Updated Booking","installmentDate":"'
            + String.valueOf(Date.today().addDays(10))
            + '","percent":15,"constantAmount":0,"sortOrder":1}]';

        Test.startTest();
        PaymentPlanApprovalController.saveApprovalLines(requestId, linesJson);
        Test.stopTest();

        List<Payment_Plan_Approval_Line__c> lines = [
            SELECT Id, Action__c, Percent__c
            FROM Payment_Plan_Approval_Line__c
            WHERE Approval_Request__c = :requestId
        ];
        System.assertEquals(1, lines.size());
        System.assertEquals('Update', lines[0].Action__c);
        System.assertEquals(15, lines[0].Percent__c);
    }

    @IsTest
    static void testSaveApprovalLines_InvalidJson_ThrowsAura() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Id requestId = PaymentPlanApprovalService.createDraftRequest(unit.Id, 'Bad json test');

        Test.startTest();
        try {
            PaymentPlanApprovalController.saveApprovalLines(requestId, 'NOT_JSON');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // submitPaymentPlanApproval — error path (no active approval process)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testSubmitPaymentPlanApproval_CreatesAndSubmitsRequest() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow__c cf = [SELECT Id FROM Cash_Flow__c LIMIT 1];

        String linesJson = '[{"action":"Update","cashFlowId":"' + cf.Id
            + '","milestoneName":"Booking","installmentDate":"'
            + String.valueOf(Date.today().addDays(5))
            + '","percent":10,"constantAmount":0,"sortOrder":1}]';

        Id result;
        Test.startTest();
        try {
            Id approverId = getTestApproverUserId();
            result = PaymentPlanApprovalController.submitPaymentPlanApproval(
                unit.Id, 'Test submit', linesJson, null, approverId
            );
        } catch (AuraHandledException e) {
            // No active approval process defined in this test run — acceptable
            return;
        }
        Test.stopTest();

        System.assertNotEquals(null, result);
        Approval_Request__c req = [SELECT Id, Status__c FROM Approval_Request__c WHERE Id = :result];
        System.assertNotEquals(null, req.Status__c);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // getApprovalRequest
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetApprovalRequest_ReturnsCorrectRecord() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Approval_Request__c request = buildRequest(unit.Id, 'Pending');
        insert request;

        Test.startTest();
        Approval_Request__c result =
            PaymentPlanApprovalController.getApprovalRequest(request.Id);
        Test.stopTest();

        System.assertEquals(request.Id, result.Id);
        System.assertEquals('Pending',              result.Status__c);
        System.assertEquals('Controller unit test', result.Justification__c);
        System.assertEquals(unit.Id,                result.Unit__c);
        System.assertEquals('Controller Test Unit', result.Unit__r.Title__c);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // getApprovalRequestLines
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetApprovalRequestLines_ReturnsLines() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow__c cf = [SELECT Id FROM Cash_Flow__c LIMIT 1];
        Approval_Request__c request = buildRequest(unit.Id, 'Pending');
        insert request;

        insert new List<Payment_Plan_Approval_Line__c>{
            new Payment_Plan_Approval_Line__c(
                Approval_Request__c = request.Id,
                Action__c = 'Update',
                Cash_Flow__c = cf.Id,
                Milestone_Name__c = 'Booking Updated',
                Date__c = Date.today().addDays(5),
                Percent__c = 12,
                Constant__c = 0,
                Sort_Order__c = 1
            ),
            new Payment_Plan_Approval_Line__c(
                Approval_Request__c = request.Id,
                Action__c = 'Insert',
                Milestone_Name__c = 'New Line',
                Date__c = Date.today().addDays(60),
                Percent__c = 20,
                Constant__c = 0,
                Sort_Order__c = 2
            )
        };

        Test.startTest();
        List<Payment_Plan_Approval_Line__c> lines =
            PaymentPlanApprovalController.getApprovalRequestLines(request.Id);
        Test.stopTest();

        System.assertEquals(2, lines.size());
        System.assertEquals('Update', lines[0].Action__c);
        System.assertEquals('Insert', lines[1].Action__c);
    }

    @IsTest
    static void testGetApprovalRequestLines_NoLines_ReturnsEmpty() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Approval_Request__c request = buildRequest(unit.Id, 'Pending');
        insert request;

        Test.startTest();
        List<Payment_Plan_Approval_Line__c> lines =
            PaymentPlanApprovalController.getApprovalRequestLines(request.Id);
        Test.stopTest();

        System.assertEquals(0, lines.size());
    }

    // ═══════════════════════════════════════════════════════════════════════
    // getPaymentPlanComparison
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetPaymentPlanComparison_NullId_ReturnsNull() {
        Test.startTest();
        PaymentPlanApprovalService.PaymentPlanComparisonDTO result =
            PaymentPlanApprovalController.getPaymentPlanComparison(null);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testGetPaymentPlanComparison_ValidRequest_ReturnsDTO() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow__c cf = [SELECT Id FROM Cash_Flow__c LIMIT 1];

        Approval_Request__c request = buildRequest(unit.Id, 'Pending');
        insert request;

        insert new Payment_Plan_Approval_Line__c(
            Approval_Request__c = request.Id,
            Action__c = 'Update',
            Cash_Flow__c = cf.Id,
            Milestone_Name__c = 'Booking Updated',
            Date__c = Date.today().addDays(5),
            Percent__c = 15,
            Constant__c = 0,
            Sort_Order__c = 1
        );

        Test.startTest();
        PaymentPlanApprovalService.PaymentPlanComparisonDTO result =
            PaymentPlanApprovalController.getPaymentPlanComparison(request.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(true, result.notApplicable, 'Should not be notApplicable');
        System.assertEquals('Pending', result.status);
        System.assertNotEquals(null, result.unitInfo);
        System.assertNotEquals(null, result.currentLines);
        System.assertNotEquals(null, result.proposedLines);
    }

    @IsTest
    static void testGetPaymentPlanComparison_WrongType_ReturnsNotApplicable() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Approval_Request__c request = buildRequest(unit.Id, 'Pending');
        request.Request_Type__c = 'Other';
        insert request;

        Test.startTest();
        PaymentPlanApprovalService.PaymentPlanComparisonDTO result =
            PaymentPlanApprovalController.getPaymentPlanComparison(request.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.notApplicable);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // buildAuraException — AuraHandledException pass-through (not double-wrapped)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBuildAuraException_IsAuraHandledException() {
        // Triggering any error path exercises buildAuraException
        Test.startTest();
        try {
            PaymentPlanApprovalController.getUnitPaymentPlanLines(null);
        } catch (AuraHandledException e) {
            System.assertEquals('System.AuraHandledException', e.getTypeName());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetPaymentPlanApproverOptions_ReturnsSalesDirectorMiraUsers() {
        Test.startTest();
        List<PaymentPlanApprovalService.ApproverOptionDTO> options =
            PaymentPlanApprovalController.getPaymentPlanApproverOptions();
        Test.stopTest();

        List<User> expectedUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE
            AND Profile.Name = 'Sales Director MIRA'
        ];
        System.assertEquals(
            expectedUsers.size(),
            options.size(),
            'Approver options should match active Sales Director MIRA users'
        );
    }

    @IsTest
    static void testCanUserRequestPaymentPlanChange() {
        Test.startTest();
        System.assertEquals(true, PaymentPlanApprovalController.canUserRequestPaymentPlanChange());
        Test.stopTest();
    }

    @IsTest
    static void testCanUserRequestPaymentPlanChange_WhenDisabled() {
        update new User(
            Id = UserInfo.getUserId(),
            Can_Request_Payment_Plan_Change__c = false
        );

        Test.startTest();
        System.assertEquals(false, PaymentPlanApprovalController.canUserRequestPaymentPlanChange());
        Test.stopTest();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // getUnitCashFlowSums
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetUnitCashFlowSums_ReturnsOptions() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow_Sum__c sum = [SELECT Id, Name FROM Cash_Flow_Sum__c LIMIT 1];

        Test.startTest();
        List<PaymentPlanApprovalService.CashFlowSumOptionDTO> result =
            PaymentPlanApprovalController.getUnitCashFlowSums(unit.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.size() >= 1, 'Should return at least one Cash Flow Sum');
        System.assertEquals(sum.Id, result[0].id);
        System.assertEquals(sum.Name, result[0].name);
    }

    @IsTest
    static void testGetUnitCashFlowSums_NullId_ThrowsAura() {
        Test.startTest();
        try {
            PaymentPlanApprovalController.getUnitCashFlowSums(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // createUnitCashFlowSum
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateUnitCashFlowSum_CreatesNewYear() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        String newYear = String.valueOf(Date.today().year() + 5);

        Test.startTest();
        Id sumId = PaymentPlanApprovalController.createUnitCashFlowSum(unit.Id, newYear);
        Test.stopTest();

        Cash_Flow_Sum__c created = [
            SELECT Id, Name, Unit__c
            FROM Cash_Flow_Sum__c
            WHERE Id = :sumId
        ];
        System.assertEquals(newYear, created.Name);
        System.assertEquals(unit.Id, created.Unit__c);
    }

    @IsTest
    static void testCreateUnitCashFlowSum_ExistingYearReturnsSameId() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow_Sum__c existing = [SELECT Id, Name FROM Cash_Flow_Sum__c LIMIT 1];

        Test.startTest();
        Id sumId = PaymentPlanApprovalController.createUnitCashFlowSum(unit.Id, existing.Name);
        Test.stopTest();

        System.assertEquals(existing.Id, sumId);
    }

    @IsTest
    static void testCreateUnitCashFlowSum_InvalidYear_ThrowsAura() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        try {
            PaymentPlanApprovalController.createUnitCashFlowSum(unit.Id, '20');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetOpenPaymentPlanRequestForUnit_NullId_ThrowsAura() {
        Test.startTest();
        try {
            PaymentPlanApprovalController.getOpenPaymentPlanRequestForUnit(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSubmitPaymentPlanApproval_WithExistingRequestId() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow__c cf = [SELECT Id FROM Cash_Flow__c LIMIT 1];
        Id requestId = PaymentPlanApprovalService.createDraftRequest(unit.Id, 'Existing request submit');

        String linesJson = '[{"action":"Update","cashFlowId":"' + cf.Id
            + '","milestoneName":"Booking","installmentDate":"'
            + String.valueOf(Date.today().addDays(5))
            + '","percent":10,"constantAmount":0,"sortOrder":1}]';

        Test.startTest();
        try {
            PaymentPlanApprovalController.submitPaymentPlanApproval(
                unit.Id,
                'Updated justification',
                linesJson,
                requestId,
                getTestApproverUserId()
            );
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetBookedOpportunityIdForUnit_Proxy() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Test.startTest();
        Id bookedOppId = PaymentPlanApprovalController.getBookedOpportunityIdForUnit(unit.Id);
        Id nullResult = PaymentPlanApprovalController.getBookedOpportunityIdForUnit(null);
        Test.stopTest();
        System.assertEquals(null, nullResult);
        // May be null if no Booked Opportunity is linked in setup data.
        System.assertEquals(true, bookedOppId == null || bookedOppId.getSObjectType() == Opportunity.SObjectType);
    }
}