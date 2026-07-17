trigger InvoiceTrigger on Invoice__c (before insert, after insert, after update, after delete, after undelete) {
    if (Trigger.isBefore && Trigger.isInsert) {
        InvoiceTriggerHelper.handleInvoiceNumberAssignment(Trigger.new);
    }
    if (Trigger.isAfter) {
        FinancialEngineTriggerHandler.handleInvoices(Trigger.new, Trigger.old);
    }
}
