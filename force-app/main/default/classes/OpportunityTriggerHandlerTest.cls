@isTest
public class OpportunityTriggerHandlerTest {
    @testSetup
    static void setup() {
        // Create test users
        User testUser1 = new User(
            Username = 'pro1@mm.com',
            Alias = 'test1',
            Email = 'mm@mm.com',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name='Standard User'].Id,
            LanguageLocaleKey = 'en_US',
            LastName = 'Test1'
        );
        insert testUser1;

        User testUser2 = new User(
            Username = 'pro2@yy.com',
            Alias = 'test2',
            Email = 'yy@yy.com',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name='Standard User'].Id,
            LanguageLocaleKey = 'en_US',
            LastName = 'Test2'
        );
        insert testUser2;
    }

    @isTest
    static void testOpportunityInsert() {
        // Test inserting an Opportunity
        User testUser1 = [SELECT Id FROM User WHERE Username = 'pro1@mm.com' LIMIT 1];
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            OwnerId = testUser1.Id
        );
        insert opp;

        Opportunity insertedOpp = [SELECT Assigned_To__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Test1', insertedOpp.Assigned_To__c);
    }

    @isTest
    static void testOpportunityUpdate() {
        // Test updating an Opportunity
        User testUser1 = [SELECT Id FROM User WHERE Username = 'pro1@mm.com' LIMIT 1];
        User testUser2 = [SELECT Id FROM User WHERE Username = 'pro2@yy.com' LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            OwnerId = testUser1.Id
        );
        insert opp;

        opp.OwnerId = testUser2.Id;
        update opp;

        Opportunity updatedOpp = [SELECT Assigned_To__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Test2', updatedOpp.Assigned_To__c);
    }
}