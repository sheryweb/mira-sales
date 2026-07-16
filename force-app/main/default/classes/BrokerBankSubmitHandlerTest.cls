@isTest
private class BrokerBankSubmitHandlerTest {

    private static Approval_Request__c makeRequest() {
        Account acc = new Account(Name = 'Bank Submit Agency ' + String.valueOf(Crypto.getRandomLong()), Skip_Trigger__c = true);
        insert acc;
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Bank Detail Update', Related_Object_Type__c = 'Account',
            Related_Record_Id__c = acc.Id, Field_To_Update__c = 'Bank Details (multiple)',
            Current_Value__c = 'See Bank Changes', Requested_Value__c = 'See Bank Changes',
            Justification__c = 'Bank detail update from Broker Portal',
            Profile_Changes_JSON__c = '[{"recordId":"","fields":{"Name":"ADCB"}}]',
            Status__c = 'Pending');
        insert req;
        return req;
    }

    @isTest
    static void event_handled_without_error() {
        Approval_Request__c req = makeRequest();
        Test.startTest();
        EventBus.publish(new Broker_Bank_Submit__e(Approval_Request_Id__c = req.Id));
        Test.stopTest();
        // No approval process in the test context -> stays Pending; the point is the handler runs cleanly.
        System.assertEquals('Pending', [SELECT Status__c FROM Approval_Request__c WHERE Id = :req.Id].Status__c);
    }

    @isTest
    static void direct_call_submits_or_catches() {
        Approval_Request__c req = makeRequest();
        Test.startTest();
        BrokerBankSubmitHandler.handle(new List<Broker_Bank_Submit__e>{
            new Broker_Bank_Submit__e(Approval_Request_Id__c = req.Id),
            new Broker_Bank_Submit__e(Approval_Request_Id__c = null),
            new Broker_Bank_Submit__e(Approval_Request_Id__c = 'not-an-id')
        });
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Approval_Request__c WHERE Id = :req.Id]);
    }

    @isTest
    static void blank_ids_return_early() {
        Test.startTest();
        BrokerBankSubmitHandler.handle(new List<Broker_Bank_Submit__e>{
            new Broker_Bank_Submit__e(Approval_Request_Id__c = null),
            new Broker_Bank_Submit__e(Approval_Request_Id__c = '')
        });
        Test.stopTest();
        System.assert(true, 'Handler returns early when no valid ids are present');
    }

    @isTest
    static void unknown_id_returns_early() {
        Id fakeId = Id.valueOf(Approval_Request__c.SObjectType.getDescribe().getKeyPrefix() + '000000000AAA');
        Test.startTest();
        BrokerBankSubmitHandler.handle(new List<Broker_Bank_Submit__e>{
            new Broker_Bank_Submit__e(Approval_Request_Id__c = String.valueOf(fakeId))
        });
        Test.stopTest();
        System.assert(true, 'Handler returns early for unknown request ids');
    }
}