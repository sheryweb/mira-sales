global class SummerEscapePresentationBatch implements Database.Batchable<SObject>, Database.Stateful {
    //private static final String ACCOUNT_RECORD_TYPE_ID = '012Hp000001yUTAIA2'; // Sandbox
    private static final String ACCOUNT_RECORD_TYPE_ID = '012Hp000001yUTAIA2'; // Production

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Company_Email__c
            FROM Account 
            WHERE RecordTypeId = :ACCOUNT_RECORD_TYPE_ID
              AND Status__c = 'Completed' AND Summer_Escape_Notification_Sent__c = false
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
                email.setSubject('EXCLUSIVE OFFER - GIANFRANCO FERRE RESIDENCES');
                String emailBody = '<html><body style="font-family: Arial, sans-serif;">' +
                    '<a href="https://miradevelopments.ae/"><img src="https://i.postimg.cc/1RDhnWjD/Whats-App-Image-2026-05-09-at-10-31-57-AM.jpg" alt="Special Offer" /></a>'+
                    '<br/><br/>'+
                    'Regards,<br/>Agent Relations<br/>MIRA Developments<br/><br/>' +
                    '<img src="https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_logo_small.jpeg" alt="MIRA Developments Logo" style="max-width: 200px;"/>' +
                    '</body></html>';
                email.setHtmlBody(emailBody);
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
                    Summer_Escape_Notification_Sent__c = true
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