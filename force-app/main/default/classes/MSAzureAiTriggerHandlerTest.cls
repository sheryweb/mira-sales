@isTest
private class MSAzureAiTriggerHandlerTest { 
    @isTest
    static void testAccount() {
        Account acc = new Account();
        acc.Name = 'Test';
        acc.BillingCity = 'Paris';
        insert acc;

        acc.Name = 'Test New';
        acc.BillingCity = 'New York';
        update acc;
    }

    @isTest
    static void testContact() {
        Account acc = new Account();
        acc.Name = 'Test';
        insert acc;
        Contact c = new Contact();
        c.AccountId = acc.Id;
        c.LastName = 'Test';
        insert c;

        c.LastName = 'Test New';
        update c;
    }

    @isTest
    static void testProject() {
        Project__c prj = new Project__c (
            Name = 'test project', 
            Description__c = 'description', 
            District__c = 'Meydan', 
            Coordinates_Latitude__c = 2, 
            Coordinates_Longitude__c = 1, 
            Handover__c = Date.today(), 
            Minimum_Cost__c = 20
        );

        insert prj;

        prj.Name = 'test project new';
        update prj;
    }
}