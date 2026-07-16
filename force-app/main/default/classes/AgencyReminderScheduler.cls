public class AgencyReminderScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        sendReminderEmails();
    }

    public static void sendReminderEmails() {
        List<Account> accountsToRemind = [
            SELECT Id, Name, Status__c, Agreement_Issued_Date__c, KYB_Signed__c, Company_Email__c, Contact_Email_2__c, MIRA_RM_Email__c, First_Reminder_Sent__c, Second_Reminder_Sent__c, Agency_Category__c
            FROM Account
            WHERE Status__c = 'Agreement Issued'
                  AND Agreement_Issued_Date__c != NULL AND Type = 'Agency' AND RecordTypeId = '012Hp000001yUTAIA2'
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Account> accountsToUpdate = new List<Account>();
        Date today = Date.today();

        for (Account acc : accountsToRemind) {
            Date IssuedDate = acc.Agreement_Issued_Date__c;
            Integer daysSinceIssued = IssuedDate.daysBetween(today);
            System.debug('Issued Date - '+ IssuedDate + ' | Days Passed till Today - '+IssuedDate.daysBetween(today));
            
            if (daysSinceIssued == 5 || daysSinceIssued == 10) {
                if (acc.First_Reminder_Sent__c == false) {
                    emails.add(createEmail(acc, 'Broker Agency Agreement Issued - 1st Reminder'));
                    acc.First_Reminder_Sent__c = true;
                    accountsToUpdate.add(acc);
                } else {
                    emails.add(createEmail(acc, 'Broker Agency Agreement Issued - 2nd Reminder'));
                    acc.Second_Reminder_Sent__c = true;
                    accountsToUpdate.add(acc);
                }
            }
        }
		
        //Sending emails
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
        
        //Update account records to reflect reminder status
        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }

    private static Messaging.SingleEmailMessage createEmail(Account acct, String subject) {    
        //Prepare recipient emails
        List<String> recipientEmails = new List<String>();
        if (!String.isBlank(acct.Company_Email__c)) {
            recipientEmails.add(acct.Company_Email__c);
        }
        if (!String.isBlank(acct.Contact_Email_2__c)) {
            recipientEmails.add(acct.Contact_Email_2__c);
        }
        
        String ccEmails = 'agents@miradevelopments.ae, maria.d@miradevelopments.ae';
        //String ccEmails = 'sheraz.dev@gmail.com';
        if (!String.isBlank(acct.MIRA_RM_Email__c)) {
            ccEmails += ', ' + acct.MIRA_RM_Email__c;
        }
        
        //Create an email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(recipientEmails);
        email.setSubject(subject);

        Boolean isGeorgian = (acct.Agency_Category__c != null && acct.Agency_Category__c.equalsIgnoreCase('Georgian'));

        if (isGeorgian) {
            //Georgian agencies: custom body, no attachments
            String emailBody = '<html><body style="font-family: Arial, sans-serif;">' +
                'Dear ' + acct.Name + ',<br/><br/>' +
                'This is a gentle reminder regarding the Broker Agency Agreement previously shared with you for review and execution.<br/><br/>' +
                'Kindly confirm that all company details are accurate and proceed with signing, stamping, and initialing all pages of the agreement at your earliest convenience. If any revisions or clarifications are required, please feel free to let us know and we will be happy to assist promptly.<br/><br/>' +
                'Once we receive the duly executed agreement, we will proceed with countersigning and share the finalized copy with you.<br/><br/>' +
                'We would appreciate your prompt attention to this matter and look forward to your response.<br/><br/>' +
                'Should you have any questions or require further assistance, please do not hesitate to contact us.<br/><br/>' +
                'Regards,<br/>Agent Relations<br/>MIRA Developments<br/><br/>' +
                '<img src="https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_logo_small.jpeg" alt="MIRA Developments Logo" style="max-width: 200px;"/>' +
                '</body></html>';
            email.setHtmlBody(emailBody);
        } else {
            //Generate the Visualforce PDF
            Blob pdfBlob;
            Blob pdfBlob2;
            if (Test.isRunningTest()) {
                //Mock PDF content for test context
                pdfBlob = Blob.valueOf('Mock PDF Content'); // Using mocked Blob for testing
                pdfBlob2 = Blob.valueOf('Mock PDF Content 2'); // Using mocked Blob for testing
            } else {
                //Actual PDF generation for non-test contexts
                PageReference pdfPage = Page.BrokerAgreementDraft;
                pdfPage.getParameters().put('actId', acct.Id);
                pdfBlob = pdfPage.getContentAsPDF();

                // Actual 2nd PDF generation for non-test contexts
                PageReference pdfPage2 = Page.KYBForm;
                pdfPage2.getParameters().put('actId', acct.Id);
                pdfBlob2 = pdfPage2.getContentAsPDF();
            }

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
        }
        
        //Add CC addresses if any valid email addresses are present
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
        return email;
    }
}