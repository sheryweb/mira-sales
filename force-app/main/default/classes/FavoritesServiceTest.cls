@isTest
private class FavoritesServiceTest {

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
            Number_of_Bedrooms__c = 1,
            Number_of_Bathrooms__c = 2,
            Status__c = 'Draft',
            Building__c = 'Test Building',
            Panorama_Link__c = 'Test Link',
            Project__c = projects[0].Id
        ));
        units.add(new Unit__c(
            Title__c = 'Test Unit 3',
            Cost_AED__c = 1000000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Additional_Area__c = 200,
            Floor__c = 5,
            Number_of_Bedrooms__c = 1,
            Number_of_Bathrooms__c = 2,
            Status__c = 'Draft',
            Building__c = 'Test Building',
            Panorama_Link__c = 'Test Link',
            Project__c = projects[0].Id
        ));
        insert units;
        
        List<Favorite__c> favoriteList = new List<Favorite__c>();
        favoriteList.add(new Favorite__c(
            Unit__c = units[0].Id
        ));
        favoriteList.add(new Favorite__c(
            Unit__c = units[1].Id

        ));
        favoriteList.add(new Favorite__c(
            Unit__c = units[2].Id

        ));
        insert favoriteList;

        List<File__c> files = new List<File__c>();

        files.add(new File__c(
            Type__c = 'Schemas/PDFs',
            Unit__c = units[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Unit Layout Preview',
            Unit__c = units[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Schemas/PDFs',
            Unit__c = units[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Schemas/PDFs',
            Unit__c = units[1].Id
        ));
        files.add(new File__c(
            Type__c = 'Unit Layout Preview',
            Unit__c = units[1].Id
        ));
        files.add(new File__c(
            Type__c = 'Schemas/PDFs',
            Unit__c = units[1].Id
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
            VersionData = Blob.valueOf('Test content4'),
            PathOnClient = 'TestDocument4' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document5',
            VersionData = Blob.valueOf('Test content5'),
            PathOnClient = 'TestDocument5' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document6',
            VersionData = Blob.valueOf('Test content6'),
            PathOnClient = 'TestDocument6' + '.pdf',
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
        insert contentDocumentLinks;

        units[0].Status__c = 'Published';
        units[1].Status__c = 'Published';
        update units;
    }

    @isTest
    static void testDoGet() {

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/favoritesService';
        req.httpMethod = 'GET';
        RestResponse response = new RestResponse();

        RestContext.request = req;
        RestContext.response = response;


        Test.startTest();
        FavoritesService.doGet();
        Test.stopTest();

        System.assertEquals('application/json', RestContext.response.headers.get('Content-Type'));
        System.assertNotEquals(null, RestContext.response.responseBody);
        System.debug(RestContext.response.responseBody);
        String responseBodyString = RestContext.response.responseBody.toString();
        Map<String, Object> parsedResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBodyString);
        List<Object> favorites = (List<Object>) parsedResponse.get('favorites');
        System.assertEquals(2, favorites.size());
    }
}