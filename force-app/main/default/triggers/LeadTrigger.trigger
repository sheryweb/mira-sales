trigger LeadTrigger on Lead (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            LeadTriggerHandler.assignRecordTypes(Trigger.new, Trigger.oldMap);
        }
    }
}