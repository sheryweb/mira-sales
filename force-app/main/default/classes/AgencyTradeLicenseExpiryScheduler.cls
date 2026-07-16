public class AgencyTradeLicenseExpiryScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        sendReminderEmails();
    }

    public static void sendReminderEmails() {
        List<Account> accountsToRemind = [
            SELECT Id, Name, Status__c, Trade_License_Expiry_Date__c, Company_Email__c, Contact_Email_2__c, MIRA_RM_Email__c, Trade_License_Expiry_Notification_Sent__c
            FROM Account
            WHERE Trade_License_Expiry_Date__c != NULL AND Type = 'Agency' AND RecordTypeId = '012Hp000001yUTAIA2' LIMIT 20
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Account> accountsToUpdate = new List<Account>();
        Date today = Date.today();

        for (Account acc : accountsToRemind) {
            Date TradeLicenseEpiry = acc.Trade_License_Expiry_Date__c;
            Integer daysDueExpiry = today.daysBetween(TradeLicenseEpiry);
            
            if (TradeLicenseEpiry < system.today() && acc.Trade_License_Expiry_Notification_Sent__c == false) {
                emails.add(createEmail(acc, 'Broker Agency Trade License Expiry - Reminder')); //Reminder for existing Agencies
                acc.Trade_License_Expiry_Notification_Sent__c = true;
                accountsToUpdate.add(acc);
            } else {
                if (daysDueExpiry == -5) {
                    emails.add(createEmail(acc, 'Broker Agency Trade License Expiry - 1st Reminder')); //5 days before Trade License Expiry
                } else if (daysDueExpiry == -10) {
                    emails.add(createEmail(acc, 'Broker Agency Trade License Expiry - 2nd Reminder')); //10 days before Trade License Expiry
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
        
        //Set the plain text body
        String emailBody = 'Dear ' + acct.Name + ',\n\n' +
            'We would like to inform you that our records show your company’s trade license has expired. In order to update our records, we kindly request that you provide the following renewed documents at your earliest convenience: \n\n' +
            '- Renewed Trade License \n ' +
            '- Renewed ORN Rera Certificate \n ' +
            '- Broker card \n\n' +
            'Please note that until the renewed documents are submitted, any eligible commission payments will be put on hold. We kindly request that you submit the required documents as soon as possible to avoid any inconvenience.\n\n ' +
            'If you have any questions or require further assistance, please feel free to contact us.\n\n ' +
            'Thank you for your prompt attention to this matter.\n\n ';
        email.setPlainTextBody(emailBody);
        
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