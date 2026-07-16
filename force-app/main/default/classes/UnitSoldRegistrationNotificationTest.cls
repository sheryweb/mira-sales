@isTest
public class UnitSoldRegistrationNotificationTest {
    @isTest
    static void testSendEmailWithPdfAttachment() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        // Create test Project
        Project__c testProject = new Project__c(
            Name = 'Test Project',
            Coordinates_Latitude__c = 12,
            Coordinates_Longitude__c = 21,
            Handover__c = system.today()
        );

        // Create test Unit__c
        Unit__c testUnit = new Unit__c(
            Title__c = 'Test Unit Title',
            Project__c = testProject.Id
        );
        insert testUnit;

        // Create test Opportunity
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'New',
            CloseDate = Date.today(),
            AccountId = testAccount.Id,
            Unit__c = testUnit.Id
        );
        insert testOpportunity;
        
        testOpportunity.StageName = 'Sold';
        update testOpportunity;

        Test.startTest();

        // Call the method
        List<Id> recordIds = new List<Id>{testOpportunity.Id};
        UnitSoldRegistrationNotification.sendEmailWithPdfAttachment(recordIds);

        Test.stopTest();
    }
}