@isTest
private class BookingFormEliePDFControllerTest {

    @TestSetup
    static void makeData(){
        List<Account> acct = new List<Account>();
        acct.add(new Account (
            FirstName = 'Test',
            LastName = 'Client',
            RecordTypeId = '012Hp000001yUTFIA2',
            Payment_methods__pc = 'Cash',
            PersonBirthdate = Date.today().addYears(-30),
            Place_of_Birth__pc = 'Dubai',
            Occupation__pc = 'Engineer',
            PersonEmail = 'test@test.com',
            PersonMobilePhone = '1234567890',
            Politically_Exposed__pc = 'No',
            Subject_to_Sanction__pc = 'No',
            Bank_Name__pc = 'Test Bank',
            BillingStreet = 'Test Street',
            BillingCity = 'Test City',
            BillingPostalCode = '12345',
            BillingCountry = 'UAE',
            Trade_License_Number__c = 'TL123456'
        ));
        acct.add(new Account (
            FirstName = 'Test',
            LastName = 'Joint',
            RecordTypeId = '012Hp000001yUTFIA2',
            Payment_methods__pc = 'Cash',
            PersonBirthdate = Date.today().addYears(-28),
            Place_of_Birth__pc = 'Abu Dhabi',
            PersonEmail = 'joint@test.com',
            PersonMobilePhone = '9876543210'
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
            Cost_CHF__c = 250000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Additional_Area__c = 200,
            Floor__c = 1,
            Number_of_Bedrooms__c = 2,
            Number_of_Bathrooms__c = 2,
            View__c = 'Test View',
            Building__c = 'Test Building',
            Panorama_Link__c = 'Test Link',
            Project__c = projects[0].Id,
            Maids_Room__c = true,
            Total_Area_Square_Meter__c = 1000
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
            Name = 'Booking / Reservation',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Constant__c = 25000,
            Date__c = Date.today()
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = units[0].Id,
            Name = 'Public Deed',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Constant__c = 25000,
            Date__c = Date.today().addMonths(1)
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = units[0].Id,
            Name = '1st Installment',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Constant__c = 25000,
            Date__c = Date.today().addMonths(2)
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = units[0].Id,
            Name = '2nd Installment',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Constant__c = 25000,
            Date__c = Date.today().addMonths(3)
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = units[0].Id,
            Name = '3rd Installment',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Constant__c = 25000,
            Date__c = Date.today().addMonths(4)
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = units[0].Id,
            Name = '4th Installment',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Constant__c = 25000,
            Date__c = Date.today().addMonths(5)
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = units[0].Id,
            Name = '5th Installment',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Constant__c = 25000,
            Date__c = Date.today().addMonths(6)
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = units[0].Id,
            Name = '100% of Construction',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Constant__c = 75000,
            Date__c = Date.today().addMonths(7)
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = units[0].Id,
            Name = 'Handover',
            Cash_Flow_Sum__c = cashFlowSums[0].Id,
            Constant__c = 0,
            Date__c = Date.today().addMonths(8)
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
        BookingFormEliePDFController bookingController = new BookingFormEliePDFController();
        System.assert(bookingController != null);
        
        // Test that objectValues map is populated
        Map<String, Object> objectValues = bookingController.objectValues;
        System.assertNotEquals(null, objectValues);
        
        // Test that oppData map is populated
        Map<String, Object> oppData = bookingController.oppData;
        System.assertNotEquals(null, oppData);
    }
    
    @isTest
    static void testConstructorInvalidId() {
        ApexPages.currentPage().getParameters().put('oppId', '006000000000000AAA');
        BookingFormEliePDFController bookingController = new BookingFormEliePDFController();
        
        // Should have an error message
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assertEquals(1, messages.size());
        System.assertEquals(ApexPages.Severity.ERROR, messages[0].getSeverity());
    }
    
    @isTest
    static void testConstructorNoId() {
        // Don't add any parameter
        BookingFormEliePDFController bookingController = new BookingFormEliePDFController();
        
        // Should have an error message
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assertEquals(1, messages.size());
        System.assertEquals(ApexPages.Severity.ERROR, messages[0].getSeverity());
    }
    
    @isTest
    static void testStaticHelperMethods() {
        // Test formatNumber method
        System.assertEquals('1,234.56', BookingFormEliePDFController.formatNumber(1234.56));
        System.assertEquals('1,000,000.00', BookingFormEliePDFController.formatNumber(1000000));
        
        // Test removeNull method
        System.assertEquals('', BookingFormEliePDFController.removeNull(null));
        System.assertEquals('test', BookingFormEliePDFController.removeNull('test'));
        
        // Test removeNullFromDate method
        System.assertEquals(Date.today(), BookingFormEliePDFController.removeNullFromDate(null));
        Date testDate = Date.newInstance(2023, 1, 1);
        System.assertEquals(testDate, BookingFormEliePDFController.removeNullFromDate(testDate));
        
        // Test addNotReceived method
        System.assertEquals('Not Received', BookingFormEliePDFController.addNotReceived(null));
        System.assertEquals('test', BookingFormEliePDFController.addNotReceived('test'));
        
        // Test formatDate method
        System.assertEquals('', BookingFormEliePDFController.formatDate(null));
        System.assertEquals('1 / 1 / 2023', BookingFormEliePDFController.formatDate(Date.newInstance(2023, 1, 1)));
        
        // Test getPicklistLabel method (this is a bit tricky to test as it depends on schema)
        System.assertEquals('', BookingFormEliePDFController.getPicklistLabel('Account', 'Nationality__c', null));
        // Testing with a non-existent value will return the value itself
        System.assertEquals('TEST_VALUE', BookingFormEliePDFController.getPicklistLabel('Account', 'Nationality__c', 'TEST_VALUE'));
        
        // Test modeOfPuchaseFirstColumn method
        System.assertEquals('Reservation Fee: 10%', BookingFormEliePDFController.modeOfPuchaseFirstColumn('Booking / Reservation Installment'));
        System.assertEquals('Public Deed: 10%', BookingFormEliePDFController.modeOfPuchaseFirstColumn('Public Deed'));
        System.assertEquals('First Payment: 10%', BookingFormEliePDFController.modeOfPuchaseFirstColumn('1st Installment'));
        System.assertEquals('Second Payment: 10%', BookingFormEliePDFController.modeOfPuchaseFirstColumn('2nd Installment'));
        System.assertEquals('Third Payment: 10%', BookingFormEliePDFController.modeOfPuchaseFirstColumn('3rd Installment'));
        System.assertEquals('Fourth Payment: 10%', BookingFormEliePDFController.modeOfPuchaseFirstColumn('4th Installment'));
        System.assertEquals('Fifth Payment: 10%', BookingFormEliePDFController.modeOfPuchaseFirstColumn('5th Installment'));
        System.assertEquals('Last Payment: 50%', BookingFormEliePDFController.modeOfPuchaseFirstColumn('100% of Construction'));
        System.assertEquals('', BookingFormEliePDFController.modeOfPuchaseFirstColumn('Unknown Value'));
        
        // Test modeOfPuchaseSecondColumn method
        System.assertEquals('upon signature of Reservation Form', BookingFormEliePDFController.modeOfPuchaseSecondColumn('Booking / Reservation Installment'));
        System.assertEquals('upon signature of the Public Deed', BookingFormEliePDFController.modeOfPuchaseSecondColumn('Public Deed'));
        System.assertEquals('within 9 months after the Public Deed', BookingFormEliePDFController.modeOfPuchaseSecondColumn('1st Installment'));
        System.assertEquals('within 6 months after the Last Payment', BookingFormEliePDFController.modeOfPuchaseSecondColumn('2nd Installment'));
        System.assertEquals('within 6 months after the Last Payment', BookingFormEliePDFController.modeOfPuchaseSecondColumn('3rd Installment'));
        System.assertEquals('within 6 months after the Last Payment', BookingFormEliePDFController.modeOfPuchaseSecondColumn('4th Installment'));
        System.assertEquals('within 6 months after the Last Payment', BookingFormEliePDFController.modeOfPuchaseSecondColumn('5th Installment'));
        System.assertEquals('Upon the Handover', BookingFormEliePDFController.modeOfPuchaseSecondColumn('100% of Construction'));
        System.assertEquals('', BookingFormEliePDFController.modeOfPuchaseSecondColumn('Unknown Value'));
        
        // Test floorText method
        System.assertEquals('Ground', BookingFormEliePDFController.floorText(9));
        System.assertEquals('First', BookingFormEliePDFController.floorText(1));
        System.assertEquals('Second', BookingFormEliePDFController.floorText(2));
        System.assertEquals('Third', BookingFormEliePDFController.floorText(3));
        System.assertEquals('Ground / First', BookingFormEliePDFController.floorText(91));
        System.assertEquals('First / Second', BookingFormEliePDFController.floorText(12));
        System.assertEquals('Second / Third', BookingFormEliePDFController.floorText(23));
        System.assertEquals('Third / Fourth', BookingFormEliePDFController.floorText(34));
        System.assertEquals('First / Second / Third', BookingFormEliePDFController.floorText(123));
        System.assertEquals('', BookingFormEliePDFController.floorText(999));
        
        // Test arabicConversionFundSource method
        System.assertEquals('', BookingFormEliePDFController.arabicConversionFundSource(null));
        System.assertEquals('الميراث', BookingFormEliePDFController.arabicConversionFundSource('Inheritance'));
        System.assertEquals('الدخل / الادخار', BookingFormEliePDFController.arabicConversionFundSource('Income/Savings'));
        System.assertEquals('الاستثمار', BookingFormEliePDFController.arabicConversionFundSource('Investment'));
        System.assertEquals('بيع الأصول', BookingFormEliePDFController.arabicConversionFundSource('Sale of Assets'));
        System.assertEquals('هدية', BookingFormEliePDFController.arabicConversionFundSource('Gift'));
        System.assertEquals('قرض', BookingFormEliePDFController.arabicConversionFundSource('Loan'));
        System.assertEquals('أموال الشركة', BookingFormEliePDFController.arabicConversionFundSource('Company Funds'));
        System.assertEquals('آخر', BookingFormEliePDFController.arabicConversionFundSource('Other'));
        System.assertEquals('', BookingFormEliePDFController.arabicConversionFundSource('Unknown Value'));
        
        // Test arabicConversionPaymentMethods method
        System.assertEquals('', BookingFormEliePDFController.arabicConversionPaymentMethods(null));
        System.assertEquals('تحويل مصرفي', BookingFormEliePDFController.arabicConversionPaymentMethods('Bank Transfer'));
        System.assertEquals('شيك', BookingFormEliePDFController.arabicConversionPaymentMethods('Cheque'));
        System.assertEquals('بطاقة الائتمان', BookingFormEliePDFController.arabicConversionPaymentMethods('Credit Card'));
        System.assertEquals('نقدا', BookingFormEliePDFController.arabicConversionPaymentMethods('Cash'));
        System.assertEquals('خصم مباشر', BookingFormEliePDFController.arabicConversionPaymentMethods('Direct Debit'));
        System.assertEquals('آخر', BookingFormEliePDFController.arabicConversionPaymentMethods('Other'));
        System.assertEquals('', BookingFormEliePDFController.arabicConversionPaymentMethods('Unknown Value'));
    }
    
    @isTest
    static void testGetterMethods() {
        Opportunity opp = [SELECT Id FROM Opportunity];
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        BookingFormEliePDFController bookingController = new BookingFormEliePDFController();
        
        // Test getBookingElieFormPDF method
        System.assertEquals(null, bookingController.getBookingElieFormPDF());
        
        // Test getTodayDate method
        System.assertEquals(null, bookingController.getTodayDate());
    }
    
    @isTest
    static void testPaymentPlanWrapper() {
        // Create and test PaymentPlanWrapper
        BookingFormEliePDFController.PaymentPlanWrapper wrapper = 
            new BookingFormEliePDFController.PaymentPlanWrapper('Milestone', 'Description', 'Date', 'Amount');
        
        System.assertEquals('Milestone', wrapper.milestone);
        System.assertEquals('Description', wrapper.description);
        System.assertEquals('Date', wrapper.paymentDate);
        System.assertEquals('Amount', wrapper.amount);
    }
    
    @isTest
    static void testObjectValuesPopulation() {
        Opportunity opp = [SELECT Id FROM Opportunity];
        ApexPages.currentPage().getParameters().put('oppId', opp.Id);
        BookingFormEliePDFController bookingController = new BookingFormEliePDFController();
        
        Map<String, Object> objectValues = bookingController.objectValues;
        
        // Check core values that should be populated
        System.assertNotEquals(null, objectValues.get('Opportunity'));
        System.assertNotEquals(null, objectValues.get('BookingDate'));
        
        // Check formattedNumbers map
        Map<String, String> formattedNumbers = (Map<String, String>)objectValues.get('formattedNumbers');
        System.assertNotEquals(null, formattedNumbers);
        System.assertNotEquals(null, formattedNumbers.get('formattedNumberOfBathrooms'));
        System.assertNotEquals(null, formattedNumbers.get('formattedTotalAreaSquareMeter'));
        System.assertNotEquals(null, formattedNumbers.get('formattedUnitCostCHF'));
        
        // Check payment plans
        List<Map<String, Object>> paymentPlans = (List<Map<String, Object>>)objectValues.get('paymentPlans');
        System.assertNotEquals(null, paymentPlans);
        System.assert(!paymentPlans.isEmpty());
        
        // Test floorText value
        System.assertEquals('First', objectValues.get('floorText'));
    }
}