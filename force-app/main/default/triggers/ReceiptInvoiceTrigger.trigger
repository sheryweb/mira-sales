trigger ReceiptInvoiceTrigger on Receipt_Invoice__c (after insert, after update, after delete, after undelete) {
    FinancialEngineTriggerHandler.handleReceiptInvoices(Trigger.new, Trigger.old);
}
