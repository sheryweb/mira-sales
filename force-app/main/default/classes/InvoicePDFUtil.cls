public with sharing class InvoicePDFUtil {
    /**
     * Get the URL to view the invoice PDF for a given invoice ID
     * @param invoiceId The ID of the invoice record
     * @return The URL to view the invoice PDF
     */
    @AuraEnabled
    public static String getInvoicePDFUrl(Id invoiceId) {
        FinancialEngine.requireEnabled();
        if (invoiceId == null) {
            throw new AuraHandledException('Invoice ID is required');
        }
        
        String baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
        String pdfUrl = baseUrl + '/apex/InvoicePDF?id=' + invoiceId;
        return pdfUrl;
    }

    /**
     * Get the URL to view the TAX INVOICE PDF for a given invoice ID. The same PDF is reused; the
     * VF page renders it in "tax" mode (title = TAX INVOICE, date = Tax_Invoice_Date__c).
     *
     * The Tax Invoice Date is locked in ONCE: if the invoice has no Tax_Invoice_Date__c yet, it is
     * set here to the earliest non-cancelled receipt's Payment Date and saved. A tax invoice implies
     * a taxable payment, so if no such receipt exists yet the request is blocked.
     *
     * @param invoiceId The ID of the invoice record
     * @return The URL to view the tax invoice PDF (with mode=tax)
     */
    @AuraEnabled
    public static String getTaxInvoicePDFUrl(Id invoiceId) {
        FinancialEngine.requireEnabled();
        if (invoiceId == null) {
            throw new AuraHandledException('Invoice ID is required');
        }

        Invoice__c invoice = [SELECT Id, Tax_Invoice_Date__c FROM Invoice__c WHERE Id = :invoiceId LIMIT 1];

        // Lock the tax date on first generation only.
        if (invoice.Tax_Invoice_Date__c == null) {
            Date firstPaymentDate = firstReceiptPaymentDate(invoiceId);
            if (firstPaymentDate == null) {
                throw new AuraHandledException(
                    'A payment must be received before a Tax Invoice can be issued for this invoice.');
            }
            invoice.Tax_Invoice_Date__c = firstPaymentDate;
            try {
                update invoice;
            } catch (Exception e) {
                throw new AuraHandledException('Could not set the Tax Invoice date: ' + e.getMessage());
            }
        }

        String baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
        return baseUrl + '/apex/InvoicePDF?id=' + invoiceId + '&mode=tax';
    }

    /**
     * Earliest Payment Date across the receipts that fund this invoice (via Receipt_Amount lines),
     * excluding Cancelled / Unreconciled receipts (mirrors FinancialEngine's exclusion rule).
     * @return the earliest payment date, or null if there is no qualifying receipt.
     */
    private static Date firstReceiptPaymentDate(Id invoiceId) {
        Date earliest = null;
        for (Receipt_Amount__c ra : [
            SELECT Receipt__r.Payment_Date__c
            FROM Receipt_Amount__c
            WHERE Invoice__c = :invoiceId
              AND Receipt__r.Payment_Date__c != null
              AND Receipt__r.Payment_Status__c != 'Cancelled'
              AND Receipt__r.Status__c != 'Unreconciled'
            ORDER BY Receipt__r.Payment_Date__c ASC
            LIMIT 1
        ]) {
            earliest = ra.Receipt__r.Payment_Date__c;
        }
        return earliest;
    }

    /**
     * Get the page reference to view the invoice PDF for a given invoice ID
     * This method is useful for redirecting to the PDF from a controller
     * @param invoiceId The ID of the invoice record
     * @return The PageReference for the invoice PDF
     */
    public static PageReference getInvoicePDFPageRef(Id invoiceId) {
        if (invoiceId == null) {
            throw new AuraHandledException('Invoice ID is required');
        }
        
        PageReference pageRef = Page.InvoicePDF;
        pageRef.getParameters().put('id', invoiceId);
        return pageRef;
    }
    
    /**
     * Generate the PDF as a Blob for a given invoice ID
     * This method is useful for attaching the PDF to records or emails
     * @param invoiceId The ID of the invoice record
     * @return The PDF content as a Blob
     */
    public static Blob generateInvoicePDFBlob(Id invoiceId) {
        if (invoiceId == null) {
            throw new AuraHandledException('Invoice ID is required');
        }
        
        PageReference pageRef = Page.InvoicePDF;
        pageRef.getParameters().put('id', invoiceId);
        
        // If running in test context, we need to return a dummy Blob
        if (Test.isRunningTest()) {
            return Blob.valueOf('Test PDF Content');
        }
        
        // Get the PDF content
        Blob pdfBlob = pageRef.getContentAsPDF();
        return pdfBlob;
    }
    
    /**
     * Attach the invoice PDF to the invoice record
     * @param invoiceId The ID of the invoice record
     * @return The ID of the created attachment
     */
    @AuraEnabled
    public static Id attachInvoicePDF(Id invoiceId) {
        FinancialEngine.requireEnabled();
        if (invoiceId == null) {
            throw new AuraHandledException('Invoice ID is required');
        }
        
        // Get the invoice name for the filename
        Invoice__c invoice = [SELECT Name, Invoice_Number__c FROM Invoice__c WHERE Id = :invoiceId LIMIT 1];
        String fileName = 'Invoice_' + (String.isNotBlank(invoice.Invoice_Number__c) ? invoice.Invoice_Number__c : invoice.Name) + '.pdf';
        
        // Generate the PDF
        Blob pdfBlob = generateInvoicePDFBlob(invoiceId);
        
        // Create the attachment
        Attachment attachment = new Attachment();
        attachment.ParentId = invoiceId;
        attachment.Name = fileName;
        attachment.Body = pdfBlob;
        attachment.ContentType = 'application/pdf';
        
        try {
            insert attachment;
            return attachment.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error attaching PDF: ' + e.getMessage());
        }
    }
}