@IsTest
private class OpportunityApprovalHistoryControllerTest {

    private static final String UNIT_PRICE = 'Unit Price Change';
    private static final String PERM_SET = 'Approval_History_Viewer';

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static User buildAdminUser(String alias) {
        return buildUserOnProfile(alias, 'System Administrator');
    }

    // A user on a profile that does NOT have the View_Approval_History custom permission,
    // for the permission-denied path. (System Administrator now grants it, so can't be used here.)
    private static User buildUserWithoutPermission(String alias) {
        return buildUserOnProfile(alias, 'Minimum Access - Salesforce');
    }

    private static User buildUserOnProfile(String alias, String profileName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        String uniq = alias + String.valueOf(System.now().getTime()) + String.valueOf(Crypto.getRandomInteger());
        return new User(
            FirstName = 'ApprovalHist',
            LastName = alias,
            Alias = alias.left(8),
            Email = uniq + '@example.com.invalid',
            Username = uniq + '@example.com.invalid',
            ProfileId = p.Id,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Dubai'
        );
    }

    private static void assignPermission(Id userId) {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :PERM_SET LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id);
    }

    /** Creates a Unit, an Opportunity (optionally linked to the Unit) and an
     *  Approval_Request anchored to the Unit. Returns the Opportunity Id. */
    private static Id buildScenario(Boolean linkUnit, String requestType) {
        Unit__c unit = new Unit__c();
        insert unit;

        Opportunity opp = new Opportunity(
            Name = 'AH Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Unit__c = linkUnit ? unit.Id : null
        );
        insert opp;

        if (requestType != null) {
            insert new Approval_Request__c(
                Request_Type__c = requestType,
                Status__c = 'Pending',
                Parent_Object__c = 'Unit__c',
                Parent_Record_Id__c = String.valueOf(unit.Id),
                Related_Object_Type__c = 'Unit__c',
                Current_Value__c = 'AED 1,000,000',
                Requested_Value__c = 'AED 950,000',
                Field_To_Update__c = 'Cost_AED__c',
                Justification__c = 'Test justification for history',
                Requester__c = UserInfo.getUserId()
            );
        }
        return opp.Id;
    }

    // ─── Tests ───────────────────────────────────────────────────────────────

    @IsTest
    static void getApprovalHistory_returnsTrackedRequests() {
        User admin = buildAdminUser('allow');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert admin;
            assignPermission(admin.Id);
        }

        Id oppId = buildScenario(true, UNIT_PRICE);

        Test.startTest();
        List<OpportunityApprovalHistoryController.RequestHistory> result;
        System.runAs(admin) {
            result = OpportunityApprovalHistoryController.getApprovalHistory(oppId);
        }
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return the one tracked request');
        OpportunityApprovalHistoryController.RequestHistory r = result[0];
        System.assertEquals(UNIT_PRICE, r.requestType);
        System.assertEquals('AED 1,000,000', r.currentValue);
        System.assertEquals('AED 950,000', r.requestedValue);
        System.assertNotEquals(null, r.steps, 'Steps list should never be null');
    }

    @IsTest
    static void getApprovalHistory_withoutPermission_throws() {
        User noPerm = buildUserWithoutPermission('deny');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert noPerm;
        }

        Id oppId = buildScenario(true, UNIT_PRICE);

        Test.startTest();
        Boolean threw = false;
        System.runAs(noPerm) {
            try {
                OpportunityApprovalHistoryController.getApprovalHistory(oppId);
            } catch (AuraHandledException e) {
                threw = true;
            }
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when the user lacks the View_Approval_History permission');
    }

    @IsTest
    static void getApprovalHistory_opportunityWithoutUnit_returnsEmpty() {
        User admin = buildAdminUser('nounit');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert admin;
            assignPermission(admin.Id);
        }

        Id oppId = buildScenario(false, null);

        Test.startTest();
        List<OpportunityApprovalHistoryController.RequestHistory> result;
        System.runAs(admin) {
            result = OpportunityApprovalHistoryController.getApprovalHistory(oppId);
        }
        Test.stopTest();

        System.assertEquals(0, result.size(), 'No Unit on the Opportunity → no history');
    }

    @IsTest
    static void getApprovalHistory_nullId_returnsEmpty() {
        User admin = buildAdminUser('nullid');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert admin;
            assignPermission(admin.Id);
        }

        Test.startTest();
        List<OpportunityApprovalHistoryController.RequestHistory> result;
        System.runAs(admin) {
            result = OpportunityApprovalHistoryController.getApprovalHistory(null);
        }
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Null Opportunity Id → empty list');
    }

    // Covers the StepInfo / RequestHistory wrapper constructors directly — the native
    // ProcessInstanceStep path can't be exercised end-to-end in an Apex test.
    @IsTest
    static void wrapperConstructors_areCovered() {
        ProcessInstanceStep step = new ProcessInstanceStep();
        OpportunityApprovalHistoryController.StepInfo si =
            new OpportunityApprovalHistoryController.StepInfo(step);
        System.assertEquals(null, si.actorName, 'no actor on an empty step');

        buildScenario(true, UNIT_PRICE);
        Approval_Request__c req = [
            SELECT Id, Name, Request_Type__c, Status__c, Current_Value__c, Requested_Value__c,
                   Field_To_Update__c, Justification__c, Requester__r.Name, CreatedDate
            FROM Approval_Request__c
            LIMIT 1
        ];

        OpportunityApprovalHistoryController.RequestHistory rh =
            new OpportunityApprovalHistoryController.RequestHistory(
                req, new List<OpportunityApprovalHistoryController.StepInfo>{ si });
        System.assertEquals(UNIT_PRICE, rh.requestType, 'request type carried through');
        System.assertEquals(1, rh.steps.size(), 'steps list carried through');

        // Null steps -> constructor substitutes an empty list (other branch).
        OpportunityApprovalHistoryController.RequestHistory rhNull =
            new OpportunityApprovalHistoryController.RequestHistory(req, null);
        System.assertEquals(0, rhNull.steps.size(), 'null steps -> empty list');
    }
}