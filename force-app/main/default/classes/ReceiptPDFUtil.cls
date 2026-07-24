public with sharing class ReceiptPDFUtil {
    /**
     * Get the URL to view the receipt PDF for a given receipt ID
     * @param receiptId The ID of the receipt record
     * @return The URL to view the receipt PDF
     */
    @AuraEnabled
    public static String getReceiptPDFUrl(Id receiptId) {
        FinancialEngine.requireEnabled();
        if (receiptId == null) {
            throw new AuraHandledException('Receipt ID is required');
        }
        
        String baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
        String pdfUrl = baseUrl + '/apex/ReceiptPDF?id=' + receiptId;
        return pdfUrl;
    }
    
    /**
     * Get the page reference to view the receipt PDF for a given receipt ID
     * This method is useful for redirecting to the PDF from a controller
     * @param receiptId The ID of the receipt record
     * @return The PageReference for the receipt PDF
     */
    public static PageReference getReceiptPDFPageRef(Id receiptId) {
        if (receiptId == null) {
            throw new AuraHandledException('Receipt ID is required');
        }
        
        PageReference pageRef = Page.ReceiptPDF;
        pageRef.getParameters().put('id', receiptId);
        return pageRef;
    }
    
    /**
     * Generate the PDF as a Blob for a given receipt ID
     * This method is useful for attaching the PDF to records or emails
     * @param receiptId The ID of the receipt record
     * @return The PDF content as a Blob
     */
    public static Blob generateReceiptPDFBlob(Id receiptId) {
        if (receiptId == null) {
            throw new AuraHandledException('Receipt ID is required');
        }
        
        PageReference pageRef = Page.ReceiptPDF;
        pageRef.getParameters().put('id', receiptId);
        
        // If running in test context, we need to return a dummy Blob
        if (Test.isRunningTest()) {
            return Blob.valueOf('Test PDF Content');
        }
        
        // Get the PDF content
        Blob pdfBlob = pageRef.getContentAsPDF();
        return pdfBlob;
    }
    
    /**
     * Attach the receipt PDF to the receipt record
     * @param receiptId The ID of the receipt record
     * @return The ID of the created attachment
     */
    @AuraEnabled
    public static Id attachReceiptPDF(Id receiptId) {
        FinancialEngine.requireEnabled();
        if (receiptId == null) {
            throw new AuraHandledException('Receipt ID is required');
        }
        
        // Get the receipt name for the filename
        Receipt__c receipt = [SELECT Name FROM Receipt__c WHERE Id = :receiptId LIMIT 1];
        String fileName = 'Receipt_' + receipt.Name + '.pdf';
        
        // Generate the PDF
        Blob pdfBlob = generateReceiptPDFBlob(receiptId);
        
        // Create the attachment
        Attachment attachment = new Attachment();
        attachment.ParentId = receiptId;
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