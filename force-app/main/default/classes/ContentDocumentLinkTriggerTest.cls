@isTest
private class ContentDocumentLinkTriggerTest {

    @isTest
    static void testContentDocumentLinkTrigger() {
        List<File__c> files = new List<File__c>();
        files.add(new File__c(Type__c = 'Sales Offer'));
        files.add(new File__c(Type__c = 'Unit Layout Preview'));
        insert files;

        List<ContentVersion> cvs = new List<ContentVersion>();
        cvs.add(new ContentVersion(
            Title = 'Test Content',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('Test Data'),
            IsMajorVersion = true
        ));
        insert cvs;

        ContentDocument cd = [SELECT Id FROM ContentDocument];

        List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();
        cdls.add(new ContentDocumentLink(
            LinkedEntityId = files[0].Id,
            ContentDocumentId = cd.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        cdls.add(new ContentDocumentLink(
            LinkedEntityId = files[1].Id,
            ContentDocumentId = cd.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));

        Test.startTest();
        insert cdls;
        Test.stopTest();

        Set<Id> cdlIds = new Set<Id>();
        for(ContentDocumentLink cdl : cdls){
            cdlIds.add(cdl.Id);
        }
        List<ContentDocumentLink> updatedCdls = [SELECT Id, Visibility FROM ContentDocumentLink WHERE Id IN :cdlIds];

        System.assertEquals('AllUsers', updatedCdls[0].Visibility);
        System.assertEquals('AllUsers', updatedCdls[1].Visibility);
    }

    @isTest
    static void testContentDocumentLinkFieldValueNullTrigger() {

        List<Project__c> projects = new List<Project__c>();
        projects.add(new Project__c (
            Name = 'test project', 
            Description__c = 'description', 
            District__c = 'Meydan', 
            Coordinates_Latitude__c = 2, 
            Coordinates_Longitude__c = 1, 
            Handover__c = Date.today(),
            Minimum_Cost__c = 20
        ));
        insert projects;

        List<Advantage__c> advantages = new List<Advantage__c>();
        advantages.add(new Advantage__c(Name = 'Teat Advantage 1', Description__c = 'test', Project__c = projects[0].Id));
        advantages.add(new Advantage__c(Name = 'Teat Advantage 2', Description__c = 'test', Project__c = projects[0].Id));
        insert advantages;

        List<ContentVersion> cvs = new List<ContentVersion>();
        cvs.add(new ContentVersion(
            Title = 'Test Content',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('Test Data'),
            IsMajorVersion = true
        ));
        insert cvs;

        ContentDocument cd = [SELECT Id FROM ContentDocument];

        List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();
        cdls.add(new ContentDocumentLink(
            LinkedEntityId = advantages[0].Id,
            ContentDocumentId = cd.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        cdls.add(new ContentDocumentLink(
            LinkedEntityId = advantages[1].Id,
            ContentDocumentId = cd.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));

        Test.startTest();
        insert cdls;
        Test.stopTest();

        Set<Id> cdlIds = new Set<Id>();
        for(ContentDocumentLink cdl : cdls){
            cdlIds.add(cdl.Id);
        }
        List<ContentDocumentLink> updatedCdls = [SELECT Id, Visibility FROM ContentDocumentLink WHERE Id IN :cdlIds];

        System.assertEquals('AllUsers', updatedCdls[0].Visibility);
        System.assertEquals('AllUsers', updatedCdls[1].Visibility);
    }
}