@isTest
private class BrokerDashboardControllerTest {

    private static Id agencyRtId() {
        Map<String, Schema.RecordTypeInfo> m = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (m.containsKey('Agency') && m.get('Agency').isAvailable()) return m.get('Agency').getRecordTypeId();
        for (Schema.RecordTypeInfo i : m.values()) if (i.isAvailable() && !i.isMaster()) return i.getRecordTypeId();
        return null;
    }

    // Stage validation rules block creating Booked directly, so insert as New then update.
    private static void makeOpp(Id clientId, Id agencyId, Id unitId, String stage, String name) {
        Opportunity o = new Opportunity(Name = name, StageName = 'New', CloseDate = Date.today().addDays(30),
            AccountId = clientId, Agency__c = agencyId, Unit__c = unitId);
        insert o;
        if (stage != 'New') { o.StageName = stage; update o; }
    }

    // Agency with New + Booked + Cancelled deals; returns its Broker_User login
    private static Broker_User__c setupAgency() {
        String u = String.valueOf(Crypto.getRandomLong());
        Account agency = new Account(Name = 'Dash Agency ' + u, Skip_Trigger__c = true);
        Id rt = agencyRtId(); if (rt != null) agency.RecordTypeId = rt;
        insert agency;
        Account client = new Account(Name = 'Dash Client ' + u, Skip_Trigger__c = true);
        insert client;
        Unit__c unit = new Unit__c(Title__c = 'Dash Unit ' + u);
        insert unit;

        // One opp per stage. NB: we do NOT create a 'Sold' opp here — moving an Opp to
        // Sold fires the "Stage & Status Automation" flow, whose email action uses a
        // production-only Org-Wide Email Address id that throws in the sandbox/test context.
        // getUnitsSold() counts Reserved + Sold, so Reserved exercises it safely.
        makeOpp(client.Id, agency.Id, unit.Id, 'New', 'New ' + u);
        makeOpp(client.Id, agency.Id, unit.Id, 'Booked', 'Booked ' + u);
        makeOpp(client.Id, agency.Id, unit.Id, 'Reserved', 'Reserved ' + u);
        makeOpp(client.Id, agency.Id, unit.Id, 'Cancelled', 'Cancelled ' + u);

        Broker_User__c bu = new Broker_User__c(Account__c = agency.Id, Email__c = 'dash' + u + '@example.com', Active__c = true);
        insert bu;
        return bu;
    }

    private static void loginAs(Broker_User__c bu) {
        Test.setCurrentPage(Page.BrokerPortalHome);
        ApexPages.currentPage().getCookies().put('brokerSession',
            new Cookie('brokerSession', BrokerLoginController.buildSessionToken(bu.Id), '/', 3600, true));
    }

    @isTest
    static void counts_for_logged_in_agency() {
        Broker_User__c bu = setupAgency();
        loginAs(bu);
        BrokerDashboardController c = new BrokerDashboardController();
        System.assertEquals(3, c.getTotalDeals(), 'New + Booked + Reserved (Cancelled excluded)');
        System.assertEquals(1, c.getUnitsBooked(), 'Booked only');
        System.assertEquals(1, c.getUnitsSold(), 'Reserved + Sold (Reserved here)');
    }

    @isTest
    static void other_agency_not_counted() {
        Broker_User__c bu = setupAgency();
        setupAgency();              // a second agency's deals must not be counted
        loginAs(bu);
        BrokerDashboardController c = new BrokerDashboardController();
        System.assertEquals(3, c.getTotalDeals(), 'Only the logged-in broker agency');
        System.assertEquals(1, c.getUnitsBooked());
        System.assertEquals(1, c.getUnitsSold());
    }

    @isTest
    static void dashboard_widgets() {
        Broker_User__c bu = setupAgency();
        loginAs(bu);
        BrokerDashboardController c = new BrokerDashboardController();

        // Donut: New + Booked + Reserved + Cancelled = 4 deals, 4 slices
        System.assertEquals(4, c.getDonutTotal(), 'donut includes Cancelled');
        System.assertEquals(true, c.getHasDeals());
        List<BrokerDashboardController.StageSlice> slices = c.getStageSlices();
        System.assertEquals(4, slices.size(), 'one slice per non-zero stage');
        System.assertEquals('Booked', slices[0].label, 'stage order starts with Booked');
        System.assertEquals(1, slices[0].cnt);
        System.assert(slices[0].dash.contains('439.82'), 'dasharray uses the circumference');

        // Bars: always 6 months
        System.assertEquals(6, c.getMonthlyBars().size());

        // Recent bookings: all 4 deals, mapped rows
        System.assertEquals(true, c.getHasRecent());
        List<BrokerDashboardController.RecentRow> rows = c.getRecentBookings();
        System.assertEquals(4, rows.size());
        for (BrokerDashboardController.RecentRow r : rows) System.assert(String.isNotBlank(r.unit));
    }

    // Base 1,000,000 @ 4% -> 40,000 computed by the Commission trigger
    @isTest
    static void commission_kpis() {
        Broker_User__c bu = setupAgency();
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Agency__c = :bu.Account__c LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        insert new Commission__c(Agency__c = bu.Account__c, Opportunity__c = opp.Id,
            Unit__c = unit.Id, Base_Amount__c = 1000000, Commission_Rate__c = 4);
        loginAs(bu);
        BrokerDashboardController c = new BrokerDashboardController();
        System.assert(c.getTotalCommission().startsWith('AED'), 'total formatted');
        System.assertNotEquals('AED 0', c.getTotalCommission(), 'commission exists -> non-zero total');
        System.assertEquals('AED 0', c.getPaidCommission(), 'nothing paid yet');
        System.assert(c.getRemainingCommission().startsWith('AED'));
    }

    @isTest
    static void zero_without_session() {
        Test.setCurrentPage(Page.BrokerPortalHome);
        BrokerDashboardController c = new BrokerDashboardController();
        System.assertEquals(0, c.getTotalDeals());
        System.assertEquals(0, c.getUnitsBooked());
        System.assertEquals('AED 0', c.getTotalCommission());
        System.assertEquals('AED 0', c.getPaidCommission());
        System.assertEquals('AED 0', c.getRemainingCommission());
        System.assertEquals(false, c.getHasDeals());
        System.assertEquals(0, c.getStageSlices().size());
        System.assertEquals(6, c.getMonthlyBars().size());
        System.assertEquals(0, c.getRecentBookings().size());
        System.assertEquals(false, c.getHasRecent());
    }
}