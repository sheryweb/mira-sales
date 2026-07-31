trigger OpportunityTrigger on Opportunity (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            OpportunityTriggerHandler.handleBeforeInsertOrUpdate(Trigger.new);
        }
    }
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            OpportunityTriggerHandler.handleAfterInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            OpportunityTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
