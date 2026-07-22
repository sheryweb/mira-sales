trigger ReceiptTrigger on Receipt__c (before insert, after insert, after update, before delete, after delete, after undelete) {
    if (Trigger.isBefore && Trigger.isInsert) {
        ReceiptTriggerHelper.handleVoucherNumberAssignment(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isDelete) {
        ReceiptTriggerHelper.handleReceiptDelete(Trigger.old);
    }
    if (Trigger.isAfter) {
        FinancialEngineTriggerHandler.handleReceipts(Trigger.new, Trigger.old);
    }
}
