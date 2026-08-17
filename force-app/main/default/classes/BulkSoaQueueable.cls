/**
 * BulkSoaQueueable — Finance Center bulk "SOA generate & email" action.
 *
 * Processes ONE opportunity per queueable execution and chains to the next: each send does a
 * PDF render (PageReference.getContent counts as a callout) followed by the email send and
 * the SOA_Log__c insert, and a callout may never follow DML inside one transaction — so
 * batching several sends into one execution would blow up on the second PDF. One-per-link
 * keeps every transaction callout-then-DML clean.
 *
 * Every attempt is logged by SOAEmailService itself (Channel = 'Bulk Email'). The engine gate
 * inside SOAEmailService still applies to every send.
 */
public without sharing class BulkSoaQueueable implements Queueable, Database.AllowsCallouts {

    private final List<Id> remaining;

    public BulkSoaQueueable(List<Id> opportunityIds) {
        remaining = opportunityIds == null ? new List<Id>() : opportunityIds;
    }

    public void execute(QueueableContext ctx) {
        if (remaining.isEmpty()) return;
        Id current = remaining.remove(0);
        SOAEmailService.bulkContext = true;
        try {
            SOAEmailService.sendSOAEmail(current); // outcome recorded in SOA_Log__c
        } finally {
            SOAEmailService.bulkContext = false;
        }
        if (!remaining.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new BulkSoaQueueable(remaining));
        }
    }
}
