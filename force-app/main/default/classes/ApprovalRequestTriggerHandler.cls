public class ApprovalRequestTriggerHandler {
    public static void handleTrigger(
        List<Approval_Request__c> newRecords,
        Map<Id, Approval_Request__c> oldMap,
        System.TriggerOperation operationType
    ) {
        switch on operationType {
            when BEFORE_INSERT {
                handleBeforeInsert(newRecords);
            }
            when BEFORE_UPDATE {
                handleBeforeUpdate(newRecords, oldMap);
            }
            when AFTER_INSERT {
                handleAfterInsert(newRecords);
            }
            when AFTER_UPDATE {
                handleAfterUpdate(newRecords, oldMap);
            }
        }
    }

    private static void handleBeforeInsert(List<Approval_Request__c> newRecords) {
        Set<Id> opportunityIds = new Set<Id>();

        for (Approval_Request__c req : newRecords) {
            if (req.Requester__c == null) {
                req.Requester__c = UserInfo.getUserId();
            }
            if (req.Status__c == null) {
                req.Status__c = 'Draft';
            }
            if (req.Request_Type__c == 'Fee Change' && req.Related_Record_Id__c != null) {
                opportunityIds.add(Id.valueOf(req.Related_Record_Id__c));
            }
            if (req.Request_Type__c == PaymentPlanApprovalService.REQUEST_TYPE_PAYMENT_PLAN
                && req.Unit__c != null) {
                populatePaymentPlanRequestOnInsert(req);
            }
        }

        if (!opportunityIds.isEmpty()) {
            Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>([
                SELECT Id, Registration_Fees__c
                FROM Opportunity
                WHERE Id IN :opportunityIds
            ]);

            for (Approval_Request__c req : newRecords) {
                if (req.Request_Type__c != 'Fee Change' || req.Related_Record_Id__c == null) {
                    continue;
                }
                Opportunity opp = opportunityMap.get(Id.valueOf(req.Related_Record_Id__c));
                if (opp == null) {
                    continue;
                }
                req.Current_Value__c = opp.Registration_Fees__c;
                if (req.Requested_Value__c == opp.Registration_Fees__c) {
                    req.addError('Requested fee must be different from the current fee.');
                }
                if (String.isBlank(req.Requested_Value__c)) {
                    req.addError('Requested fee cannot be empty.');
                }
            }
        }
    }

    private static void handleBeforeUpdate(
        List<Approval_Request__c> newRecords,
        Map<Id, Approval_Request__c> oldMap
    ) {
        for (Approval_Request__c req : newRecords) {
            Approval_Request__c oldReq = oldMap.get(req.Id);

            if (req.Request_Type__c == 'Fee Change') {
                if (req.Current_Value__c != oldReq.Current_Value__c) {
                    req.addError('Current fee cannot be modified once set.');
                }
                if (req.Related_Record_Id__c != oldReq.Related_Record_Id__c) {
                    req.addError('Related record cannot be changed once set.');
                }
            }

            if (req.Request_Type__c == PaymentPlanApprovalService.REQUEST_TYPE_PAYMENT_PLAN
                && req.Unit__c != oldReq.Unit__c
                && oldReq.Unit__c != null) {
                req.addError('Unit cannot be changed once set on a payment plan approval request.');
            }

            if (req.Request_Type__c == UnitPriceApprovalService.REQUEST_TYPE_UNIT_PRICE
                && req.Unit__c != oldReq.Unit__c
                && oldReq.Unit__c != null) {
                req.addError('Unit cannot be changed once set on a unit price approval request.');
            }

            if (req.Request_Type__c == ShareDealApprovalService.REQUEST_TYPE_SHARE_DEAL
                && req.Opportunity__c != oldReq.Opportunity__c
                && oldReq.Opportunity__c != null) {
                req.addError('Opportunity cannot be changed once set on a Share Deal approval request.');
            }
        }
    }

    private static void populatePaymentPlanRequestOnInsert(Approval_Request__c req) {
        List<Unit__c> units = [
            SELECT Id, Title__c
            FROM Unit__c
            WHERE Id = :req.Unit__c
            LIMIT 1
        ];
        if (units.isEmpty()) {
            return;
        }
        PaymentPlanApprovalService.populatePaymentPlanHeaderFields(req, units[0], null);
    }

    private static void handleAfterInsert(List<Approval_Request__c> newRecords) {
        // Profile/Bank portal requests are created directly as Pending — notify on submission.
        // (Document Re-upload is created as Draft and notified later via Draft->Pending update.)
        Set<Id> notifyIds = new Set<Id>();
        for (Approval_Request__c req : newRecords) {
            if (req.Status__c == 'Pending' || req.Status__c == 'Approved' || req.Status__c == 'Rejected') {
                notifyIds.add(req.Id);
            }
        }
        if (!notifyIds.isEmpty()) {
            ApprovalRequestNotificationService.notify(notifyIds);
        }
    }

    private static void handleAfterUpdate(
        List<Approval_Request__c> newRecords,
        Map<Id, Approval_Request__c> oldMap
    ) {
        Set<Id> notifyIds = new Set<Id>();
        for (Approval_Request__c req : newRecords) {
            Approval_Request__c oldReq = oldMap.get(req.Id);
            if (req.Status__c == oldReq.Status__c) {
                continue;
            }
            // Email the agency when the request is submitted (Draft->Pending) or decided
            // (Approved/Rejected). The service ignores non-portal request types.
            if (req.Status__c == 'Pending' || req.Status__c == 'Approved' || req.Status__c == 'Rejected') {
                notifyIds.add(req.Id);
            }
            if (req.Status__c == 'Rejected'
                && req.Request_Type__c == ShareDealApprovalService.REQUEST_TYPE_SHARE_DEAL) {
                ShareDealApprovalService.handleRejected(req.Id);
                continue;
            }
            if (req.Status__c != 'Approved') {
                continue;
            }
            if (req.Request_Type__c == PaymentPlanApprovalService.REQUEST_TYPE_PAYMENT_PLAN) {
                PaymentPlanApprovalService.applyApprovedChanges(req.Id);
            } else if (req.Request_Type__c == UnitPriceApprovalService.REQUEST_TYPE_UNIT_PRICE) {
                UnitPriceApprovalService.applyApprovedChanges(req.Id);
            } else if (req.Request_Type__c == ShareDealApprovalService.REQUEST_TYPE_SHARE_DEAL) {
                ShareDealApprovalService.applyApprovedChanges(req.Id);
            }
        }
        if (!notifyIds.isEmpty()) {
            ApprovalRequestNotificationService.notify(notifyIds);
        }
    }
}