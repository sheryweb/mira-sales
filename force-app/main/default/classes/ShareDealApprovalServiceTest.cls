@IsTest
private class ShareDealApprovalServiceTest {

    @TestSetup
    static void setupData() {
        Profile salesManagerProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Sales Manager MIRA'
            LIMIT 1
        ];

        User managerUser = new User(
            Alias = 'sdmgr',
            LastName = 'ShareManager',
            Email = 'share.manager@example.com',
            Username = 'share.manager.' + System.currentTimeMillis() + '@example.com',
            ProfileId = salesManagerProfile.Id,
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert managerUser;

        User ownerUser = new User(
            Alias = 'sdown',
            LastName = 'ShareOwner',
            Email = 'share.owner@example.com',
            Username = 'share.owner.' + System.currentTimeMillis() + '@example.com',
            ProfileId = salesManagerProfile.Id,
            ManagerId = managerUser.Id,
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        User sharedRm = new User(
            Alias = 'sdshr',
            LastName = 'SharePartner',
            Email = 'share.partner@example.com',
            Username = 'share.partner.' + System.currentTimeMillis() + '@example.com',
            ProfileId = salesManagerProfile.Id,
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert new List<User>{ ownerUser, sharedRm };

        // Approvals use submitting user's Manager hierarchy when not record-owner based.
        update new User(Id = UserInfo.getUserId(), ManagerId = managerUser.Id);

        // Avoid mixed-DML (User + non-setup objects) and prod stage validations:
        // Opportunities may only be created in New, then moved to Booked with a Unit.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Project__c project = new Project__c(
                Name = 'Share Deal Test Project',
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
                Title__c = 'Share Deal Unit',
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
            unit.Status__c = 'Booked';
            update unit;

            // Sales Manager owners need Unit visibility to stamp Unit__c on Approval_Request__c.
            insert new List<Unit__Share>{
                new Unit__Share(
                    ParentId = unit.Id,
                    UserOrGroupId = ownerUser.Id,
                    AccessLevel = 'Edit',
                    RowCause = Schema.Unit__Share.RowCause.Manual
                ),
                new Unit__Share(
                    ParentId = unit.Id,
                    UserOrGroupId = sharedRm.Id,
                    AccessLevel = 'Read',
                    RowCause = Schema.Unit__Share.RowCause.Manual
                )
            };

            Account account = new Account(Name = 'Share Deal Test Account');
            insert account;

            Opportunity opp = new Opportunity(
                Name = 'Share Deal Opp',
                StageName = 'New',
                CloseDate = Date.today().addDays(30),
                AccountId = account.Id,
                OwnerId = ownerUser.Id
            );
            insert opp;

            opp.Unit__c = unit.Id;
            opp.StageName = 'Booked';
            update opp;
        }
    }

    private static Opportunity getOpp() {
        // Production may overwrite Opportunity.Name via automation; locate by test Account.
        return [
            SELECT Id, OwnerId, StageName, Share_Deal__c, Shared_RM__c, Share_Deal_Status__c, Unit_Price__c
            FROM Opportunity
            WHERE Account.Name = 'Share Deal Test Account'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    private static User getSharedRm() {
        return [SELECT Id, Name FROM User WHERE Alias = 'sdshr' LIMIT 1];
    }

    private static User getOwnerUser() {
        return [SELECT Id, Name FROM User WHERE Alias = 'sdown' LIMIT 1];
    }

    private static Id getLineManagerUserId() {
        List<User> salesDirectors = [
            SELECT Id
            FROM User
            WHERE IsActive = true
              AND Profile.Name = :ShareDealApprovalService.LINE_MANAGER_PROFILE
            LIMIT 1
        ];
        System.assert(
            !salesDirectors.isEmpty(),
            'Test requires at least one active user with the Sales Director MIRA profile.'
        );
        return salesDirectors[0].Id;
    }

    private static Approval_Request__c newShareDealRequest(
        Id opportunityId,
        Id requesterId,
        Id requestedSharedRmId,
        String status,
        String justification
    ) {
        return new Approval_Request__c(
            Request_Type__c = ShareDealApprovalService.REQUEST_TYPE_SHARE_DEAL,
            Status__c = status,
            Opportunity__c = opportunityId,
            Requested_Shared_RM__c = requestedSharedRmId,
            Requester__c = requesterId,
            Justification__c = justification,
            Field_To_Update__c = 'Shared_RM__c',
            Related_Object_Type__c = 'Opportunity',
            Related_Record_Id__c = String.valueOf(opportunityId),
            Parent_Object__c = 'Opportunity',
            Parent_Record_Id__c = String.valueOf(opportunityId),
            Current_Value__c = 'Single deal',
            Requested_Value__c = 'Share 50/50'
        );
    }

    @IsTest
    static void testGetShareDealInfoEligible() {
        Opportunity opp = getOpp();
        User ownerUser = getOwnerUser();

        ShareDealApprovalService.ShareDealInfoDTO info;
        System.runAs(ownerUser) {
            Test.startTest();
            info = ShareDealApprovalController.getShareDealInfo(opp.Id);
            Test.stopTest();
        }

        System.assertEquals(true, info.eligible, 'Booked owner should be eligible');
        System.assertEquals(opp.Id, info.opportunityId);
    }

    @IsTest
    static void testNonOwnerWithoutPrivilegeIsIneligible() {
        Opportunity opp = getOpp();
        User nonOwner = getSharedRm();

        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new OpportunityShare(
                OpportunityId = opp.Id,
                UserOrGroupId = nonOwner.Id,
                OpportunityAccessLevel = 'Edit',
                RowCause = Schema.OpportunityShare.RowCause.Manual
            );
        }

        ShareDealApprovalService.forcePrivilegedRequester = false;
        ShareDealApprovalService.ShareDealInfoDTO info;
        System.runAs(nonOwner) {
            Test.startTest();
            info = ShareDealApprovalController.getShareDealInfo(opp.Id);
            Test.stopTest();
        }

        System.assertEquals(false, info.eligible, 'Non-owner without privilege must be ineligible');
        System.assert(
            info.ineligibleReason != null && info.ineligibleReason.contains('Opportunity Owner'),
            'Reason should mention who may request: ' + info.ineligibleReason
        );
    }

    @IsTest
    static void testSystemAdminNonOwnerIsEligible() {
        Opportunity opp = getOpp();
        System.assertNotEquals(
            UserInfo.getUserId(),
            opp.OwnerId,
            'Test runner must not be the Opportunity Owner'
        );

        ShareDealApprovalService.forcePrivilegedRequester = null;
        Test.startTest();
        ShareDealApprovalService.ShareDealInfoDTO info =
            ShareDealApprovalController.getShareDealInfo(opp.Id);
        Test.stopTest();

        System.assertEquals(true, info.eligible,
            'System Administrator may request Share Deal without being the Owner');
    }

    @IsTest
    static void testOpsGroupMemberNonOwnerIsEligible() {
        Opportunity opp = getOpp();
        User nonOwner = getSharedRm();

        Group g = new Group(Name = 'Test Share Deal Ops', DeveloperName = 'Test_Share_Deal_Ops', Type = 'Regular');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert g;
            insert new GroupMember(GroupId = g.Id, UserOrGroupId = nonOwner.Id);
            insert new OpportunityShare(
                OpportunityId = opp.Id,
                UserOrGroupId = nonOwner.Id,
                OpportunityAccessLevel = 'Edit',
                RowCause = Schema.OpportunityShare.RowCause.Manual
            );
        }
        ShareDealApprovalService.PRIVILEGED_REQUESTER_GROUP_DEV_NAMES =
            new Set<String>{ 'Test_Share_Deal_Ops' };
        ShareDealApprovalService.forcePrivilegedRequester = null;

        ShareDealApprovalService.ShareDealInfoDTO info;
        System.runAs(nonOwner) {
            Test.startTest();
            info = ShareDealApprovalController.getShareDealInfo(opp.Id);
            Test.stopTest();
        }

        System.assertEquals(true, info.eligible, 'Ops public-group member may raise Share Deal');
    }

    @IsTest
    static void testPrivilegedNonOwnerCanSubmit() {
        Opportunity opp = getOpp();
        User sharedRm = getSharedRm();
        System.assertNotEquals(UserInfo.getUserId(), opp.OwnerId);

        // System Administrator profile path (no force hook) — ops raising on behalf of RM.
        ShareDealApprovalService.forcePrivilegedRequester = null;
        Id requestId;
        Test.startTest();
        requestId = ShareDealApprovalController.submitShareDealApproval(
            opp.Id,
            sharedRm.Id,
            'Ops-raised share deal request for this booking.',
            null,
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, requestId, 'Privileged non-owner submit should succeed');
        Approval_Request__c saved = [
            SELECT Status__c, Requested_Shared_RM__c
            FROM Approval_Request__c
            WHERE Id = :requestId
        ];
        System.assertEquals('Pending', saved.Status__c);
        System.assertEquals(sharedRm.Id, saved.Requested_Shared_RM__c);
    }

    @IsTest
    static void testGetEligibleSharedRmOptionsExcludesOwner() {
        Opportunity opp = getOpp();
        User ownerUser = getOwnerUser();

        List<ShareDealApprovalService.RmOptionDTO> options;
        System.runAs(ownerUser) {
            Test.startTest();
            options = ShareDealApprovalController.getEligibleSharedRmOptions(opp.Id);
            Test.stopTest();
        }

        for (ShareDealApprovalService.RmOptionDTO opt : options) {
            System.assertNotEquals(ownerUser.Id, opt.id, 'Owner must not appear as Shared RM option');
        }
    }

    @IsTest
    static void testApplyApprovedChangesCreatesShareDealAndCredits() {
        Opportunity opp = getOpp();
        User sharedRm = getSharedRm();

        Approval_Request__c request = newShareDealRequest(
            opp.Id,
            opp.OwnerId,
            sharedRm.Id,
            'Approved',
            'Jointly closed this booking with partner RM.'
        );
        insert request;

        Test.startTest();
        ShareDealApprovalService.applyApprovedChanges(request.Id);
        Test.stopTest();

        Opportunity updated = [
            SELECT Share_Deal__c, Shared_RM__c, Share_Deal_Status__c, Deal_Type__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        System.assertEquals(true, updated.Share_Deal__c);
        System.assertEquals(sharedRm.Id, updated.Shared_RM__c);
        System.assertEquals('Approved', updated.Share_Deal_Status__c);
        System.assertEquals('Share', updated.Deal_Type__c);

        List<RM_Deal_Credit__c> credits = [
            SELECT RM__c, Credit_Percent__c, Credit_Amount__c, Is_Primary__c, Deal_Type__c
            FROM RM_Deal_Credit__c
            WHERE Opportunity__c = :opp.Id
            ORDER BY Is_Primary__c DESC
        ];
        System.assertEquals(2, credits.size(), 'Share deal should create two credit rows');
        System.assertEquals(50, credits[0].Credit_Percent__c);
        System.assertEquals(50, credits[1].Credit_Percent__c);
        System.assertEquals('Share', credits[0].Deal_Type__c);

        Approval_Request__c applied = [
            SELECT Status__c FROM Approval_Request__c WHERE Id = :request.Id
        ];
        System.assertEquals('Applied', applied.Status__c);
    }

    @IsTest
    static void testHandleRejectedSetsStatus() {
        Opportunity opp = getOpp();
        update new Opportunity(Id = opp.Id, Share_Deal_Status__c = 'Pending');

        Approval_Request__c request = newShareDealRequest(
            opp.Id,
            opp.OwnerId,
            null,
            'Rejected',
            'Rejected share deal request text.'
        );
        insert request;

        Test.startTest();
        ShareDealApprovalService.handleRejected(request.Id);
        Test.stopTest();

        Opportunity updated = [
            SELECT Share_Deal_Status__c, Share_Deal__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        System.assertEquals('Rejected', updated.Share_Deal_Status__c);
        System.assertEquals(false, updated.Share_Deal__c);
    }

    @IsTest
    static void testApplyRejectsSameOwnerAsSharedRm() {
        Opportunity opp = getOpp();

        Approval_Request__c request = newShareDealRequest(
            opp.Id,
            opp.OwnerId,
            opp.OwnerId,
            'Approved',
            'Invalid same-owner share attempt.'
        );
        insert request;

        Boolean threw = false;
        try {
            Test.startTest();
            ShareDealApprovalService.applyApprovedChanges(request.Id);
            Test.stopTest();
        } catch (Exception e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Same owner as Shared RM must fail');
    }

    @IsTest
    static void testSingleDealCreditOnInsert() {
        Opportunity opp = getOpp();
        List<RM_Deal_Credit__c> credits = [
            SELECT Credit_Percent__c, Is_Primary__c, Deal_Type__c, RM__c
            FROM RM_Deal_Credit__c
            WHERE Opportunity__c = :opp.Id
        ];
        System.assertEquals(1, credits.size(), 'Single deal should create one credit row on insert');
        System.assertEquals(100, credits[0].Credit_Percent__c);
        System.assertEquals(true, credits[0].Is_Primary__c);
        System.assertEquals('Single', credits[0].Deal_Type__c);
        System.assertEquals(opp.OwnerId, credits[0].RM__c);
    }

    @IsTest
    static void testRebuildBatch() {
        Opportunity opp = getOpp();
        Test.startTest();
        Database.executeBatch(new RMDealCreditRebuildBatch(new Set<Id>{ opp.Id }), 50);
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM RM_Deal_Credit__c WHERE Opportunity__c = :opp.Id]
        );
    }

    @IsTest
    static void testControllerOpenRequestNullWhenNone() {
        Opportunity opp = getOpp();
        User ownerUser = getOwnerUser();
        ShareDealApprovalService.OpenShareDealRequestDTO openReq;
        System.runAs(ownerUser) {
            openReq = ShareDealApprovalController.getOpenShareDealRequest(opp.Id);
        }
        System.assertEquals(null, openReq);
    }

    @IsTest
    static void testOpenRequestReturnsDraft() {
        Opportunity opp = getOpp();
        User ownerUser = getOwnerUser();
        User sharedRm = getSharedRm();

        Approval_Request__c draft;
        ShareDealApprovalService.OpenShareDealRequestDTO openReq;
        System.runAs(ownerUser) {
            // Insert as owner so with-sharing open-request query can see it.
            draft = newShareDealRequest(
                opp.Id,
                ownerUser.Id,
                sharedRm.Id,
                'Draft',
                'Draft share deal request for coverage.'
            );
            insert draft;

            Test.startTest();
            openReq = ShareDealApprovalController.getOpenShareDealRequest(opp.Id);
            Test.stopTest();
        }
        System.assertNotEquals(null, openReq);
        System.assertEquals(draft.Id, openReq.approvalRequestId);
        System.assertEquals('Draft', openReq.status);
    }

    @IsTest
    static void testGetBookedOpportunityIdForUnit() {
        Opportunity opp = getOpp();
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Title__c = 'Share Deal Unit' LIMIT 1];

        Test.startTest();
        Id bookedOppId = ShareDealApprovalController.getBookedOpportunityIdForUnit(unit.Id);
        Test.stopTest();

        System.assertEquals(opp.Id, bookedOppId);
    }

    @IsTest
    static void testRebuildCreditsOnShareFieldUpdate() {
        Opportunity opp = getOpp();
        User sharedRm = getSharedRm();

        Test.startTest();
        update new Opportunity(
            Id = opp.Id,
            Share_Deal__c = true,
            Shared_RM__c = sharedRm.Id,
            Share_Deal_Status__c = 'Approved'
        );
        Test.stopTest();

        List<RM_Deal_Credit__c> credits = [
            SELECT Credit_Percent__c, Deal_Type__c
            FROM RM_Deal_Credit__c
            WHERE Opportunity__c = :opp.Id
        ];
        System.assertEquals(2, credits.size());
        System.assertEquals('Share', credits[0].Deal_Type__c);
    }

    @IsTest
    static void testSubmitShareDealApproval() {
        Opportunity opp = getOpp();
        User sharedRm = getSharedRm();
        User ownerUser = getOwnerUser();

        Id requestId;
        System.runAs(ownerUser) {
            Test.startTest();
            requestId = ShareDealApprovalController.submitShareDealApproval(
                opp.Id,
                sharedRm.Id,
                'Jointly closed this booking with partner RM.',
                null,
                null
            );
            Test.stopTest();
        }

        System.assertNotEquals(null, requestId);
        Id ownerManagerId = [
            SELECT ManagerId
            FROM User
            WHERE Id = :ownerUser.Id
        ].ManagerId;
        Approval_Request__c submitted = [
            SELECT Status__c, Request_Type__c, Requested_Shared_RM__c, Opportunity__c, Approver__c
            FROM Approval_Request__c
            WHERE Id = :requestId
        ];
        System.assertEquals('Pending', submitted.Status__c);
        System.assertEquals(ShareDealApprovalService.REQUEST_TYPE_SHARE_DEAL, submitted.Request_Type__c);
        System.assertEquals(sharedRm.Id, submitted.Requested_Shared_RM__c);
        System.assertEquals(opp.Id, submitted.Opportunity__c);
        System.assertEquals(
            ownerManagerId,
            submitted.Approver__c,
            'RM submit should stamp Approver from User.Manager hierarchy'
        );

        Opportunity pendingOpp = [
            SELECT Share_Deal_Status__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        System.assertEquals('Pending', pendingOpp.Share_Deal_Status__c);
    }

    @IsTest
    static void testSubmitValidations() {
        Opportunity opp = getOpp();
        User sharedRm = getSharedRm();
        User ownerUser = getOwnerUser();

        System.runAs(ownerUser) {
            Boolean shortJustificationFailed = false;
            try {
                ShareDealApprovalController.submitShareDealApproval(
                    opp.Id,
                    sharedRm.Id,
                    'short',
                    null,
                    null
                );
            } catch (Exception e) {
                shortJustificationFailed = true;
            }
            System.assertEquals(true, shortJustificationFailed);

            Boolean sameOwnerFailed = false;
            try {
                ShareDealApprovalController.submitShareDealApproval(
                    opp.Id,
                    ownerUser.Id,
                    'Same owner cannot be Shared RM.',
                    null,
                    null
                );
            } catch (Exception e) {
                sameOwnerFailed = true;
            }
            System.assertEquals(true, sameOwnerFailed);
        }
    }

    @IsTest
    static void testApplyAndInfoEdgeCases() {
        Opportunity opp = getOpp();
        User sharedRm = getSharedRm();
        User ownerUser = getOwnerUser();

        System.assertEquals(null, ShareDealApprovalController.getBookedOpportunityIdForUnit(null));
        RMDealCreditService.rebuildForOpportunity(null);
        RMDealCreditService.rebuildForOpportunityIds(new Set<Id>());

        // Non-Booked Opportunity is ineligible (admin can still read it).
        Account account = [SELECT Id FROM Account WHERE Name = 'Share Deal Test Account' LIMIT 1];
        Opportunity newStageOpp = new Opportunity(
            Name = 'Share Deal New Stage',
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = account.Id,
            OwnerId = ownerUser.Id
        );
        insert newStageOpp;
        ShareDealApprovalService.ShareDealInfoDTO newStageInfo =
            ShareDealApprovalController.getShareDealInfo(newStageOpp.Id);
        System.assertEquals(false, newStageInfo.eligible);

        Boolean nullOppFailed = false;
        try {
            ShareDealApprovalController.getShareDealInfo(null);
        } catch (Exception e) {
            nullOppFailed = true;
        }
        System.assertEquals(true, nullOppFailed);

        Approval_Request__c draftOnly = newShareDealRequest(
            opp.Id,
            ownerUser.Id,
            sharedRm.Id,
            'Draft',
            'Draft should not apply as approved.'
        );
        insert draftOnly;
        ShareDealApprovalService.applyApprovedChanges(draftOnly.Id);

        Approval_Request__c applied = newShareDealRequest(
            opp.Id,
            ownerUser.Id,
            sharedRm.Id,
            'Applied',
            'Already applied share deal request.'
        );
        insert applied;
        ShareDealApprovalService.applyApprovedChanges(applied.Id);

        Approval_Request__c missingSharedRm = newShareDealRequest(
            opp.Id,
            ownerUser.Id,
            null,
            'Approved',
            'Approved request missing Shared RM.'
        );
        insert missingSharedRm;
        Boolean missingRmFailed = false;
        try {
            ShareDealApprovalService.applyApprovedChanges(missingSharedRm.Id);
        } catch (Exception e) {
            missingRmFailed = true;
        }
        System.assertEquals(true, missingRmFailed);

        // Rejected handler leaves an already-approved share intact.
        update new Opportunity(
            Id = opp.Id,
            Share_Deal__c = true,
            Shared_RM__c = sharedRm.Id,
            Share_Deal_Status__c = 'Approved'
        );
        Approval_Request__c rejectedWhileApproved = newShareDealRequest(
            opp.Id,
            ownerUser.Id,
            sharedRm.Id,
            'Rejected',
            'Rejected while opportunity already shared.'
        );
        insert rejectedWhileApproved;
        ShareDealApprovalService.handleRejected(rejectedWhileApproved.Id);
        System.assertEquals(
            'Approved',
            [SELECT Share_Deal_Status__c FROM Opportunity WHERE Id = :opp.Id].Share_Deal_Status__c
        );

        // Open request for Pending after submit.
        System.runAs(ownerUser) {
            Id pendingId = ShareDealApprovalController.submitShareDealApproval(
                opp.Id,
                sharedRm.Id,
                'Request while already shared keeps Opp Approved.',
                null,
                null
            );
            ShareDealApprovalService.OpenShareDealRequestDTO openPending =
                ShareDealApprovalController.getOpenShareDealRequest(opp.Id);
            System.assertNotEquals(null, openPending);
            System.assertEquals(pendingId, openPending.approvalRequestId);
            System.assertEquals('Pending', openPending.status);

            Boolean duplicatePendingFailed = false;
            try {
                ShareDealApprovalController.submitShareDealApproval(
                    opp.Id,
                    sharedRm.Id,
                    'Second pending request should be blocked.',
                    null,
                    null
                );
            } catch (Exception e) {
                duplicatePendingFailed = true;
            }
            System.assertEquals(true, duplicatePendingFailed);
        }
    }

    @IsTest
    static void testSubmitFromExistingDraft() {
        Opportunity opp = getOpp();
        User sharedRm = getSharedRm();
        User ownerUser = getOwnerUser();

        Id requestId;
        System.runAs(ownerUser) {
            Approval_Request__c draft = newShareDealRequest(
                opp.Id,
                ownerUser.Id,
                sharedRm.Id,
                'Draft',
                'Existing draft share deal request.'
            );
            insert draft;

            Test.startTest();
            requestId = ShareDealApprovalController.submitShareDealApproval(
                opp.Id,
                sharedRm.Id,
                'Submitting from an existing draft request.',
                draft.Id,
                null
            );
            Test.stopTest();
        }

        System.assertNotEquals(null, requestId);
        System.assertEquals(
            'Pending',
            [SELECT Status__c FROM Approval_Request__c WHERE Id = :requestId].Status__c
        );
    }

    @IsTest
    static void testLineManagerOptionsAndSalesAdminFlag() {
        Opportunity opp = getOpp();
        User ownerUser = getOwnerUser();

        List<ShareDealApprovalService.RmOptionDTO> options =
            ShareDealApprovalController.getLineManagerOptions();
        System.assert(!options.isEmpty(), 'Expected Sales Director MIRA Line Manager options');

        // RM owner path — no Line Manager picker required.
        ShareDealApprovalService.forceRequiresLineManagerSelection = false;
        ShareDealApprovalService.ShareDealInfoDTO ownerInfo;
        System.runAs(ownerUser) {
            ownerInfo = ShareDealApprovalController.getShareDealInfo(opp.Id);
        }
        System.assertEquals(false, ownerInfo.requiresLineManagerSelection);

        // Sales Admin path — Line Manager selection required.
        ShareDealApprovalService.forceRequiresLineManagerSelection = true;
        ShareDealApprovalService.ShareDealInfoDTO adminInfo =
            ShareDealApprovalController.getShareDealInfo(opp.Id);
        System.assertEquals(true, adminInfo.requiresLineManagerSelection);
        ShareDealApprovalService.forceRequiresLineManagerSelection = null;
    }

    @IsTest
    static void testSalesAdminSubmitRequiresLineManager() {
        Opportunity opp = getOpp();
        User sharedRm = getSharedRm();
        Id lineManagerId = getLineManagerUserId();

        // Simulate Sales Admin (privileged, no Manager hierarchy).
        ShareDealApprovalService.forcePrivilegedRequester = true;
        ShareDealApprovalService.forceRequiresLineManagerSelection = true;

        Boolean missingManagerFailed = false;
        try {
            ShareDealApprovalController.submitShareDealApproval(
                opp.Id,
                sharedRm.Id,
                'Sales Admin must select a Line Manager.',
                null,
                null
            );
        } catch (Exception e) {
            missingManagerFailed = true;
        }
        System.assertEquals(true, missingManagerFailed, 'Submit without Line Manager should fail');

        Id requestId;
        Test.startTest();
        requestId = ShareDealApprovalController.submitShareDealApproval(
            opp.Id,
            sharedRm.Id,
            'Sales Admin selected Line Manager for Share Deal.',
            null,
            lineManagerId
        );
        Test.stopTest();

        ShareDealApprovalService.forcePrivilegedRequester = null;
        ShareDealApprovalService.forceRequiresLineManagerSelection = null;

        System.assertNotEquals(null, requestId);
        Approval_Request__c submitted = [
            SELECT Status__c, Approver__c, Requested_Shared_RM__c
            FROM Approval_Request__c
            WHERE Id = :requestId
        ];
        System.assertEquals('Pending', submitted.Status__c);
        System.assertEquals(lineManagerId, submitted.Approver__c);
        System.assertEquals(sharedRm.Id, submitted.Requested_Shared_RM__c);
    }

    @IsTest
    static void testUnregisteredAgencyBlocksSubmitAndApply() {
        User sharedRm = getSharedRm();
        User ownerUser = getOwnerUser();
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Title__c = 'Share Deal Unit' LIMIT 1];

        Id agencyRtId = Schema.SObjectType.Account.getRecordTypeInfosByName()
            .get('Agency')
            .getRecordTypeId();
        Account agency = new Account(
            Name = 'Unregistered Share Deal Agency',
            RecordTypeId = agencyRtId,
            Status__c = 'Completed',
            Company_Email__c = 'unregistered.share.deal@example.com'
        );
        insert agency;
        Contact agent = new Contact(
            LastName = 'Unregistered Share Deal Agent',
            AccountId = agency.Id
        );
        insert agent;

        Account client = new Account(Name = 'Share Deal Agency Client');
        insert client;
        Opportunity opp = new Opportunity(
            Name = 'Share Deal Agency Opp',
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = client.Id,
            OwnerId = ownerUser.Id,
            Assisted_by_Agent__c = true,
            Agency__c = agency.Id,
            Agent__c = agent.Id
        );
        insert opp;
        opp.Unit__c = unit.Id;
        opp.StageName = 'Booked';
        update opp;

        // Drop registration after booking — Opp Share Deal updates must surface the friendly message.
        update new Account(Id = agency.Id, Status__c = 'In Process');

        System.assertEquals(
            ShareDealApprovalService.AGENCY_NOT_REGISTERED_MESSAGE,
            ShareDealApprovalService.assistedAgencyRegistrationError(opp.Id)
        );

        ShareDealApprovalService.forcePrivilegedRequester = true;
        Boolean submitFailed = false;
        String submitMessage;
        try {
            System.runAs(ownerUser) {
                ShareDealApprovalController.submitShareDealApproval(
                    opp.Id,
                    sharedRm.Id,
                    'Should fail because Assisted Agency is not registered.',
                    null,
                    null
                );
            }
        } catch (Exception e) {
            submitFailed = true;
            submitMessage = e.getMessage();
        }
        ShareDealApprovalService.forcePrivilegedRequester = null;
        System.assertEquals(true, submitFailed, 'Submit must fail for unregistered Assisted Agency');
        System.assert(
            submitMessage != null &&
            submitMessage.contains(ShareDealApprovalService.AGENCY_NOT_REGISTERED_MESSAGE),
            'Submit message: ' + submitMessage
        );

        Approval_Request__c approvedReq = newShareDealRequest(
            opp.Id,
            ownerUser.Id,
            sharedRm.Id,
            'Approved',
            'Apply blocked by unregistered Assisted Agency.'
        );
        insert approvedReq;

        Boolean applyFailed = false;
        String applyMessage;
        try {
            ShareDealApprovalService.applyApprovedChanges(approvedReq.Id);
        } catch (ShareDealApprovalService.ShareDealApprovalException e) {
            applyFailed = true;
            applyMessage = e.getMessage();
        }
        System.assertEquals(true, applyFailed, 'Final apply must fail for unregistered Assisted Agency');
        System.assertEquals(
            ShareDealApprovalService.AGENCY_NOT_REGISTERED_MESSAGE,
            applyMessage
        );
    }
}
