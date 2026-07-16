@isTest
private class BrokerProfileEditControllerTest {

    private static Id agencyRtId() {
        Map<String, Schema.RecordTypeInfo> m = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (m.containsKey('Agency') && m.get('Agency').isAvailable()) return m.get('Agency').getRecordTypeId();
        for (Schema.RecordTypeInfo i : m.values()) if (i.isAvailable() && !i.isMaster()) return i.getRecordTypeId();
        return null;
    }

    private static Broker_User__c setup() {
        String u = String.valueOf(Crypto.getRandomLong());
        Account agency = new Account(Name = 'Edit Agency ' + u, Skip_Trigger__c = true, Phone = '111', Company_Email__c = 'old' + u + '@abc.ae');
        Id rt = agencyRtId(); if (rt != null) agency.RecordTypeId = rt;
        insert agency;
        Broker_User__c bu = new Broker_User__c(Account__c = agency.Id, Email__c = 'edit' + u + '@example.com', Active__c = true);
        insert bu;
        return bu;
    }

    private static void loginAs(Broker_User__c bu) {
        Test.setCurrentPage(Page.BrokerProfileEdit);
        ApexPages.currentPage().getCookies().put('brokerSession',
            new Cookie('brokerSession', BrokerLoginController.buildSessionToken(bu.Id), '/', 3600, true));
    }

    private static void setField(BrokerProfileEditController c, String api, String val) {
        for (BrokerProfileEditController.FieldDef f : c.fields) {
            if (f.api == api) { f.value = val; return; }
        }
    }

    @isTest
    static void loads_fields_unlocked() {
        Broker_User__c bu = setup();
        loginAs(bu);
        BrokerProfileEditController c = new BrokerProfileEditController();
        System.assertEquals(false, c.locked, 'no pending request');
        System.assert(c.fields.size() > 0, 'fields loaded');
    }

    @isTest
    static void save_creates_request_and_submits() {
        Broker_User__c bu = setup();
        loginAs(bu);
        BrokerProfileEditController c = new BrokerProfileEditController();
        setField(c, 'Phone', '+971 4 999 8888');

        Test.startTest();
        c.save();
        Test.stopTest();

        System.assertEquals(true, c.submitted, 'submitted');
        List<Approval_Request__c> reqs = [
            SELECT Status__c, Request_Type__c, Profile_Changes_JSON__c, Related_Record_Id__c
            FROM Approval_Request__c
            WHERE Related_Record_Id__c = :String.valueOf(bu.Account__c) AND Request_Type__c = 'Agency Profile Update'
        ];
        System.assertEquals(1, reqs.size(), 'one request created');
        System.assertEquals('Pending', reqs[0].Status__c);
        System.assert(reqs[0].Profile_Changes_JSON__c.contains('Phone'), 'JSON has the changed field');
        System.assert(reqs[0].Profile_Changes_JSON__c.contains('999 8888'), 'JSON has the new value');
    }

    @isTest
    static void no_changes_shows_message() {
        Broker_User__c bu = setup();
        loginAs(bu);
        BrokerProfileEditController c = new BrokerProfileEditController();
        c.save(); // nothing changed
        System.assertEquals(false, c.submitted);
        System.assertNotEquals(null, c.message);
        System.assertEquals(0, [SELECT COUNT() FROM Approval_Request__c WHERE Related_Record_Id__c = :String.valueOf(bu.Account__c)]);
    }

    @isTest
    static void locked_when_request_pending() {
        Broker_User__c bu = setup();
        insert new Approval_Request__c(
            Request_Type__c = 'Agency Profile Update', Related_Object_Type__c = 'Account',
            Related_Record_Id__c = String.valueOf(bu.Account__c), Field_To_Update__c = 'x',
            Current_Value__c = 'x', Requested_Value__c = 'x', Justification__c = 'pending one',
            Status__c = 'Pending');
        loginAs(bu);
        BrokerProfileEditController c = new BrokerProfileEditController();
        System.assertEquals(true, c.locked, 'locked because a request is pending');
    }
}