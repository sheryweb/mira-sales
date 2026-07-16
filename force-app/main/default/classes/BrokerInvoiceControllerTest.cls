@isTest
private class BrokerInvoiceControllerTest {

    private static Id agencyRtId() {
        Map<String, Schema.RecordTypeInfo> m = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (m.containsKey('Agency') && m.get('Agency').isAvailable()) return m.get('Agency').getRecordTypeId();
        for (Schema.RecordTypeInfo i : m.values()) if (i.isAvailable() && !i.isMaster()) return i.getRecordTypeId();
        return null;
    }

    private class Refs { Id commId; Id brokerId; }

    private static Refs makeAgencyCommission(String vat) {
        String u = String.valueOf(Crypto.getRandomLong());
        Account agency = new Account(Name = 'Inv Agency ' + u, Skip_Trigger__c = true, VAT_TRN__c = vat);
        Id rt = agencyRtId(); if (rt != null) agency.RecordTypeId = rt;
        insert agency;

        Opportunity opp = new Opportunity(Name = 'Inv Opp ' + u, StageName = 'New',
            CloseDate = Date.today().addDays(30), AccountId = agency.Id, Agency__c = agency.Id);
        insert opp;

        Unit__c unit = new Unit__c(Title__c = 'Inv Unit ' + u, Building__c = 'Tower 7');
        insert unit;

        Commission__c c = new Commission__c(Agency__c = agency.Id, Opportunity__c = opp.Id,
            Unit__c = unit.Id, Base_Amount__c = 1000000, Commission_Rate__c = 4);
        insert c;

        Broker_User__c bu = new Broker_User__c(Account__c = agency.Id, Email__c = 'inv' + u + '@example.com', Active__c = true);
        insert bu;

        Refs r = new Refs();
        r.commId = c.Id;
        r.brokerId = bu.Id;
        return r;
    }

    private static void login(Id brokerId, String commId) {
        Test.setCurrentPage(Page.BrokerCommissionInvoice);
        if (brokerId != null) {
            ApexPages.currentPage().getCookies().put('brokerSession',
                new Cookie('brokerSession', BrokerLoginController.buildSessionToken(brokerId), '/', 3600, true));
        }
        if (commId != null) ApexPages.currentPage().getParameters().put('id', commId);
    }

    @isTest
    static void valid_invoice_for_vat_eligible() {
        Refs r = makeAgencyCommission('Yes');
        login(r.brokerId, r.commId);
        BrokerInvoiceController ctrl = new BrokerInvoiceController();
        System.assertEquals(true, ctrl.getIsValid());
        BrokerInvoiceController.InvoiceData d = ctrl.getInvoice();
        System.assert(String.isNotBlank(d.commNo), 'commission number populated');
        System.assertEquals('Tower 7', d.tower);
        System.assertNotEquals(null, d.commissionAmount);
        System.assertNotEquals(null, d.vatAmount);
        System.assertNotEquals(null, d.totalAmount);
    }

    @isTest
    static void blocked_when_not_vat_eligible() {
        Refs r = makeAgencyCommission('No');
        login(r.brokerId, r.commId);
        BrokerInvoiceController ctrl = new BrokerInvoiceController();
        System.assertEquals(false, ctrl.getIsValid(), 'non-VAT agency cannot generate an invoice');
    }

    @isTest
    static void blocked_for_other_agencys_commission() {
        Refs a = makeAgencyCommission('Yes');
        Refs b = makeAgencyCommission('Yes');
        login(a.brokerId, b.commId);   // logged in as A, requesting B's commission
        BrokerInvoiceController ctrl = new BrokerInvoiceController();
        System.assertEquals(false, ctrl.getIsValid(), 'cannot invoice another agency commission');
    }

    @isTest
    static void blocked_without_session() {
        Refs r = makeAgencyCommission('Yes');
        login(null, r.commId);   // no session cookie
        BrokerInvoiceController ctrl = new BrokerInvoiceController();
        System.assertEquals(false, ctrl.getIsValid());
    }
}