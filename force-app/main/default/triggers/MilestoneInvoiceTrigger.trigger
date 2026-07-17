trigger MilestoneInvoiceTrigger on Milestone_Invoice__c (after insert, after update, after delete, after undelete) {
    FinancialEngineTriggerHandler.handleMilestoneInvoices(Trigger.new, Trigger.old);
}
