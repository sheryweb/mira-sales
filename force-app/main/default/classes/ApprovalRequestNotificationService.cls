/**
 * Sends notification emails to the AGENCY when an Approval_Request__c that originated from the
 * MIRA Broker Portal is submitted, approved, or rejected. Approval requests are owned by the
 * internal Account owner, so the agency otherwise has no visibility outside the portal UI.
 *
 * Scope: only the three portal-originated request types (Agency Profile Update, Bank Detail
 * Update, Document Re-upload). Internal sales approvals (Fee Change, Discount, Credit Limit,
 * Payment Plan Change, Unit Price Change, Other) are deliberately ignored.
 *
 * Recipient: every Active__c Broker_User__c.Email__c for the request's Account
 * (Related_Record_Id__c). Sender: org-wide address, sandbox/prod auto-detected.
 *
 * Entry point notify(Set<Id>) is safe to call from any context: it never throws to the caller,
 * so a mail failure can never block an approval decision or a portal submission.
 */
public without sharing class ApprovalRequestNotificationService {

    private static final String PORTAL_URL      = 'https://miradevelopments.my.salesforce-sites.com/agency/BrokerLogin';
    private static final String SANDBOX_OWEA_ID = '0D2U90000000Y4vKAE';
    private static final String PROD_OWEA_ID    = '0D2Rg0000000LkPKAU';
    private static final String LOGO_URL        = 'https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_logo_small.jpeg';

    private static final Set<String> AGENCY_TYPES = new Set<String>{
        'Agency Profile Update', 'Bank Detail Update', 'Document Re-upload'
    };

    // Friendly label shown to the agency for each request type.
    private static final Map<String, String> TYPE_LABEL = new Map<String, String>{
        'Agency Profile Update' => 'Company Profile Update',
        'Bank Detail Update'    => 'Bank Details Update',
        'Document Re-upload'    => 'Document Re-upload'
    };

    // Exposed so tests can assert on what would be sent without delivering mail.
    @TestVisible private static List<Messaging.SingleEmailMessage> lastBuilt;

    // ── Director of Operations internal notifications ─────────────────────────
    // Separate audience/purpose from the agency emails above: the Director of
    // Operations is notified on submit + final decision for these internal sales
    // approval types. Recipients = active direct user members of the public group.
    @TestVisible private static String OPS_GROUP_DEV_NAME = 'Director_of_Operations';
    private static final Set<String> OPS_TYPES = new Set<String>{
        'Unit Price Change', 'Payment Plan Change'
    };
    // DOO emails come from a system-style address (noreply), not the broker-facing "MIRA Agents".
    private static final String OPS_FROM_ADDRESS = 'noreply@miradevelopments.ae';
    @TestVisible private static List<Messaging.SingleEmailMessage> lastOpsBuilt;

    public static void notify(Set<Id> requestIds) {
        if (requestIds == null || requestIds.isEmpty()) return;
        try {
            List<Messaging.SingleEmailMessage> emails = buildEmails(requestIds);
            lastBuilt = emails;
            if (!emails.isEmpty()) {
                Messaging.sendEmail(emails, false);
            }
        } catch (Exception ex) {
            // Never let a notification failure break the approval/submission transaction.
            System.debug(LoggingLevel.ERROR, 'ApprovalRequestNotification failed :: ' + ex.getMessage());
        }
        // Internal Director-of-Operations notifications (own try/catch; isolated from agency send).
        notifyOperations(requestIds);
    }

    @TestVisible
    private static List<Messaging.SingleEmailMessage> buildEmails(Set<Id> requestIds) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        List<Approval_Request__c> reqs = [
            SELECT Id, Request_Type__c, Status__c, Related_Record_Id__c
            FROM Approval_Request__c
            WHERE Id IN :requestIds AND Request_Type__c IN :AGENCY_TYPES
        ];
        if (reqs.isEmpty()) return emails;

        // Collect the Account ids referenced by these requests.
        Set<Id> acctIds = new Set<Id>();
        for (Approval_Request__c r : reqs) {
            Id acc = toAccountId(r.Related_Record_Id__c);
            if (acc != null) acctIds.add(acc);
        }
        if (acctIds.isEmpty()) return emails;

        // Agency display name per Account.
        Map<Id, Account> accts = new Map<Id, Account>([
            SELECT Id, Name FROM Account WHERE Id IN :acctIds
        ]);

        // Active portal login emails per Account.
        Map<Id, List<String>> emailsByAccount = new Map<Id, List<String>>();
        for (Broker_User__c bu : [
            SELECT Email__c, Account__c FROM Broker_User__c
            WHERE Account__c IN :acctIds AND Active__c = true AND Email__c != null
        ]) {
            if (!emailsByAccount.containsKey(bu.Account__c)) {
                emailsByAccount.put(bu.Account__c, new List<String>());
            }
            emailsByAccount.get(bu.Account__c).add(bu.Email__c.trim());
        }

        Id oweaId = resolveOweaId();
        List<OrgWideEmailAddress> oweas = [SELECT Id FROM OrgWideEmailAddress WHERE Id = :oweaId LIMIT 1];

        // Approver's comment from the native Approval Process, per decided request.
        Map<Id, String> commentByReq = decisionComments(reqs);

        for (Approval_Request__c r : reqs) {
            String event = eventFor(r.Status__c);
            if (event == null) continue;                          // not a notifiable status

            Id acc = toAccountId(r.Related_Record_Id__c);
            if (acc == null) continue;

            List<String> toList = emailsByAccount.get(acc);
            if (toList == null || toList.isEmpty()) continue;     // no active portal user to notify

            String agencyName = (accts.containsKey(acc) && accts.get(acc).Name != null)
                ? accts.get(acc).Name : 'Valued Partner';
            String typeLabel = TYPE_LABEL.containsKey(r.Request_Type__c)
                ? TYPE_LABEL.get(r.Request_Type__c) : r.Request_Type__c;

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(toList);
            email.setSubject(subjectFor(event, typeLabel));
            email.setHtmlBody(bodyFor(event, agencyName, typeLabel, commentByReq.get(r.Id)));
            email.setSaveAsActivity(false);
            if (!oweas.isEmpty()) email.setOrgWideEmailAddressId(oweas[0].Id);
            emails.add(email);
        }
        return emails;
    }

    // Latest non-blank approver comment per decided request, from the native Approval Process steps.
    private static Map<Id, String> decisionComments(List<Approval_Request__c> reqs) {
        Set<Id> decidedIds = new Set<Id>();
        for (Approval_Request__c r : reqs) {
            if (r.Status__c == 'Approved' || r.Status__c == 'Rejected') decidedIds.add(r.Id);
        }
        Map<Id, String> byReq = new Map<Id, String>();
        if (decidedIds.isEmpty()) return byReq;

        // ORDER BY CreatedDate ASC so the most recent decision comment overwrites earlier ones.
        for (ProcessInstanceStep step : [
            SELECT ProcessInstance.TargetObjectId, Comments
            FROM ProcessInstanceStep
            WHERE ProcessInstance.TargetObjectId IN :decidedIds
              AND StepStatus IN ('Approved', 'Rejected')
            ORDER BY CreatedDate ASC
        ]) {
            if (String.isNotBlank(step.Comments)) {
                byReq.put((Id) step.ProcessInstance.TargetObjectId, step.Comments);
            }
        }
        return byReq;
    }

    private static String eventFor(String status) {
        if (status == 'Pending')  return 'Submitted';
        if (status == 'Approved') return 'Approved';
        if (status == 'Rejected') return 'Rejected';
        return null;
    }

    private static String subjectFor(String event, String typeLabel) {
        if (event == 'Submitted') return 'We\'ve received your request – ' + typeLabel;
        if (event == 'Approved')  return 'Your request has been approved – ' + typeLabel;
        return 'An update on your request – ' + typeLabel;   // Rejected
    }

    @TestVisible
    private static String bodyFor(String event, String agencyName, String typeLabel, String reviewerComment) {
        String intro;
        if (event == 'Submitted') {
            intro =
                'We are writing to confirm that we have received your <strong>' + typeLabel + '</strong> request ' +
                'submitted through the MIRA Developments Broker Portal.<br/><br/>' +
                'Our team will review it shortly. You will receive a further email once a decision has been made, ' +
                'and you can track the status at any time from your portal.';
        } else if (event == 'Approved') {
            intro =
                'We are pleased to inform you that your <strong>' + typeLabel + '</strong> request, submitted through ' +
                'the MIRA Developments Broker Portal, has been <strong>approved</strong>.<br/><br/>' +
                'The approved changes are now reflected on your account. You can review the details by logging in to the portal.';
        } else { // Rejected
            intro =
                'Thank you for your <strong>' + typeLabel + '</strong> request submitted through the MIRA Developments ' +
                'Broker Portal.<br/><br/>' +
                'After review, this request could not be approved at this time. You are welcome to review the details and ' +
                're-submit from the portal. If you have any questions, our team will be happy to assist.';
        }

        // Show the reviewer's comment (if any) for approved/rejected decisions.
        String commentBlock = '';
        if ((event == 'Approved' || event == 'Rejected') && String.isNotBlank(reviewerComment)) {
            String heading = (event == 'Rejected') ? 'Reason / comments from our team:' : 'Comments from our team:';
            commentBlock =
                '<div style="margin:0 0 16px;padding:12px 16px;background:#f7f7f7;border-left:4px solid #c8a24a;">' +
                '<strong>' + heading + '</strong><br/>' + reviewerComment.escapeHtml4() + '</div>';
        }

        return
            '<html><body style="font-family: Arial, sans-serif; font-size: 14px; color: #333; line-height: 1.6;">' +
            'Dear ' + agencyName + ',<br/><br/>' +
            intro + '<br/><br/>' +
            commentBlock +
            'Broker Portal: <a href="' + PORTAL_URL + '">Agency Login</a><br/><br/>' +
            'Should you need any assistance, please reach out to us at ' +
            '<a href="mailto:agents@miradevelopments.ae">agents@miradevelopments.ae</a>.<br/><br/>' +
            '<hr style="border:none;border-top:1px solid #ddd;"/>' +
            'Best regards,<br/>Sales Operations Team<br/>MIRA Developments<br/><br/>' +
            '<img src="' + LOGO_URL + '" alt="MIRA Developments Logo" style="max-width: 200px;"/>' +
            '</body></html>';
    }

    private static Id resolveOweaId() {
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        return isSandbox ? SANDBOX_OWEA_ID : PROD_OWEA_ID;
    }

    private static Id toAccountId(String relatedRecordId) {
        if (String.isBlank(relatedRecordId)) return null;
        try {
            Id parsed = Id.valueOf(relatedRecordId);
            return (parsed.getSobjectType() == Account.SObjectType) ? parsed : null;
        } catch (Exception ignored) {
            return null;
        }
    }

    // ── Director of Operations internal notifications ─────────────────────────

    public static void notifyOperations(Set<Id> requestIds) {
        if (requestIds == null || requestIds.isEmpty()) return;
        try {
            List<Messaging.SingleEmailMessage> emails = buildOperationsEmails(requestIds);
            lastOpsBuilt = emails;
            if (!emails.isEmpty()) {
                Messaging.sendEmail(emails, false);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'OperationsApprovalNotification failed :: ' + ex.getMessage());
        }
    }

    @TestVisible
    private static List<Messaging.SingleEmailMessage> buildOperationsEmails(Set<Id> requestIds) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        List<Approval_Request__c> reqs = [
            SELECT Id, Name, Request_Type__c, Status__c, Current_Value__c, Requested_Value__c,
                   Field_To_Update__c, Justification__c, Parent_Object__c, Parent_Record_Id__c,
                   Requester__r.Name
            FROM Approval_Request__c
            WHERE Id IN :requestIds AND Request_Type__c IN :OPS_TYPES
        ];
        if (reqs.isEmpty()) return emails;

        // Keep only the notifiable lifecycle events (Submitted / Approved / Rejected).
        List<Approval_Request__c> notifiable = new List<Approval_Request__c>();
        for (Approval_Request__c r : reqs) {
            if (eventFor(r.Status__c) != null) notifiable.add(r);
        }
        if (notifiable.isEmpty()) return emails;

        // Recipients: active direct user members of the Director of Operations public group.
        List<String> toAddresses = operationsGroupEmails();
        if (toAddresses.isEmpty()) return emails;

        Map<Id, Unit__c> unitsById = unitsFor(notifiable);
        Map<Id, String> commentByReq = decisionComments(notifiable);

        List<OrgWideEmailAddress> oweas = [
            SELECT Id FROM OrgWideEmailAddress
            WHERE Address = :OPS_FROM_ADDRESS AND IsVerified = true LIMIT 1
        ];

        for (Approval_Request__c r : notifiable) {
            String event = eventFor(r.Status__c);
            Unit__c unit = null;
            if (String.isNotBlank(r.Parent_Record_Id__c)) {
                try { unit = unitsById.get(Id.valueOf(r.Parent_Record_Id__c)); }
                catch (Exception ignored) { /* not a unit id */ }
            }
            String unitLabel = unitLabelFor(unit);
            String projectName = projectNameFor(unit);

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(toAddresses);
            email.setSubject(opsSubjectFor(event, r.Request_Type__c, unitLabel));
            email.setHtmlBody(opsBodyFor(r, event, unitLabel, projectName, commentByReq.get(r.Id)));
            email.setSaveAsActivity(false);
            if (!oweas.isEmpty()) email.setOrgWideEmailAddressId(oweas[0].Id);
            emails.add(email);
        }
        return emails;
    }

    // Active direct user members of the Director of Operations public group.
    private static List<String> operationsGroupEmails() {
        List<String> addrs = new List<String>();
        List<Group> grps = [
            SELECT Id FROM Group
            WHERE DeveloperName = :OPS_GROUP_DEV_NAME AND Type = 'Regular' LIMIT 1
        ];
        if (grps.isEmpty()) return addrs;

        Set<Id> userIds = new Set<Id>();
        for (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :grps[0].Id]) {
            if (gm.UserOrGroupId != null && gm.UserOrGroupId.getSobjectType() == User.SObjectType) {
                userIds.add(gm.UserOrGroupId);
            }
        }
        if (userIds.isEmpty()) return addrs;
        for (User u : [SELECT Email FROM User WHERE Id IN :userIds AND IsActive = true AND Email != null]) {
            addrs.add(u.Email.trim());
        }
        return addrs;
    }

    // Unit records per parent-record id (only for parents that are Units).
    private static Map<Id, Unit__c> unitsFor(List<Approval_Request__c> reqs) {
        Set<Id> unitIds = new Set<Id>();
        for (Approval_Request__c r : reqs) {
            if (r.Parent_Object__c == 'Unit__c' && String.isNotBlank(r.Parent_Record_Id__c)) {
                try {
                    Id pid = Id.valueOf(r.Parent_Record_Id__c);
                    if (pid.getSobjectType() == Unit__c.SObjectType) unitIds.add(pid);
                } catch (Exception ignored) { /* skip */ }
            }
        }
        Map<Id, Unit__c> byId = new Map<Id, Unit__c>();
        if (unitIds.isEmpty()) return byId;
        for (Unit__c u : [
            SELECT Id, Title__c, Building__c, Project_Name_Text__c, Project__r.Name
            FROM Unit__c WHERE Id IN :unitIds
        ]) {
            byId.put(u.Id, u);
        }
        return byId;
    }

    // "Building-Title" (e.g. "A-101"); falls back to Title, then the Id.
    private static String unitLabelFor(Unit__c u) {
        if (u == null) return null;
        String title = String.isNotBlank(u.Title__c) ? u.Title__c : String.valueOf(u.Id);
        return String.isNotBlank(u.Building__c) ? (u.Building__c + '-' + title) : title;
    }

    // Project display name for a Unit: prefers the text field, then the lookup's Name.
    private static String projectNameFor(Unit__c u) {
        if (u == null) return null;
        if (String.isNotBlank(u.Project_Name_Text__c)) return u.Project_Name_Text__c;
        return (u.Project__r != null) ? u.Project__r.Name : null;
    }

    private static String opsSubjectFor(String event, String requestType, String unitName) {
        String suffix = String.isBlank(unitName) ? '' : ' – ' + unitName;
        return 'Approval ' + event + ': ' + requestType + suffix;
    }

    @TestVisible
    private static String opsBodyFor(Approval_Request__c r, String event, String unitName, String projectName, String reviewerComment) {
        String recordLink = URL.getOrgDomainUrl().toExternalForm()
            + '/lightning/r/Approval_Request__c/' + r.Id + '/view';
        String requester = (r.Requester__r != null && r.Requester__r.Name != null) ? r.Requester__r.Name : 'a user';
        String statusColor = (event == 'Approved') ? '#2e844a' : (event == 'Rejected') ? '#ba0517' : '#c59b08';

        String commentBlock = '';
        if ((event == 'Approved' || event == 'Rejected') && String.isNotBlank(reviewerComment)) {
            commentBlock =
                '<div style="margin:0 0 16px;padding:12px 16px;background:#f7f7f7;border-left:4px solid #c8a24a;">' +
                '<strong>Approver comment:</strong><br/>' + reviewerComment.escapeHtml4() + '</div>';
        }

        String justificationBlock = String.isBlank(r.Justification__c) ? '' :
            '<div style="margin:0 0 16px;"><strong>Justification:</strong><br/>' + r.Justification__c.escapeHtml4() + '</div>';

        return
            '<html><body style="font-family: Arial, sans-serif; font-size: 14px; color: #333; line-height: 1.6;">' +
            'Dear Director of Operations,<br/><br/>' +
            'An approval request has been <strong style="color:' + statusColor + ';">' + event.toLowerCase() + '</strong>:' +
            '<table style="border-collapse:collapse;margin:16px 0;">' +
            opsRow('Request type', r.Request_Type__c) +
            (String.isBlank(projectName) ? '' : opsRow('Project', projectName)) +
            (String.isBlank(unitName) ? '' : opsRow('Unit', unitName)) +
            opsRow('Current value', r.Current_Value__c) +
            opsRow('Requested value', r.Requested_Value__c) +
            opsRow('Requested by', requester) +
            opsRow('Status', r.Status__c) +
            '</table>' +
            commentBlock +
            justificationBlock +
            '<a href="' + recordLink + '" style="background:#c8a24a;color:#ffffff;padding:8px 16px;' +
            'text-decoration:none;border-radius:4px;">View Approval Request</a>' +
            '<br/><br/><hr style="border:none;border-top:1px solid #ddd;"/>' +
            'MIRA Developments — Sales Operations' +
            '</body></html>';
    }

    private static String opsRow(String label, String value) {
        return '<tr><td style="padding:4px 12px 4px 0;color:#666;">' + label + '</td>' +
               '<td style="padding:4px 0;"><strong>' +
               (String.isBlank(value) ? '—' : value.escapeHtml4()) + '</strong></td></tr>';
    }
}