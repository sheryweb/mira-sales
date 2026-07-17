trigger ReceiptTrigger on Receipt__c (before insert, after insert, after update, after delete, after undelete) {
    if (Trigger.isBefore && Trigger.isInsert) {
        ReceiptTriggerHelper.handleVoucherNumberAssignment(Trigger.new);
    }
    if (Trigger.isAfter) {
        FinancialEngineTriggerHandler.handleReceipts(Trigger.new, Trigger.old);
    }
}
