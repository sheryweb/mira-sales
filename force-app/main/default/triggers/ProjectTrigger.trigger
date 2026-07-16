trigger ProjectTrigger on Project__c (before insert, after insert, before update, after update) {
    if(Trigger.isAfter && Trigger.isUpdate){
        ProjectTriggerHandler.handleProjecsAfterUpdate(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)){
        MSAzureAiTriggerHandler.handleSObjectTransliteratableFieldsChange(trigger.new, trigger.old);
    }

    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)){
        MSAzureAiTriggerHandler.handleSObjectTransliteratableFieldsNullify(trigger.new, trigger.old);
    }
}