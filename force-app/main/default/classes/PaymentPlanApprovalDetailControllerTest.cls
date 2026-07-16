@IsTest
private class PaymentPlanApprovalDetailControllerTest {

    // ─── Test data setup ────────────────────────────────────────────────────

    @TestSetup
    static void setupData() {
        Project__c project = new Project__c(
            Name = 'Detail Controller Test Project',
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
            Title__c = 'Test Unit',
            Cost_AED__c = 500000,
            Type__c = 'Apartment',
            Total_Area__c = 800,
            Living_Space__c = 600,
            Additional_Area__c = 200,
            Floor__c = 2,
            Number_of_Bedrooms__c = 1,
            Number_of_Bathrooms__c = 1,
            Status__c = 'Draft',
            Building__c = 'Block B',
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

    // ─── Helper: set up VF page context ─────────────────────────────────────

    private static void setPage(String idParam) {
        PageReference pr = new PageReference('/apex/PaymentPlanApprovalDetail');
        Test.setCurrentPage(pr);
        if (String.isNotBlank(idParam)) {
            ApexPages.currentPage().getParameters().put('id', idParam);
        }
    }

    // ─── Helper: build a direct Approval_Request__c ──────────────────────────

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
            Current_Value__c = 'Test Unit (1 installment(s))',
            Requested_Value__c = 'Add: 0, Update: 1, Delete: 0',
            Justification__c = 'Controller test'
        );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // NO RECORD ID
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testNoRecordIdParam_SetsHasError() {
        setPage(null); // no 'id' param

        Test.startTest();
        PaymentPlanApprovalDetailController ctrl = new PaymentPlanApprovalDetailController();
        Test.stopTest();

        System.assertEquals(true,  ctrl.hasError);
        System.assertEquals(false, ctrl.isPaymentPlan);
        System.assertEquals('No record ID provided.', ctrl.errorMessage);
        System.assertEquals(0, ctrl.currentRows.size());
        System.assertEquals(0, ctrl.proposedRows.size());
    }

    // ═══════════════════════════════════════════════════════════════════════
    // VALID APPROVAL REQUEST ID
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testWithValidApprovalRequestId_PopulatesRows() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow__c cf = [SELECT Id FROM Cash_Flow__c LIMIT 1];
        Cash_Flow_Sum__c sum = [SELECT Id FROM Cash_Flow_Sum__c LIMIT 1];

        // Second cash flow for delete action
        Cash_Flow__c cf2 = new Cash_Flow__c(
            Unit__c = unit.Id, Cash_Flow_Sum__c = sum.Id,
            Name = '2nd Payment', Date__c = Date.today().addDays(30),
            Percent__c = 20, Constant__c = 50000
        );
        insert cf2;

        Approval_Request__c request = buildRequest(unit.Id, 'Pending');
        insert request;

        insert new List<Payment_Plan_Approval_Line__c>{
            new Payment_Plan_Approval_Line__c(
                Approval_Request__c = request.Id,
                Action__c = 'Update',
                Cash_Flow__c = cf.Id,
                Milestone_Name__c = 'Booking Updated',
                Date__c = Date.today().addDays(7),
                Percent__c = 12,
                Constant__c = 0,
                Sort_Order__c = 1
            ),
            new Payment_Plan_Approval_Line__c(
                Approval_Request__c = request.Id,
                Action__c = 'Delete',
                Cash_Flow__c = cf2.Id,
                Milestone_Name__c = '2nd Payment',
                Sort_Order__c = 2
            ),
            new Payment_Plan_Approval_Line__c(
                Approval_Request__c = request.Id,
                Action__c = 'Insert',
                Milestone_Name__c = 'New Installment',
                Date__c = Date.today().addDays(90),
                Percent__c = 15,
                Constant__c = 1000000,
                Sort_Order__c = 3
            )
        };

        setPage(request.Id);

        Test.startTest();
        PaymentPlanApprovalDetailController ctrl = new PaymentPlanApprovalDetailController();
        Test.stopTest();

        System.assert(!ctrl.hasError, 'hasError should be false. errorMessage: ' + String.valueOf(ctrl.errorMessage));
        System.assertEquals(true,  ctrl.isPaymentPlan);
        System.assertEquals('Pending', ctrl.requestStatus);
        System.assertEquals('Test Unit', ctrl.unitTitle);
        System.assert(ctrl.currentRows.size() >= 2, 'Should have current rows');
        System.assert(ctrl.proposedRows.size() >= 2, 'Should have proposed rows');
    }

    @IsTest
    static void testWithApprovalRequestId_HeaderFieldsPopulated() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow__c cf = [SELECT Id FROM Cash_Flow__c LIMIT 1];

        Approval_Request__c request = buildRequest(unit.Id, 'Pending');
        request.Justification__c = 'Test justification text';
        insert request;

        insert new Payment_Plan_Approval_Line__c(
            Approval_Request__c = request.Id,
            Action__c = 'Update',
            Cash_Flow__c = cf.Id,
            Milestone_Name__c = 'Booking / Reservation',
            Date__c = Date.today().addDays(10),
            Percent__c = 15,
            Constant__c = 0,
            Sort_Order__c = 1
        );

        setPage(request.Id);

        Test.startTest();
        PaymentPlanApprovalDetailController ctrl = new PaymentPlanApprovalDetailController();
        Test.stopTest();

        System.assert(!ctrl.hasError, 'hasError should be false. errorMessage: ' + String.valueOf(ctrl.errorMessage));
        System.assertNotEquals(null, ctrl.requestName);
        System.assertEquals('Pending', ctrl.requestStatus);
        System.assertEquals('Test justification text', ctrl.justification);
        System.assertEquals('Test Unit', ctrl.unitTitle);
        System.assertEquals('Block B', ctrl.building);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // INVALID / UNRESOLVABLE ID  (exception path)
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testWithNonApprovalRequestId_SetsHasError() {
        // Pass a Unit__c ID — not an Approval_Request__c or ProcessInstanceWorkitem
        // The SOQL inside the else branch throws, caught by the outer try/catch
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        setPage(unit.Id);

        Test.startTest();
        PaymentPlanApprovalDetailController ctrl = new PaymentPlanApprovalDetailController();
        Test.stopTest();

        System.assertEquals(true, ctrl.hasError);
        System.assertNotEquals(null, ctrl.errorMessage);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // COMPARISON ROW — ALL CHANGE TYPES
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testComparisonRow_DeletedChangeType() {
        PaymentPlanApprovalService.ComparisonLineDTO line = new PaymentPlanApprovalService.ComparisonLineDTO();
        line.milestoneName   = 'Booking';
        line.installmentDate = '2025-06-01';
        line.percent         = 10;
        line.constantAmount  = 0;
        line.amount          = 100000;
        line.changeType      = 'deleted';
        line.hasPayments     = false;

        Test.startTest();
        PaymentPlanApprovalDetailController.ComparisonRow row =
            new PaymentPlanApprovalDetailController.ComparisonRow(line);
        Test.stopTest();

        System.assertEquals('Delete', row.badge);
        System.assertEquals(true,     row.hasBadge);
        System.assertEquals('Booking', row.milestoneName);
        System.assertEquals('10%',     row.percent);
        System.assertEquals('AED 100,000', row.constantAmount);
    }

    @IsTest
    static void testComparisonRow_UpdatedChangeType() {
        PaymentPlanApprovalService.ComparisonLineDTO line = new PaymentPlanApprovalService.ComparisonLineDTO();
        line.milestoneName   = '2nd Installment';
        line.installmentDate = '2025-09-01';
        line.percent         = 25;
        line.constantAmount  = 0;
        line.changeType      = 'updated';
        line.hasPayments     = false;

        Test.startTest();
        PaymentPlanApprovalDetailController.ComparisonRow row =
            new PaymentPlanApprovalDetailController.ComparisonRow(line);
        Test.stopTest();

        System.assertEquals('Update', row.badge);
        System.assertEquals(true,     row.hasBadge);
        System.assertEquals('25%',    row.percent);
    }

    @IsTest
    static void testComparisonRow_AddedChangeType() {
        PaymentPlanApprovalService.ComparisonLineDTO line = new PaymentPlanApprovalService.ComparisonLineDTO();
        line.milestoneName   = 'New Line';
        line.installmentDate = '2025-12-01';
        line.percent         = null;
        line.constantAmount  = 1500000;
        line.changeType      = 'added';
        line.hasPayments     = false;

        Test.startTest();
        PaymentPlanApprovalDetailController.ComparisonRow row =
            new PaymentPlanApprovalDetailController.ComparisonRow(line);
        Test.stopTest();

        System.assertEquals('New',  row.badge);
        System.assertEquals(true,   row.hasBadge);
        System.assertEquals('\u2014', row.percent); // em dash for null percent
        System.assertEquals('AED 1,500,000', row.constantAmount);
    }

    @IsTest
    static void testComparisonRow_UnchangedChangeType() {
        PaymentPlanApprovalService.ComparisonLineDTO line = new PaymentPlanApprovalService.ComparisonLineDTO();
        line.milestoneName   = 'Handover';
        line.installmentDate = '2026-01-01';
        line.percent         = 30;
        line.constantAmount  = 0;
        line.changeType      = 'unchanged';
        line.hasPayments     = false;

        Test.startTest();
        PaymentPlanApprovalDetailController.ComparisonRow row =
            new PaymentPlanApprovalDetailController.ComparisonRow(line);
        Test.stopTest();

        System.assertEquals('',    row.badge);
        System.assertEquals(false, row.hasBadge);
        System.assertEquals('30%', row.percent);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // COMPARISON ROW — NULL / BLANK VALUES SHOW EM DASH
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testComparisonRow_NullValuesShowEmDash() {
        PaymentPlanApprovalService.ComparisonLineDTO line = new PaymentPlanApprovalService.ComparisonLineDTO();
        line.milestoneName   = null;
        line.installmentDate = null;
        line.percent         = null;
        line.constantAmount  = null;
        line.changeType      = 'unchanged';
        line.hasPayments     = false;

        Test.startTest();
        PaymentPlanApprovalDetailController.ComparisonRow row =
            new PaymentPlanApprovalDetailController.ComparisonRow(line);
        Test.stopTest();

        System.assertEquals('\u2014', row.milestoneName);
        System.assertEquals('\u2014', row.installmentDate);
        System.assertEquals('\u2014', row.percent);
        System.assertEquals('\u2014', row.constantAmount);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // FORMAT AMOUNT — THOUSANDS SEPARATOR
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testFormatAmount_SmallNumber() {
        PaymentPlanApprovalService.ComparisonLineDTO line = new PaymentPlanApprovalService.ComparisonLineDTO();
        line.milestoneName = 'Test'; line.changeType = 'unchanged';
        line.constantAmount = 500;

        Test.startTest();
        PaymentPlanApprovalDetailController.ComparisonRow row =
            new PaymentPlanApprovalDetailController.ComparisonRow(line);
        Test.stopTest();

        System.assertEquals('AED 500', row.constantAmount);
    }

    @IsTest
    static void testFormatAmount_Millions() {
        PaymentPlanApprovalService.ComparisonLineDTO line = new PaymentPlanApprovalService.ComparisonLineDTO();
        line.milestoneName = 'Test'; line.changeType = 'unchanged';
        line.constantAmount = 2500000;

        Test.startTest();
        PaymentPlanApprovalDetailController.ComparisonRow row =
            new PaymentPlanApprovalDetailController.ComparisonRow(line);
        Test.stopTest();

        System.assertEquals('AED 2,500,000', row.constantAmount);
    }

    @IsTest
    static void testFormatAmount_Zero() {
        PaymentPlanApprovalService.ComparisonLineDTO line = new PaymentPlanApprovalService.ComparisonLineDTO();
        line.milestoneName = 'Test'; line.changeType = 'unchanged';
        line.constantAmount = 0;

        Test.startTest();
        PaymentPlanApprovalDetailController.ComparisonRow row =
            new PaymentPlanApprovalDetailController.ComparisonRow(line);
        Test.stopTest();

        System.assertEquals('AED 0', row.constantAmount);
    }
}