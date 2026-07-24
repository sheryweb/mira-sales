public with sharing class ReceiptEmailService {
    
    // Static variables for testing
    @TestVisible private static Blob testPdfBlob;
    @TestVisible private static Boolean isTestMode = false;
    
    @AuraEnabled
    public static String sendReceiptEmail(Id receiptId) {
        FinancialEngine.requireEnabled();
        try {
            // Fetch Receipt record with Account Email and Opportunity Owner Email
            Receipt__c receipt = [
                SELECT Id, Name, Customer_Name__c,
                       Account__c, Account__r.PersonEmail, Unit__r.Title__c, Unit__r.Project_Name_F__c,
                       Opportunity__c, Opportunity__r.Owner.Email, Unit__r.Building__c
                FROM Receipt__c
                WHERE Id = :receiptId
                LIMIT 1
            ];
            
            // Check if we're using a regular account
            if (receipt.Account__r.PersonEmail == null) {
                // Try to get contact email
                List<Contact> contacts = [
                    SELECT Email 
                    FROM Contact 
                    WHERE AccountId = :receipt.Account__c 
                    AND Email != null 
                    ORDER BY CreatedDate DESC 
                    LIMIT 1
                ];
                
                if (!contacts.isEmpty()) {
                    // We have a contact's email, use it for the primary contact
                    receipt.Account__r.PersonEmail = contacts[0].Email;
                }
            }
            
            // Validate customer email
            if (receipt.Account__c == null || String.isBlank(receipt.Account__r.PersonEmail)) {
                return 'Error: No customer email found for this receipt.';
            }
            
            // Generate PDF content
            PageReference pdfPage = Page.ReceiptPDF;
            pdfPage.getParameters().put('id', receiptId);
            
            // Set rendering options to ensure PDF is fully rendered
            pdfPage.setRedirect(true);
            
            // Generate the PDF blob
            Blob pdfBlob;
            // Check if we're in a test context
            if (Test.isRunningTest()) {
                if (isTestMode && testPdfBlob != null) {
                    // Use the custom PDF blob from test
                    pdfBlob = testPdfBlob;
                } else {
                    // Use simple test content
                    pdfBlob = Blob.valueOf('Test PDF Content');
                }
            } else {
                // Real PDF generation
                pdfBlob = pdfPage.getContentAsPDF();
            }
            
            // Prepare email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            // Set email recipients
            email.setToAddresses(new String[] { receipt.Account__r.PersonEmail });
            
            // Set CC recipient - include Opportunity Owner if available
            List<String> ccAddresses = new List<String>{ 'finance@miradevelopments.ae' };
            if (receipt.Opportunity__c != null && String.isNotBlank(receipt.Opportunity__r.Owner.Email)) {
                ccAddresses.add(receipt.Opportunity__r.Owner.Email);
            }
            email.setCcAddresses(ccAddresses);
            
            // Set email subject and body
            email.setSubject('Payment Receipt for Unit ' + receipt.Unit__r.Title__c + ' ' + receipt.Unit__r.Project_Name_F__c + ' - Receipt #' + receipt.Name);
            email.setHtmlBody('Dear ' + receipt.Customer_Name__c + ',<br/><br/>' +
                             'Please find the attached payment receipt for Unit No. ' + receipt.Unit__r.Title__c + ' at ' + receipt.Unit__r.Project_Name_F__c + ' - '+ receipt.Unit__r.Building__c + ', for your reference.<br/><br/>' +
                             'Best regards,<br/><br/>' +
                             'Finance: finance@miradevelopments.ae<br/>' +
                             'M I R A Developments L L C');
            
            // Attach PDF to email
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName('Receipt_' + receipt.Name + '.pdf');
            attachment.setBody(pdfBlob);
            attachment.setContentType('application/pdf');
            //email.setOrgWideEmailAddressId('0D2U90000000z9xKAA'); //SandBox Organization-Wide Email Address ID
            email.setOrgWideEmailAddressId('0D2Rg0000000VWrKAM'); //Production Organization-Wide Email Address ID
            
            email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
            
            // Send email
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            
            // Check results
            if (results[0].isSuccess()) {
                return 'Success: Receipt email sent to ' + receipt.Account__r.PersonEmail;
            } else {
                return 'Error: ' + results[0].getErrors()[0].getMessage();
            }
            
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }
}