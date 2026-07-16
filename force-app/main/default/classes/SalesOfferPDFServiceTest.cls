@isTest
private class SalesOfferPDFServiceTest {

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
            Project__c = projects[0].Id,
            Maids_Room__c = true
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
            Percent__c = 20,
            Date__c = Date.today(),
            Project__c = projects[0].Id
        ));

        insert paymentPlans;

        List<File__c> files = new List<File__c>();

        files.add(new File__c(
            Type__c = 'Schemas/PDFs',
            Unit__c = units[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Schemas/PDFs',
            Unit__c = units[0].Id
        ));
        files.add(new File__c(
            Type__c = 'Schemas/PDFs',
            Unit__c = units[0].Id
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

        insert contentDocumentLinks;
    }

    @isTest
    static void testGeneratePdf_Success() {
        Unit__c testUnit = [SELECT Id FROM Unit__c];

        RestRequest req = new RestRequest();
        RestResponse response = new RestResponse();
        RestContext.response = response;
        req.requestURI = '/services/apexrest/generatePdf';
        req.httpMethod = 'GET';
        req.addParameter('unitId', testUnit.Id);
        RestContext.request = req;

        Test.startTest();
        SalesOfferPDFService.generatePdf();
        Test.stopTest();
        
        System.assertEquals('TEST', RestContext.response.responseBody.toString());
    }

    @isTest
    static void testGeneratePdf_MissingUnitId() {
        
        RestRequest req = new RestRequest();
        RestResponse response = new RestResponse();
        RestContext.response = response;
        req.requestURI = '/services/apexrest/generatePdf';
        req.httpMethod = 'GET';
        RestContext.request = req;

        Test.startTest();
         SalesOfferPDFService.generatePdf();
        Test.stopTest();
        
        System.assertEquals('Unit ID parameter is required.', RestContext.response.responseBody.toString());
    }

}