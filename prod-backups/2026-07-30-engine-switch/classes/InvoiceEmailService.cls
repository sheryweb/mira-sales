public with sharing class InvoiceEmailService {
    
    @AuraEnabled
    public static String sendInvoiceEmail(Id invoiceId) {
        try {
            // Fetch Invoice record with Account Email and Opportunity Owner Email
            Invoice__c invoice = [
                SELECT Id, Name, Invoice_Number__c, Customer_Name__c,
                       Account__c, Account__r.PersonEmail, Unit__r.Title__c, Unit__r.Project_Name_F__c,
                       Opportunity__c, Opportunity__r.Owner.Email, Unit__r.Building__c
                FROM Invoice__c
                WHERE Id = :invoiceId
                LIMIT 1
            ];
            
            // Validate customer email
            if (invoice.Account__c == null || String.isBlank(invoice.Account__r.PersonEmail)) {
                return 'Error: No customer email found for this invoice.';
            }
            
            // Generate PDF content
            PageReference pdfPage = Page.InvoicePDF;
            pdfPage.getParameters().put('id', invoiceId);
            
            // Set rendering options to ensure PDF is fully rendered
            pdfPage.setRedirect(true);
            
            // Generate the PDF blob
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF Content');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }
            
            // Prepare email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            // Set email recipients
            email.setToAddresses(new String[] { invoice.Account__r.PersonEmail });
            
            // Set CC recipient - include Opportunity Owner if available
            List<String> ccAddresses = new List<String>{ 'finance@miradevelopments.ae' };
            if (invoice.Opportunity__c != null && String.isNotBlank(invoice.Opportunity__r.Owner.Email)) {
                ccAddresses.add(invoice.Opportunity__r.Owner.Email);
            }
            email.setCcAddresses(ccAddresses);
            
            // Set email subject and body
            email.setSubject('Proforma Invoice for Unit ' + invoice.Unit__r.Title__c +' '+ invoice.Unit__r.Project_Name_F__c + ' - Invoice #' + invoice.Invoice_Number__c);
            email.setHtmlBody('Dear ' + invoice.Customer_Name__c + ',<br/><br/>' +
                             'I hope this email finds you well.<br/><br/>' +
                             'Please find the attached proforma invoice for Unit No. ' + invoice.Unit__r.Title__c + ' at ' + invoice.Unit__r.Project_Name_F__c + ' - '+ invoice.Unit__r.Building__c+', for your reference.<br/><br/>' +
                             'Timely payment ensures that your account remains in good standing and helps us continue to provide you with excellent service.<br/><br/>' +
                             'If you have any questions or need assistance, please don`t hesitate to reach out.<br/><br/>' +
                             'Thank you for your prompt attention to this matter.<br/><br/>' +
                             '<strong>Note: Please Ignore this email if the payment is already done.</strong><br/><br/><br/>' +
                             'Best regards,<br/><br/>' +
                             'Finance: finance@miradevelopments.ae<br/>' +
                             'M I R A Developments L L C');
            
            // Attach PDF to email
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName('Invoice_' + invoice.Invoice_Number__c + '.pdf');
            attachment.setBody(pdfBlob);
            attachment.setContentType('application/pdf');
            //email.setOrgWideEmailAddressId('0D2U90000000z9xKAA'); //SandBox Organization-Wide Email Address ID
            email.setOrgWideEmailAddressId('0D2Rg0000000VWrKAM'); //Production Organization-Wide Email Address ID

            email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
            
            // Send email
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            
            // Check results
            if (results[0].isSuccess()) {
                return 'Success: Invoice email sent to ' + invoice.Account__r.PersonEmail;
            } else {
                return 'Error: ' + results[0].getErrors()[0].getMessage();
            }
            
        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }
}