public class InvoiceRecordInsert {
    @InvocableMethod(label='Process Invoice Insertion' description='Processes collections of Invoice and Milestone Invoice records')
    public static List<ResponseWrapper> processInvoices(List<RequestWrapper> requestList) {
        if (requestList == null || requestList.isEmpty()) {
            throw new AuraHandledException('No data passed from the flow.');
        }

        // Extract data from the wrapper
        RequestWrapper request = requestList[0];
        List<Invoice__c> invoiceRecordAll = request.invoiceRecordAll;
        List<Milestone_Invoice__c> milestoneInvoiceAll = request.milestoneInvoiceAll;

        if (invoiceRecordAll == null || invoiceRecordAll.isEmpty()) {
            throw new AuraHandledException('The InvoiceRecordAll collection must have at least one record.');
        }

        try {
            // Step 1: Insert the first Invoice__c record
            Invoice__c invoice = invoiceRecordAll[0];
            insert invoice;

            // Get the newly inserted Invoice ID
            Id invoiceId = invoice.Id;

            // Step 2: Assign the Invoice ID to Milestone Invoice collection
            if (milestoneInvoiceAll != null && !milestoneInvoiceAll.isEmpty()) {
                for (Milestone_Invoice__c milestone : milestoneInvoiceAll) {
                    milestone.Invoice__c = invoiceId;
                }
                // Insert updated Milestone Invoice records
                insert milestoneInvoiceAll;
            }

            // Create and return the response
            ResponseWrapper response = new ResponseWrapper();
            response.invoiceId = invoiceId;
            return new List<ResponseWrapper>{response};

        } catch (Exception e) {
            throw new AuraHandledException('Error processing invoice records: ' + e.getMessage());
        }
    }

    // Wrapper class to accept multiple collection variables from the flow
    public class RequestWrapper {
        @InvocableVariable(required=true label='Invoice Records' description='Collection of Invoice__c records')
        public List<Invoice__c> invoiceRecordAll;

        @InvocableVariable(required=false label='Milestone Invoice Records' description='Collection of Milestone_Invoice__c records')
        public List<Milestone_Invoice__c> milestoneInvoiceAll;
    }

    // Wrapper class to return the Invoice ID back to the flow
    public class ResponseWrapper {
        @InvocableVariable(label='Invoice ID' description='ID of the newly created Invoice record')
        public Id invoiceId;
    }
}