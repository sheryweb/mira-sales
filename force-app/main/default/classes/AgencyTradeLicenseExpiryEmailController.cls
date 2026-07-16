public with sharing class AgencyTradeLicenseExpiryEmailController {

    private static final String AGENCY_RECORD_TYPE_ID = '012Hp000001yUTAIA2';
    private static final String CC_EMAILS = 'agents@miradevelopments.ae';
    private static final String PRODUCTION_ORG_WIDE_EMAIL_ID = '0D2Rg0000000LkPKAU';
    private static final String SANDBOX_ORG_WIDE_EMAIL_ID = '0D2U90000000Y4vKAE';
    private static final Integer ELIGIBLE_ACCOUNTS_LIMIT = 15;

    @TestVisible
    private static Boolean skipRecordTypeFilterInTest = false;

    public class EligibleAccountWrapper {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String name;
        @AuraEnabled public String companyEmail;
        @AuraEnabled public String contactEmail2;
        @AuraEnabled public Integer notificationCount;
        @AuraEnabled public Date notificationDate;
        @AuraEnabled public Boolean notificationSent;
        @AuraEnabled public Date tradeLicenseExpiryDate;

        public EligibleAccountWrapper(Account acct) {
            this.accountId = acct.Id;
            this.name = acct.Name;
            this.companyEmail = acct.Company_Email__c;
            this.contactEmail2 = acct.Contact_Email_2__c;
            this.notificationCount = (acct.Trade_License_Expiry_Notification_Count__c != null)
                ? Integer.valueOf(acct.Trade_License_Expiry_Notification_Count__c)
                : 0;
            this.notificationDate = acct.Trade_License_Expiry_Notification_Date__c;
            this.notificationSent = acct.Trade_License_Expiry_Notification_Sent__c;
            this.tradeLicenseExpiryDate = acct.Trade_License_Expiry_Date__c;
        }
    }

    public class BulkSendResult {
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer failureCount;
        @AuraEnabled public List<String> errorMessages;

        public BulkSendResult() {
            this.successCount = 0;
            this.failureCount = 0;
            this.errorMessages = new List<String>();
        }
    }

    @TestVisible
    private static Boolean isTradeLicenseExpired(Date tradeLicenseExpiryDate) {
        return tradeLicenseExpiryDate != null && tradeLicenseExpiryDate <= Date.today();
    }

    @AuraEnabled(cacheable=true)
    public static List<EligibleAccountWrapper> getEligibleAgencyAccounts() {
        Date today = Date.today();
        Date notificationResendThreshold = today.addDays(-30);
        List<Account> accounts;

        if (skipRecordTypeFilterInTest) {
            accounts = [
                SELECT Id, Name, Company_Email__c, Contact_Email_2__c,
                    Trade_License_Expiry_Date__c,
                    Trade_License_Expiry_Notification_Count__c, Trade_License_Expiry_Notification_Date__c,
                    Trade_License_Expiry_Notification_Sent__c
                FROM Account
                WHERE Trade_License_Expiry_Date__c != null
                    AND Trade_License_Expiry_Date__c <= :today
                    AND Status__c = 'Completed'
                    AND (Trade_License_Expiry_Notification_Sent__c = false
                        OR Trade_License_Expiry_Notification_Date__c <= :notificationResendThreshold)
                ORDER BY Trade_License_Expiry_Date__c ASC
                LIMIT :ELIGIBLE_ACCOUNTS_LIMIT
            ];
        } else {
            Id agencyRecordTypeId = AGENCY_RECORD_TYPE_ID;
            accounts = [
                SELECT Id, Name, Company_Email__c, Contact_Email_2__c,
                    Trade_License_Expiry_Date__c,
                    Trade_License_Expiry_Notification_Count__c, Trade_License_Expiry_Notification_Date__c,
                    Trade_License_Expiry_Notification_Sent__c
                FROM Account
                WHERE RecordTypeId = :agencyRecordTypeId
                    AND Trade_License_Expiry_Date__c != null
                    AND Trade_License_Expiry_Date__c <= :today
                    AND Status__c = 'Completed'
                    AND (Trade_License_Expiry_Notification_Sent__c = false
                        OR Trade_License_Expiry_Notification_Date__c <= :notificationResendThreshold)
                ORDER BY Trade_License_Expiry_Date__c ASC
                LIMIT :ELIGIBLE_ACCOUNTS_LIMIT
            ];
        }

        List<EligibleAccountWrapper> wrappers = new List<EligibleAccountWrapper>();
        for (Account acct : accounts) {
            wrappers.add(new EligibleAccountWrapper(acct));
        }
        return wrappers;
    }

    @AuraEnabled
    public static void sendExpiryNotificationEmail(String accountId) {
        if (String.isBlank(accountId)) {
            throw new AuraHandledException('Account ID is required');
        }
        BulkSendResult result = sendExpiryNotificationEmails(new List<String>{ accountId });
        if (result.successCount == 0) {
            String message = !result.errorMessages.isEmpty()
                ? result.errorMessages[0]
                : 'Failed to send expiry notification email.';
            throw new AuraHandledException(message);
        }
    }

    @AuraEnabled
    public static BulkSendResult sendExpiryNotificationEmails(List<String> accountIds) {
        BulkSendResult result = new BulkSendResult();

        if (accountIds == null || accountIds.isEmpty()) {
            throw new AuraHandledException('At least one Account ID is required');
        }

        Set<Id> accountIdSet = new Set<Id>();
        for (String accountId : accountIds) {
            if (!String.isBlank(accountId)) {
                accountIdSet.add(accountId);
            }
        }

        if (accountIdSet.isEmpty()) {
            throw new AuraHandledException('At least one valid Account ID is required');
        }

        List<Account> accounts = [
            SELECT Id, Name, Company_Email__c, Contact_Email_2__c, Trade_License_Expiry_Date__c,
                Trade_License_Expiry_Notification_Count__c
            FROM Account
            WHERE Id IN :accountIdSet
        ];

        if (accounts.isEmpty()) {
            throw new AuraHandledException('No accounts found for the provided IDs.');
        }

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        List<Account> accountsPendingEmail = new List<Account>();
        Map<Id, Account> accountById = new Map<Id, Account>();

        for (Account acct : accounts) {
            accountById.put(acct.Id, acct);

            if (!isTradeLicenseExpired(acct.Trade_License_Expiry_Date__c)) {
                result.failureCount++;
                result.errorMessages.add(acct.Name + ': Trade license is not expired.');
                continue;
            }

            List<String> recipientEmails = getRecipientEmails(acct);

            if (recipientEmails.isEmpty()) {
                result.failureCount++;
                result.errorMessages.add(acct.Name + ': No recipient email found on the record.');
                continue;
            }

            emailsToSend.add(buildExpiryEmail(acct, recipientEmails));
            accountsPendingEmail.add(acct);
        }

        List<Account> accountsToUpdate = new List<Account>();
        if (!emailsToSend.isEmpty()) {
            accountsToUpdate = sendEmailsAndCollectSuccessfulAccounts(emailsToSend, accountsPendingEmail, result);
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
            for (Account acct : accountsToUpdate) {
                System.debug(
                    'Expiry notification email sent for account: ' + acct.Name +
                    ', Count: ' + acct.Trade_License_Expiry_Notification_Count__c
                );
            }
        }

        for (Id accountId : accountIdSet) {
            if (!accountById.containsKey(accountId)) {
                result.failureCount++;
                result.errorMessages.add('Account not found: ' + accountId);
            }
        }

        return result;
    }

    private static List<String> getRecipientEmails(Account acct) {
        List<String> recipientEmails = new List<String>();
        if (!String.isBlank(acct.Company_Email__c)) {
            recipientEmails.add(acct.Company_Email__c);
        }
        if (!String.isBlank(acct.Contact_Email_2__c)) {
            recipientEmails.add(acct.Contact_Email_2__c);
        }
        return recipientEmails;
    }

    private static Account prepareAccountForUpdate(Account acct) {
        Account updateAcct = new Account(Id = acct.Id);
        updateAcct.Trade_License_Expiry_Notification_Count__c = (acct.Trade_License_Expiry_Notification_Count__c != null)
            ? acct.Trade_License_Expiry_Notification_Count__c + 1
            : 1;
        updateAcct.Trade_License_Expiry_Notification_Sent__c = true;
        updateAcct.Trade_License_Expiry_Notification_Date__c = Date.today();
        return updateAcct;
    }

    private static Messaging.SingleEmailMessage buildExpiryEmail(Account acct, List<String> recipientEmails) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(recipientEmails);
        email.setWhatId(acct.Id);
        email.setSubject('Request for the Updated Documents');

        String emailBody = '<html><body style="font-family: Arial, sans-serif;">' +
            'Dear ' + acct.Name + ',<br/><br/>' +
            'Our records indicate your company documents have expired. To ensure compliance, we kindly request you to provide the updated versions of the following documents at your earliest convenience:<br/><br/>' +
            '• Trade License<br/>' +
            '• RERA Agency Registration (ORN Certificate)<br/>' +
            '• Broker Card<br/>' +
            '• Emirates ID (for all Partners / Shareholders)<br/>' +
            '• Passport Copies (for all Partners / Shareholders)<br/>' +
            '• VAT Certificate (If applicable)<br/>' +
            '• Bank Account Details<br/><br/>' +
            'Should you require any clarification or assistance, please do not hesitate to reach out. We appreciate your prompt attention to this matter and look forward to receiving the updated documents soon.<br/><br/>' +
            'Regards,<br/>Agent Relations<br/>MIRA Developments<br/><br/>' +
            '<img src="https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_logo_small.jpeg" alt="MIRA Developments Logo" style="max-width: 200px;"/>' +
            '</body></html>';
        email.setHtmlBody(emailBody);

        String ccEmails = Test.isRunningTest() ? 'test@example.com' : CC_EMAILS;
        applyCcAddresses(email, ccEmails);

        applyOrgWideEmailAddress(email);

        return email;
    }

    private static void applyOrgWideEmailAddress(Messaging.SingleEmailMessage email) {
        if (Test.isRunningTest()) {
            return;
        }

        try {
            Organization org = [SELECT IsSandbox FROM Organization LIMIT 1];
            Id configuredOweaId = org.IsSandbox
                ? SANDBOX_ORG_WIDE_EMAIL_ID
                : PRODUCTION_ORG_WIDE_EMAIL_ID;

            List<OrgWideEmailAddress> oweas = [
                SELECT Id
                FROM OrgWideEmailAddress
                WHERE Id = :configuredOweaId
                LIMIT 1
            ];

            if (!oweas.isEmpty()) {
                email.setOrgWideEmailAddressId(oweas[0].Id);
            } else {
                System.debug('Org-wide email address not found for Id: ' + configuredOweaId);
            }
        } catch (Exception ex) {
            System.debug('Error setting OrgWideEmailAddressId: ' + ex.getMessage());
        }
    }

    private static void applyCcAddresses(Messaging.SingleEmailMessage email, String ccEmails) {
        if (String.isBlank(ccEmails)) {
            return;
        }

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

    private static List<Account> sendEmailsAndCollectSuccessfulAccounts(
        List<Messaging.SingleEmailMessage> emailsToSend,
        List<Account> accountsPendingEmail,
        BulkSendResult result
    ) {
        List<Account> accountsToUpdate = new List<Account>();

        if (Test.isRunningTest()) {
            result.successCount += emailsToSend.size();
            for (Account acct : accountsPendingEmail) {
                accountsToUpdate.add(prepareAccountForUpdate(acct));
            }
            System.debug('Test Email batch size: ' + emailsToSend.size());
            return accountsToUpdate;
        }

        try {
            Messaging.SendEmailResult[] sendResults = Messaging.sendEmail(emailsToSend, false);
            for (Integer i = 0; i < sendResults.size(); i++) {
                Account sourceAccount = accountsPendingEmail[i];
                if (sendResults[i].isSuccess()) {
                    result.successCount++;
                    accountsToUpdate.add(prepareAccountForUpdate(sourceAccount));
                } else {
                    result.failureCount++;
                    for (Messaging.SendEmailError err : sendResults[i].getErrors()) {
                        result.errorMessages.add(sourceAccount.Name + ': ' + err.getMessage());
                    }
                }
            }
        } catch (Exception ex) {
            System.debug('Error sending emails: ' + ex.getMessage());
            throw new AuraHandledException(ex.getMessage());
        }

        return accountsToUpdate;
    }
}