@isTest
public class FilePreviewAndDownloadControllerTest {
    @isTest
    static void testFormData() {
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
            Maids_Room__c = true,
            Status__c = 'Draft'
        ));
        insert units;
        
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
        
        Test.startTest();
        Map<ID, String> contentDocumentId = FilePreviewAndDownloadController.getRelatedFilesByRecordId(files[0].Id);
        Test.stopTest();
    }
    
   /* @IsTest
    static void testGeneratePdf_NewContent() {
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        Map<ID, String> contentDocumentId = FilePreviewAndDownloadController.getRelatedFilesByRecordId(testUnit.Id);
        Test.stopTest();
        
        ContentDocumentLink cdl = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :testUnit.Id];
        //System.assertEquals(contentDocumentId, cdl.ContentDocumentId);
    }*/
    
    /*@IsTest
    static void testGeneratePdf_DeleteExistingContent() {
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];
        
        ContentVersion existingCV = new ContentVersion();
        existingCV.ContentLocation = 'S';
        existingCV.PathOnClient = 'Sales Offer Existing.pdf';
        existingCV.VersionData = Blob.valueOf('Existing PDF content');
        insert existingCV;

        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :existingCV.Id].ContentDocumentId;

        ContentDocumentLink existingCDL = new ContentDocumentLink();
        existingCDL.ContentDocumentId = contentDocId;
        existingCDL.LinkedEntityId = testUnit.Id;
        existingCDL.ShareType = 'V';
        insert existingCDL;
        
        Test.startTest();
        Map<ID, String> contentDocumentId = FilePreviewAndDownloadController.getRelatedFilesByRecordId(testUnit.Id);
        Test.stopTest();
        
        Integer oldCount = [SELECT COUNT() FROM ContentDocumentLink WHERE ContentDocumentId = :contentDocId];
        System.assertEquals(0, oldCount);
        
        Integer oldCVCount = [SELECT COUNT() FROM ContentDocument WHERE Id = :existingCV.ContentDocumentId];
        System.assertEquals(0, oldCVCount);
        
        ContentDocumentLink cdl = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :testUnit.Id];
        System.assertEquals(testUnit.Id, cdl.LinkedEntityId);
        //System.assertEquals(contentDocumentId, cdl.ContentDocumentId);
    }*/
}