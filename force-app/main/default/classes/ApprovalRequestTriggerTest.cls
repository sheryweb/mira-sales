@IsTest
private class ApprovalRequestTriggerTest {

    // ─── Test data setup ────────────────────────────────────────────────────

    @TestSetup
    static void setupData() {
        // Opportunity for Fee Change tests
        Opportunity opp = new Opportunity(
            Name = 'Trigger Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Registration_Fees__c = 'Fully paid by the Purchaser'
        );
        insert opp;

        // Unit + cash flows for Payment Plan tests
        Project__c project = new Project__c(
            Name = 'Trigger Test Project',
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
            Title__c = 'Trigger Test Unit',
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

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static Approval_Request__c buildMinRequest(String requestType) {
        return new Approval_Request__c(
            Request_Type__c = requestType,
            Current_Value__c = 'Old Value',
            Field_To_Update__c = 'Test_Field__c',
            Requested_Value__c = 'New Value',
            Justification__c = 'Test justification',
            Related_Object_Type__c = 'Unit__c'
        );
    }

    private static Approval_Request__c buildPaymentPlanRequest(Id unitId) {
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
            Current_Value__c = 'Trigger Test Unit (1 installment(s))',
            Requested_Value__c = 'Add: 0, Update: 1, Delete: 0',
            Justification__c = 'Trigger test'
        );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BEFORE INSERT — default field population
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeInsert_DefaultsRequesterAndStatus() {
        Approval_Request__c req = buildMinRequest('Other');
        // Deliberately omit Requester__c and Status__c — trigger should set defaults

        Test.startTest();
        insert req;
        Test.stopTest();

        req = [SELECT Requester__c, Status__c FROM Approval_Request__c WHERE Id = :req.Id];
        System.assertEquals(UserInfo.getUserId(), req.Requester__c, 'Requester should default to current user');
        System.assertEquals('Draft', req.Status__c, 'Status should default to Draft');
    }

    @IsTest
    static void testBeforeInsert_ExistingRequesterNotOverwritten() {
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Approval_Request__c req = buildMinRequest('Other');
        req.Requester__c = currentUser.Id;
        req.Status__c    = 'Pending';

        Test.startTest();
        insert req;
        Test.stopTest();

        req = [SELECT Requester__c, Status__c FROM Approval_Request__c WHERE Id = :req.Id];
        System.assertEquals(currentUser.Id, req.Requester__c);
        System.assertEquals('Pending', req.Status__c);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BEFORE INSERT — Payment Plan request → populatePaymentPlanRequestOnInsert
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeInsert_PaymentPlanRequest_HeaderFieldsPopulated() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];

        Approval_Request__c req = buildPaymentPlanRequest(unit.Id);
        // Allow the trigger to repopulate the summary fields
        req.Current_Value__c  = null;
        req.Requested_Value__c = null;

        Test.startTest();
        insert req;
        Test.stopTest();

        req = [SELECT Current_Value__c, Requested_Value__c FROM Approval_Request__c WHERE Id = :req.Id];
        System.assertNotEquals(null, req.Current_Value__c,  'Trigger should populate Current_Value__c');
        System.assertNotEquals(null, req.Requested_Value__c, 'Trigger should populate Requested_Value__c');
    }

    @IsTest
    static void testBeforeInsert_PaymentPlanRequest_NoUnit_NoError() {
        // Unit__c is null → populatePaymentPlanRequestOnInsert returns early without error
        Approval_Request__c req = buildMinRequest(PaymentPlanApprovalService.REQUEST_TYPE_PAYMENT_PLAN);

        Test.startTest();
        insert req;
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM Approval_Request__c WHERE Id = :req.Id]);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BEFORE INSERT — Fee Change → Opportunity lookup
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeInsert_FeeChange_PopulatesCurrentFee() {
        Opportunity opp = [SELECT Id, Registration_Fees__c FROM Opportunity LIMIT 1];

        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c     = 'Fee Change',
            Related_Record_Id__c = opp.Id,
            Related_Object_Type__c = 'Opportunity',
            Field_To_Update__c  = 'Registration_Fees__c',
            Requested_Value__c  = 'Fully paid by the Seller',
            Justification__c    = 'Fee change test'
            // Current_Value__c intentionally omitted — trigger should set it
        );

        Test.startTest();
        insert req;
        Test.stopTest();

        req = [SELECT Current_Value__c FROM Approval_Request__c WHERE Id = :req.Id];
        System.assertEquals('Fully paid by the Purchaser', req.Current_Value__c,
            'Trigger should auto-populate Current_Value__c from Opportunity');
    }

    @IsTest
    static void testBeforeInsert_FeeChange_SameFee_ThrowsError() {
        Opportunity opp = [SELECT Id, Registration_Fees__c FROM Opportunity LIMIT 1];

        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c     = 'Fee Change',
            Related_Record_Id__c = opp.Id,
            Related_Object_Type__c = 'Opportunity',
            Field_To_Update__c  = 'Registration_Fees__c',
            Requested_Value__c  = 'Fully paid by the Purchaser', // same as current
            Justification__c    = 'Same fee test'
        );

        Test.startTest();
        try {
            insert req;
            System.assert(false, 'Should throw DmlException for same fee');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Requested fee must be different'),
                'Error should mention fee difference requirement');
        }
        Test.stopTest();
    }

    @IsTest
    static void testBeforeInsert_FeeChange_BlankRequestedValue_ThrowsError() {
        Opportunity opp = [SELECT Id, Registration_Fees__c FROM Opportunity LIMIT 1];

        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c      = 'Fee Change',
            Related_Record_Id__c  = opp.Id,
            Related_Object_Type__c = 'Opportunity',
            Field_To_Update__c   = 'Registration_Fees__c',
            Requested_Value__c   = '',   // blank
            Justification__c     = 'Blank fee test',
            Current_Value__c     = 'Placeholder'
        );

        Test.startTest();
        try {
            insert req;
            System.assert(false, 'Should throw DmlException for blank requested value');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Requested fee cannot be empty'),
                'Error should mention blank fee: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testBeforeInsert_FeeChange_NoRelatedRecord_NoLookup() {
        // Fee Change with no Related_Record_Id__c → opportunityIds stays empty → no query
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c      = 'Fee Change',
            Related_Object_Type__c = 'Opportunity',
            Field_To_Update__c   = 'Registration_Fees__c',
            Requested_Value__c   = 'Fully paid by the Seller',
            Justification__c     = 'No related record',
            Current_Value__c     = 'Fully paid by the Purchaser'
        );

        Test.startTest();
        insert req;
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM Approval_Request__c WHERE Id = :req.Id]);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BEFORE UPDATE — Fee Change protections
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeUpdate_FeeChange_PreventCurrentValueChange() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c      = 'Fee Change',
            Related_Record_Id__c  = opp.Id,
            Related_Object_Type__c = 'Opportunity',
            Field_To_Update__c   = 'Registration_Fees__c',
            Requested_Value__c   = 'Fully paid by the Seller',
            Justification__c     = 'Before update test'
        );
        insert req;

        req = [SELECT Id, Current_Value__c FROM Approval_Request__c WHERE Id = :req.Id];
        req.Current_Value__c = '50% payable by Purchaser, 50% payable by Seller, Purchaser pays all administration fees';

        Test.startTest();
        try {
            update req;
            System.assert(false, 'Should throw DmlException for current fee modification');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Current fee cannot be modified'),
                'Error should mention current fee protection: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testBeforeUpdate_FeeChange_PreventRelatedRecordChange() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c      = 'Fee Change',
            Related_Record_Id__c  = opp.Id,
            Related_Object_Type__c = 'Opportunity',
            Field_To_Update__c   = 'Registration_Fees__c',
            Requested_Value__c   = 'Fully paid by the Seller',
            Justification__c     = 'Related record change test'
        );
        insert req;

        req = [SELECT Id, Related_Record_Id__c FROM Approval_Request__c WHERE Id = :req.Id];
        req.Related_Record_Id__c = UserInfo.getUserId(); // change to something else

        Test.startTest();
        try {
            update req;
            System.assert(false, 'Should throw DmlException for related record change');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Related record cannot be changed'),
                'Error should mention related record protection: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testBeforeUpdate_FeeChange_UnrelatedFieldChange_NoError() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c      = 'Fee Change',
            Related_Record_Id__c  = opp.Id,
            Related_Object_Type__c = 'Opportunity',
            Field_To_Update__c   = 'Registration_Fees__c',
            Requested_Value__c   = 'Fully paid by the Seller',
            Justification__c     = 'Original justification'
        );
        insert req;

        req = [SELECT Id, Justification__c FROM Approval_Request__c WHERE Id = :req.Id];
        req.Justification__c = 'Updated justification';

        Test.startTest();
        update req;
        Test.stopTest();

        req = [SELECT Justification__c FROM Approval_Request__c WHERE Id = :req.Id];
        System.assertEquals('Updated justification', req.Justification__c);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BEFORE UPDATE — Payment Plan: Unit__c cannot change once set
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testBeforeUpdate_PaymentPlan_PreventUnitChange() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Approval_Request__c req = buildPaymentPlanRequest(unit.Id);
        insert req;

        // Insert a second unit to change to
        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        Unit__c unit2 = new Unit__c(
            Title__c = 'Second Unit', Cost_AED__c = 500000,
            Type__c = 'Apartment', Total_Area__c = 800,
            Living_Space__c = 600, Additional_Area__c = 200,
            Floor__c = 2, Number_of_Bedrooms__c = 1,
            Number_of_Bathrooms__c = 1, Status__c = 'Draft',
            Building__c = 'Tower B', Panorama_Link__c = 'Link',
            Project__c = project.Id
        );
        insert unit2;

        req = [SELECT Id, Unit__c FROM Approval_Request__c WHERE Id = :req.Id];
        req.Unit__c = unit2.Id;

        Test.startTest();
        try {
            update req;
            System.assert(false, 'Should throw DmlException for unit change');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Unit cannot be changed'),
                'Error should mention unit protection: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testBeforeUpdate_PaymentPlan_UnitFromNull_NoError() {
        // Insert request without Unit__c, then set Unit__c → allowed (old Unit was null)
        Approval_Request__c req = buildMinRequest(PaymentPlanApprovalService.REQUEST_TYPE_PAYMENT_PLAN);
        insert req;

        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        req = [SELECT Id, Unit__c FROM Approval_Request__c WHERE Id = :req.Id];
        req.Unit__c = unit.Id;

        Test.startTest();
        update req;
        Test.stopTest();

        req = [SELECT Unit__c FROM Approval_Request__c WHERE Id = :req.Id];
        System.assertEquals(unit.Id, req.Unit__c);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // AFTER UPDATE — Payment Plan status changes
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_SameStatus_NoAction() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Approval_Request__c req = buildPaymentPlanRequest(unit.Id);
        insert req;

        // Update something other than Status__c — afterUpdate should skip
        req = [SELECT Id, Justification__c FROM Approval_Request__c WHERE Id = :req.Id];
        req.Justification__c = 'Updated justification';

        Test.startTest();
        update req;
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM Approval_Request__c WHERE Id = :req.Id]);
    }

    @IsTest
    static void testAfterUpdate_NonPaymentPlanType_Skipped() {
        Approval_Request__c req = buildMinRequest('Other');
        req.Status__c = 'Pending';
        insert req;

        req = [SELECT Id, Status__c FROM Approval_Request__c WHERE Id = :req.Id];
        req.Status__c = 'Approved';

        Test.startTest();
        update req;
        Test.stopTest();

        // No payment plan logic triggered — just verify no exception thrown
        System.assertEquals('Approved', [SELECT Status__c FROM Approval_Request__c WHERE Id = :req.Id].Status__c);
    }

    @IsTest
    static void testAfterUpdate_StatusToRejected_NoApplyChanges() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Approval_Request__c req = buildPaymentPlanRequest(unit.Id);
        insert req;

        req = [SELECT Id, Status__c FROM Approval_Request__c WHERE Id = :req.Id];
        req.Status__c = 'Rejected';

        Test.startTest();
        update req;
        Test.stopTest();

        // Status changed but not to 'Approved' — applyApprovedChanges should NOT run
        System.assertEquals('Rejected', [SELECT Status__c FROM Approval_Request__c WHERE Id = :req.Id].Status__c);
    }

    @IsTest
    static void testAfterUpdate_StatusToApproved_AppliesChanges() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Cash_Flow__c cf = [SELECT Id FROM Cash_Flow__c LIMIT 1];

        Approval_Request__c req = buildPaymentPlanRequest(unit.Id);
        insert req;

        insert new Payment_Plan_Approval_Line__c(
            Approval_Request__c = req.Id,
            Action__c           = 'Update',
            Cash_Flow__c        = cf.Id,
            Milestone_Name__c   = 'Booking Updated',
            Date__c             = Date.today().addDays(10),
            Percent__c          = 15,
            Constant__c         = 0,
            Sort_Order__c       = 1
        );

        req = [SELECT Id, Status__c FROM Approval_Request__c WHERE Id = :req.Id];
        req.Status__c = 'Approved';

        Test.startTest();
        update req;
        Test.stopTest();

        // Verify the cash flow was updated by applyApprovedChanges
        Cash_Flow__c updated = [SELECT Percent__c FROM Cash_Flow__c WHERE Id = :cf.Id];
        System.assertEquals(15, updated.Percent__c, 'Cash flow should be updated after approval');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // AFTER UPDATE — Unit Price Change status changes
    // ═══════════════════════════════════════════════════════════════════════

    @IsTest
    static void testAfterUpdate_StatusToApproved_UnitPriceAppliesChanges() {
        Unit__c unit = [SELECT Id, Cost_AED__c FROM Unit__c LIMIT 1];
        unit.Status__c = 'Booked';
        update unit;

        Id requestId = UnitPriceApprovalService.createDraftRequest(
            unit.Id,
            'Trigger handler unit price test.',
            1500000
        );

        Approval_Request__c req = [SELECT Id, Status__c FROM Approval_Request__c WHERE Id = :requestId];
        req.Status__c = 'Approved';

        Test.startTest();
        update req;
        Test.stopTest();

        Unit__c updatedUnit = [SELECT Cost_AED__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals(1500000, updatedUnit.Cost_AED__c, 'Unit cost should update after approval');

        Approval_Request__c applied = [SELECT Status__c FROM Approval_Request__c WHERE Id = :requestId];
        System.assertEquals('Applied', applied.Status__c);
    }

    @IsTest
    static void testBeforeUpdate_UnitPrice_PreventUnitChange() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        unit.Status__c = 'Booked';
        update unit;

        Id requestId = UnitPriceApprovalService.createDraftRequest(
            unit.Id,
            'Unit price unit lock test.',
            1200000
        );

        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        Unit__c unit2 = new Unit__c(
            Title__c = 'Unit Price Second Unit',
            Cost_AED__c = 500000,
            Type__c = 'Apartment',
            Total_Area__c = 800,
            Living_Space__c = 600,
            Additional_Area__c = 200,
            Floor__c = 2,
            Number_of_Bedrooms__c = 1,
            Number_of_Bathrooms__c = 1,
            Status__c = 'Draft',
            Building__c = 'Tower B',
            Panorama_Link__c = 'Link',
            Project__c = project.Id
        );
        insert unit2;

        Approval_Request__c req = [SELECT Id, Unit__c FROM Approval_Request__c WHERE Id = :requestId];
        req.Unit__c = unit2.Id;

        Test.startTest();
        try {
            update req;
            System.assert(false, 'Should throw DmlException for unit change');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Unit cannot be changed'),
                'Error should mention unit protection: ' + e.getMessage());
        }
        Test.stopTest();
    }
}