global class ProjectNotificationBatch implements Database.Batchable<SObject>, Database.Stateful {
    //private static final String ACCOUNT_RECORD_TYPE_ID = '012Hp000001yUTAIA2'; // Sandbox
    private static final String ACCOUNT_RECORD_TYPE_ID = '012Hp000001yUTAIA2'; // Production

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Company_Email__c 
            FROM Account 
            WHERE RecordTypeId = :ACCOUNT_RECORD_TYPE_ID
              AND Status__c = 'Completed' 
              AND Company_Email__c != null
              AND Project_Detail_Notification_Sent__c = false
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Account_Notification_Log__c> logs = new List<Account_Notification_Log__c>();
        List<Account> accountsToUpdate = new List<Account>();

        for (Account acc : scope) {
            try {
                // Generate PDF
                Blob pdfBlob;
                if (Test.isRunningTest()) {
                    pdfBlob = Blob.valueOf('Test PDF Content');
                } else {
                    PageReference pdfPage = Page.ProjectNotificationDraft;
                    pdfPage.getParameters().put('actId', acc.Id); // using 'actId' as per your VF usage
                    pdfBlob = pdfPage.getContent();
                }

                Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                attachment.setFileName('ProjectNotification.pdf');
                attachment.setBody(pdfBlob);
                attachment.setContentType('application/pdf');

                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new String[] { acc.Company_Email__c });
                email.setSubject('Formal Notification and Authorization to Market Project/Projects');
                String emailBody = 'Dear ' + acc.Name + ',\n\n' +
                    'Greetings from MIRA Developments!\n\n' +
                    'Please find attached the updated Notification and Authorization to market, Mira Developments Project/Projects.\n\n' +
                    'If you have any questions, please feel free to contact us on agents@miradevelopments.ae\n\n' +
                    'We appreciate your interest and look forward to potentially working together.\n\n\n' +
                    'Regards,\nAgent Relations\nMIRA Developments';
                email.setPlainTextBody(emailBody);
                email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
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
                    Project_Detail_Notification_Sent__c = true
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