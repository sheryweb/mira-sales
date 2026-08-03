@isTest
private class ApprovalRequestNotificationServiceTest {

    // Account with one active portal user; returns the Account Id.
    private static Id agencyWithActiveUser(String emailLocalPart) {
        String u = String.valueOf(Crypto.getRandomLong());
        Account agency = new Account(Name = 'Notify Agency ' + u, Skip_Trigger__c = true);
        insert agency;
        insert new Broker_User__c(
            Account__c = agency.Id,
            Email__c = emailLocalPart + u + '@example.com',
            Active__c = true
        );
        return agency.Id;
    }

    private static Approval_Request__c makeRequest(Id acctId, String type, String status) {
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = type,
            Related_Object_Type__c = 'Account',
            Related_Record_Id__c = (acctId == null) ? null : String.valueOf(acctId),
            Field_To_Update__c = 'x',
            Current_Value__c = 'a',
            Requested_Value__c = 'b',
            Justification__c = 'test',
            Status__c = status
        );
        insert req;
        return req;
    }

    @isTest
    static void submitted_email_built_for_active_user() {
        Id acc = agencyWithActiveUser('submit');
        Approval_Request__c req = makeRequest(acc, 'Agency Profile Update', 'Pending');

        Test.startTest();
        List<Messaging.SingleEmailMessage> built =
            ApprovalRequestNotificationService.buildEmails(new Set<Id>{ req.Id });
        Test.stopTest();

        System.assertEquals(1, built.size(), 'one submitted email');
        System.assert(built[0].getSubject().contains('received'), 'submitted subject: ' + built[0].getSubject());
        System.assert(built[0].getSubject().contains('Company Profile Update'), 'friendly type label');
        System.assertEquals(1, built[0].getToAddresses().size(), 'one recipient');
        System.assert(built[0].getToAddresses()[0].startsWith('submit'), 'recipient is the broker user email');
        System.assert(built[0].getHtmlBody().contains('Notify Agency'), 'personalized with agency name');
    }

    @isTest
    static void approved_and_rejected_emails_built() {
        Id acc = agencyWithActiveUser('decide');
        Approval_Request__c approved = makeRequest(acc, 'Bank Detail Update', 'Approved');
        Approval_Request__c rejected = makeRequest(acc, 'Document Re-upload', 'Rejected');

        Test.startTest();
        List<Messaging.SingleEmailMessage> built =
            ApprovalRequestNotificationService.buildEmails(new Set<Id>{ approved.Id, rejected.Id });
        Test.stopTest();

        System.assertEquals(2, built.size(), 'one approved + one rejected');
        Boolean sawApproved = false, sawRejected = false;
        for (Messaging.SingleEmailMessage m : built) {
            if (m.getSubject().contains('approved')) sawApproved = true;
            if (m.getSubject().contains('update on your request')) sawRejected = true;
        }
        System.assert(sawApproved, 'approved subject present');
        System.assert(sawRejected, 'rejected subject present');
    }

    @isTest
    static void internal_request_types_are_ignored() {
        Id acc = agencyWithActiveUser('internal');
        Approval_Request__c req = makeRequest(acc, 'Fee Change', 'Approved');

        Test.startTest();
        List<Messaging.SingleEmailMessage> built =
            ApprovalRequestNotificationService.buildEmails(new Set<Id>{ req.Id });
        Test.stopTest();

        System.assertEquals(0, built.size(), 'internal sales approvals must not email the agency');
    }

    @isTest
    static void no_active_user_means_no_email() {
        String u = String.valueOf(Crypto.getRandomLong());
        Account agency = new Account(Name = 'No User Agency ' + u, Skip_Trigger__c = true);
        insert agency;
        // Inactive portal user -> must be skipped.
        insert new Broker_User__c(Account__c = agency.Id, Email__c = 'inactive' + u + '@example.com', Active__c = false);
        Approval_Request__c req = makeRequest(agency.Id, 'Agency Profile Update', 'Pending');

        Test.startTest();
        List<Messaging.SingleEmailMessage> built =
            ApprovalRequestNotificationService.buildEmails(new Set<Id>{ req.Id });
        Test.stopTest();

        System.assertEquals(0, built.size(), 'no active portal user -> no email');
    }

    @isTest
    static void notify_send_path_runs_clean() {
        Id acc = agencyWithActiveUser('send');
        Approval_Request__c req = makeRequest(acc, 'Agency Profile Update', 'Pending');

        Test.startTest();
        ApprovalRequestNotificationService.notify(new Set<Id>{ req.Id });
        Test.stopTest();

        System.assertNotEquals(null, ApprovalRequestNotificationService.lastBuilt, 'send path executed');
        System.assertEquals(1, ApprovalRequestNotificationService.lastBuilt.size(), 'one email queued to send');
    }

    @isTest
    static void trigger_after_insert_pending_notifies() {
        Id acc = agencyWithActiveUser('ins');

        Test.startTest();
        // Inserting a Pending agency request fires ApprovalRequestTrigger -> after insert -> notify.
        makeRequest(acc, 'Agency Profile Update', 'Pending');
        Test.stopTest();

        System.assertNotEquals(null, ApprovalRequestNotificationService.lastBuilt, 'after-insert ran notify');
        System.assertEquals(1, ApprovalRequestNotificationService.lastBuilt.size(), 'one submitted email');
        System.assert(ApprovalRequestNotificationService.lastBuilt[0].getSubject().contains('received'),
            'submitted subject on insert');
    }

    @isTest
    static void trigger_after_update_decision_notifies() {
        Id acc = agencyWithActiveUser('upd');
        // Document Re-upload starts as Draft (no email), then a decision is recorded.
        Approval_Request__c req = makeRequest(acc, 'Document Re-upload', 'Draft');

        Test.startTest();
        req.Status__c = 'Approved';
        update req;   // fires after update -> notify
        Test.stopTest();

        System.assertNotEquals(null, ApprovalRequestNotificationService.lastBuilt, 'after-update ran notify');
        System.assertEquals(1, ApprovalRequestNotificationService.lastBuilt.size(), 'one decision email');
        System.assert(ApprovalRequestNotificationService.lastBuilt[0].getSubject().contains('approved'),
            'approved subject on update');
    }

    @isTest
    static void reviewer_comment_is_shown_and_escaped() {
        // Rejected: comment shown under a "Reason" heading and HTML-escaped.
        String rejectedBody = ApprovalRequestNotificationService.bodyFor(
            'Rejected', 'Agency X', 'Bank Details Update', 'IBAN missing <b>fix</b>');
        System.assert(rejectedBody.contains('Reason / comments from our team'), 'reject heading shown');
        System.assert(rejectedBody.contains('IBAN missing &lt;b&gt;fix&lt;/b&gt;'), 'comment HTML-escaped');
        System.assert(!rejectedBody.contains('IBAN missing <b>fix</b>'), 'raw HTML not injected');

        // Approved: comment shown under a neutral heading.
        String approvedBody = ApprovalRequestNotificationService.bodyFor(
            'Approved', 'Agency X', 'Company Profile Update', 'Looks good, approved.');
        System.assert(approvedBody.contains('Comments from our team'), 'approve heading shown');
        System.assert(approvedBody.contains('Looks good, approved.'), 'approve comment shown');

        // Submitted: never shows a comment block even if one is passed.
        String submittedBody = ApprovalRequestNotificationService.bodyFor(
            'Submitted', 'Agency X', 'Company Profile Update', 'ignore me');
        System.assert(!submittedBody.contains('ignore me'), 'no comment on submitted email');

        // No comment -> no comment block.
        String noComment = ApprovalRequestNotificationService.bodyFor(
            'Approved', 'Agency X', 'Company Profile Update', null);
        System.assert(!noComment.contains('Comments from our team'), 'no block when comment blank');
    }

    // ── Director of Operations internal notifications ─────────────────────────

    @isTest
    static void operations_email_built_for_group_members() {
        // Public group with the running user as a member (setup objects -> runAs to avoid MIXED_DML).
        Group g = new Group(Name = 'Test DoO', DeveloperName = 'Test_DoO_Group', Type = 'Regular');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert g;
            insert new GroupMember(GroupId = g.Id, UserOrGroupId = UserInfo.getUserId());
        }
        ApprovalRequestNotificationService.OPS_GROUP_DEV_NAMES = new Set<String>{ 'Test_DoO_Group' };

        Unit__c unit = new Unit__c();
        insert unit;
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Unit Price Change',
            Related_Object_Type__c = 'Unit__c',
            Parent_Object__c = 'Unit__c',
            Parent_Record_Id__c = String.valueOf(unit.Id),
            Field_To_Update__c = 'Cost_AED__c',
            Current_Value__c = 'AED 1,000,000',
            Requested_Value__c = 'AED 950,000',
            Justification__c = 'Client negotiation',
            Status__c = 'Approved'
        );
        insert req;

        Test.startTest();
        List<Messaging.SingleEmailMessage> built =
            ApprovalRequestNotificationService.buildOperationsEmails(new Set<Id>{ req.Id });
        Test.stopTest();

        System.assertEquals(1, built.size(), 'one ops email for the group');
        System.assert(built[0].getSubject().startsWith('Approval Approved: Unit Price Change'),
            'ops subject: ' + built[0].getSubject());
        System.assert(built[0].getToAddresses().size() >= 1, 'at least one recipient resolved from the group');
    }

    // Recipients are the union of every OPS_GROUP_DEV_NAMES group, de-duplicated: in production
    // Jad sits in Sales_Admin_Special only, the rest in Director_of_Operations.
    @isTest
    static void operations_recipients_span_all_groups_without_duplicates() {
        Group a = new Group(Name = 'Test Ops A', DeveloperName = 'Test_Ops_A', Type = 'Regular');
        Group b = new Group(Name = 'Test Ops B', DeveloperName = 'Test_Ops_B', Type = 'Regular');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new List<Group>{ a, b };
            // Member of the SECOND group only — must still be notified.
            insert new GroupMember(GroupId = b.Id, UserOrGroupId = UserInfo.getUserId());
        }
        ApprovalRequestNotificationService.OPS_GROUP_DEV_NAMES =
            new Set<String>{ 'Test_Ops_A', 'Test_Ops_B' };

        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Unit Price Change',
            Related_Object_Type__c = 'Unit__c',
            Field_To_Update__c = 'Cost_AED__c',
            Current_Value__c = 'AED 1,000,000',
            Requested_Value__c = 'AED 950,000',
            Justification__c = 'Client negotiation',
            Status__c = 'Pending'
        );
        insert req;

        List<Messaging.SingleEmailMessage> built =
            ApprovalRequestNotificationService.buildOperationsEmails(new Set<Id>{ req.Id });
        System.assertEquals(1, built.size(), 'a member of the second group alone is still notified');
        System.assertEquals(1, built[0].getToAddresses().size(), 'one recipient');

        // Same user now in BOTH groups -> still a single copy.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new GroupMember(GroupId = a.Id, UserOrGroupId = UserInfo.getUserId());
        }
        built = ApprovalRequestNotificationService.buildOperationsEmails(new Set<Id>{ req.Id });
        System.assertEquals(1, built.size(), 'still one email');
        System.assertEquals(1, built[0].getToAddresses().size(),
            'membership in both groups is de-duplicated');
    }

    // Regression: applyApprovedChanges() stamps Status__c = 'Applied' before notify() runs, so a
    // finally-approved request reads as 'Applied' when the service re-queries it. That used to map
    // to no event at all and the Director of Operations never got the final-approval email.
    @isTest
    static void operations_applied_status_still_sends_approved_email() {
        Group g = new Group(Name = 'Test DoO Applied', DeveloperName = 'Test_DoO_Applied', Type = 'Regular');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert g;
            insert new GroupMember(GroupId = g.Id, UserOrGroupId = UserInfo.getUserId());
        }
        ApprovalRequestNotificationService.OPS_GROUP_DEV_NAMES = new Set<String>{ 'Test_DoO_Applied' };

        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Payment Plan Change',
            Related_Object_Type__c = 'Unit__c',
            Field_To_Update__c = 'Cash_Flow__c',
            Current_Value__c = 'Unit (7 installment(s))',
            Requested_Value__c = 'Add: 0, Update: 1, Delete: 0',
            Justification__c = 'test',
            Status__c = 'Applied'
        );
        insert req;

        Test.startTest();
        List<Messaging.SingleEmailMessage> built =
            ApprovalRequestNotificationService.buildOperationsEmails(new Set<Id>{ req.Id });
        Test.stopTest();

        System.assertEquals(1, built.size(), 'Applied must still produce the final-approval email');
        System.assert(built[0].getSubject().startsWith('Approval Approved: Payment Plan Change'),
            'Applied is reported as Approved: ' + built[0].getSubject());
    }

    @isTest
    static void operations_no_group_members_means_no_email() {
        ApprovalRequestNotificationService.OPS_GROUP_DEV_NAMES = new Set<String>{ 'No_Such_Group_X' };
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Payment Plan Change',
            Related_Object_Type__c = 'Unit__c',
            Field_To_Update__c = 'Cash_Flow__c',
            Current_Value__c = 'Unit (7 installment(s))',
            Requested_Value__c = 'Add: 0, Update: 1, Delete: 0',
            Justification__c = 'test',
            Status__c = 'Pending'
        );
        insert req;

        Test.startTest();
        List<Messaging.SingleEmailMessage> built =
            ApprovalRequestNotificationService.buildOperationsEmails(new Set<Id>{ req.Id });
        Test.stopTest();

        System.assertEquals(0, built.size(), 'no group members -> no ops email');
    }

    @isTest
    static void operations_body_shows_comment_and_escapes() {
        Approval_Request__c r = new Approval_Request__c(
            Request_Type__c = 'Unit Price Change',
            Related_Object_Type__c = 'Unit__c',
            Field_To_Update__c = 'Cost_AED__c',
            Current_Value__c = 'AED 1,000,000',
            Requested_Value__c = 'AED 950,000',
            Justification__c = 'Client negotiation',
            Status__c = 'Rejected'
        );
        insert r;
        r = [SELECT Id, Request_Type__c, Status__c, Current_Value__c, Requested_Value__c,
                    Field_To_Update__c, Justification__c, Requester__r.Name
             FROM Approval_Request__c WHERE Id = :r.Id];

        String body = ApprovalRequestNotificationService.opsBodyFor(
            r, 'Rejected', 'A-211', 'MIRA Project', null, 'Price too low <b>no</b>');

        System.assert(body.contains('A-211'), 'unit label shown');
        System.assert(body.contains('MIRA Project'), 'project name shown');
        System.assert(!body.contains('Cost_AED__c'), 'field name (Cost_AED__c) no longer shown');
        System.assert(body.contains('Approver comment'), 'comment heading shown');
        System.assert(body.contains('Price too low &lt;b&gt;no&lt;/b&gt;'), 'comment HTML-escaped');
        System.assert(body.contains('/lightning/r/Approval_Request__c/'), 'record link present');
    }

    @isTest
    static void operations_share_deal_pending_builds_email() {
        Group g = new Group(Name = 'Test DoO Share', DeveloperName = 'Test_DoO_Share', Type = 'Regular');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert g;
            insert new GroupMember(GroupId = g.Id, UserOrGroupId = UserInfo.getUserId());
        }
        ApprovalRequestNotificationService.OPS_GROUP_DEV_NAMES = new Set<String>{ 'Test_DoO_Share' };

        Unit__c unit = new Unit__c(Title__c = 'SD-101', Building__c = 'A');
        insert unit;

        Account acct = new Account(Name = 'Share Deal Notify Acct ' + String.valueOf(Crypto.getRandomLong()));
        insert acct;
        Opportunity opp = new Opportunity(
            Name = 'Share Deal Notify Opp',
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = acct.Id,
            Unit__c = unit.Id
        );
        insert opp;

        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Share Deal',
            Related_Object_Type__c = 'Opportunity',
            Parent_Object__c = 'Opportunity',
            Parent_Record_Id__c = String.valueOf(opp.Id),
            Opportunity__c = opp.Id,
            Unit__c = unit.Id,
            Field_To_Update__c = 'Shared_RM__c',
            Current_Value__c = 'Single deal (Owner: Test User)',
            Requested_Value__c = 'Share 50/50 with Shared RM',
            Justification__c = 'Client asked for co-ownership',
            Status__c = 'Pending'
        );
        insert req;

        Test.startTest();
        List<Messaging.SingleEmailMessage> built =
            ApprovalRequestNotificationService.buildOperationsEmails(new Set<Id>{ req.Id });
        Test.stopTest();

        System.assertEquals(1, built.size(), 'Share Deal Pending must produce an ops email');
        System.assert(built[0].getSubject().startsWith('Approval Submitted: Share Deal'),
            'share deal subject: ' + built[0].getSubject());
        System.assert(built[0].getSubject().contains('A-SD-101'),
            'subject includes unit label: ' + built[0].getSubject());
        System.assert(built[0].getHtmlBody().contains('Share 50/50 with Shared RM'), 'requested value in body');
        System.assert(built[0].getHtmlBody().contains('Single deal (Owner: Test User)'), 'current value in body');
    }

    @isTest
    static void operations_share_deal_applied_still_sends_approved_email() {
        Group g = new Group(Name = 'Test DoO Share Applied', DeveloperName = 'Test_DoO_Share_Applied', Type = 'Regular');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert g;
            insert new GroupMember(GroupId = g.Id, UserOrGroupId = UserInfo.getUserId());
        }
        ApprovalRequestNotificationService.OPS_GROUP_DEV_NAMES = new Set<String>{ 'Test_DoO_Share_Applied' };

        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Share Deal',
            Related_Object_Type__c = 'Opportunity',
            Parent_Object__c = 'Opportunity',
            Field_To_Update__c = 'Shared_RM__c',
            Current_Value__c = 'Single deal',
            Requested_Value__c = 'Share 50/50 with Shared RM',
            Justification__c = 'test',
            Status__c = 'Applied'
        );
        insert req;

        Test.startTest();
        List<Messaging.SingleEmailMessage> built =
            ApprovalRequestNotificationService.buildOperationsEmails(new Set<Id>{ req.Id });
        Test.stopTest();

        System.assertEquals(1, built.size(), 'Share Deal Applied must still produce the final-approval email');
        System.assert(built[0].getSubject().startsWith('Approval Approved: Share Deal'),
            'Applied is reported as Approved: ' + built[0].getSubject());
    }

    @isTest
    static void operations_body_shows_opportunity_name_for_share_deal() {
        Approval_Request__c r = new Approval_Request__c(
            Request_Type__c = 'Share Deal',
            Related_Object_Type__c = 'Opportunity',
            Field_To_Update__c = 'Shared_RM__c',
            Current_Value__c = 'Single deal',
            Requested_Value__c = 'Share 50/50 with Shared RM',
            Justification__c = 'Co-brokered',
            Status__c = 'Pending'
        );
        insert r;
        r = [SELECT Id, Request_Type__c, Status__c, Current_Value__c, Requested_Value__c,
                    Field_To_Update__c, Justification__c, Requester__r.Name
             FROM Approval_Request__c WHERE Id = :r.Id];

        String body = ApprovalRequestNotificationService.opsBodyFor(
            r, 'Submitted', 'A-SD-101', 'MIRA Project', 'Opp Share Deal X', null);

        System.assert(body.contains('Opp Share Deal X'), 'opportunity name shown');
        System.assert(body.contains('A-SD-101'), 'unit label shown');
        System.assert(body.contains('Share 50/50 with Shared RM'), 'requested value shown');
    }

    @isTest
    static void empty_and_null_inputs_are_safe() {
        Test.startTest();
        ApprovalRequestNotificationService.notify(null);
        ApprovalRequestNotificationService.notify(new Set<Id>());
        List<Messaging.SingleEmailMessage> built =
            ApprovalRequestNotificationService.buildEmails(new Set<Id>{
                Id.valueOf(Approval_Request__c.SObjectType.getDescribe().getKeyPrefix() + '000000000AAA')
            });
        Test.stopTest();

        System.assertEquals(0, built.size(), 'unknown id -> no email, no error');
    }
}