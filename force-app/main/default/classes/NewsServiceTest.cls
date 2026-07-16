@isTest
private class NewsServiceTest {

    @isTest
    static void testNewsService() {
        List<News__c> news = new List<News__c>();
        news.add(new News__c (Name = 'test news', Description__c = 'description'));
        insert news;

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
        units.add(new Unit__c (
            Status__c = 'Draft', 
            Type__c = 'Apartment', 
            Total_Area__c = 123, 
            Living_Space__c = 12, 
            Number_of_Bedrooms__c = 2, 
            Number_of_Bathrooms__c = 1, 
            Cost_AED__c = 40, 
            Project__c = projects[0].Id
        ));
        insert units;

        units[0].Status__c = 'On Approval';
        update units;

        List<File__c> files = new List<File__c>();
        files.add(new File__c (Type__c = 'News Preview', News__c = news[0].Id, Unit__c = units[0].Id));
        files.add(new File__c (Type__c = 'News Content Photo', News__c = news[0].Id, Unit__c = units[0].Id));
        insert files;

        List<ContentVersion> contentVersions = new List<ContentVersion>();
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        );
        ContentVersion cv2 = new ContentVersion(
            Title = 'Test Document2',
            VersionData = Blob.valueOf('Test content2'),
            PathOnClient = 'TestDocument2' + '.pdf',
            IsMajorVersion = true
        );
        contentVersions.add(cv);
        contentVersions.add(cv2);
        insert contentVersions;
        contentVersions = [SELECT Id, ContentDocumentId, Title, FileExtension FROM ContentVersion];

        List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = contentVersions[0].ContentDocumentId;
        link.LinkedEntityId = files[0].Id;
        link.ShareType = 'V';
        link.Visibility = 'AllUsers';

        ContentDocumentLink link2 = new ContentDocumentLink();
        link2.ContentDocumentId = contentVersions[1].ContentDocumentId;
        link2.LinkedEntityId = files[1].Id;
        link2.ShareType = 'V';
        link2.Visibility = 'AllUsers';
        contentDocumentLinks.add(link);
        contentDocumentLinks.add(link2);
        insert contentDocumentLinks;

        news[0].Status__c = 'Published';
        update news;

        RestRequest request = new RestRequest();
        String month = String.valueOf(Date.today().month()).length() == 1 ? '0'+ String.valueOf(Date.today().month()) : String.valueOf(Date.today().month());
        String day = String.valueOf(Date.today().day()).length() == 1 ? '0'+ String.valueOf(Date.today().day()) : String.valueOf(Date.today().day());
        RestResponse response = new RestResponse();
        request.requestURI = '/services/apexrest/newsService';
        request.httpMethod = 'GET';
        request.addParameter('createdDate', '>= '+Date.today().year()+'-'+month+'-'+day+'T00:00:00Z');
        request.addParameter('limitRows', '5');
        request.addParameter('orderBy', 'CreatedDate DESC');
        request.addParameter('offset', '0');
        request.addParameter('unitId', units[0].Id);

        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        NewsService.doGet();
        Test.stopTest();

        response = RestContext.response;
        System.assertEquals('application/json', response.headers.get('Content-Type'));
        System.assertNotEquals(null, response.responseBody);
        List<Object> responseBody = (List<Object>) JSON.deserializeUntyped(response.responseBody.toString());
        List<Map<String, Object>> responseList = new List<Map<String, Object>>();
        for (Object obj : responseBody) {
            responseList.add((Map<String, Object>)obj);
        }
        System.assertEquals(1, responseList.size()); 
    }
}