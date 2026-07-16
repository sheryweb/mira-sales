@isTest
private class MSAzureAiQueueableTest {
    public class AzureMockTransliterate implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setBody('[{"text":"Test Arabic", "script":"ar"}]');
            res.setStatusCode(200);
            return res;
        }
    }

    public class AzureMockTranslate implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setBody('[{"detectedLanguage": {"language":"", "score":10}, "translations":[{"text":"Paris Arabic", "to":"ar"}]}]');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testQueueableTransliterate() {
        Account acc = new Account();
        acc.Name = 'Test';
        acc.BillingCity = 'Paris';
        insert acc;

        Map<String, Map<Id,Set<String>>> recordsToProcess = new Map<String, Map<Id,Set<String>>>();
        
        recordsToProcess.put('transliterate', new Map<Id,Set<String>>());
        recordsToProcess.get('transliterate').put(acc.Id, new Set<String>());
        recordsToProcess.get('transliterate').get(acc.Id).add('Name');
        
        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new AzureMockTransliterate());
            System.enqueueJob(new MSAzureAiQueueable(recordsToProcess));
        Test.stopTest();

        Account changed = [Select Id, Account_Name_Arabic__c From Account LIMIT 1];
        Assert.areEqual('Test Arabic', changed.Account_Name_Arabic__c);
    }

    @isTest
    static void testQueueableTranslate() {
        Account acc = new Account();
        acc.Name = 'Test';
        acc.BillingCity = 'Paris';
        insert acc;

        Map<String, Map<Id,Set<String>>> recordsToProcess = new Map<String, Map<Id,Set<String>>>();

        recordsToProcess.put('translate', new Map<Id,Set<String>>());
        recordsToProcess.get('translate').put(acc.Id, new Set<String>());
        recordsToProcess.get('translate').get(acc.Id).add('BillingCity');

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new AzureMockTranslate());
            System.enqueueJob(new MSAzureAiQueueable(recordsToProcess));
        Test.stopTest();
        Account changed = [Select Id, City_Arabic__c From Account LIMIT 1];
        Assert.areEqual('Paris Arabic', changed.City_Arabic__c);
    }

}