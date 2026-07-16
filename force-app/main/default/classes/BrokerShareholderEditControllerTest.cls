@isTest
private class BrokerShareholderEditControllerTest {

    private static Id agencyRtId() {
        Map<String, Schema.RecordTypeInfo> m = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (m.containsKey('Agency') && m.get('Agency').isAvailable()) return m.get('Agency').getRecordTypeId();
        for (Schema.RecordTypeInfo i : m.values()) if (i.isAvailable() && !i.isMaster()) return i.getRecordTypeId();
        return null;
    }

    private static Broker_User__c setup(Integer shareholderCount) {
        String u = String.valueOf(Crypto.getRandomLong());
        Account agency = new Account(Name = 'SH Agency ' + u, Skip_Trigger__c = true);
        Id rt = agencyRtId(); if (rt != null) agency.RecordTypeId = rt;
        insert agency;
        if (shareholderCount == 2) {
            insert new List<Shareholder__c>{
                new Shareholder__c(Account__c = agency.Id, Name = 'Alice', Percent__c = 60),
                new Shareholder__c(Account__c = agency.Id, Name = 'Bob', Percent__c = 40)
            };
        }
        Broker_User__c bu = new Broker_User__c(Account__c = agency.Id, Email__c = 'sh' + u + '@example.com', Active__c = true);
        insert bu;
        return bu;
    }

    private static void loginAs(Broker_User__c bu) {
        Test.setCurrentPage(Page.BrokerShareholderEdit);
        ApexPages.currentPage().getCookies().put('brokerSession',
            new Cookie('brokerSession', BrokerLoginController.buildSessionToken(bu.Id), '/', 3600, true));
    }

    @isTest
    static void loads_existing_rows_and_total() {
        Broker_User__c bu = setup(2);
        loginAs(bu);
        BrokerShareholderEditController c = new BrokerShareholderEditController();
        System.assertEquals(false, c.locked);
        System.assertEquals(2, c.rows.size());
        System.assertEquals(true, c.getHasRows());
        System.assertEquals('100', c.getTotalPercent());
    }

    @isTest
    static void add_and_remove_rows() {
        Broker_User__c bu = setup(2);
        loginAs(bu);
        BrokerShareholderEditController c = new BrokerShareholderEditController();

        c.addRow();
        System.assertEquals(3, c.rows.size(), 'add appended a blank row');

        c.removeKey = c.rows[2].rowKey;
        c.removeRow();
        System.assertEquals(2, c.rows.size(), 'remove dropped the blank row');
    }

    @isTest
    static void save_blocked_when_total_not_100() {
        Broker_User__c bu = setup(2);
        loginAs(bu);
        BrokerShareholderEditController c = new BrokerShareholderEditController();
        c.rows[0].percent = '70';   // 70 + 40 = 110

        c.save();
        System.assertEquals(false, c.submitted);
        System.assert(c.message.contains('100'), 'message explains the 100% rule: ' + c.message);
    }

    @isTest
    static void save_blocked_when_name_blank() {
        Broker_User__c bu = setup(2);
        loginAs(bu);
        BrokerShareholderEditController c = new BrokerShareholderEditController();
        c.rows[0].holder = '';   // missing name

        c.save();
        System.assertEquals(false, c.submitted);
        System.assertNotEquals(null, c.message);
    }

    @isTest
    static void save_applies_edit_add_delete_at_100() {
        Broker_User__c bu = setup(2);
        loginAs(bu);
        BrokerShareholderEditController c = new BrokerShareholderEditController();

        // Remove Bob (40), reduce Alice to 50, add Carol 50 -> total 100.
        c.rows[0].percent = '50';                 // Alice -> 50
        c.removeKey = c.rows[1].rowKey;            // remove Bob (existing)
        c.removeRow();
        c.addRow();
        c.rows[c.rows.size() - 1].holder = 'Carol';
        c.rows[c.rows.size() - 1].percent = '50';

        Test.startTest();
        c.save();            // publishes the event
        Test.stopTest();     // delivers it -> handler applies

        System.assertEquals(true, c.submitted);
        Map<String, Decimal> byName = new Map<String, Decimal>();
        for (Shareholder__c sh : [SELECT Name, Percent__c FROM Shareholder__c WHERE Account__c = :bu.Account__c]) {
            byName.put(sh.Name, sh.Percent__c);
        }
        System.assertEquals(2, byName.size(), 'Bob removed, Carol added');
        System.assertEquals(50, byName.get('Alice'));
        System.assertEquals(50, byName.get('Carol'));
        System.assertEquals(false, byName.containsKey('Bob'));
    }

    @isTest
    static void no_changes_shows_message() {
        Broker_User__c bu = setup(2);
        loginAs(bu);
        BrokerShareholderEditController c = new BrokerShareholderEditController();
        // Save unchanged 60/40 = 100 still submits; instead clear everything to hit "no changes".
        c.rows.clear();
        c.save();
        System.assertEquals(false, c.submitted);
        System.assertNotEquals(null, c.message);
    }

    @isTest
    static void session_expired_locks() {
        Test.setCurrentPage(Page.BrokerShareholderEdit);   // no session cookie
        BrokerShareholderEditController c = new BrokerShareholderEditController();
        System.assertEquals(true, c.locked);
    }
}