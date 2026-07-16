public class AgencyAgreementEmail {
    // Method to send email with PDF attached
    @InvocableMethod
    public static void sendEmailWithPdfAttachment(List<Id> recordIds) {
        sendEmailWithPdfAttachment(recordIds[0], false);
    }
    
    // Method to be called from LWC
    @AuraEnabled
    public static void sendEmailWithPdfAttachmentFromLWC(Id recordId, Boolean isRenewal) {
        try {
            sendEmailWithPdfAttachment(recordId, isRenewal);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // New method to update Account Registered_In__c field from LWC
    @AuraEnabled
    @TestVisible
    public static void updateAccountRegisteredIn(Id recordId, String registeredIn, String issuingAuthority) {
        if (String.isBlank(registeredIn)) {
            throw new AuraHandledException('Registered In value cannot be blank.');
        } else if (String.isBlank(issuingAuthority)) {
            throw new AuraHandledException('Issuing Authority value cannot be blank.');
        }

        try {
            Account accountToUpdate = new Account(
                Id = recordId,
                Registered_In__c = registeredIn,
                Issuing_Authority__c = issuingAuthority
            );
            update accountToUpdate;
        } catch (DmlException e) {
            // Handle potential DML exceptions (e.g., validation rules, field access issues)
            String errorMessage = 'Error updating account: ' + e.getDmlMessage(0);
            System.debug('Error updating Account Registered_In__c: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
            throw new AuraHandledException(errorMessage);
        } catch (Exception e) {
            // Handle other potential exceptions
             System.debug('Unexpected error updating Account Registered_In__c: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('An unexpected error occurred while updating the account.');
        }
    }
    
    // Private implementation method
    private static void sendEmailWithPdfAttachment(Id recordId, Boolean isRenewal) {
        // Fetch the recipient email from the record
        Account acct = [SELECT Id, Name, Company_Email__c, Contact_Email_2__c, MIRA_RM_Email__c, KYB_Signed__c FROM Account WHERE Id = :recordId LIMIT 1];
        
        //Prepare recipient emails
        List<String> recipientEmails = new List<String>();
        if (!String.isBlank(acct.Company_Email__c)) {
            recipientEmails.add(acct.Company_Email__c);
        }
        if (!String.isBlank(acct.Contact_Email_2__c)) {
            recipientEmails.add(acct.Contact_Email_2__c);
        }

        if (recipientEmails.isEmpty()) {
            throw new CustomException('No recipient email found on the record.');
        }
        
        String ccEmails = 'agents@miradevelopments.ae, maria.d@miradevelopments.ae';
        if (!String.isBlank(acct.MIRA_RM_Email__c)) {
            ccEmails += ', ' + acct.MIRA_RM_Email__c;
        }
        
        // Generate the Visualforce PDF
        Blob pdfBlob;
        Blob pdfBlob2;
        if (Test.isRunningTest()) {
            // Mock PDF content for test context
            pdfBlob = Blob.valueOf('Mock PDF Content'); // Using mocked Blob for testing
            pdfBlob2 = Blob.valueOf('Mock PDF Content 2'); // Using mocked Blob for testing
        } else {
            // Actual 1stPDF generation for non-test contexts
            PageReference pdfPage = Page.BrokerAgreementDraft;
            pdfPage.getParameters().put('actId', recordId);
            pdfBlob = pdfPage.getContentAsPDF();

            // Actual 2nd PDF generation for non-test contexts
            PageReference pdfPage2 = Page.KYBForm;
            pdfPage2.getParameters().put('actId', recordId);
            pdfBlob2 = pdfPage2.getContentAsPDF();
        }
        
        //Create an email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        //email.setToAddresses(new String[] { recipientEmails });
        email.setToAddresses(recipientEmails);
        
        // Set subject based on whether it's a renewal
        String subject = isRenewal ? 'Renewal - Broker Agency Agreement Issued - ' + acct.Name : 'Broker Agency Agreement Issued - ' + acct.Name;
        email.setSubject(subject);
        
        //Set the plain text body
        String emailBody = '<html><body style="font-family: Arial, sans-serif;">' +
            'Dear ' + acct.Name + ',<br/><br/>' +
            'Please find attached the Broker Agreement for your review. We kindly request that you ' +
            'review the document thoroughly, ensuring that all your company details listed in the ' +
            'agreement are accurate. If any amendments are needed, please let us know, and we ' +
            'will make the necessary changes.<br/><br/>' +
            'Once verified, please sign, stamp, and initial all pages of the agreement. Please note ' +
            'that we do not accept scanned copies as they do not comply with our internal ' +
            'requirements. You can either E-sign and return the document to us via email or send ' +
            'the original signed and stamped copy to our office at the following address:<br/><br/>' +
            'Address: MIRA Developments, Art of Living Mall, Al Barsha 2, Dubai, UAE<br/><br/>' +
            'Please ensure that the signed and stamped agreement is returned to us within two ' +
            'weeks from the date of this email. If we do not receive the agreement within this ' +
            'timeframe, the request will be considered null and void.<br/><br/>' +
            'After we receive the signed and stamped agreement, we will countersign it and provide ' +
            'you with the NOC for marketing purposes. We will notify you once your copy is ready for ' +
            'collection.<br/><br/>' +
            'Additionally, please find attached the "Know Your Broker" form, which must be completed, signed, stamped, and returned to us, as this is a mandatory requirement by the authorities.<br/><br/>' +
            'Thank you for your prompt attention to this matter. If you have any questions or need ' +
            'further assistance, please feel free to reach out.<br/><br/>' +
            'Regards,<br/>Agent Relations<br/>MIRA Developments<br/><br/>' +
            '<img src="https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_logo_small.jpeg" alt="MIRA Developments Logo" style="max-width: 200px;"/>' +
            '</body></html>';
        email.setHtmlBody(emailBody);
        
        // Attach 1st PDF to the email
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName('Agreement.pdf');
        attachment.setBody(pdfBlob); // Here is the PDF attachment being set

        // Attach 2nd PDF to the email
        Messaging.EmailFileAttachment attachment2 = new Messaging.EmailFileAttachment();
        attachment2.setFileName('Know Your Broker Form.pdf');
        attachment2.setBody(pdfBlob2); // Here is the PDF attachment being set

        if (acct.KYB_Signed__c) {
            email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
        } else {
            email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment, attachment2 });
        }
        
        // Add CC addresses if any
        // Add CC addresses if any valid email addresses are present
        if (!String.isBlank(ccEmails)) {
            // Split CC emails by comma and check if any are valid
            List<String> ccList = new List<String>();
            for (String ccEmail : ccEmails.split(',')) {
                ccEmail = ccEmail.trim();
                if (!String.isBlank(ccEmail)) {
                    ccList.add(ccEmail);
                }
            }
            
            // Set CC addresses if we have valid ones
            if (!ccList.isEmpty()) {
                email.setCcAddresses(ccList);
            }
        }
        
        // Set "From" address using Organization-Wide Email Address
        //email.setOrgWideEmailAddressId('0D2U90000000Y4vKAE'); //SandBox Organization-Wide Email Address ID
        email.setOrgWideEmailAddressId('0D2Rg0000000LkPKAU'); //Production Organization-Wide Email Address ID
        
        // Send the email
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        
        // Update Renewal_Issued__c field with current date if it's a renewal
        if (isRenewal) {
            Account accountToUpdate = new Account(
                Id = recordId,
                Renewal_Issued__c = Date.today()
            );
            update accountToUpdate;
        }
    }

    // Custom Exception to handle errors
    public class CustomException extends Exception {}
}