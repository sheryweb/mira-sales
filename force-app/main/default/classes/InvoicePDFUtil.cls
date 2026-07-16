public with sharing class InvoicePDFUtil {
    /**
     * Get the URL to view the invoice PDF for a given invoice ID
     * @param invoiceId The ID of the invoice record
     * @return The URL to view the invoice PDF
     */
    @AuraEnabled
    public static String getInvoicePDFUrl(Id invoiceId) {
        if (invoiceId == null) {
            throw new AuraHandledException('Invoice ID is required');
        }
        
        String baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
        String pdfUrl = baseUrl + '/apex/InvoicePDF?id=' + invoiceId;
        return pdfUrl;
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