public with sharing class SignedAgreementController {

    @AuraEnabled
    /*public static String uploadFileToAccount(Id recordId, String fileName, String base64Data, String contentType) {
        try {
            // Decode the base64 data (if needed)
            base64Data = EncodingUtil.urlDecode(base64Data, 'UTF-8');
            
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.FirstPublishLocationId = recordId;
            cv.IsMajorVersion = true;

            insert cv;

            // Get the ContentDocumentId
            ContentVersion insertedCV = [
                SELECT Id, ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :cv.Id 
                LIMIT 1
            ];

            return insertedCV.ContentDocumentId;
        } catch (Exception e) {
            throw new AuraHandledException('Error uploading file: ' + e.getMessage());
        }
    }*/
    public static String uploadFileToAccount(Id recordId, String fileName, String base64Data, String contentType) {
        try {
            // Validate inputs
            if (String.isBlank(base64Data)) {
                throw new AuraHandledException('Failed to upload file: File content cannot be empty');
            }
            
            if (String.isBlank(contentType)) {
                contentType = 'application/pdf';
            }

            System.debug('Starting file upload process for: ' + fileName);
            System.debug('Content length: ' + base64Data.length());

            // Create ContentVersion record
            ContentVersion cv = new ContentVersion();
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.IsMajorVersion = true;
            cv.FirstPublishLocationId = recordId;
            
            // Insert the ContentVersion
            Database.SaveResult sr = Database.insert(cv, false);
            if (!sr.isSuccess()) {
                String errorMsg = 'Failed to insert ContentVersion: ';
                for(Database.Error err : sr.getErrors()) {
                    errorMsg += err.getMessage() + '; ';
                }
                throw new AuraHandledException(errorMsg);
            }
            
            // Query for ContentDocumentId
            cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            System.debug('File uploaded successfully. ContentDocumentId: ' + cv.ContentDocumentId);
            
            return cv.ContentDocumentId;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in uploadFileToAccount: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Failed to upload file: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void sendEmailWithContentVersion(Id recordId, Id contentVersionId) {
        Savepoint sp = Database.setSavepoint();
        try {
            System.debug('Starting email process for recordId: ' + recordId + ', contentVersionId: ' + contentVersionId);

            // Query the Account and related fields
            Account acc;
            try {
                acc = [
                    SELECT Id, Name, Company_Email__c, Contact_Email_2__c, MIRA_RM_Email__c, Renewal_Completed__c
                    FROM Account 
                    WHERE Id = :recordId 
                    LIMIT 1
                ];
                System.debug('Account queried successfully: ' + acc);
            } catch (Exception e) {
                throw new AuraHandledException('Failed to query account details: ' + e.getMessage());
            }

            // Build recipient email list
            List<String> recipientEmails = new List<String>();
            if (!String.isBlank(acc.Company_Email__c)) {
                recipientEmails.add(acc.Company_Email__c);
            }
            if (!String.isBlank(acc.Contact_Email_2__c)) {
                recipientEmails.add(acc.Contact_Email_2__c);
            }

            if (recipientEmails.isEmpty()) {
                throw new AuraHandledException('No recipient email found on the record.');
            }
            System.debug('Recipient emails: ' + recipientEmails);

            // Build CC email list
            String ccEmails = 'agents@miradevelopments.ae, maria.d@miradevelopments.ae';
            if (!String.isBlank(acc.MIRA_RM_Email__c)) {
                ccEmails += ', ' + acc.MIRA_RM_Email__c;
            }

            List<String> ccList = new List<String>();
            for (String ccEmail : ccEmails.split(',')) {
                if (!String.isBlank(ccEmail.trim())) {
                    ccList.add(ccEmail.trim());
                }
            }
            System.debug('CC emails: ' + ccList);

            // Query file to attach with proper error handling
            ContentVersion cv;
            try {
                cv = [
                    SELECT Id, Title, VersionData, ContentSize
                    FROM ContentVersion
                    WHERE Id = :contentVersionId
                    AND IsLatest = true
                    LIMIT 1
                ];
                System.debug('File queried successfully. Size: ' + cv.ContentSize);
            } catch (Exception e) {
                throw new AuraHandledException('Could not find the uploaded file: ' + e.getMessage());
            }

            // Construct email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(recipientEmails);
            email.setCcAddresses(ccList);
            email.setSubject('Renewal - Signed Agency Agreement - ' + acc.Name);

            String emailBody = '<html><body style="font-family: Arial, sans-serif;">' +
                'Dear ' + acc.Name + ',<br/><br/>' +
                'We are pleased to confirm that the renewal of your Broker Agreement with MIRA DEVELOPMENTS LLC has been successfully processed. The signed and stamped agreement is now ready for collection at our office.<br/><br/>' +
                'For your reference, we have attached the scanned copies of the renewed Broker Agreement and Marketing NOC. Kindly arrange to collect the original documents from our office at your earliest convenience.<br/><br/>' +
                'We value our partnership and look forward to another year of successful collaboration. Should you require any assistance, please don`t hesitate to contact us.<br/><br/>' +
                'Best Regards,<br/>Agent Relations<br/>MIRA Developments<br/><br/>' +
                '<img src="https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_logo_small.jpeg" alt="MIRA Developments Logo" style="max-width: 200px;"/>' +
                '</body></html>';

            email.setHtmlBody(emailBody);

            // Add file as attachment with proper error handling
            try {
                Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                attachment.setFileName(cv.Title);
                attachment.setBody(cv.VersionData);
                attachment.setContentType('application/pdf');
                email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
                System.debug('Attachment prepared successfully');
            } catch (Exception e) {
                throw new AuraHandledException('Error preparing file attachment: ' + e.getMessage());
            }

            // Set "From" address using Organization-Wide Email Address
            //email.setOrgWideEmailAddressId('0D2U90000000Y4vKAE'); //SandBox Organization-Wide Email Address ID
            email.setOrgWideEmailAddressId('0D2Rg0000000LkPKAU'); //Production Organization-Wide Email Address ID

            // Send the email with proper error handling
            try {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email }, false);
                for (Messaging.SendEmailResult result : results) {
                    if (!result.isSuccess()) {
                        String errorMsg = 'Email send failed: ';
                        for (Messaging.SendEmailError err : result.getErrors()) {
                            errorMsg += err.getMessage() + '; ';
                        }
                        throw new AuraHandledException(errorMsg);
                    }
                }
                System.debug('Email sent successfully');
            } catch (Exception e) {
                throw new AuraHandledException('Error sending email: ' + e.getMessage());
            }

            // Update Account with renewal completion date
            try {
                acc.Renewal_Completed__c = Date.today();
                update acc;
                System.debug('Account updated successfully');
            } catch (Exception e) {
                throw new AuraHandledException('Error updating account: ' + e.getMessage());
            }

        } catch (Exception e) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'Error in sendEmailWithContentVersion: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }
}