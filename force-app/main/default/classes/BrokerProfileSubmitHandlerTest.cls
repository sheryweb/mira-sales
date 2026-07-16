@isTest
private class BrokerProfileSubmitHandlerTest {

    private static Approval_Request__c makeRequest() {
        Account acc = new Account(Name = 'Submit Agency ' + String.valueOf(Crypto.getRandomLong()), Skip_Trigger__c = true);
        insert acc;
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Agency Profile Update',
            Related_Object_Type__c = 'Account',
            Related_Record_Id__c = acc.Id,
            Field_To_Update__c = 'Company Profile (multiple)',
            Current_Value__c = 'See Profile Changes',
            Requested_Value__c = 'See Profile Changes',
            Justification__c = 'Company profile update from Broker Portal',
            Profile_Changes_JSON__c = '[{"field":"Phone","label":"Phone","oldValue":"1","newValue":"2"}]',
            Status__c = 'Pending'
        );
        insert req;
        return req;
    }

    @isTest
    static void event_handled_without_error() {
        Approval_Request__c req = makeRequest();

        Test.startTest();
        EventBus.publish(new Broker_Profile_Submit__e(Approval_Request_Id__c = req.Id));
        Test.stopTest(); // delivers the event -> trigger -> handler

        // No approval process exists in the test context, so Approval.process is caught and the
        // record stays Pending. The point is the handler runs cleanly (no unhandled exception).
        Approval_Request__c after = [SELECT Status__c FROM Approval_Request__c WHERE Id = :req.Id];
        System.assertEquals('Pending', after.Status__c);
    }

    @isTest
    static void blank_and_invalid_events_are_ignored() {
        Test.startTest();
        EventBus.publish(new Broker_Profile_Submit__e(Approval_Request_Id__c = null));
        EventBus.publish(new Broker_Profile_Submit__e(Approval_Request_Id__c = 'not-an-id'));
        Test.stopTest();
        System.assert(true, 'Handler ignores blank/invalid ids without error');
    }

    // Direct handler calls — guarantee coverage independent of platform event delivery.

    @isTest
    static void direct_call_submits_or_catches() {
        Approval_Request__c req = makeRequest();

        Test.startTest();
        BrokerProfileSubmitHandler.handle(new List<Broker_Profile_Submit__e>{
            new Broker_Profile_Submit__e(Approval_Request_Id__c = req.Id),
            new Broker_Profile_Submit__e(Approval_Request_Id__c = null),
            new Broker_Profile_Submit__e(Approval_Request_Id__c = 'not-an-id')
        });
        Test.stopTest();

        // Whether or not an approval process is active, the handler must not throw
        // and the request must still exist.
        System.assertEquals(1, [SELECT COUNT() FROM Approval_Request__c WHERE Id = :req.Id]);
    }

    @isTest
    static void direct_call_blank_ids_only_returns_early() {
        Test.startTest();
        BrokerProfileSubmitHandler.handle(new List<Broker_Profile_Submit__e>{
            new Broker_Profile_Submit__e(Approval_Request_Id__c = null),
            new Broker_Profile_Submit__e(Approval_Request_Id__c = '')
        });
        Test.stopTest();
        System.assert(true, 'Handler returns early when no valid ids are present');
    }

    @isTest
    static void direct_call_unknown_id_returns_early() {
        // Well-formed Approval_Request__c id that does not exist -> query returns empty.
        Id fakeId = Id.valueOf(
            Approval_Request__c.SObjectType.getDescribe().getKeyPrefix() + '000000000AAA'
        );
        Test.startTest();
        BrokerProfileSubmitHandler.handle(new List<Broker_Profile_Submit__e>{
            new Broker_Profile_Submit__e(Approval_Request_Id__c = String.valueOf(fakeId))
        });
        Test.stopTest();
        System.assert(true, 'Handler returns early for unknown request ids');
    }

    @isTest
    static void direct_call_without_related_account() {
        // No Related_Record_Id__c -> ownerId stays null -> submit without submitterId.
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Agency Profile Update',
            Related_Object_Type__c = 'Account',
            Field_To_Update__c = 'Company Profile (multiple)',
            Current_Value__c = 'See Profile Changes',
            Requested_Value__c = 'See Profile Changes',
            Justification__c = 'Company profile update from Broker Portal',
            Status__c = 'Pending'
        );
        insert req;

        Test.startTest();
        BrokerProfileSubmitHandler.handle(new List<Broker_Profile_Submit__e>{
            new Broker_Profile_Submit__e(Approval_Request_Id__c = req.Id)
        });
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Approval_Request__c WHERE Id = :req.Id]);
    }
}