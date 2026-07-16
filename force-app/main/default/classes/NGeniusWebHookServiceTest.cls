@IsTest
private class NGeniusWebHookServiceTest {

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
            Maids_Room__c = true,
            Status__c = 'Draft'
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

        units[0].Status__c = 'Published';
        update units;
        System.debug('before soql');
        System.debug(units[0].Status__c);
        units = [SELECT Id, Status__c FROM Unit__c WHERE Id = :units[0].Id];

        System.debug('after soql');
        System.debug(units[0].Status__c);

        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Agency').getRecordTypeId();
        Account acc = new Account(
            Name = 'Test Account' + '1',
            BillingStreet = 'Somestrasse 25',
            BillingCity = 'Edinburgh',
            BillingPostalCode = '123442',
            BillingCountry = 'Germany',
            RecordTypeId = recordTypeId
        );
        insert acc;

        Contact c = new Contact(LastName = 'Test', Email = 'test@test.com', AccountId = acc.Id);
        insert c;
        User u;
        User adminU = new User(Id = UserInfo.getUserId());
        System.runAs(adminU) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Agency User'];
            
            u = new User(
                Alias = 'standt',
                Email = 'standarduser@testorg.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'testetete123141@testorg.com',
                contactId = c.Id
            );

            
            insert u;
        }

        System.runAs(u){
            System.debug(units[0].Status__c);
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

            List<Booking__c> bookings = new List<Booking__c>();
            bookings.add(new Booking__c(
                UnitId__c = units[0].Id,
                Payment_Date__c = Date.today(),
                client__c = clients[0].Id,
                Manager__c = adminU.Id
            ));
            insert bookings;
        }
    }
    @IsTest
    static void testDoPostCapturedEvent() {
        // Create a test Booking record

        Booking__c testBooking = [SELECT Id, Status__c FROM Booking__c LIMIT 1];
        testBooking.Invoice_Reference_Number__c = 'd0e6453d-0968-4a09-859f-aa8912abc0d5';
        update testBooking;
        // Setup the request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/nGeniusWebHookService/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"eventId":"testEventId","eventName":"CAPTURED","order":{"_id":"urn:order:12345","_links":{},"type":"SINGLE","merchantDefinedData":{},"action":"SALE","amount":{"currencyCode":"AED","value":3700000},"language":"en","merchantAttributes":{"paymentAttempts":"3"},"emailAddress":"test@example.com","reference":"12345","outletId":"testOutlet","createDateTime":"2024-06-03T07:09:01.167Z","paymentMethods":{"card":["VISA"]},"referrer":"urn:invoice:d0e6453d-0968-4a09-859f-aa8912abc0d5","formattedAmount":"37,000","_embedded":{}}}');

        Test.setCurrentPageReference(new PageReference('/services/apexrest/nGeniusWebHookService/'));
        RestContext.request = req;
        RestContext.response = res;

        // Call the service
        NGeniusWebHookService.doPost();

        // Verify the status and booking status update
        testBooking = [SELECT Id, Status__c FROM Booking__c LIMIT 1];
        System.assertEquals('EOI Paid', testBooking.Status__c);
    }

    @IsTest
    static void testDoPostDeclinedEvent() {
        // Create a test Booking record
        Booking__c testBooking = [SELECT Id, Status__c, Invoice_Payment_Attempts__c FROM Booking__c LIMIT 1];
        testBooking.Invoice_Reference_Number__c = 'd0e6453d-0968-4a09-859f-aa8912abc0d5';
        update testBooking;
        System.debug(testBooking);
        // Setup the request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/nGeniusWebHookService/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"eventId":"testEventId","eventName":"DECLINED","order":{"_id":"urn:order:12345","_links":{},"type":"SINGLE","merchantDefinedData":{},"action":"SALE","amount":{"currencyCode":"AED","value":3700000},"language":"en","merchantAttributes":{"paymentAttempts":"3"},"emailAddress":"test@example.com","reference":"12345","outletId":"testOutlet","createDateTime":"2024-06-03T07:09:01.167Z","paymentMethods":{"card":["VISA"]},"referrer":"urn:invoice:d0e6453d-0968-4a09-859f-aa8912abc0d5","formattedAmount":"37,000","_embedded":{}}}');

        Test.setCurrentPageReference(new PageReference('/services/apexrest/nGeniusWebHookService/'));
        RestContext.request = req;
        RestContext.response = res;

        // Call the service
        NGeniusWebHookService.doPost();

        // Verify the status and booking payment attempts update
        testBooking = [SELECT Id, Invoice_Payment_Attempts__c FROM Booking__c WHERE Id = :testBooking.Id];
        System.assertEquals(1, testBooking.Invoice_Payment_Attempts__c);
    }

    @IsTest
    static void testDoPostThreeDSNotAuthenticatedEvent() {
        // Create a test Booking record
        
        Booking__c testBooking = [SELECT Id, Status__c FROM Booking__c LIMIT 1];
        testBooking.Invoice_Reference_Number__c = 'd0e6453d-0968-4a09-859f-aa8912abc0d5';
        update testBooking;


        // Setup the request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/nGeniusWebHookService/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"eventId":"testEventId","eventName":"THREE_DS_NOT_AUTHENTICATED","order":{"_id":"urn:order:12345","_links":{},"type":"SINGLE","merchantDefinedData":{},"action":"SALE","amount":{"currencyCode":"AED","value":3700000},"language":"en","merchantAttributes":{"paymentAttempts":"3"},"emailAddress":"test@example.com","reference":"12345","outletId":"testOutlet","createDateTime":"2024-06-03T07:09:01.167Z","paymentMethods":{"card":["VISA"]},"referrer":"urn:invoice:d0e6453d-0968-4a09-859f-aa8912abc0d5","formattedAmount":"37,000","_embedded":{}}}');

        Test.setCurrentPageReference(new PageReference('/services/apexrest/nGeniusWebHookService/'));
        RestContext.request = req;
        RestContext.response = res;

        // Call the service
        NGeniusWebHookService.doPost();

        // Verify the status and booking payment attempts update
        testBooking = [SELECT Id, Invoice_Payment_Attempts__c FROM Booking__c WHERE Id = :testBooking.Id];
        System.assertEquals(1, testBooking.Invoice_Payment_Attempts__c);
    }

    @IsTest
    static void testDoPostGatewayRiskPreAuthRejectedEvent() {
        // Create a test Booking record
        
        Booking__c testBooking = [SELECT Id, Status__c FROM Booking__c LIMIT 1];
        testBooking.Invoice_Reference_Number__c = 'd0e6453d-0968-4a09-859f-aa8912abc0d5';
        update testBooking;


        // Setup the request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/nGeniusWebHookService/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"eventId":"testEventId","eventName":"GATEWAY_RISK_PRE_AUTH_REJECTED","order":{"_id":"urn:order:12345","_links":{},"type":"SINGLE","merchantDefinedData":{},"action":"SALE","amount":{"currencyCode":"AED","value":3700000},"language":"en","merchantAttributes":{"paymentAttempts":"3"},"emailAddress":"test@example.com","reference":"12345","outletId":"testOutlet","createDateTime":"2024-06-03T07:09:01.167Z","paymentMethods":{"card":["VISA"]},"referrer":"urn:invoice:d0e6453d-0968-4a09-859f-aa8912abc0d5","formattedAmount":"37,000","_embedded":{}}}');

        Test.setCurrentPageReference(new PageReference('/services/apexrest/nGeniusWebHookService/'));
        RestContext.request = req;
        RestContext.response = res;

        // Call the service
        NGeniusWebHookService.doPost();

        // Verify the status and booking payment attempts update
        testBooking = [SELECT Id, Invoice_Payment_Attempts__c FROM Booking__c WHERE Id = :testBooking.Id];
        System.assertEquals(3, testBooking.Invoice_Payment_Attempts__c);
    }

    @IsTest
    static void testExtractReferenceNumber() {
        String referrer = 'urn:invoice:d0e6453d-0968-4a09-859f-aa8912abc0d5';
        String expectedReference = 'd0e6453d-0968-4a09-859f-aa8912abc0d5';
        String actualReference = NGeniusWebHookService.extractReferenceNumber(referrer);
        System.assertEquals(expectedReference, actualReference);

        referrer = 'invalid_referrer';
        expectedReference = null;
        actualReference = NGeniusWebHookService.extractReferenceNumber(referrer);
        System.assertEquals(expectedReference, actualReference);
    }
}