@IsTest
private class ReceiptPDFUtilTest {
    
    @TestSetup
    static void setupTestData() {
        // Create a test receipt
        Receipt__c receipt = new Receipt__c(
            Description__c = 'Test Receipt Description',
            Receipt_Added_Date__c = Date.today(),
            Payment_Date__c = Date.today(),
            Received_Amount__c = 5000.75,
            Status__c = 'Reconciled',
            Customer_Name__c = 'Test Customer'
        );
        insert receipt;
    }
    
    @IsTest
    static void testGetReceiptPDFUrl() {
        // Get test receipt
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];
        
        Test.startTest();
        String pdfUrl = ReceiptPDFUtil.getReceiptPDFUrl(receipt.Id);
        Test.stopTest();
        
        // Verify URL structure
        System.assert(pdfUrl != null, 'URL should not be null');
        System.assert(pdfUrl.toLowerCase().endsWith('/apex/receiptpdf?id=' + String.valueOf(receipt.Id).toLowerCase()), 
                    'URL should end with the correct page and parameters');
        System.assert(pdfUrl.startsWith(System.URL.getOrgDomainUrl().toExternalForm()), 
                    'URL should start with org domain');
    }
    
    @IsTest
    static void testGetReceiptPDFUrlWithNullId() {
        // Test null ID handling
        Test.startTest();
        try {
            String pdfUrl = ReceiptPDFUtil.getReceiptPDFUrl(null);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            // Just verify an exception was thrown, don't check the specific message
            System.assert(e != null, 'Exception should not be null');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGetReceiptPDFPageRef() {
        // Get test receipt
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];
        
        Test.startTest();
        PageReference pageRef = ReceiptPDFUtil.getReceiptPDFPageRef(receipt.Id);
        Test.stopTest();
        
        // Verify PageReference properties
        System.assertEquals(true, pageRef.getUrl().toLowerCase().contains('receiptpdf'), 
                          'Page name should include receiptpdf');
        System.assertEquals(receipt.Id, pageRef.getParameters().get('id'), 
                          'ID parameter should match receipt ID');
    }
    
    @IsTest
    static void testGetReceiptPDFPageRefWithNullId() {
        // Test null ID handling
        Test.startTest();
        try {
            PageReference pageRef = ReceiptPDFUtil.getReceiptPDFPageRef(null);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            // Just verify an exception was thrown, don't check the specific message
            System.assert(e != null, 'Exception should not be null');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testGenerateReceiptPDFBlob() {
        // Get test receipt
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];
        
        Test.startTest();
        Blob pdfBlob = ReceiptPDFUtil.generateReceiptPDFBlob(receipt.Id);
        Test.stopTest();
        
        // In test context, this should return our test dummy content
        System.assertNotEquals(null, pdfBlob, 'PDF Blob should not be null');
        System.assertEquals('Test PDF Content', pdfBlob.toString(), 
                          'PDF Blob should contain test content');
    }
    
    @IsTest
    static void testGenerateReceiptPDFBlobWithNullId() {
        // Test null ID handling
        Test.startTest();
        try {
            Blob pdfBlob = ReceiptPDFUtil.generateReceiptPDFBlob(null);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            // Just verify an exception was thrown, don't check the specific message
            System.assert(e != null, 'Exception should not be null');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testAttachReceiptPDF() {
        // Get test receipt
        Receipt__c receipt = [SELECT Id, Name FROM Receipt__c LIMIT 1];
        
        Test.startTest();
        Id attachmentId = ReceiptPDFUtil.attachReceiptPDF(receipt.Id);
        Test.stopTest();
        
        // Verify attachment was created
        System.assertNotEquals(null, attachmentId, 'Attachment ID should not be null');
        
        // Query the attachment
        Attachment att = [
            SELECT Id, Name, ParentId, ContentType 
            FROM Attachment 
            WHERE Id = :attachmentId
        ];
        
        // Verify attachment properties
        System.assertEquals(receipt.Id, att.ParentId, 'Attachment should be linked to the receipt');
        System.assertEquals('Receipt_' + receipt.Name + '.pdf', att.Name, 'Attachment name should match expected pattern');
        System.assertEquals('application/pdf', att.ContentType, 'Content type should be PDF');
    }
    
    @IsTest
    static void testAttachReceiptPDFWithNullId() {
        // Test null ID handling
        Test.startTest();
        try {
            Id attachmentId = ReceiptPDFUtil.attachReceiptPDF(null);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            // Just verify an exception was thrown, don't check the specific message
            System.assert(e != null, 'Exception should not be null');
        }
        Test.stopTest();
    }
}