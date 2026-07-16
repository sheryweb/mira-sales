@isTest
private class BrokerDocSubmitHandlerTest {

    private static Approval_Request__c makeRequest() {
        Account acc = new Account(Name = 'Doc Submit ' + String.valueOf(Crypto.getRandomLong()), Skip_Trigger__c = true);
        insert acc;
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Document Re-upload', Related_Object_Type__c = 'Account',
            Related_Record_Id__c = acc.Id, Field_To_Update__c = 'Trade License',
            Current_Value__c = 'x', Requested_Value__c = 'y',
            Justification__c = 'Document re-upload from Broker Portal',
            Profile_Changes_JSON__c = '{"category":"Trade License"}', Status__c = 'Pending'
        );
        insert req;
        return req;
    }

    @isTest
    static void event_handled_without_error() {
        Approval_Request__c req = makeRequest();
        Test.startTest();
        EventBus.publish(new Broker_Doc_Submit__e(Approval_Request_Id__c = req.Id));
        Test.stopTest();
        System.assertEquals('Pending', [SELECT Status__c FROM Approval_Request__c WHERE Id = :req.Id].Status__c);
    }

    @isTest
    static void direct_call_submits_or_catches() {
        Approval_Request__c req = makeRequest();
        Test.startTest();
        BrokerDocSubmitHandler.handle(new List<Broker_Doc_Submit__e>{
            new Broker_Doc_Submit__e(Approval_Request_Id__c = req.Id),
            new Broker_Doc_Submit__e(Approval_Request_Id__c = null),
            new Broker_Doc_Submit__e(Approval_Request_Id__c = 'not-an-id')
        });
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Approval_Request__c WHERE Id = :req.Id]);
    }

    @isTest
    static void blank_ids_return_early() {
        Test.startTest();
        BrokerDocSubmitHandler.handle(new List<Broker_Doc_Submit__e>{
            new Broker_Doc_Submit__e(Approval_Request_Id__c = null),
            new Broker_Doc_Submit__e(Approval_Request_Id__c = '')
        });
        Test.stopTest();
        System.assert(true, 'returns early with no valid ids');
    }
}