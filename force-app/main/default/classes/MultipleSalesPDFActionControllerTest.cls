@IsTest
private class MultipleSalesPDFActionControllerTest {

    @TestSetup
    static void makeData() {
        Project__c project = new Project__c(
            Name                      = 'test project',
            Description__c            = 'description',
            District__c               = 'Meydan',
            Coordinates_Latitude__c   = 2,
            Coordinates_Longitude__c  = 1,
            Handover__c               = Date.today(),
            Minimum_Cost__c           = 20
        );
        insert project;

        Unit__c unit = new Unit__c(
            Title__c               = 'Test Unit',
            Cost_AED__c            = 1000000,
            Type__c                = 'Apartment',
            Total_Area__c          = 1000,
            Living_Space__c        = 800,
            Additional_Area__c     = 200,
            Floor__c               = 5,
            Number_of_Bedrooms__c  = 2,
            Number_of_Bathrooms__c = 2,
            View__c                = 'Test View',
            Building__c            = 'Test Building',
            Panorama_Link__c       = 'Test Link',
            Project__c             = project.Id,
            Maids_Room__c          = true,
            Status__c              = 'Draft'
        );
        insert unit;

        Cash_Flow_Sum__c cashFlowSum = new Cash_Flow_Sum__c(
            Unit__c = unit.Id,
            Name    = 'cash Flow test'
        );
        insert cashFlowSum;

        List<Cash_Flow__c> cashFlows = new List<Cash_Flow__c>();
        for (Integer i = 0; i < 8; i++) {
            cashFlows.add(new Cash_Flow__c(
                Unit__c           = unit.Id,
                Name              = 'Instalment ' + i,
                Cash_Flow_Sum__c  = cashFlowSum.Id,
                Date__c           = Date.today().addDays(i),
                Percent__c        = 10
            ));
        }
        insert cashFlows;

        insert new Payment_Plan__c(
            Name       = 'payment plan',
            Percent__c = 20,
            Date__c   = Date.today(),
            Project__c = project.Id
        );

        List<File__c> files = new List<File__c>{
            new File__c(Type__c = 'Schemas/PDFs', Unit__c = unit.Id),
            new File__c(Type__c = 'Schemas/PDFs', Unit__c = unit.Id),
            new File__c(Type__c = 'Schemas/PDFs', Unit__c = unit.Id)
        };
        insert files;
        files = [SELECT Id FROM File__c WHERE Unit__c = :unit.Id ORDER BY Id];

        List<ContentVersion> contentVersions = new List<ContentVersion>{
            new ContentVersion(
                Title          = 'MSPDFAction Test Doc 1',
                VersionData    = Blob.valueOf('Test content'),
                PathOnClient   = 'MSPDFActionTest1.pdf',
                IsMajorVersion = true
            ),
            new ContentVersion(
                Title          = 'MSPDFAction Test Doc 2',
                VersionData    = Blob.valueOf('Test content'),
                PathOnClient   = 'MSPDFActionTest2.pdf',
                IsMajorVersion = true
            ),
            new ContentVersion(
                Title          = 'MSPDFAction Test Doc 3',
                VersionData    = Blob.valueOf('Test content'),
                PathOnClient   = 'MSPDFActionTest3.pdf',
                IsMajorVersion = true
            )
        };
        insert contentVersions;
        contentVersions = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :new Map<Id, ContentVersion>(contentVersions).keySet()
        ];

        List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
        for (Integer i = 0; i < 3; i++) {
            contentDocumentLinks.add(new ContentDocumentLink(
                ContentDocumentId = contentVersions[i].ContentDocumentId,
                LinkedEntityId    = files[i].Id,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            ));
        }
        insert contentDocumentLinks;
    }

    @IsTest
    static void testGetContentDocumentId_createsSalesOfferPdfAndLink() {
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];

        MultipleSalesPDFActionController.FlowInput fparams = new MultipleSalesPDFActionController.FlowInput();
        fparams.recordsIds          = String.valueOf(testUnit.Id);
        fparams.selectedCurrency    = 'USD';
        fparams.selectedProjectName = 'test project';

        Test.startTest();
        MultipleSalesPDFActionController.FlowOutput[] outs =
            MultipleSalesPDFActionController.getContentDocumentId(
                new List<MultipleSalesPDFActionController.FlowInput>{ fparams }
            );
        Test.stopTest();

        System.assertNotEquals(null, outs, 'Invocable should return outputs');
        System.assertEquals(1, outs.size(), 'Expected one ContentDocument id');
        System.assert(
            String.isNotBlank(outs[0].contentDocumentId),
            'contentDocumentId should be populated'
        );

        List<ContentDocumentLink> unitLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testUnit.Id
            LIMIT 10
        ];
        System.assertEquals(1, unitLinks.size(), 'Exactly one file should be linked to the unit');
    }

    @IsTest
    static void testQuerySalesOfferDocumentLinks_emptyIds() {
        System.assertEquals(
            0,
            MultipleSalesPDFActionController.querySalesOfferDocumentLinks(new List<Id>()).size()
        );
        System.assertEquals(
            0,
            MultipleSalesPDFActionController.querySalesOfferDocumentLinks(null).size()
        );
    }

    @IsTest
    static void testGetPageReferenceForMultipleSalesOffer_knownProjects() {
        System.assertEquals(
            Page.MultipleSalesOfferT2Page.getUrl(),
            MultipleSalesPDFActionController.getPageReferenceForMultipleSalesOffer('Trussardi Residences 2').getUrl()
        );
        System.assertEquals(
            Page.SalesOfferPage.getUrl(),
            MultipleSalesPDFActionController.getPageReferenceForMultipleSalesOffer('unknown project').getUrl()
        );
        System.assertEquals(
            Page.SalesOfferPage.getUrl(),
            MultipleSalesPDFActionController.getPageReferenceForMultipleSalesOffer(null).getUrl()
        );
    }
}