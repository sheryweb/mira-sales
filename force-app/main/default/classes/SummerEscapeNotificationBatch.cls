global class SummerEscapeNotificationBatch implements Database.Batchable<SObject>, Database.Stateful {
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
                email.setSubject('🌴 Mira Developments Summer Escape 🌴 11 August – 11 September');
                String emailBody = '<html><body style="font-family: Arial, sans-serif;">' +
                    '🌴 Mira Developments Summer Escape 🌴 11 August – 11 September,<br/><br/>' +
                    'Join us for an exclusive one-month festival at Mira Developments Sales Boutique – Art of Living Mall.<br/><br/>' +
                    '🏆 Top Sales Awards<br/>' +
                    '<ul>' +
                    '<li>The first three agents who sell AED 5 million or more will each receive a Rolex watch.</li>' +
                    '<li>The top three brokerage firms by total sales volume will also be awarded – with Rolex Watches for their outstanding performance.</li>' +
                    '</ul><br/>' +
                    '🍹 VIP Broker Experience<br/>' +
                    'All registered brokers who visit our sales boutique will enjoy:<br/>' +
                    '<ul>' +
                    '<li>Complimentary access to selected restaurants and coffee shops</li>' +
                    '<li>Free barbershop services and more</li>' +
                    '<li>A vibrant work atmosphere inspired by Amalfi and Capri – the perfect summer escape, right from our boutique.</li>' +
                    '</ul><br/>' +
                    '🗓️ Don’t miss this chance to close deals, win big, and enjoy a month of luxury, rewards, and unforgettable summer vibes.<br/>' +
                    '👉 <a href="https://mirasummer.ae/">Register now</a> and be part of the Mira Developments Summer Escape.<br/><br/>' +
                    '<a href="https://mirasummer.ae/"><img src="https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_summer_offer.jpeg" alt="Summer Escape" style="max-width: 400px;"/></a><br/><br/>' +
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