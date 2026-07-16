@IsTest
private class PaymentPlanComparisonReaderTest {

    // ─── Test data setup ────────────────────────────────────────────────────

    @TestSetup
    static void setupData() {
        Project__c project = new Project__c(
            Name = 'Reader Test Project',
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
            Title__c = 'Reader Test Unit',
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

        // Visible milestone
        insert new Cash_Flow__c(
            Unit__c = unit.Id,
            Cash_Flow_Sum__c = cashFlowSum.Id,
            Name = 'Booking / Reservation',
            Date__c = Date.today(),
            Percent__c = 10,
            Constant__c = 0
        );

        // Excluded milestones — should be filtered out by queryCashFlows
        insert new List<Cash_Flow__c>{
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cashFlowSum.Id,
                Name = 'DLD Fee',          Date__c = Date.today(), Percent__c = 0, Constant__c = 4000),
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cashFlowSum.Id,
                Name = 'Oqood',            Date__c = Date.today(), Percent__c = 0, Constant__c = 500),
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cashFlowSum.Id,
                Name = 'Registration Fee', Date__c = Date.today(), Percent__c = 0, Constant__c = 1000),
            new Cash_Flow__c(Unit__c = unit.Id, Cash_Flow_Sum__c = cashFlowSum.Id,
                Name = 'Purchase Taxes',   Date__c = Date.today(), Percent__c = 0, Constant__c = 2000)
        };
    }

    // ─── Helper: build an Approval_Request__c directly ──────────────────────

    private static Approval_Request__c buildRequest(Id unitId) {
        return new Approval_Request__c(
            Request_Type__c = PaymentPlanApprovalService.REQUEST_TYPE_PAYMENT_PLAN,
            Unit__c = unitId,
            Status__c = 'Pending',
            Requester__c = UserInfo.getUserId(),
            Related_Record_Id__c = String.valueOf(unitId),
            Related_Object_Type__c = 'Unit__c',
            Parent_Record_Id__c = String.valueOf(unitId),
            Parent_Object__c = 'Unit__c',
            Field_To_Update__c = 'Cash_Flow__c',
            Current_Value__c = 'Reader Test Unit (1 installment(s))',
            Requested_Value__c = 'Add: 0, Update: 1, Delete: 0',
            Justification__c = 'Reader test'
        );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // resolveApprovalRequestId
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testResolveApprovalRequestId_Null_ReturnsNull() {
        Test.startTest();
        Id result = PaymentPlanComparisonReader.resolveApprovalRequestId(null);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testResolveApprovalRequestId_ApprovalRequestId_ReturnsSelf() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Approval_Request__c request = buildRequest(unit.Id);
        insert request;

        Test.startTest();
        Id result = PaymentPlanComparisonReader.resolveApprovalRequestId(request.Id);
        Test.stopTest();

        System.assertEquals(request.Id, result);
    }

    @IsTest
    static void testResolveApprovalRequestId_UnknownId_ReturnsNull() {
        // Pass a Unit__c ID — not an AR, ProcessInstance, or Workitem
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        Id result = PaymentPlanComparisonReader.resolveApprovalRequestId(unit.Id);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // queryRequest
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testQueryRequest_ReturnsMatchingRequest() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Approval_Request__c request = buildRequest(unit.Id);
        insert request;

        Test.startTest();
        List<Approval_Request__c> result =
            PaymentPlanComparisonReader.queryRequest(request.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(request.Id,  result[0].Id);
        System.assertEquals('Pending',    result[0].Status__c);
        System.assertEquals('Reader test', result[0].Justification__c);
        System.assertNotEquals(null, result[0].Requester__r);
    }

    @IsTest
    static void testQueryRequest_NotFound_ReturnsEmpty() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        // Pass a Unit ID — no matching Approval_Request__c
        Test.startTest();
        List<Approval_Request__c> result =
            PaymentPlanComparisonReader.queryRequest(unit.Id);
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    // ═══════════════════════════════════════════════════════════════════════
    // queryUnit
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testQueryUnit_ReturnsUnit() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        List<Unit__c> result = PaymentPlanComparisonReader.queryUnit(unit.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('Reader Test Unit', result[0].Title__c);
        System.assertEquals('Tower A',          result[0].Building__c);
    }

    @IsTest
    static void testQueryUnit_NotFound_ReturnsEmpty() {
        // Pass a non-Unit ID (Approval_Request__c ID style won't match Unit query)
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Approval_Request__c request = buildRequest(unit.Id);
        insert request;

        Test.startTest();
        List<Unit__c> result = PaymentPlanComparisonReader.queryUnit(request.Id);
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    // ═══════════════════════════════════════════════════════════════════════
    // queryCashFlows — excludes DLD Fee, Oqood, Registration Fee, Purchase Taxes
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testQueryCashFlows_ExcludesFilteredMilestones() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        List<Cash_Flow__c> result = PaymentPlanComparisonReader.queryCashFlows(unit.Id);
        Test.stopTest();

        // Only 'Booking / Reservation' should be returned; the 4 excluded are filtered out
        System.assertEquals(1, result.size());
        System.assertEquals('Booking / Reservation', result[0].Name);
    }

    @IsTest
    static void testQueryCashFlows_IncludesRequiredFields() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        List<Cash_Flow__c> result = PaymentPlanComparisonReader.queryCashFlows(unit.Id);
        Test.stopTest();

        Cash_Flow__c cf = result[0];
        System.assertNotEquals(null, cf.Id);
        System.assertNotEquals(null, cf.Name);
        System.assertNotEquals(null, cf.Date__c);
        System.assertEquals(10, cf.Percent__c);
        System.assertEquals(0,  cf.Constant__c);
        // Received_Amount__c is queried — verify field is accessible (null is valid)
        System.assertEquals(null, cf.Received_Amount__c);
    }

    @IsTest
    static void testQueryCashFlows_OrderedByDate() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow_Sum__c sum = [SELECT Id FROM Cash_Flow_Sum__c LIMIT 1];

        insert new Cash_Flow__c(
            Unit__c = unit.Id, Cash_Flow_Sum__c = sum.Id,
            Name = '2nd Installment', Date__c = Date.today().addDays(30),
            Percent__c = 20, Constant__c = 0
        );
        insert new Cash_Flow__c(
            Unit__c = unit.Id, Cash_Flow_Sum__c = sum.Id,
            Name = '3rd Installment', Date__c = Date.today().addDays(60),
            Percent__c = 30, Constant__c = 0
        );

        Test.startTest();
        List<Cash_Flow__c> result = PaymentPlanComparisonReader.queryCashFlows(unit.Id);
        Test.stopTest();

        System.assertEquals(3, result.size());
        System.assertEquals('Booking / Reservation', result[0].Name);
        System.assertEquals('2nd Installment',       result[1].Name);
        System.assertEquals('3rd Installment',       result[2].Name);
    }

    @IsTest
    static void testQueryCashFlows_NoUnit_ReturnsEmpty() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Approval_Request__c request = buildRequest(unit.Id);
        insert request;

        Test.startTest();
        // Pass a non-Unit ID — no cash flows will match
        List<Cash_Flow__c> result = PaymentPlanComparisonReader.queryCashFlows(request.Id);
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    // ═══════════════════════════════════════════════════════════════════════
    // queryApprovalLines — excludes filtered milestones by name
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testQueryApprovalLines_ReturnsLinesOrderedBySortOrder() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow__c cf = [
            SELECT Id FROM Cash_Flow__c
            WHERE Name = 'Booking / Reservation' LIMIT 1
        ];

        Approval_Request__c request = buildRequest(unit.Id);
        insert request;

        insert new List<Payment_Plan_Approval_Line__c>{
            new Payment_Plan_Approval_Line__c(
                Approval_Request__c = request.Id,
                Action__c = 'Update',
                Cash_Flow__c = cf.Id,
                Milestone_Name__c = 'Booking Updated',
                Date__c = Date.today().addDays(5),
                Percent__c = 15,
                Constant__c = 0,
                Sort_Order__c = 2
            ),
            new Payment_Plan_Approval_Line__c(
                Approval_Request__c = request.Id,
                Action__c = 'Insert',
                Milestone_Name__c = 'New Installment',
                Date__c = Date.today().addDays(60),
                Percent__c = 20,
                Constant__c = 0,
                Sort_Order__c = 1
            )
        };

        Test.startTest();
        List<Payment_Plan_Approval_Line__c> result =
            PaymentPlanComparisonReader.queryApprovalLines(request.Id);
        Test.stopTest();

        System.assertEquals(2, result.size());
        // Ordered by Sort_Order__c ASC
        System.assertEquals('Insert', result[0].Action__c);
        System.assertEquals('Update', result[1].Action__c);
    }

    @IsTest
    static void testQueryApprovalLines_ExcludesFilteredMilestoneNames() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow__c cf = [
            SELECT Id FROM Cash_Flow__c
            WHERE Name = 'Booking / Reservation' LIMIT 1
        ];

        Approval_Request__c request = buildRequest(unit.Id);
        insert request;

        insert new List<Payment_Plan_Approval_Line__c>{
            new Payment_Plan_Approval_Line__c(
                Approval_Request__c = request.Id,
                Action__c = 'Update',
                Cash_Flow__c = cf.Id,
                Milestone_Name__c = 'Booking Updated',
                Date__c = Date.today().addDays(5),
                Percent__c = 15, Constant__c = 0, Sort_Order__c = 1
            ),
            // These should be excluded
            new Payment_Plan_Approval_Line__c(
                Approval_Request__c = request.Id,
                Action__c = 'Update',
                Milestone_Name__c = 'DLD Fee',
                Sort_Order__c = 2
            ),
            new Payment_Plan_Approval_Line__c(
                Approval_Request__c = request.Id,
                Action__c = 'Update',
                Milestone_Name__c = 'Oqood',
                Sort_Order__c = 3
            ),
            new Payment_Plan_Approval_Line__c(
                Approval_Request__c = request.Id,
                Action__c = 'Update',
                Milestone_Name__c = 'Registration Fee',
                Sort_Order__c = 4
            ),
            new Payment_Plan_Approval_Line__c(
                Approval_Request__c = request.Id,
                Action__c = 'Update',
                Milestone_Name__c = 'Purchase Taxes',
                Sort_Order__c = 5
            )
        };

        Test.startTest();
        List<Payment_Plan_Approval_Line__c> result =
            PaymentPlanComparisonReader.queryApprovalLines(request.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('Booking Updated', result[0].Milestone_Name__c);
    }

    @IsTest
    static void testQueryApprovalLines_NoLines_ReturnsEmpty() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Approval_Request__c request = buildRequest(unit.Id);
        insert request;

        Test.startTest();
        List<Payment_Plan_Approval_Line__c> result =
            PaymentPlanComparisonReader.queryApprovalLines(request.Id);
        Test.stopTest();

        System.assertEquals(0, result.size());
    }
}