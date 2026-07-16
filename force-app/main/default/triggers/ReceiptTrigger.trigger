trigger ReceiptTrigger on Receipt__c (before insert) {
    if(Trigger.isBefore && Trigger.isInsert) {
        ReceiptTriggerHelper.handleVoucherNumberAssignment(Trigger.new);
    }
}