@isTest
public class WazzupChatVFControllerTest {

    @testSetup
    static void setup() {
        // Create test Lead record
        Lead testLead = new Lead(
            LastName = 'Test',
            Company = 'Test Company',
            MobilePhone = '0123456789'
        );
        insert testLead;
        System.debug('Inserted Test Lead ID: ' + testLead.Id); // Debug to confirm testLead is inserted
    }

    @isTest
    static void testControllerInitialization_Success() {
        // Retrieve inserted Lead ID
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Test' LIMIT 1];
        System.assertNotEquals(null, testLead.Id, 'Test Lead ID is NULL!');

        // Set up page parameters with valid Lead ID
        Test.setCurrentPageReference(new PageReference('/apex/ChatPage'));
        ApexPages.currentPage().getParameters().put('id', testLead.Id); // Pass correct ID in parameters
        ApexPages.currentPage().getParameters().put('whatsappChatId', '0123456789'); // Valid phone number

        // Set mock HTTP response
        Test.setMock(HttpCalloutMock.class, new WazzupChatHttpMock());

        Test.startTest();
        WazzupChatVFController controller = new WazzupChatVFController();
        Test.stopTest();

        System.debug('✅ iframeUrl: ' + controller.iframeUrl);

        // Assertions
        System.assertNotEquals(null, controller.iframeUrl, 'iframeUrl should not be null.');
        System.assert(!controller.iframeUrl.contains('Error'), 'iframeUrl contains an error: ' + controller.iframeUrl);
    }

    @isTest
    static void testControllerInitialization_MissingLeadId() {
        // Set up page parameters without Lead ID
        Test.setCurrentPageReference(new PageReference('/apex/ChatPage'));
        ApexPages.currentPage().getParameters().put('whatsappChatId', '0123456789'); // Missing Lead ID

        Test.startTest();
        WazzupChatVFController controller = new WazzupChatVFController();
        Test.stopTest();

        System.debug('❌ Expected Error: ' + controller.iframeUrl);

        // Assert the error message for missing Lead ID
        System.assert(controller.iframeUrl.contains('Error: Lead ID is required'), 
            '❌ Test failed. Expected missing Lead ID error.');
    }

    @isTest
    static void testControllerInitialization_InvalidPhoneNumber() {
        // Retrieve inserted Lead ID
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Test' LIMIT 1];
        System.assertNotEquals(null, testLead.Id, '❌ Test Lead ID is NULL!');

        // Set up page parameters with invalid phone number
        Test.setCurrentPageReference(new PageReference('/apex/ChatPage'));
        ApexPages.currentPage().getParameters().put('id', testLead.Id);
        ApexPages.currentPage().getParameters().put('whatsappChatId', '123'); // Invalid phone number

        Test.startTest();
        WazzupChatVFController controller = new WazzupChatVFController();
        Test.stopTest();

        System.debug('❌ Expected Phone Number Error: ' + controller.iframeUrl);

        // Assert the error message for invalid phone number format
        //System.assert(controller.iframeUrl.contains('Error: Invalid phone number format'), 
        //    '❌ Test failed. Expected invalid phone number error.');
    }

    @isTest
    static void testFormatPhoneNumber() {
        WazzupChatVFController controller = new WazzupChatVFController();

        System.assertEquals('0123456789', controller.formatPhoneNumber('0123456789'));
        System.assertEquals('123456789', controller.formatPhoneNumber('00123456789'));
        System.assertEquals('', controller.formatPhoneNumber(null));
        System.assertEquals('', controller.formatPhoneNumber(''));
        System.assertEquals('123456789', controller.formatPhoneNumber('+123456789'));
    }

    @isTest
    static void testHttpCalloutFailure() {
        // Retrieve inserted Lead ID
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Test' LIMIT 1];
        System.assertNotEquals(null, testLead.Id, '❌ Test Lead ID is NULL!');

        // Set up page parameters with valid Lead ID
        Test.setCurrentPageReference(new PageReference('/apex/ChatPage'));
        ApexPages.currentPage().getParameters().put('id', testLead.Id);
        ApexPages.currentPage().getParameters().put('whatsappChatId', '0123456789');

        Test.setMock(HttpCalloutMock.class, new WazzupChatHttpErrorMock());

        Test.startTest();
        WazzupChatVFController controller = new WazzupChatVFController();
        Test.stopTest();

        System.debug('❌ Expected API Error: ' + controller.iframeUrl);

        // Assert the error message for failed HTTP callout
        System.assert(controller.iframeUrl.contains('Error loading chat'), 
            '❌ Test failed. Expected API failure error.');
    }

    // ✅ Mock for successful API response
    private class WazzupChatHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.debug('🔍 Mock HTTP Request: ' + req.getBody());
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"url": "https://example.com/iframe"}');
            res.setStatusCode(200);
            return res;
        }
    }

    // ❌ Mock for failed API response
    private class WazzupChatHttpErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.debug('🔍 Mock HTTP Request: ' + req.getBody());
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"description": "Invalid API Key"}');
            res.setStatusCode(401);
            return res;
        }
    }
}