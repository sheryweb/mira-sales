@isTest
private class BrokerInventoryControllerTest {
    // Units must be created as Draft (validation rule), then updated to Published.
    // The status-change rule only blocks the Inventory Manager profile, so the
    // test-running user can publish freely.

    private static Id agencyRtId() {
        Map<String, Schema.RecordTypeInfo> m = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (m.containsKey('Agency') && m.get('Agency').isAvailable()) return m.get('Agency').getRecordTypeId();
        for (Schema.RecordTypeInfo i : m.values()) if (i.isAvailable() && !i.isMaster()) return i.getRecordTypeId();
        return null;
    }

    private static Id setupPublishedInventory() {
        Project__c project = new Project__c(
            Name = 'Inv Test Project',
            Description__c = 'Test',
            District__c = 'Meydan',
            Coordinates_Latitude__c = 1,
            Coordinates_Longitude__c = 1,
            Handover__c = Date.today(),
            Minimum_Cost__c = 1,
            Publish_Project__c = 'Published'
        );
        insert project;

        Unit__c full = new Unit__c(
            Title__c = 'Inv Full Unit',
            Cost_AED__c = 1500000,
            Type__c = 'Apartment',
            Total_Area__c = 1200,
            Living_Space__c = 900,
            Additional_Area__c = 300,
            Floor__c = 3,
            Number_of_Bedrooms__c = 2,
            Number_of_Bathrooms__c = 2,
            Status__c = 'Draft',
            Building__c = 'Tower A',
            Panorama_Link__c = 'Link',
            Project__c = project.Id
        );
        // Studio with no title/cost/baths/area covers the fallback branches.
        Unit__c studio = new Unit__c(
            Cost_AED__c = null,
            Type__c = 'Apartment',
            Total_Area__c = 500,
            Living_Space__c = 400,
            Additional_Area__c = 100,
            Floor__c = 1,
            Number_of_Bedrooms__c = 0,
            Status__c = 'Draft',
            Panorama_Link__c = 'Link',
            Project__c = project.Id
        );
        insert new List<Unit__c>{ full, studio };

        full.Status__c = 'Published';
        studio.Status__c = 'Published';
        update new List<Unit__c>{ full, studio };

        return project.Id;
    }

    private static void loginBroker() {
        String u = String.valueOf(Crypto.getRandomLong());
        Account agency = new Account(Name = 'Inv Agency ' + u, Skip_Trigger__c = true);
        Id rt = agencyRtId(); if (rt != null) agency.RecordTypeId = rt;
        insert agency;
        Broker_User__c bu = new Broker_User__c(Account__c = agency.Id, Email__c = 'inv' + u + '@example.com', Active__c = true);
        insert bu;
        Test.setCurrentPage(Page.BrokerInventory);
        ApexPages.currentPage().getCookies().put('brokerSession',
            new Cookie('brokerSession', BrokerLoginController.buildSessionToken(bu.Id), '/', 3600, true));
    }

    @isTest
    static void no_session_returns_empty() {
        setupPublishedInventory();
        Test.setCurrentPage(Page.BrokerInventory);
        BrokerInventoryController c = new BrokerInventoryController();
        System.assertEquals(false, c.getHasUnits());
        System.assertEquals(0, c.getUnits().size());
        // Dropdown still offers "All Projects", with no project rows when not logged in
        System.assertEquals(1, c.getProjectOptions().size());
        System.assertEquals('', c.getProjectOptions()[0].getValue());
    }

    @isTest
    static void all_projects_branch_builds_rows() {
        Id projectId = setupPublishedInventory();
        loginBroker();
        BrokerInventoryController c = new BrokerInventoryController();

        List<SelectOption> opts = c.getProjectOptions();
        System.assert(opts.size() >= 2, 'All Projects + the published project');
        System.assertEquals('All Projects', opts[0].getLabel());

        c.selectedProjectId = '';
        List<BrokerInventoryController.UnitRow> rows = c.getUnits();
        System.assertEquals(true, c.getHasUnits());
        System.assertEquals(2, rows.size(), 'both published units listed');

        BrokerInventoryController.UnitRow fullRow;
        BrokerInventoryController.UnitRow studioRow;
        for (BrokerInventoryController.UnitRow r : rows) {
            if (r.title == 'Inv Full Unit') fullRow = r; else studioRow = r;
        }

        System.assertNotEquals(null, fullRow, 'titled unit present');
        System.assert(fullRow.price.startsWith('AED'), 'formatted price: ' + fullRow.price);
        System.assert(fullRow.location.contains('Inv Test Project'), 'project in location');
        System.assert(fullRow.location.contains('Tower A'), 'building in location');
        System.assert(fullRow.specs.contains('2 Bed'), 'bedrooms in specs');
        System.assert(fullRow.specs.contains('2 Bath'), 'bathrooms in specs');
        System.assert(fullRow.specs.contains('sqft'), 'area in specs');

        System.assertNotEquals(null, studioRow, 'untitled unit present');
        System.assert(String.isNotBlank(studioRow.title), 'falls back to unit Name');
        System.assertEquals('', studioRow.price, 'no cost -> empty price');
        System.assert(studioRow.specs.contains('Studio'), '0 bedrooms -> Studio');
        System.assert(!studioRow.specs.contains('Bath'), 'no bathrooms in specs');
    }

    @isTest
    static void single_project_branch_filters() {
        Id projectId = setupPublishedInventory();
        loginBroker();
        BrokerInventoryController c = new BrokerInventoryController();

        c.selectedProjectId = projectId;
        System.assertEquals(2, c.getUnits().size(), 'filtered query returns the project units');
        System.assertEquals(true, c.getHasUnits());

        // A different (non-project) id runs the filtered branch and returns nothing
        c.selectedProjectId = UserInfo.getUserId();
        System.assertEquals(0, c.getUnits().size());
        System.assertEquals(false, c.getHasUnits());
    }

    // ---- Sales Offer (OAuth password flow -> token -> PDF endpoint) ----
    private static Id firstPublishedUnit() {
        return [SELECT Id FROM Unit__c WHERE Status__c = 'Published' LIMIT 1].Id;
    }

    private static void setConfig() {
        BrokerInventoryController.configOverride = new Sales_Offer_Auth__mdt(
            Client_Id__c = 'cid', Client_Secret__c = 'sec', Username__c = 'u@x.com', Password__c = 'pw',
            Token_Url__c = 'https://test.my.salesforce.com/services/oauth2/token'
        );
    }

    // Only the token POST is an Apex callout now (the PDF fetch happens browser-side).
    private class TokenMock implements HttpCalloutMock {
        Boolean ok;
        TokenMock(Boolean ok) { this.ok = ok; }
        public HttpResponse respond(HttpRequest req) {
            System.assert(req.getEndpoint().contains('/services/oauth2/token'), 'only the token endpoint is called from Apex');
            System.assertEquals('POST', req.getMethod(), 'token call is a POST');
            HttpResponse res = new HttpResponse();
            res.setStatusCode(ok ? 200 : 400);
            res.setBody(ok ? '{"access_token":"TKN","instance_url":"https://x.my.salesforce.com"}'
                           : '{"error":"invalid_grant"}');
            return res;
        }
    }

    @isTest
    static void prepare_offer_mints_token_and_url() {
        setupPublishedInventory();
        loginBroker();
        setConfig();
        Id unitId = firstPublishedUnit();
        BrokerInventoryController c = new BrokerInventoryController();
        c.offerUnitId = String.valueOf(unitId);

        Test.setMock(HttpCalloutMock.class, new TokenMock(true));
        Test.startTest();
        c.prepareOffer();                                   // no secondary currency
        c.offerCurrency = 'USD';
        c.prepareOffer();                                   // with secondary currency
        Test.stopTest();

        System.assertEquals('TKN', c.offerToken, 'token handed to the browser');
        System.assert(c.offerApiUrl.contains('/services/apexrest/generateSalesOfferPdf?unitId=' + unitId), c.offerApiUrl);
        System.assert(c.offerApiUrl.contains('&sCurrency=USD'), 'chosen currency appended: ' + c.offerApiUrl);
        System.assertEquals(null, c.offerError);
    }

    @isTest
    static void prepare_offer_token_failure_sets_error() {
        setupPublishedInventory();
        loginBroker();
        setConfig();
        BrokerInventoryController c = new BrokerInventoryController();
        c.offerUnitId = String.valueOf(firstPublishedUnit());

        Test.setMock(HttpCalloutMock.class, new TokenMock(false));
        Test.startTest();
        c.prepareOffer();
        Test.stopTest();

        System.assertEquals(null, c.offerToken, 'token failed -> none');
        System.assertNotEquals(null, c.offerError);
    }

    @isTest
    static void prepare_offer_not_configured_sets_error() {
        setupPublishedInventory();
        loginBroker();
        BrokerInventoryController.configOverride = new Sales_Offer_Auth__mdt(Token_Url__c = null);  // blank config
        BrokerInventoryController c = new BrokerInventoryController();
        c.offerUnitId = String.valueOf(firstPublishedUnit());
        c.prepareOffer();
        System.assertEquals(null, c.offerToken);
        System.assertNotEquals(null, c.offerError, 'unconfigured -> an error is shown');
    }

    @isTest
    static void prepare_offer_rejects_no_session_and_non_published() {
        Test.setCurrentPage(Page.BrokerInventory);
        BrokerInventoryController c = new BrokerInventoryController();
        c.offerUnitId = 'not-an-id';
        c.prepareOffer();
        System.assertEquals(null, c.offerToken, 'no session / bad id -> no token');
        System.assertNotEquals(null, c.offerError);

        setupPublishedInventory();
        loginBroker();
        BrokerInventoryController c2 = new BrokerInventoryController();
        c2.offerUnitId = UserInfo.getUserId();   // valid id, not a Published unit
        c2.prepareOffer();
        System.assertEquals(null, c2.offerToken, 'non-inventory unit -> rejected');
        System.assertNotEquals(null, c2.offerError);
    }
}