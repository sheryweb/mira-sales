public class AgencyAgreementHalfExecuted {
    // Method to send email with PDF attached
    @InvocableMethod
    public static void sendEmailNotification(List<Id> recordIds) {
        // Assuming only one Id is passed from Flow
        Id recordId = recordIds[0];
        // Fetch the recipient email from the record
        Account acct = [SELECT Id, Name, Company_Email__c, Contact_Email_2__c, MIRA_RM_Email__c, Agency_Category__c FROM Account WHERE Id = :recordId LIMIT 1];
        
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
        
        // Create an email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        //email.setToAddresses(new String[] { recipientEmail });
        email.setToAddresses(recipientEmails);
        email.setSubject('Half Executed Broker Agreement - ' + acct.Name);
        
        String emailBody = '';

        if (acct.Agency_Category__c == 'Georgian') {
            emailBody = '<html><body style="font-family: Arial, sans-serif;">' +
            'Dear ' + acct.Name + ',<br/><br/>' +
            'This is to confirm that we have received the signed agreement from your end.<br/><br/>' +
            'We will now proceed with the counter-signing process. Once the agreement is countersigned, we will promptly notify you and provide you with a copy of the agreement.<br/><br/>' +
            'Should you have any further questions or require any additional information, please feel free to reach out.<br/><br/>' +
            'Thank you once again for your cooperation.<br/><br/>' +
            'Regards,<br/>Agent Relations<br/>MIRA Developments<br/><br/>' +
            '<img src="https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_logo_small.jpeg" alt="MIRA Developments Logo" style="max-width: 200px;"/>' +
            '</body></html>';
        } else {
            emailBody = '<html><body style="font-family: Arial, sans-serif;">' +
            'Dear ' + acct.Name + ',<br/><br/>' +
            'This is to confirm that we have received the signed agreement from your end.<br/><br/>' +
            'We will now proceed with the counter-signing process. Once the agreement is countersigned, we will promptly notify you and provide you with a copy of the agreement and NOC for your records.<br/><br/>' +
            'Should you have any further questions or require any additional information, please feel free to reach out.<br/><br/>' +
            'Thank you once again for your cooperation.<br/><br/>' +
            'Regards,<br/>Agent Relations<br/>MIRA Developments<br/><br/>' +
            '<img src="https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_logo_small.jpeg" alt="MIRA Developments Logo" style="max-width: 200px;"/>' +
            '</body></html>';
        }
        email.setHtmlBody(emailBody);
        
        // Set the plain text body
        /*String emailBody = '<html><body style="font-family: Arial, sans-serif;">' +
            'Dear ' + acct.Name + ',<br/><br/>' +
            'This is to confirm that we have received the signed agreement from your end.<br/><br/>' +
            'We will now proceed with the counter-signing process. Once the agreement is countersigned, we will promptly notify you and provide you with a copy of the agreement and NOC for your records.<br/><br/>' +
            'Should you have any further questions or require any additional information, please feel free to reach out.<br/><br/>' +
            'Thank you once again for your cooperation.<br/><br/>' +
            'Regards,<br/>Agent Relations<br/>MIRA Developments<br/><br/>' +
            '<img src="https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_logo_small.jpeg" alt="MIRA Developments Logo" style="max-width: 200px;"/>' +
            '</body></html>';*/
        
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
    }

    // Custom Exception to handle errors
    public class CustomException extends Exception {}
}