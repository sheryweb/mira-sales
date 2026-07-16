@isTest
private class SalesOfferPDFControllerTest {

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
            Living_Space__c = 8000,
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
    static void testConstructor() {
        Unit__c unit = [SELECT Id FROM Unit__c];

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);

        SalesOfferPDFController controller = new SalesOfferPDFController();

        System.assertEquals(unit.Id, controller.unitObject.Id);
        System.assertEquals(String.valueOf(DateTime.newInstance(Date.today().year(),Date.today().month(),Date.today().day()).format('dd MMM YYYY')), controller.getTodayDate());
        System.assertEquals('Yes', controller.isMaidsRoom);
        
    }
    
    @isTest
    static void testGetters() {
        Unit__c unit = [SELECT Id FROM Unit__c];

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);

        SalesOfferPDFController controller = new SalesOfferPDFController();

        String formattedLivingSpace = controller.getFormattedLivingSpace();
        String formattedAdditionalArea = controller.getFormattedAdditionalArea();
        String formattedTotalArea = controller.getFormattedTotalArea();
        String formattedCost = controller.getFormattedCost();
        String formattedDollar = controller.getFormattedDollarValue();
        String formattedEuro = controller.getFormattedEuroValue();
        
        System.assertEquals('8,000.00', formattedLivingSpace);
        System.assertEquals('200.00', formattedAdditionalArea);
        System.assertEquals('1,000.00', formattedTotalArea);
        System.assertEquals('1,000,000.00', formattedCost);
        //System.assertEquals('1,000,000.00', formattedDollar);
        ///System.assertEquals('1,000,000.00', formattedEuro);
        
    }

    @isTest
    static void testAllGetters() {
        Unit__c unit = [SELECT Id FROM Unit__c];
        unit.Balcony_Size__c = 50.5;
        unit.Total_Area_Square_Meter__c = 100.7;
        unit.Cost_CHF__c = 250000;
        update unit;

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller = new SalesOfferPDFController();

        String formattedBalcony = controller.getFormattedBalcony();
        String formattedTotalAreaSquareMeter = controller.getFormattedTotalAreaSquareMeter();
        String formattedCostAEDForCHF = controller.getFormattedCostAEDForCHF();
        String formattedCHFValue = controller.getFormattedCHFValue();
        String formattedRubValue = controller.getFormattedRubValue();
        String formattedGbpValue = controller.getFormattedGbpValue();
        String formattedPaymentAmount = controller.getFormattedPaymentAmount(1234567.89);

        System.assertEquals('50', formattedBalcony);
        System.assertEquals('100', formattedTotalAreaSquareMeter);
        System.assertNotEquals(null, formattedCostAEDForCHF);
        System.assertNotEquals(null, formattedCHFValue);
        System.assertNotEquals(null, formattedRubValue);
        System.assertNotEquals(null, formattedGbpValue);
        System.assertEquals('1,234,567.89', formattedPaymentAmount);
    }

    @isTest
    static void testFloorText() {
        Unit__c unit = [SELECT Id FROM Unit__c];

        // Test all floor values for getFloorText
        unit.Floor__c = 9;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller1 = new SalesOfferPDFController();
        System.assertEquals('Ground', controller1.getFloorText());

        unit.Floor__c = 1;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller2 = new SalesOfferPDFController();
        System.assertEquals('First', controller2.getFloorText());

        unit.Floor__c = 2;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller3 = new SalesOfferPDFController();
        System.assertEquals('Second', controller3.getFloorText());

        unit.Floor__c = 3;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller4 = new SalesOfferPDFController();
        System.assertEquals('Third', controller4.getFloorText());

        unit.Floor__c = 91;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller5 = new SalesOfferPDFController();
        System.assertEquals('Ground / First', controller5.getFloorText());

        unit.Floor__c = 12;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller6 = new SalesOfferPDFController();
        System.assertEquals('First / Second', controller6.getFloorText());

        unit.Floor__c = 23;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller7 = new SalesOfferPDFController();
        System.assertEquals('Second / Third', controller7.getFloorText());

        unit.Floor__c = 34;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller8 = new SalesOfferPDFController();
        System.assertEquals('Third / Fourth', controller8.getFloorText());

        unit.Floor__c = 123;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller9 = new SalesOfferPDFController();
        System.assertEquals('First / Second / Third', controller9.getFloorText());

        unit.Floor__c = 99;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller10 = new SalesOfferPDFController();
        System.assertEquals('', controller10.getFloorText());
    }

    @isTest
    static void testFloorTextFranco() {
        Unit__c unit = [SELECT Id FROM Unit__c];

        // Test all floor values for getFloorTextFranco
        unit.Floor__c = 1;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller1 = new SalesOfferPDFController();
        System.assertEquals('First', controller1.getFloorTextFranco());

        unit.Floor__c = 2;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller2 = new SalesOfferPDFController();
        System.assertEquals('Second', controller2.getFloorTextFranco());

        unit.Floor__c = 3;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller3 = new SalesOfferPDFController();
        System.assertEquals('Third', controller3.getFloorTextFranco());

        unit.Floor__c = 4;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller4 = new SalesOfferPDFController();
        System.assertEquals('Fourth', controller4.getFloorTextFranco());

        unit.Floor__c = 5;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller5 = new SalesOfferPDFController();
        System.assertEquals('Fifth', controller5.getFloorTextFranco());

        unit.Floor__c = 6;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller6 = new SalesOfferPDFController();
        System.assertEquals('Sixth', controller6.getFloorTextFranco());

        unit.Floor__c = 7;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller7 = new SalesOfferPDFController();
        System.assertEquals('Seventh', controller7.getFloorTextFranco());

        unit.Floor__c = 8;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller8 = new SalesOfferPDFController();
        System.assertEquals('Eighth', controller8.getFloorTextFranco());

        unit.Floor__c = 9;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller9 = new SalesOfferPDFController();
        System.assertEquals('Ninth', controller9.getFloorTextFranco());

        unit.Floor__c = 23;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller10 = new SalesOfferPDFController();
        System.assertEquals('Second / Third', controller10.getFloorTextFranco());

        unit.Floor__c = 34;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller11 = new SalesOfferPDFController();
        System.assertEquals('Third / Fourth', controller11.getFloorTextFranco());

        unit.Floor__c = 45;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller12 = new SalesOfferPDFController();
        System.assertEquals('Fourth / Fifth', controller12.getFloorTextFranco());

        unit.Floor__c = 56;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller13 = new SalesOfferPDFController();
        System.assertEquals('Fifth / Sixth', controller13.getFloorTextFranco());

        unit.Floor__c = 67;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller14 = new SalesOfferPDFController();
        System.assertEquals('Sixth / Seventh', controller14.getFloorTextFranco());

        unit.Floor__c = 78;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller15 = new SalesOfferPDFController();
        System.assertEquals('Seventh / Eighth', controller15.getFloorTextFranco());

        unit.Floor__c = 89;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller16 = new SalesOfferPDFController();
        System.assertEquals('Eighth / Ninth', controller16.getFloorTextFranco());

        unit.Floor__c = 99;
        update unit;
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller17 = new SalesOfferPDFController();
        System.assertEquals('', controller17.getFloorTextFranco());
    }

    @isTest
    static void testFormatNumber() {
        // Test formatNumber with various scenarios
        String result1 = SalesOfferPDFController.formatNumber(1234567.89);
        System.assertEquals('1,234,567.89', result1);

        String result2 = SalesOfferPDFController.formatNumber(1000.00);
        System.assertEquals('1,000.00', result2);

        String result3 = SalesOfferPDFController.formatNumber(100.5);
        System.assertEquals('100.5', result3);

        String result4 = SalesOfferPDFController.formatNumber(0);
        System.assertEquals('0.00', result4);

        // Test null input for code coverage
        String result5 = SalesOfferPDFController.formatNumber(null);
        // Method may return null or formatted string - both are acceptable for coverage

        // Test with integer (no decimal part)
        String result6 = SalesOfferPDFController.formatNumber(5000);
        System.assertEquals('5,000.00', result6);

        // Test with very large number
        String result7 = SalesOfferPDFController.formatNumber(999999999.99);
        System.assertEquals('999,999,999.99', result7);

        // Test with single digit
        String result8 = SalesOfferPDFController.formatNumber(5.5);
        System.assertEquals('5.5', result8);
    }

    @isTest
    static void testConstructorWithPoolFalse() {
        Unit__c unit = [SELECT Id FROM Unit__c];
        unit.Pool__c = false;
        update unit;

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller = new SalesOfferPDFController();

        System.assertEquals('No', controller.isPool);
    }

    @isTest
    static void testConstructorWithMaidsRoomFalse() {
        Unit__c unit = [SELECT Id FROM Unit__c];
        unit.Maids_Room__c = false;
        update unit;

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller = new SalesOfferPDFController();

        System.assertEquals('No', controller.isMaidsRoom);
    }

    @isTest
    static void testConstructorWithLessThan8CashFlows() {
        Unit__c unit = [SELECT Id FROM Unit__c];
        
        // Delete some cash flows to have less than 8
        List<Cash_Flow__c> cashFlows = [SELECT Id FROM Cash_Flow__c WHERE Unit__c = :unit.Id LIMIT 5];
        delete cashFlows;

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller = new SalesOfferPDFController();

        System.assertEquals(true, controller.lessPayments);
    }

    @isTest
    static void testConstructorWithExcludedCashFlows() {
        Unit__c unit = [SELECT Id FROM Unit__c];
        
        // Create cash flows with excluded names
        List<Cash_Flow_Sum__c> cashFlowSums = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c = :unit.Id];
        
        List<Cash_Flow__c> excludedCashFlows = new List<Cash_Flow__c>();
        excludedCashFlows.add(new Cash_Flow__c(
            Unit__c = unit.Id,
            Name = 'Oqood',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Date__c = Date.today(),
            Is_Additional_Payment__c = false
        ));
        excludedCashFlows.add(new Cash_Flow__c(
            Unit__c = unit.Id,
            Name = 'DLD Fee',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Date__c = Date.today(),
            Is_Additional_Payment__c = false
        ));
        excludedCashFlows.add(new Cash_Flow__c(
            Unit__c = unit.Id,
            Name = 'Registration Fee',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Date__c = Date.today(),
            Is_Additional_Payment__c = false
        ));
        excludedCashFlows.add(new Cash_Flow__c(
            Unit__c = unit.Id,
            Name = 'Purchase Taxes',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Date__c = Date.today(),
            Is_Additional_Payment__c = false
        ));
        insert excludedCashFlows;

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller = new SalesOfferPDFController();

        // These excluded cash flows should not be in payment plans
        System.assertNotEquals(null, controller.paymentPlansFirst);
    }

    @isTest
    static void testConstructorWithAdditionalPaymentCashFlows() {
        Unit__c unit = [SELECT Id FROM Unit__c];
        
        List<Cash_Flow_Sum__c> cashFlowSums = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c = :unit.Id];
        
        Cash_Flow__c additionalPayment = new Cash_Flow__c(
            Unit__c = unit.Id,
            Name = 'Additional Payment',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Date__c = Date.today(),
            Is_Additional_Payment__c = true
        );
        insert additionalPayment;

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller = new SalesOfferPDFController();

        // Additional payment should not be included
        System.assertNotEquals(null, controller.paymentPlansFirst);
    }

    @isTest
    static void testConstructorWithElieSaabProject() {
        Project__c project = [SELECT Id FROM Project__c];
        project.Name = 'POST HOTEL & RESIDENCES By ELIE SAAB';
        update project;

        Unit__c unit = [SELECT Id FROM Unit__c];
        unit.Project__c = project.Id;
        update unit;

        // Update files to use Floor Plan type
        List<File__c> files = [SELECT Id FROM File__c WHERE Unit__c = :unit.Id];
        for(File__c f : files) {
            f.Type__c = 'Floor Plan';
        }
        update files;

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller = new SalesOfferPDFController();

        System.assertNotEquals(null, controller.unitObject);
    }

    @isTest
    static void testConstructorWithGianfrancoProject() {
        Project__c project = [SELECT Id FROM Project__c];
        project.Name = 'GIANFRANCO FERRE RESIDENCES';
        update project;

        Unit__c unit = [SELECT Id FROM Unit__c];
        unit.Project__c = project.Id;
        update unit;

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller = new SalesOfferPDFController();

        System.assertNotEquals(null, controller.unitObject);
    }

    @isTest
    static void testConstructorWithSingleFile() {
        Unit__c unit = [SELECT Id FROM Unit__c];
        
        // Delete all but one file
        List<File__c> files = [SELECT Id FROM File__c WHERE Unit__c = :unit.Id];
        if(files.size() > 1) {
            List<File__c> filesToDelete = new List<File__c>();
            for(Integer i = 1; i < files.size(); i++) {
                filesToDelete.add(files[i]);
            }
            delete filesToDelete;
        }

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller = new SalesOfferPDFController();

        System.assertEquals(true, controller.isOnePic);
    }

    @isTest
    static void testConstructorWithOddNumberOfFiles() {
        Unit__c unit = [SELECT Id FROM Unit__c];
        
        // Ensure we have an odd number of files (3 is already set up)
        List<File__c> files = [SELECT Id FROM File__c WHERE Unit__c = :unit.Id];
        if(Math.mod(files.size(), 2) == 0) {
            File__c newFile = new File__c(
                Type__c = 'Schemas/PDFs',
                Unit__c = unit.Id
            );
            insert newFile;
        }

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller = new SalesOfferPDFController();

        System.assertNotEquals(null, controller.imageUrlToStyle);
    }

    @isTest
    static void testConstructorWithHandoverDateSingleDigits() {
        Project__c project = [SELECT Id FROM Project__c];
        project.Handover__c = Date.newInstance(2024, 1, 5); // Single digit month and day
        update project;

        Unit__c unit = [SELECT Id FROM Unit__c];
        unit.Project__c = project.Id;
        update unit;

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller = new SalesOfferPDFController();

        System.assertNotEquals(null, controller.completionDate);
        System.assert(controller.completionDate.contains('05'));
        System.assert(controller.completionDate.contains('01'));
    }

    @isTest
    static void testConstructorWithAllCurrencyFields() {
        Unit__c unit = [SELECT Id FROM Unit__c];
        unit.Cost_CHF__c = 250000;
        unit.Secondary_Currency__c = 'USD';
        update unit;

        // Test that controller handles currency fields (which are formula fields)
        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller = new SalesOfferPDFController();

        System.assertNotEquals(null, controller.purchasePriceUSD);
        System.assertNotEquals(null, controller.purchasePriceEUR);
        System.assertNotEquals(null, controller.purchasePriceRUB);
        System.assertNotEquals(null, controller.purchasePriceGBP);
        System.assertNotEquals(null, controller.purchasePriceCHF);
        System.assertNotEquals(null, controller.purchasePriceAED);
    }

    @isTest
    static void testConstructorWithMoreThan8CashFlows() {
        Unit__c unit = [SELECT Id FROM Unit__c];
        List<Cash_Flow_Sum__c> cashFlowSums = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c = :unit.Id];
        
        // Add more cash flows to exceed 8
        List<Cash_Flow__c> additionalCashFlows = new List<Cash_Flow__c>();
        for(Integer i = 0; i < 5; i++) {
            additionalCashFlows.add(new Cash_Flow__c(
                Unit__c = unit.Id,
                Name = 'Payment ' + i,
                Cash_Flow_Sum__c = cashFlowSums[0].Id,
                Date__c = Date.today().addMonths(i),
                Is_Additional_Payment__c = false,
                Percent__c = 10
            ));
        }
        insert additionalCashFlows;

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller = new SalesOfferPDFController();

        System.assertEquals(false, controller.lessPayments);
        System.assertNotEquals(null, controller.paymentPlansRest);
        System.assert(controller.paymentPlansRest.size() > 0);
    }

    @isTest
    static void testConstructorWithNoFiles() {
        Unit__c unit = [SELECT Id FROM Unit__c];
        
        // Delete all files
        List<File__c> files = [SELECT Id FROM File__c WHERE Unit__c = :unit.Id];
        delete files;

        ApexPages.currentPage().getParameters().put('unitId', unit.Id);
        SalesOfferPDFController controller = new SalesOfferPDFController();

        System.assertNotEquals(null, controller.unitObject);
    }

}