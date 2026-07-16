trigger InvoiceTrigger on Invoice__c (before insert) {
    if(Trigger.isBefore && Trigger.isInsert) {
        InvoiceTriggerHelper.handleInvoiceNumberAssignment(Trigger.new);
    }
}