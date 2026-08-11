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
                email.setSubject('GET READY — MIRA CORAL BAY IS COMING!');
                String emailBody = '<html><body style="font-family: Arial, sans-serif;">' +
                    '<p>Dear Valued Partner,</p><br/>'+
                    '<p>We are pleased to announce the upcoming launch of MIRA Coral Bay in Ras Al Khaimah, the world`s first multi-branded waterfront community, and the newest addition to the MIRA Developments portfolio.</p>'+
                    '<ul>'+
                    '<li>Premium Waterfront Community</li>'+
                    '<li>Apartments & Villas</li>'+
                    '<li>Fully Branded</li>'+
                    '<li>Fully Furnished</li>'+
                    '<li>100% Turnkey</li>'+
                    '<li>Starting from AED 550,000</li>'+
                    '</ul>'+
                    '<br/>'+
                    '<p>PAYMENT PLAN:</p>'+
                    '<ul>'+
                    '<li>50% During Construction</li>'+
                    '<li>50% Over 3 Years Post-Handover</li>'+
                    '</ul>'+
                    '<br/>'+
                    '<p>EOI NOW OPEN — AED 55,000</p><br/>'+
                    '<p>With an attractive entry point and a post-handover plan extending three years, MIRA Coral Bay is positioned to appeal to both end-users and investors seeking strong capital appreciation in one of the UAE`s fastest-growing emirates.</p>'+
                    '<p>Submit your clients’ EOI to our sales team NOW to secure priority allocation. We encourage you to begin engaging your database early to secure priority for your clients.</p>'+
                    '<p>Please find the launch creatives attached for your marketing use. For unit availability, floor plans, or to submit an EOI, kindly reach out to your Relationship Manager.</p>'+
                    '<p>We look forward to a successful launch together in SEPTEMBER 2026.</p><br/><br/>'+
                    '<a href="https://miradevelopments.ae/"><img src="https://iili.io/C675S71.md.jpg" alt="MIRA Coral Bay" /></a>'+
                    '<a href="https://miradevelopments.ae/"><img src="https://iili.io/C67YvOF.md.jpg" alt="MIRA Coral Bay Payment Plan" /></a>'+
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