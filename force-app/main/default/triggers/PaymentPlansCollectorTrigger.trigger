trigger PaymentPlansCollectorTrigger on Payment_Plans_Collector__c (before insert, after insert, before update, after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        PlanCollectorTriggerHandler.handlePlanCollectorAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}