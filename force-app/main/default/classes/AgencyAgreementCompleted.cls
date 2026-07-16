public class AgencyAgreementCompleted {
    @InvocableMethod
    public static void sendEmailNotification(List<Id> recordIds) {
        Id recordId = recordIds[0];

        // Fetch the Account record
        Account acct = [SELECT Id, Name, Company_Email__c, Contact_Email_2__c, MIRA_RM_Email__c, Assigned_RM__c, Assigned_RM_Name_as_User__c, Assigned_RM_Contact__c, Agency_Category__c
                        FROM Account WHERE Id = :recordId LIMIT 1];
		
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
        /*String recipientEmail = acct.Company_Email__c;
        if (String.isBlank(recipientEmail)) {
            throw new CustomException('Recipient email is missing on the record.');
        }*/

        String ccEmails = 'agents@miradevelopments.ae, maria.d@miradevelopments.ae';
        //String ccEmails = 'sheraz.dev@gmail.com';
        if (!String.isBlank(acct.MIRA_RM_Email__c)) {
            ccEmails += ', ' + acct.MIRA_RM_Email__c;
        }
		
        // Step 1: Query ContentDocumentLink to get ContentDocumentIds related to the Account
        List<ContentDocumentLink> documentLinks = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :recordId
        ];
        
        // Extract ContentDocumentIds into a Set
        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink link : documentLinks) {
            contentDocumentIds.add(link.ContentDocumentId);
        }
        
        // Step 2: Query ContentVersion using ContentDocumentIds
        List<ContentVersion> versions = new List<ContentVersion>();
        if (!contentDocumentIds.isEmpty()) {
            versions = [
                SELECT Id, Title, VersionData, ContentDocumentId, FileType 
                FROM ContentVersion 
                WHERE ContentDocumentId IN :contentDocumentIds AND Title LIKE '%NOC_Broker Agreement%' 
            	ORDER BY LastModifiedDate DESC LIMIT 1
            ];
        }

        System.debug('Content Versions: ' + versions);

        // Check if versions were found
        if (versions.isEmpty()) {
            throw new CustomException('No PDF file found with a matching title for the account.');
        }

        ContentVersion version = versions[0];  // Get the latest version
        Blob pdfBlob = version.VersionData;
        String pdfFileName = version.Title + '.pdf';
        
        Blob pdfBlob2;
        if (Test.isRunningTest()) {
            // Mock PDF content for test context
            pdfBlob2 = Blob.valueOf('Mock PDF Content 2'); // Using mocked Blob for testing
        } else {
            // Actual 2nd PDF generation for non-test contexts
            PageReference pdfPage2 = Page.ProjectNotificationDraft;
            pdfPage2.getParameters().put('actId', recordId);
            pdfBlob2 = pdfPage2.getContentAsPDF();
        }

        // Log the PDF Blob size
        System.debug('PDF Blob Size: ' + pdfBlob.size());
        
        // Check if the blob is empty or not a PDF
        if (pdfBlob == null || pdfBlob.size() == 0) {
            throw new CustomException('The PDF data is empty or invalid.');
        }

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        //email.setToAddresses(new String[] { recipientEmail });
        email.setToAddresses(recipientEmails);
        email.setSubject('Broker Registration Completed - ' + acct.Name);

        String emailBody = '';

        if (acct.Agency_Category__c == 'Georgian') {
            emailBody = '<html><body style="font-family: Arial, sans-serif;">' +
            'Dear ' + acct.Name + ',<br/><br/>' +
            'This is to inform you that the broker agreement between MIRA DEVELOPMENTS LLC and (' + acct.Name + ') has been duly signed and stamped.<br/><br/>' +
            'We are pleased to have reached this milestone in our partnership and are eager to move forward with our collaborative efforts. Your expertise and support are invaluable to us, and we are confident that this agreement will pave the way for a successful relationship between our organizations.<br/><br/>' +
            'We have attached the copy of the Broker agreement for your reference.<br/><br/>' +
            'Thank you once again for your cooperation throughout this process. We look forward to a fruitful partnership ahead.<br/><br/>' +
            'Regards,<br/>Agent Relations<br/>MIRA Developments<br/><br/>' +
            '<img src="https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_logo_small.jpeg" alt="MIRA Developments Logo" style="max-width: 200px;"/>' +
            '</body></html>';
        } else {
            emailBody = '<html><body style="font-family: Arial, sans-serif;">' +
            'Dear ' + acct.Name + ',<br/><br/>' +
            'This is to inform you that the broker agreement between MIRA DEVELOPMENTS LLC and (' + acct.Name + ') has been duly signed and stamped, and it is now ready for collection.<br/><br/>' +
            'We are pleased to have reached this milestone in our partnership and are eager to move forward with our collaborative efforts. Your expertise and support are invaluable to us, and we are confident that this agreement will pave the way for a successful relationship between our organizations.<br/><br/>' +
            'Kindly arrange to collect the signed and stamped agreement from our office. We have attached the scanned copy of the Broker agreement and Marketing NOC for your reference.<br/><br/>' +
            'Alternatively, if you would prefer us to courier the original to you, simply share your address and contact details and we will be glad to arrange delivery.<br/><br/>' +
            'Thank you once again for your cooperation throughout this process. We look forward to a fruitful partnership ahead.<br/><br/>' +
            'Note: Please create a group including all your agents and add our Relationship Manager "' + acct.Assigned_RM_Name_as_User__c + ' (Contact- '+ acct.Assigned_RM_Contact__c +')" to facilitate seamless communication if not created already.<br/><br/>' +
            'Kindly grant admin access to "' + acct.Assigned_RM_Name_as_User__c + '".<br/><br/>' +
            'Regards,<br/>Agent Relations<br/>MIRA Developments<br/><br/>' +
            '<img src="https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_logo_small.jpeg" alt="MIRA Developments Logo" style="max-width: 200px;"/>' +
            '</body></html>';
        }
        email.setHtmlBody(emailBody);

        // Add CC addresses if any
        if (!String.isBlank(ccEmails)) {
            List<String> ccList = new List<String>();
            for (String ccEmail : ccEmails.split(',')) {
                ccEmail = ccEmail.trim();
                if (!String.isBlank(ccEmail)) {
                    ccList.add(ccEmail);
                }
            }
            if (!ccList.isEmpty()) {
                email.setCcAddresses(ccList);
            }
        }

        // Attach the PDF to the email
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(pdfFileName); // Ensure the filename ends with .pdf
        attachment.setBody(pdfBlob);
        attachment.setContentType('application/pdf'); // Explicitly set the content type

        // Attach 2nd PDF (Project Notification) to the email
        Messaging.EmailFileAttachment attachment2 = new Messaging.EmailFileAttachment();
        attachment2.setFileName('Project Notification.pdf');
        attachment2.setBody(pdfBlob2); // Here is the PDF attachment being set

        email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment, attachment2 });

        //Set "From" address using Organization-Wide Email Address
        //email.setOrgWideEmailAddressId('0D2U90000000Y4vKAE'); //SandBox Organization-Wide Email Address ID
        email.setOrgWideEmailAddressId('0D2Rg0000000LkPKAU'); //Production Organization-Wide Email Address ID
        
        // Send the email
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        
        // Save the Project Notification PDF to Files after sending email
        try {
            // Create ContentVersion to save the PDF
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Project Notification - ' + acct.Name;
            cv.PathOnClient = 'Project_Notification_' + acct.Name + '.pdf';
            cv.VersionData = pdfBlob2;
            cv.ContentLocation = 'S'; // S = Salesforce (stored in Salesforce)
            cv.FirstPublishLocationId = recordId; // Link to the Account record
            
            insert cv;
            
            System.debug('Project Notification PDF saved to Files successfully for Account: ' + acct.Name);
            
        } catch (Exception ex) {
            System.debug('Error saving Project Notification PDF to Files: ' + ex.getMessage());
            // Continue execution even if file save fails, since email was already sent
        }
    }

    public class CustomException extends Exception {}
}