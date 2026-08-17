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
                email.setSubject('Mira Coral Bay Project Briefing - Tuesday 18th August 2026');
                String emailBody = '<html><body style="font-family: Arial, sans-serif;">' +
                    '<p>MIRA DEVELOPMENTS - A new Era in Beachfront Living has arrived!</p><br/>'+
                    '<p><strong>MIRA CORAL BAY – AL MAIRID – RAS AL KHAIMAH</strong></p>'+
                    '<p>Location: https://maps.app.goo.gl/8tgwkDPNgx4kNSsbA</p><br/>'+
                    '<p>Unveiling Mira Coral Bay, the world’s first BRANDED waterfront community, set on the picturesque shores of Al, Mairid, Ras Al Khaimah.</p><br/>'+
                    '<p><strong>STARTING PRICE: Studio: AED 550K - Unbelievable for branded beachfront property!</strong></p>'+
                    '<ul>'+
                    '<li><strong>Payment Plan: 50 / 50 - 3 years post-handover</strong></li>'+
                    '<li><strong>EOIs now open! – Booking Deposit – AED 55K ($15K)</strong></li>'+
                    '<li><strong>LAUNCHING: September 2026</strong></li>'+
                    '</ul>'+
                    '<a href="https://miradevelopments.ae/"><img src="https://iili.io/Ci2bat4.md.jpg" alt="MIRA Coral Bay Payment Plan" /></a>'+
                    '<br/><br/>'+
                    'Regards,<br/>Agent Relations<br/>MIRA Developments<br/><br/>' +
                    '<img src="https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_logo_small.jpeg" alt="MIRA Developments Logo" style="max-width: 200px;"/>' +
                    '</body></html>';
                email.setHtmlBody(emailBody);
                //email.setOrgWideEmailAddressId('0D2Rg0000000LkPKAU'); //Working Organization-Wide Email Address ID (agents@miradevelopments.ae)
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