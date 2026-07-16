@isTest
private class BookingFormPDFControllerTest {

    @TestSetup
    static void makeData(){
        List<Account> acct = new List<Account>();
        acct.add(new Account (
            FirstName = 'Test',
            LastName = 'Client',
            RecordTypeId = '012Hp000001yUTFIA2',
            Payment_methods__pc = 'Cash'
        ));
        acct.add(new Account (
            FirstName = 'Test',
            LastName = 'Joint',
            RecordTypeId = '012Hp000001yUTFIA2',
            Payment_methods__pc = 'Cash'
        ));
        insert acct;
        
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
            Type__c = 'Floor Plan',
            Unit__c = units[0].Id,
            Layout__c = 'Contemporary Floor Plan'
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

        Opportunity opp = new Opportunity(
            AccountId = acct[0].Id,
            Name = 'opp name',
            Unit__c = units[0].Id,
            StageName = 'New',
            Booking_Date_Time__c = Date.today(),
            CloseDate = Date.today()
        );
        insert opp;
        
        Joint_Owners__c jo = new Joint_Owners__c(
        	Account__c = acct[1].Id,
            Opportunity__c = opp.Id,
            Ownership_Share__c = 10,
            Order__c = 2
        );
        insert jo;
    }
    
    @isTest
    static void testConstructor() {
        Opportunity opp = [SELECT Id FROM Opportunity];
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        BookingFormPDFController bookingController = new BookingFormPDFController();
        
        System.assert(bookingController != null);
        System.assert(bookingController.oppData != null);
        System.assert(bookingController.hasJointOwners, 'Expected joint owners to be loaded');
        System.assert(bookingController.jointOwnerAccounts.size() > 0, 'Expected at least one joint owner account');
    }
    
    @isTest
    static void testConstructorWithNonPersonAccount() {
        // Create a non-person account
        Account nonPersonAccount = new Account(
            Name = 'Test Company',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Company').getRecordTypeId()
        );
        insert nonPersonAccount;
        
        // Create a contact for the non-person account
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = nonPersonAccount.Id,
            Primary__c = true,
            Source_of_Funds__c = 'Salary',
            Payment_methods__c = 'Cash'
        );
        insert testContact;
        
        // Create joint owner contact
        Contact jointContact = new Contact(
            FirstName = 'Joint',
            LastName = 'Owner',
            AccountId = nonPersonAccount.Id,
            Source_of_Funds__c = 'Investments',
            Payment_methods__c = 'Cheques'
        );
        insert jointContact;
        
        // Get existing unit and project
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Project__c project = [SELECT Id FROM Project__c LIMIT 1];
        
        // Create opportunity with non-person account
        Opportunity opp = new Opportunity(
            AccountId = nonPersonAccount.Id,
            Name = 'Test Opportunity',
            Unit__c = unit.Id,
            StageName = 'New',
            Booking_Date_Time__c = Date.today(),
            CloseDate = Date.today()
        );
        insert opp;
        
        // Create joint owner
        Joint_Owners__c jo = new Joint_Owners__c(
            Account__c = nonPersonAccount.Id,
            Opportunity__c = opp.Id,
            Ownership_Share__c = 50,
            Order__c = 1
        );
        insert jo;
        
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        BookingFormPDFController bookingController = new BookingFormPDFController();
        
        System.assert(bookingController != null);
        System.assert(bookingController.oppData != null);
        System.assert(bookingController.hasJointOwners, 'Expected joint owners for company account opportunity');
        System.assertEquals(1, bookingController.jointOwnerAccounts.size());
        System.assert(bookingController.hasSharedContacts, 'Expected shared contacts for company account opportunity');
        System.assertEquals(2, bookingController.sharedContactList.size());
        System.assertEquals(testContact.Id, bookingController.sharedContactList[0].Id, 'Primary contact should be listed first');
    }
    
    @isTest
    static void testFormatNumber() {
        // Test with null
        System.assertEquals('0.00', BookingFormPDFController.formatNumber(null));
        
        // Test with valid decimal
        System.assertEquals('1,000.50', BookingFormPDFController.formatNumber(1000.50));
        
        // Test with integer
        System.assertEquals('1,000.00', BookingFormPDFController.formatNumber(1000));
        
        // Test with zero
        System.assertEquals('0.00', BookingFormPDFController.formatNumber(0));
        
        // Test with large number
        System.assertEquals('1,000,000.99', BookingFormPDFController.formatNumber(1000000.99));
    }
    
    @isTest
    static void testRegistrationFeeSetup() {
        // Test with null
        String result = BookingFormPDFController.RegistrationFeeSetup(null);
        System.assert(result.contains('٥٠٪؜ تدفع من قبل المشترى'));
        
        // Test with 'Fully paid by the Purchaser'
        result = BookingFormPDFController.RegistrationFeeSetup('Fully paid by the Purchaser');
        System.assertEquals('مدفوعة بالكامل من قبل المشتري', result);
        
        // Test with 'Fully paid by the Seller'
        result = BookingFormPDFController.RegistrationFeeSetup('Fully paid by the Seller');
        System.assertEquals('مدفوعة بالكامل من قبل البائع', result);
        
        // Test with '25% payable by Purchaser, 75% payable by Seller, Purchaser pays all administration fees'
        result = BookingFormPDFController.RegistrationFeeSetup('25% payable by Purchaser, 75% payable by Seller, Purchaser pays all administration fees');
        System.assertEquals('٢٥٪؜ تدفع من قبل المشترى ، و ٧٥٪؜  تدفع من قبل البائع ، يدفع المشترى جميع الرسوم الادارية', result);
        
        // Test with '75% payable by Purchaser, 25% payable by Seller, Purchaser pays all administration fees'
        result = BookingFormPDFController.RegistrationFeeSetup('75% payable by Purchaser, 25% payable by Seller, Purchaser pays all administration fees');
        System.assertEquals('٧٥٪؜ تدفع من قبل المشترى ، و ٢٥٪؜  تدفع من قبل البائع ، يدفع المشترى جميع الرسوم الادارية', result);
        
        // Test with unknown value
        result = BookingFormPDFController.RegistrationFeeSetup('Unknown Value');
        System.assertEquals('٥٠٪؜ تدفع من قبل المشترى ، و ٥٠٪؜  تدفع من قبل البائع ، يدفع المشترى جميع الرسوم الادارية', result);
    }
    
    @isTest
    static void testRemoveNull() {
        // Test with null
        System.assertEquals('', BookingFormPDFController.removeNull(null));
        
        // Test with valid string
        System.assertEquals('Test String', BookingFormPDFController.removeNull('Test String'));
        
        // Test with empty string
        System.assertEquals('', BookingFormPDFController.removeNull(''));
    }
    
    @isTest
    static void testRemoveNullFromDate() {
        // Test with null
        Date result = BookingFormPDFController.removeNullFromDate(null);
        System.assertEquals(Date.today(), result);
        
        // Test with valid date
        Date testDate = Date.newInstance(2023, 1, 1);
        result = BookingFormPDFController.removeNullFromDate(testDate);
        System.assertEquals(testDate, result);
    }
    
    @isTest
    static void testAddNotReceived() {
        // Test with null
        System.assertEquals('Not Received', BookingFormPDFController.addNotReceived(null));
        
        // Test with valid string
        System.assertEquals('Valid String', BookingFormPDFController.addNotReceived('Valid String'));
        
        // Test with empty string
        System.assertEquals('', BookingFormPDFController.addNotReceived(''));
    }
    
    @isTest
    static void testArabicConversionFundSource() {
        // Test with null
        System.assertEquals('آخر__________', BookingFormPDFController.arabicConversionFundSource(null));
        
        // Test with 'Salary'
        System.assertEquals('راتب', BookingFormPDFController.arabicConversionFundSource('Salary'));
        
        // Test with 'Investments'
        System.assertEquals('استثمارات', BookingFormPDFController.arabicConversionFundSource('Investments'));
        
        // Test with 'Business Income'
        System.assertEquals('دخل من الأعمال', BookingFormPDFController.arabicConversionFundSource('Business Income'));
        
        // Test with 'Loans'
        System.assertEquals('قروض', BookingFormPDFController.arabicConversionFundSource('Loans'));
        
        // Test with unknown value
        System.assertEquals('آخر__________', BookingFormPDFController.arabicConversionFundSource('Unknown'));
    }
    
    @isTest
    static void testArabicConversionPaymentMethods() {
        // Test with null
        System.assertEquals('آخر__________', BookingFormPDFController.arabicConversionPaymentMethods(null));
        
        // Test with empty string
        System.assertEquals('آخر__________', BookingFormPDFController.arabicConversionPaymentMethods(''));
        
        // Test with 'Cash'
        System.assertEquals('نقدأ', BookingFormPDFController.arabicConversionPaymentMethods('Cash'));
        
        // Test with 'Cheques'
        System.assertEquals('شيكات', BookingFormPDFController.arabicConversionPaymentMethods('Cheques'));
        
        // Test with 'Bank Transfer'
        System.assertEquals('تحويل بنكى', BookingFormPDFController.arabicConversionPaymentMethods('Bank Transfer'));
        
        // Test with multiple values
        System.assertEquals('نقدأ, شيكات', BookingFormPDFController.arabicConversionPaymentMethods('Cash;Cheques'));
        
        // Test with unknown value
        System.assertEquals('آخر__________', BookingFormPDFController.arabicConversionPaymentMethods('Unknown'));
    }
    
    @isTest
    static void testGetBookingFormPDF() {
        // Set up a valid opportunity ID to avoid constructor exception
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        
        BookingFormPDFController controller = new BookingFormPDFController();
        System.assertEquals(null, controller.getBookingFormPDF());
    }
    
    @isTest
    static void testGetTodayDate() {
        // Set up a valid opportunity ID to avoid constructor exception
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        
        BookingFormPDFController controller = new BookingFormPDFController();
        System.assertEquals(null, controller.getTodayDate());
    }
    
    @isTest
    static void testConstructorWithException() {
        // Test with invalid opportunity ID
        ApexPages.currentPage().getParameters().put('oppId', 'invalid_id');
        
        try {
            BookingFormPDFController bookingController = new BookingFormPDFController();
            System.assert(false, 'Expected exception was not thrown');
        } catch (Exception e) {
            // Handle various exception types that might be thrown
            System.assert(e.getMessage().contains('Invalid id') || 
                         e.getMessage().contains('Opportunity not found') ||
                         e.getMessage().contains('Script-thrown exception'), 
                         'Actual message: ' + e.getMessage());
        }
    }
    
    @isTest
    static void testConstructorWithNoOppId() {
        // Test with no opportunity ID parameter
        ApexPages.currentPage().getParameters().clear();
        
        try {
            BookingFormPDFController bookingController = new BookingFormPDFController();
            System.assert(false, 'Expected exception was not thrown');
        } catch (Exception e) {
            // Handle various exception types that might be thrown
            System.assert(e.getMessage().contains('Invalid id') || 
                         e.getMessage().contains('Opportunity not found') ||
                         e.getMessage().contains('Script-thrown exception'), 
                         'Actual message: ' + e.getMessage());
        }
    }
    
    @isTest
    static void testConstructorWithSpecialProjectNames() {
        // Test with Trussardi Residences project
        Project__c trussardiProject = new Project__c(
            Name = 'Trussardi Residences',
            Description__c = 'Test Project',
            District__c = 'Meydan',
            Coordinates_Latitude__c = 2,
            Coordinates_Longitude__c = 1,
            Handover__c = Date.today(),
            Minimum_Cost__c = 20
        );
        insert trussardiProject;
        
        Unit__c trussardiUnit = new Unit__c(
            Title__c = 'Trussardi Unit',
            Cost_AED__c = 1000000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Project__c = trussardiProject.Id
        );
        insert trussardiUnit;
        
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        opp.Unit__c = trussardiUnit.Id;
        opp.Offer_layout__c = 'Contemporary';
        update opp;
        
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        BookingFormPDFController bookingController = new BookingFormPDFController();

        System.assert(bookingController != null);
    }
    
    @isTest
    static void testConstructorWithGianfrancoProject() {
        // Test with GIANFRANCO FERRE RESIDENCES project
        Project__c gianfrancoProject = new Project__c(
            Name = 'GIANFRANCO FERRE RESIDENCES',
            Description__c = 'Test Project',
            District__c = 'Meydan',
            Coordinates_Latitude__c = 2,
            Coordinates_Longitude__c = 1,
            Handover__c = Date.today(),
            Minimum_Cost__c = 20
        );
        insert gianfrancoProject;
        
        Unit__c gianfrancoUnit = new Unit__c(
            Title__c = 'Gianfranco Unit',
            Cost_AED__c = 1000000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Project__c = gianfrancoProject.Id
        );
        insert gianfrancoUnit;
        
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        opp.Unit__c = gianfrancoUnit.Id;
        opp.Offer_layout__c = 'Formal';
        update opp;
        
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        BookingFormPDFController bookingController = new BookingFormPDFController();

        System.assert(bookingController != null);
    }
    
    @isTest
    static void testConstructorWithDifferentOfferLayouts() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Test with Traditional layout
        opp.Offer_layout__c = 'Traditional';
        update opp;
        
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        BookingFormPDFController bookingController1 = new BookingFormPDFController();
        System.assert(bookingController1 != null);
        
        // Test with Formal layout
        opp.Offer_layout__c = 'Formal';
        update opp;
        
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        BookingFormPDFController bookingController2 = new BookingFormPDFController();
        System.assert(bookingController2 != null);
        
        // Test with null layout
        opp.Offer_layout__c = null;
        update opp;
        
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        BookingFormPDFController bookingController3 = new BookingFormPDFController();
        System.assert(bookingController3 != null);
    }
    
    @isTest
    static void testConstructorWithNoBookingDate() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        opp.Booking_Date_Time__c = null;
        update opp;
        
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        BookingFormPDFController bookingController = new BookingFormPDFController();

        System.assert(bookingController != null);
    }
    
    @isTest
    static void testConstructorWithNoJointOwners() {
        // Delete existing joint owners
        delete [SELECT Id FROM Joint_Owners__c];
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        BookingFormPDFController bookingController = new BookingFormPDFController();

        System.assert(bookingController != null);
    }
    
    @isTest
    static void testConstructorWithNoFloorPlanFiles() {
        // Delete existing files
        delete [SELECT Id FROM File__c];
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        BookingFormPDFController bookingController = new BookingFormPDFController();

        System.assert(bookingController != null);
    }
    
    @isTest
    static void testConstructorWithNoCashFlows() {
        // Delete existing cash flows
        delete [SELECT Id FROM Cash_Flow__c];
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        BookingFormPDFController bookingController = new BookingFormPDFController();
        
        System.assert(bookingController != null);
    }
}