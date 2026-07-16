@isTest
private class BrokerCommissionsControllerTest {

    private static Id agencyRtId() {
        Map<String, Schema.RecordTypeInfo> m = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (m.containsKey('Agency') && m.get('Agency').isAvailable()) return m.get('Agency').getRecordTypeId();
        for (Schema.RecordTypeInfo i : m.values()) if (i.isAvailable() && !i.isMaster()) return i.getRecordTypeId();
        return null;
    }

    // Agency with one commission (Base 1,000,000 @ 4% -> 40,000 computed by the Commission trigger)
    private static Broker_User__c setupAgencyWithCommission() {
        String u = String.valueOf(Crypto.getRandomLong());
        Account agency = new Account(Name = 'Comm Agency ' + u, Skip_Trigger__c = true, VAT_TRN__c = 'Yes');
        Id rt = agencyRtId(); if (rt != null) agency.RecordTypeId = rt;
        insert agency;

        Opportunity opp = new Opportunity(Name = 'Comm Opp ' + u, StageName = 'New',
            CloseDate = Date.today().addDays(30), AccountId = agency.Id, Agency__c = agency.Id);
        insert opp;

        Unit__c unit = new Unit__c(Title__c = 'Comm Unit ' + u, Building__c = 'Tower 1');
        insert unit;

        Commission__c c = new Commission__c(Agency__c = agency.Id, Opportunity__c = opp.Id,
            Unit__c = unit.Id, Base_Amount__c = 1000000, Commission_Rate__c = 4);
        insert c;

        Broker_User__c bu = new Broker_User__c(Account__c = agency.Id, Email__c = 'comm' + u + '@example.com', Active__c = true);
        insert bu;
        return bu;
    }

    private static void loginAs(Broker_User__c bu) {
        Test.setCurrentPage(Page.BrokerCommissions);
        ApexPages.currentPage().getCookies().put('brokerSession',
            new Cookie('brokerSession', BrokerLoginController.buildSessionToken(bu.Id), '/', 3600, true));
    }

    @isTest
    static void rows_and_totals() {
        Broker_User__c bu = setupAgencyWithCommission();
        loginAs(bu);
        BrokerCommissionsController c = new BrokerCommissionsController();

        System.assertEquals(true, c.getHasCommissions());
        List<BrokerCommissionsController.CommissionRow> rows = c.getCommissions();
        System.assertEquals(1, rows.size());
        System.assert(String.isNotBlank(rows[0].commNo), 'commission number populated');
        System.assertNotEquals(null, rows[0].unit, 'unit title resolved');
        System.assertEquals('Tower 1', rows[0].tower, 'tower from Unit Building');
        System.assertEquals('4%', rows[0].rate);
        System.assertEquals('Eligible', rows[0].status);
        System.assertEquals('b-new', rows[0].badgeClass);
        System.assert(rows[0].commission.startsWith('AED'), 'commission formatted');

        // Totals: earned 40,000, paid 0, outstanding 40,000, avg rate 4.0%
        System.assert(c.getTotalEarned().startsWith('AED'));
        System.assertEquals('AED 0', c.getPaidTotal());
        System.assert(c.getOutstandingTotal().startsWith('AED'));
        System.assert(c.getAvgRate().contains('4'), 'avg rate ~4%');
    }

    @isTest
    static void other_agency_excluded() {
        Broker_User__c bu = setupAgencyWithCommission();
        setupAgencyWithCommission();   // another agency's commission must not appear
        loginAs(bu);
        BrokerCommissionsController c = new BrokerCommissionsController();
        System.assertEquals(1, c.getCommissions().size(), 'only the logged-in agency commissions');
    }

    @isTest
    static void empty_without_session() {
        Test.setCurrentPage(Page.BrokerCommissions);
        BrokerCommissionsController c = new BrokerCommissionsController();
        System.assertEquals(false, c.getHasCommissions());
        System.assertEquals(0, c.getCommissions().size());
        System.assertEquals('AED 0', c.getTotalEarned());
        System.assertEquals('0%', c.getAvgRate());
    }
}