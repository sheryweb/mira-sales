@isTest
public class AgencyReminderSchedulerTest {

    @isTest
    static void testExecuteMethod() {
        //Create test Account records
        Account acc1 = new Account(
            Name = 'Test Account 1',
            Status__c = 'Agreement Issued',
            Agreement_Issued_Date__c = Date.today().addDays(-5),
            Company_Email__c = 'test1@company.com',
            Contact_Email_2__c = 'test1@contact.com',
            First_Reminder_Sent__c = false,
            Second_Reminder_Sent__c = false,
            Type = 'Agency',
            RecordTypeId = '012Hp000001yUTAIA2'
        );
        insert acc1;

        Account acc2 = new Account(
            Name = 'Test Account 2',
            Status__c = 'Agreement Issued',
            Agreement_Issued_Date__c = Date.today().addDays(10),
            Company_Email__c = 'test2@company.com',
            Contact_Email_2__c = 'test2@contact.com',
            First_Reminder_Sent__c = true,
            Second_Reminder_Sent__c = false,
            Type = 'Agency',
            RecordTypeId = '012Hp000001yUTAIA2'
        );
        insert acc2;

        //Simulate the execution of the scheduled job
        Test.startTest();
        AgencyReminderScheduler.sendReminderEmails();  // Directly invoking the method
        Test.stopTest();
    }

    @isTest
    static void testSendReminderEmails() {
        //Create an Account with the right conditions to test the email sending logic
        Account acc = new Account(
            Name = 'Test Account 3',
            Status__c = 'Agreement Issued',
            Agreement_Issued_Date__c = Date.today().addDays(5),
            Company_Email__c = 'test3@company.com',
            Contact_Email_2__c = 'test3@contact.com',
            First_Reminder_Sent__c = false,
            Second_Reminder_Sent__c = false,
            Type = 'Agency',
            RecordTypeId = '012Hp000001yUTAIA2'
        );
        insert acc;

        //Test the static method sendReminderEmails
        Test.startTest();
        AgencyReminderScheduler.sendReminderEmails();  // Directly invoking the method
        Test.stopTest();
    }

    @isTest
    static void testNoEmailsForInactiveAccounts() {
        //Create an Account with Status not meeting criteria
        Account acc = new Account(
            Name = 'Test Account 4',
            Status__c = 'Agreement Issued',
            Agreement_Issued_Date__c = null,
            Company_Email__c = 'test4@company.com',
            First_Reminder_Sent__c = true,
            Second_Reminder_Sent__c = false,
            Type = 'Agency',
            RecordTypeId = '012Hp000001yUTAIA2'
        );
        insert acc;

        //Test the static method sendReminderEmails
        Test.startTest();
        AgencyReminderScheduler.sendReminderEmails();  // Directly invoking the method
        Test.stopTest();
    }
}