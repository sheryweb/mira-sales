@isTest
private class BrokerBookingsControllerTest {

    private static Id agencyRtId() {
        Map<String, Schema.RecordTypeInfo> m = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (m.containsKey('Agency') && m.get('Agency').isAvailable()) return m.get('Agency').getRecordTypeId();
        for (Schema.RecordTypeInfo i : m.values()) if (i.isAvailable() && !i.isMaster()) return i.getRecordTypeId();
        return null;
    }

    // Stage validation rules block creating Booked directly, so insert as New then update.
    // Unit_Title__c / Unit_Tower__c / Unit_Price__c are read-only formulas, so they stay blank in tests
    // (the controller falls back to Name when Unit_Title__c is blank).
    private static void makeOpp(Id clientId, Id agencyId, Id unitId, String stage, String name, Datetime bookedAt) {
        Opportunity o = new Opportunity(Name = name, StageName = 'New', CloseDate = Date.today().addDays(30),
            AccountId = clientId, Agency__c = agencyId, Unit__c = unitId);
        insert o;
        Boolean changed = false;
        if (stage != 'New') { o.StageName = stage; changed = true; }
        if (bookedAt != null) { o.Booking_Date_Time__c = bookedAt; changed = true; }
        if (changed) update o;
    }

    private static Broker_User__c setupWithBookings() {
        String u = String.valueOf(Crypto.getRandomLong());
        Account agency = new Account(Name = 'Bk Agency ' + u, Skip_Trigger__c = true);
        Id rt = agencyRtId(); if (rt != null) agency.RecordTypeId = rt;
        insert agency;
        Account client = new Account(Name = 'Bk Client ' + u, Skip_Trigger__c = true);
        insert client;
        Unit__c unit = new Unit__c(Title__c = 'Bk Unit ' + u);
        insert unit;

        makeOpp(client.Id, agency.Id, unit.Id, 'Booked', 'Booked Deal ' + u, System.now());
        makeOpp(client.Id, agency.Id, unit.Id, 'New', 'New Deal ' + u, null);

        Broker_User__c bu = new Broker_User__c(Account__c = agency.Id, Email__c = 'bk' + u + '@example.com', Active__c = true);
        insert bu;
        return bu;
    }

    private static void loginAs(Broker_User__c bu) {
        Test.setCurrentPage(Page.BrokerBookings);
        ApexPages.currentPage().getCookies().put('brokerSession',
            new Cookie('brokerSession', BrokerLoginController.buildSessionToken(bu.Id), '/', 3600, true));
    }

    @isTest
    static void lists_scoped_bookings() {
        Broker_User__c bu = setupWithBookings();
        loginAs(bu);
        BrokerBookingsController c = new BrokerBookingsController();

        System.assertEquals(true, c.getHasBookings());
        List<BrokerBookingsController.BookingRow> rows = c.getBookings();
        System.assertEquals(2, rows.size());
        // Booked has a Booking_Date_Time so it sorts first (New is null -> last)
        System.assertEquals('Booked', rows[0].stage);
        System.assertEquals('b-booked', rows[0].badgeClass);
        System.assertNotEquals(null, rows[0].unit, 'falls back to Name when Unit_Title__c is blank');
        System.assertNotEquals(null, rows[0].client, 'client (buyer) name resolved');
        System.assertEquals('New', rows[1].stage);
        System.assertEquals(1, c.getCountBooked());
        System.assertEquals(1, c.getCountNew());
        System.assertEquals(0, c.getCountReserved());
        System.assertEquals(0, c.getCountSold());
        System.assertEquals(0, c.getCountCancelled());
    }

    @isTest
    static void other_agency_excluded() {
        Broker_User__c bu = setupWithBookings();
        setupWithBookings();        // another agency's bookings must not appear
        loginAs(bu);
        BrokerBookingsController c = new BrokerBookingsController();
        System.assertEquals(2, c.getBookings().size(), 'Only the logged-in agency bookings');
    }

    @isTest
    static void empty_without_session() {
        Test.setCurrentPage(Page.BrokerBookings);
        BrokerBookingsController c = new BrokerBookingsController();
        System.assertEquals(false, c.getHasBookings());
        System.assertEquals(0, c.getBookings().size());
    }
}