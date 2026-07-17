trigger ReceiptAmountTrigger on Receipt_Amount__c (after insert, after update, after delete, after undelete) {
    FinancialEngineTriggerHandler.handleReceiptAmounts(Trigger.new, Trigger.old);
}
