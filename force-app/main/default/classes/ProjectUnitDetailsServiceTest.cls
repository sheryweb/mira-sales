@isTest
private class ProjectUnitDetailsServiceTest {

    @TestSetup
    static void makeData(){
        
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

        List<Unit__c> units = new List<Unit__c>();

        units.add(new Unit__c(
            Title__c = 'Test Unit',
            Cost_AED__c = 1000000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Additional_Area__c = 200,
            Floor__c = 5,
            Number_of_Bedrooms__c = 2,
            Number_of_Bathrooms__c = 2,
            View__c = 'Test View',
            Building__c = 'Test Building',
            Panorama_Link__c = 'Test Link',
            Project__c = projects[0].Id
        ));
        units.add(new Unit__c(
            Title__c = 'Test Unit 2',
            Cost_AED__c = 1000000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Additional_Area__c = 200,
            Floor__c = 5,
            Number_of_Bedrooms__c = 2,
            Number_of_Bathrooms__c = 2,
            View__c = 'Test View',
            Building__c = 'Test Building',
            Panorama_Link__c = 'Test Link',
            Project__c = projects[0].Id
        ));
        insert units;

        List<Cash_Flow_Sum__c> cashFlowSums = new List<Cash_Flow_Sum__c>();

        cashFlowSums.add(new Cash_Flow_Sum__c(
            Unit__c = units[0].Id,
            Name = 'cash Flow test'
        ));

        insert cashFlowSums;

        List<Cash_Flow__c> cashFlows = new List<Cash_Flow__c>();

        cashFlows.add(new Cash_Flow__c(
            Unit__c = units[0].Id,
            Name = 'cash Flow',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Date__c = Date.today()
        ));

        cashFlows.add(new Cash_Flow__c(
            Unit__c = units[0].Id,
            Name = 'cash Flow',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Date__c = Date.today()
        ));

        insert cashFlows;

        List<Payment_Plan__c> paymentPlans = new List<Payment_Plan__c>();

        paymentPlans.add(new Payment_Plan__c(
            Name = 'payment plan',
            Percent__c = 100,
            Date__c = Date.today(),
            Project__c = projects[0].Id
        ));

        insert paymentPlans;


        List<Main_Information__c> mainInformations = new List<Main_Information__c>();

        mainInformations.add(new Main_Information__c(
            Name = 'main info test',
            Description__c = 'desc',
            Project__c = projects[0].Id
        ));

        insert mainInformations;
        List<Advantage__c> advantages = new List<Advantage__c>();

        advantages.add(new Advantage__c(
            Name = 'adv test',
            Description__c = 'desc',
            Project__c = projects[0].Id
        ));

        insert advantages;

        List<File__c> files = new List<File__c>();

        files.add(new File__c(
            Type__c = 'Photos',
            Unit__c = units[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Project Interior Photos',
            Unit__c = units[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Sales Offer',
            Unit__c = units[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Schemas/PDFs',
            Unit__c = units[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Unit Layout Preview',
            Unit__c = units[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Project Interior Photos',
            Project__c = projects[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Unit Layout Preview',
            Unit__c = units[1].Id
        ));
        files.add(new File__c(
            Type__c = 'Photos',
            Unit__c = units[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Project Preview',
            Project__c = projects[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Project Cover Image',
            Project__c = projects[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Project Map Image',
            Project__c = projects[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Project Exterior Photos',
            Project__c = projects[0].Id
        ));
        insert files;

        
        List<ContentVersion> contentVersions = new List<ContentVersion>();
        contentVersions.add(new ContentVersion(
            Title = 'Test Document',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document2',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document3',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document4',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document5',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document6',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document7',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document8',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document9',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document10',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document11',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document12',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document13',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        insert contentVersions;
        contentVersions = [SELECT Id, ContentDocumentId, Title, FileExtension FROM ContentVersion];

        List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[0].ContentDocumentId,
            LinkedEntityId = files[0].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[1].ContentDocumentId,
            LinkedEntityId = files[1].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[2].ContentDocumentId,
            LinkedEntityId = files[2].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[3].ContentDocumentId,
            LinkedEntityId = files[3].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[4].ContentDocumentId,
            LinkedEntityId = files[4].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[5].ContentDocumentId,
            LinkedEntityId = files[5].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[6].ContentDocumentId,
            LinkedEntityId = files[6].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[7].ContentDocumentId,
            LinkedEntityId = files[7].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[7].ContentDocumentId,
            LinkedEntityId = files[8].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[7].ContentDocumentId,
            LinkedEntityId = files[9].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[7].ContentDocumentId,
            LinkedEntityId = files[10].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[7].ContentDocumentId,
            LinkedEntityId = files[11].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[8].ContentDocumentId,
            LinkedEntityId = advantages[0].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));

        insert contentDocumentLinks;

        units[0].Status__c = 'Published';
        update units;
        projects[0].Publish_Project__c = 'Published';
        projects[0].No_Handover_Payment__c = false;
        update projects;
    }

    @isTest
    static void testDoGet() {
        List<Unit__c> units = [SELECT Id FROM Unit__c ORDER BY Title__c ASC];
        List<Favorite__c> favorites = new List<Favorite__c>();
        favorites.add(new Favorite__c(
            Unit__c = units[0].Id
        ));
        favorites.add(new Favorite__c(
            Unit__c = units[1].Id
        ));
        insert favorites;

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/projectUnitDetailsService';
        req.httpMethod = 'GET';
        req.params.put('Id', units[0].Id);
        RestResponse response = new RestResponse();

        RestContext.request = req;
        RestContext.response = response;


        Test.startTest();
        ProjectUnitDetailsService.doGet();
        Test.stopTest();

        System.assertEquals('application/json', RestContext.response.headers.get('Content-Type'));
        System.assertNotEquals(null, RestContext.response.responseBody);

        // Map<String, Object> responseBodyMap = (Map<String, Object>)JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        // System.assertEquals(units[0].Id, responseBodyMap.get('id'));
        // System.assertEquals(units[0].Title_Formula__c, responseBodyMap.get('title'));
    }

    @isTest
    static void testDoGet2() {
        List<Unit__c> units = [SELECT Id FROM Unit__c WHERE Title__c = 'Test Unit'];
    
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/projectUnitDetailsService';
        req.httpMethod = 'GET';
        req.params.put('Id', units[0].Id);
        RestResponse response = new RestResponse();

        RestContext.request = req;
        RestContext.response = response;


        Test.startTest();
        ProjectUnitDetailsService.doGet();
        Test.stopTest();

        System.assertEquals('application/json', RestContext.response.headers.get('Content-Type'));
        System.assertNotEquals(null, RestContext.response.responseBody);

        // Map<String, Object> responseBodyMap = (Map<String, Object>)JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        // System.assertEquals(units[0].Id, responseBodyMap.get('id'));
        // System.assertEquals(units[0].Title_Formula__c, responseBodyMap.get('title'));
    }

}