global class TradeLicenseExpiryNotificationBatch implements Database.Batchable<SObject>, Database.Stateful {
    //private static final String ACCOUNT_RECORD_TYPE_ID = '012Hp000001yUTAIA2'; // Sandbox
    private static final String ACCOUNT_RECORD_TYPE_ID = '012Hp000001yUTAIA2'; // Production

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Company_Email__c, Trade_License_Expiry_Date__c
            FROM Account 
            WHERE RecordTypeId = :ACCOUNT_RECORD_TYPE_ID
              AND Trade_License_Expiry_Date__c <= :System.today()
              AND Company_Email__c != null
              AND Trade_License_Expiry_Notification_Sent__c = false
              AND Status__c = 'Completed'
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Account_Notification_Log__c> logs = new List<Account_Notification_Log__c>();
        List<Account> accountsToUpdate = new List<Account>();

        for (Account acc : scope) {
            try {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new String[] { acc.Company_Email__c });
                email.setSubject('Request for Updated Company Documents');
                String emailBody = '<html><body style="font-family: Arial, sans-serif;">' +
                    'Dear ' + acc.Name + ',<br/><br/>' +
                    'Our records indicate your company documents have expired. To ensure compliance, we kindly request you to provide the updated versions of the following documents at your earliest convenience:<br/><br/>' +
                    '<ul>' +
                    '<li><strong style="color: #2c5282;">Trade License</strong></li>' +
                    '<li><strong style="color: #2c5282;">RERA Agency Registration (ORN Certificate)</strong></li>' +
                    '<li><strong style="color: #2c5282;">Broker Card</strong></li>' +
                    '<li><strong style="color: #2c5282;">Emirates ID</strong> (for all Partners / Shareholders)</li>' +
                    '<li><strong style="color: #2c5282;">Passport Copies</strong> (for all Partners / Shareholders)</li>' +
                    '<li><strong style="color: #2c5282;">VAT Certificate</strong> (If applicable)</li>' +
                    '</ul><br/>' +
                    'Should you require any clarification or assistance, please do not hesitate to reach out. We appreciate your prompt attention to this matter and look forward to receiving the updated documents soon.<br/><br/>' +
                    'Regards,<br/>Agent Relations<br/>MIRA Developments<br/><br/>' +
                    '<img src="https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_logo_small.jpeg" alt="MIRA Developments Logo" style="max-width: 200px;"/>' +
                    '</body></html>';
                email.setHtmlBody(emailBody);
                // Remove setPlainTextBody since we're using HTML email
                //email.setPlainTextBody(emailBody);
                //email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
                //email.setOrgWideEmailAddressId('0D2U90000000Y4vKAE'); //SandBox Organization-Wide Email Address ID
                email.setOrgWideEmailAddressId('0D2Rg0000000LkPKAU'); //Production Organization-Wide Email Address ID

                emails.add(email);

                // Log success
                logs.add(new Account_Notification_Log__c(
                    Name = acc.Name != null ? acc.Name.left(80) : 'Unnamed Account',
                    Account__c = acc.Id,
                    Email__c = acc.Company_Email__c,
                    Status__c = 'Sent',
                    Sent_On__c = System.now(),
                    Second_Log__c = true,
                    Error_Message__c = 'No Error'
                ));

                // Flag the Account as sent
                accountsToUpdate.add(new Account(
                    Id = acc.Id,
                    Trade_License_Expiry_Notification_Sent__c = true
                ));

            } catch (Exception e) {
                // Log failure
                logs.add(new Account_Notification_Log__c(
                    Name = acc.Name != null ? acc.Name.left(80) : 'Unnamed Account',
                    Account__c = acc.Id,
                    Email__c = acc.Company_Email__c,
                    Status__c = 'Failed',
                    Sent_On__c = System.now(),
                    Error_Message__c = e.getMessage()
                ));
            }
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }

        if (!logs.isEmpty()) {
            insert logs;
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Batch finished with logging and Account flag updates.');
    }
}