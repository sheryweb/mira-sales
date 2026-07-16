@isTest
private class ProjectDetailsServiceTest {

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
            Minimum_Cost__c = 2,
            Publish_Project__c = 'Published'
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
            Number_of_Bedrooms__c = 0,
            Number_of_Bathrooms__c = 2,
            Status__c = 'Draft',
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
            Status__c = 'Draft',
            Building__c = 'Test Building',
            Panorama_Link__c = 'Test Link',
            Project__c = projects[0].Id
        ));
        insert units;


        List<Main_Information__c> mainInformations = new List<Main_Information__c>();
        mainInformations.add(new Main_Information__c(
            Name = 'Main Information 1',
            Description__c = 'Description',
            Project__c = projects[0].Id
        ));
        mainInformations.add(new Main_Information__c(
            Name = 'Main Information 2',
            Description__c = 'Description',
            Project__c = projects[0].Id
        ));
        insert mainInformations;

        List<Advantage__c> advanteges = new List<Advantage__c>();
        advanteges.add(new Advantage__c(
            Name = 'Advantage 1',
            Description__c = 'Description',
            Project__c = projects[0].Id
        ));
        advanteges.add(new Advantage__c(
            Name = 'Advantage 2',
            Description__c = 'Description',
            Project__c = projects[0].Id
        ));
        insert advanteges;

        List<File__c> files = new List<File__c>();
        files.add(new File__c(
            Type__c = 'Project Exterior Photos',
            Project__c = projects[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Project Interior Photos',
            Project__c = projects[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Schemas/PDFs',
            Project__c = projects[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Project Map Image',
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
            LinkedEntityId = advanteges[0].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));

        insert contentDocumentLinks;
    }

    @isTest
    static void testDoGet() {
        List<Project__c> projects = [SELECT Id FROM Project__c];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/projectDetailsService';
        req.httpMethod = 'GET';
        req.params.put('Id', projects[0].Id);
        RestResponse response = new RestResponse();

        RestContext.request = req;
        RestContext.response = response;


        Test.startTest();
        ProjectDetailsService.doGet();
        Test.stopTest();

        System.assertEquals('application/json', RestContext.response.headers.get('Content-Type'));
        System.assertNotEquals(null, RestContext.response.responseBody);

        // Map<String, Object> responseBodyMap = (Map<String, Object>)JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        // System.assertEquals(units[0].Id, responseBodyMap.get('id'));
        // System.assertEquals(units[0].Title_Formula__c, responseBodyMap.get('title'));
    }
}