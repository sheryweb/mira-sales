trigger CashFlowTrigger on Cash_Flow__c (after insert, after update, after delete) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            CashFlowTriggerHandler.handleCashFlowsAfterInsert(trigger.newMap.keySet());
            CashFlowTriggerHandler.updateInstallmentMilestone(Trigger.new);
            CashFlowTriggerHandler.handleCollectionStateChange(Trigger.new, null);
        } else if (Trigger.isUpdate) {
            CashFlowTriggerHandler.handleCashFlowsAfterUpdate(Trigger.newMap, Trigger.oldMap);
            CashFlowTriggerHandler.updateInstallmentMilestoneOnDateChange(Trigger.newMap, Trigger.oldMap);
            CashFlowTriggerHandler.handleCollectionStateChange(Trigger.new, Trigger.oldMap);
        } else if(Trigger.isDelete) {
            CashFlowTriggerHandler.updateInstallmentMilestone(Trigger.old);
            CashFlowTriggerHandler.handleCollectionStateChange(Trigger.old, null);
        }
    }
}
