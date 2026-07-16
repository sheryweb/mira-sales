trigger ContactTrigger on Contact (before insert, after insert, before update, after update) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)){
        MSAzureAiTriggerHandler.handleSObjectTransliteratableFieldsNullify(trigger.new, trigger.old);
    }
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)){
        MSAzureAiTriggerHandler.handleSObjectTransliteratableFieldsChange(trigger.new, trigger.old);
    }
}