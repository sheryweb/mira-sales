@isTest
private class ProjectTriggerTest {

    @isTest
    static void testHandleProjecsAfterUpdate() {
        List<Project__c> projects = new List<Project__c>();
        projects.add(new Project__c (
            Name = 'test project', 
            Description__c = 'description', 
            District__c = 'Meydan', 
            Coordinates_Latitude__c = 2, 
            Coordinates_Longitude__c = 1, 
            Handover__c = Date.today(), 
            Minimum_Cost__c = 2,
            Publish_Project__c = 'Draft',
            Old_Project__c = true
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
        files.add(new File__c(
            Type__c = 'Project Interior Photos',
            Project__c = projects[0].Id
        ));
        insert files;
        
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
        contentVersions.add(new ContentVersion(
            Title = 'Test Document7',
            VersionData = Blob.valueOf('Test content7'),
            PathOnClient = 'TestDocument7' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document8',
            VersionData = Blob.valueOf('Test content8'),
            PathOnClient = 'TestDocument8' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document9',
            VersionData = Blob.valueOf('Test content9'),
            PathOnClient = 'TestDocument9' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document10',
            VersionData = Blob.valueOf('Test content10'),
            PathOnClient = 'TestDocument10' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document11',
            VersionData = Blob.valueOf('Test content11'),
            PathOnClient = 'TestDocument11' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document12',
            VersionData = Blob.valueOf('Test content12'),
            PathOnClient = 'TestDocument12' + '.pdf',
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
            ContentDocumentId = contentVersions[5].ContentDocumentId,
            LinkedEntityId = files[6].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[5].ContentDocumentId,
            LinkedEntityId = files[7].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[5].ContentDocumentId,
            LinkedEntityId = files[8].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[5].ContentDocumentId,
            LinkedEntityId = files[9].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[5].ContentDocumentId,
            LinkedEntityId = files[10].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));

        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[3].ContentDocumentId,
            LinkedEntityId = advantages[0].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        insert contentDocumentLinks;

        units[0].Status__c = 'Published';
        units[1].Status__c = 'Booked';
        update units;

        List<Payment_Plan__c> paymentPlans = new List<Payment_Plan__c>();
        paymentPlans.add(new Payment_Plan__c(Project__c = projects[0].Id, Date__c = Date.today(), Percent__c = 50));
        paymentPlans.add(new Payment_Plan__c(Project__c = projects[0].Id, Date__c = Date.today().addYears(1), Percent__c = 50));
        insert paymentPlans;

        List<Additional_Payment__c> additionalPlans = new List<Additional_Payment__c>();
        additionalPlans.add(new Additional_Payment__c(Project__c = projects[0].Id, Percent__c = 25));
        additionalPlans.add(new Additional_Payment__c(Project__c = projects[0].Id, Percent__c = 15));
        insert additionalPlans;

        Test.startTest();
        projects[0].Publish_Project__c = 'Published';
        projects[0].No_Handover_Payment__c = false;
        update projects;
        Test.stopTest();

        List<Cash_Flow_Sum__c> cashFlowSums = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c = :units[0].Id];
        System.assertEquals(2, cashFlowSums.size());

        List<Cash_Flow__c> cashFlows = [SELECT Id FROM Cash_Flow__c WHERE Unit__c = :units[0].Id];
        System.assertEquals(4, cashFlows.size());

        List<Cash_Flow_Sum__c> cashFlowSums2 = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c = :units[1].Id];
        System.assertEquals(0, cashFlowSums2.size());

        List<Cash_Flow__c> cashFlows2 = [SELECT Id FROM Cash_Flow__c WHERE Unit__c = :units[1].Id];
        System.assertEquals(0, cashFlows2.size());
    }
}