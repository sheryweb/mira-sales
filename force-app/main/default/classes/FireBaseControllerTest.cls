@isTest
private class FireBaseControllerTest {
    
    @isTest
    static void testSendNotifications() {
        Notification__c notification = new Notification__c(
            Name = 'test',
            Description__c = 'Test, test'
        );
        insert notification;
        Contact contact = new Contact(
            LastName = 'test',
            FireBase_token__c = '123'
        );
        insert contact;
        String notificationId = notification.Id;
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        FireBaseController.sendNotifications(notificationId);
        Test.stopTest();
        
    }
    
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatus('200');
            res.setBody('{"access_token":"dummyAccessToken"}');
            return res;
        }
    }
    
}