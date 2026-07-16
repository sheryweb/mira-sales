@isTest
private class ClientFileServiceTest {

    @TestSetup
    static void makeData(){
        
        List<Client__c> clients = new List<Client__c>();
        clients.add(new Client__c (
            First_Name__c = 'FirstName', 
            Last_Name__c = 'LastName',
            Email__c = 'email@op.pl',
            Phone__c = '123456789',
            Citizenship__c = '🇦🇩',
            Passport_ID__c = '123',
            Registration_Address_City__c = 'Waw',
            Registration_address_Country__c = '🇦🇩',
            Registration_Address_Postal_Code__c = '11-111',
            Registration_Address_Street__c = 'St',
            Shipping_Address_City__c = 'Waw',
            Shipping_Address_Country__c = '🇦🇩',
            Shipping_Address_Postal_Code__c = '11-111',
            Shipping_Address_Street__c = 'St'
        ));
        insert clients;

        List<File__c> files = new List<File__c>();

        files.add(new File__c(
            Type__c = 'Schemas/PDFs',
            Client__c = clients[0].Id
        ));
        insert files;

        List<ContentVersion> contentVersions = new List<ContentVersion>();
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        );
        contentVersions.add(cv);
        insert contentVersions;
        contentVersions = [SELECT Id, ContentDocumentId, Title, FileExtension FROM ContentVersion];

        List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = contentVersions[0].ContentDocumentId;
        link.LinkedEntityId = files[0].Id;
        link.ShareType = 'V';
        link.Visibility = 'AllUsers';
        contentDocumentLinks.add(link);
        insert contentDocumentLinks;

    }

    @isTest
    static void testDeleteClientFile() {
        List<File__c> files = [SELECT Id FROM File__c];

        List<ContentDocumentLink> cdlList = [SELECT Id, ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :files[0].Id];

        RestRequest req = new RestRequest();
        RestResponse response = new RestResponse();
        RestContext.response = response;
        req.requestURI = '/services/apexrest/ClientFileService';
        req.httpMethod = 'DELETE';
        req.addParameter('contentDocumentId', cdlList[0].ContentDocumentId);
        RestContext.request = req;
        Test.startTest();
        ClientFileService.deleteClientFile();
        Test.stopTest();
        List<ContentVersion> contentVersions = [SELECT Id, ContentDocumentId, Title, FileExtension FROM ContentVersion];
        System.assertEquals(0, contentVersions.size());
    }

    @isTest
    static void testGetClientFile() {
        Client__c client = [SELECT Id FROM Client__c];

        RestRequest req = new RestRequest();
        RestResponse response = new RestResponse();
        req.requestURI = '/services/apexrest/ClientFileService';
        req.httpMethod = 'GET';
        req.addParameter('clientId', client.Id);
        RestContext.request = req;
        RestContext.response = response;

        Test.startTest();
        ClientFileService.getClientFile();
        Test.stopTest();
        response = RestContext.response;
        System.assertEquals('application/json', RestContext.response.headers.get('Content-Type'));
        System.assertNotEquals(null, RestContext.response.responseBody);
    }

}