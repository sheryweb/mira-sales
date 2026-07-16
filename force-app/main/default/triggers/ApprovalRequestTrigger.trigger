trigger ApprovalRequestTrigger on Approval_Request__c (before insert, before update, after insert, after update) {
    ApprovalRequestTriggerHandler.handleTrigger(Trigger.new, Trigger.oldMap, Trigger.operationType);
}