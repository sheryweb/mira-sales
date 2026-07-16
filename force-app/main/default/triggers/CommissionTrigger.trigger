trigger CommissionTrigger on Commission__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            CommissionTriggerHandler.handleBeforeInsertOrUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            CommissionTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            CommissionTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}