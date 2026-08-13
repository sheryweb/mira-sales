/**
 * Tests for ProjectCollectionDashboardController (AED-only reporting).
 *
 * Value fields are AED at the source (Cost_AED__c is populated for every unit
 * regardless of project currency, mirroring the real business data), so the
 * test units always carry Cost_AED__c. Received amounts stay in the project
 * currency and the controller converts them through CurrencyService; the setup
 * seeds Currency_Exchange_Rate__c with round rates (CHF 0.2/AED = x5,
 * USD 0.25/AED = x4) so every expectation is deterministic.
 * Units are inserted as Draft (validation rule), updated to their target
 * status with received amounts, then a deal (Opportunity) is created per
 * Booked/Reserved/Sold unit with a matching stage.
 */
@IsTest
private class ProjectCollectionDashboardControllerTest {

    @TestSetup
    static void makeData() {
        // Deterministic market rates for CurrencyService: CHF x5, USD x4 to AED.
        insert new List<Currency_Exchange_Rate__c>{
            new Currency_Exchange_Rate__c(
                Name = 'CHF', Rate_Per_AED__c = 0.2,
                Last_Refreshed__c = Datetime.now(), Source__c = 'test'),
            new Currency_Exchange_Rate__c(
                Name = 'USD', Rate_Per_AED__c = 0.25,
                Last_Refreshed__c = Datetime.now(), Source__c = 'test')
        };

        Project__c blankCur = newProject('Blank Currency Towers', null);
        Project__c aed = newProject('AED Marina Heights', 'AED');
        Project__c chf = newProject('CHF Alpine Residences', 'CHF');
        Project__c usd = newProject('USD Bay Tower', 'USD');
        // Project with no units: must still appear as a zero row.
        Project__c emptyAed = newProject('AED Empty Project', 'AED');
        insert new List<Project__c>{ blankCur, aed, chf, usd, emptyAed };

        List<Unit__c> units = new List<Unit__c>();
        List<String> statuses = new List<String>();
        List<Decimal> received = new List<Decimal>();

        // Blank-currency project (counts as AED): 2,000,000 AED value
        units.add(aedUnit(blankCur.Id, 1200000)); statuses.add('Sold');      received.add(400000);
        units.add(aedUnit(blankCur.Id, 800000));  statuses.add('Published'); received.add(0);

        // AED project: 6,000,000 AED value; B/R/S 4,500,000; R/S 3,000,000
        units.add(aedUnit(aed.Id, 2000000)); statuses.add('Sold');      received.add(1000000);
        units.add(aedUnit(aed.Id, 1000000)); statuses.add('Reserved');  received.add(200000);
        units.add(aedUnit(aed.Id, 1500000)); statuses.add('Booked');    received.add(150000);
        units.add(aedUnit(aed.Id, 1500000)); statuses.add('Draft');     received.add(0);

        // CHF project: AED values 9,000,000 + 6,750,000; received in CHF
        units.add(chfUnit(chf.Id, 2000000, 9000000)); statuses.add('Sold');     received.add(1200000);
        units.add(chfUnit(chf.Id, 1500000, 6750000)); statuses.add('Reserved'); received.add(300000);

        // USD project: AED values 3,300,000 + 2,200,000; received in USD
        units.add(usdUnit(usd.Id, 900000, 3300000)); statuses.add('Sold');      received.add(500000);
        units.add(usdUnit(usd.Id, 600000, 2200000)); statuses.add('Published'); received.add(0);

        insert units; // all Draft (validation rule: new units must start as Draft)

        for (Integer i = 0; i < units.size(); i++) {
            units[i].Status__c = statuses[i];
            units[i].Total_Received_Amount__c = received[i];
        }
        update units; // realtime DLRS rollups stamp the Project__c value fields here

        // One deal per Booked/Reserved/Sold unit, stage matching the unit status.
        // Org automation forces new Opportunities to stage 'New', so the target
        // stage has to be set in a second DML (forward transitions are allowed).
        List<Opportunity> deals = new List<Opportunity>();
        List<String> dealStages = new List<String>();
        for (Integer i = 0; i < units.size(); i++) {
            if (statuses[i] == 'Booked' || statuses[i] == 'Reserved' || statuses[i] == 'Sold') {
                deals.add(new Opportunity(
                    Name = 'Test Deal ' + i,
                    StageName = statuses[i],
                    CloseDate = Date.today(),
                    Unit__c = units[i].Id
                ));
                dealStages.add(statuses[i]);
            }
        }
        insert deals;
        for (Integer i = 0; i < deals.size(); i++) {
            deals[i].StageName = dealStages[i];
        }
        update deals;
    }

    @IsTest
    static void aggregatesAllProjectsInAed() {
        Test.startTest();
        ProjectCollectionDashboardController.DashboardData data =
            ProjectCollectionDashboardController.getDashboardData();
        Test.stopTest();

        System.assertEquals(5, data.projects.size(), 'Every project must appear, including the empty one');

        // Project_Value__c (Sum of Cost_AED__c, all statuses):
        // 2,000,000 + 6,000,000 + 15,750,000 + 5,500,000 + 0
        System.assertEquals(29250000, data.totalValue);

        // Received: AED bucket 400k + 1.35M as-is; CHF 1.5M x5; USD 500k x4
        Decimal expectedReceived = 400000 + 1350000 + 7500000 + 2000000;
        System.assertEquals(expectedReceived, data.totalReceived);
        System.assertEquals(data.totalValue - expectedReceived, data.totalRemaining);
        System.assertNotEquals(null, data.ratesAsOf, 'Market-rate stamp must surface to the UI');

        // Rows sorted by name; empty project shows zeros
        System.assertEquals('AED Empty Project', data.projects[0].projectName);
        System.assertEquals(0, data.projects[0].totalValue);
        System.assertEquals(0, data.projects[0].brsValue);
    }

    @IsTest
    static void chfReceivedConvertsAtMarketRate() {
        ProjectCollectionDashboardController.DashboardData data =
            ProjectCollectionDashboardController.getDashboardData();

        ProjectCollectionDashboardController.ProjectRow row = rowByName(data, 'CHF Alpine Residences');
        System.assertEquals(15750000, row.totalValue, 'Value must read the AED rollup, no conversion');
        System.assertEquals(7500000, row.totalReceived, 'CHF 1.5M received must convert at 0.2/AED (x5)');
        System.assertEquals(row.totalValue - row.totalReceived, row.totalRemaining);

        // Both CHF deals are Reserved/Sold: deal values from Unit_Price_Dashboard__c (AED)
        System.assertEquals(15750000, row.brsValue);
        System.assertEquals(7500000, row.brsReceived);
    }

    @IsTest
    static void usdReceivedConvertsAtMarketRate() {
        ProjectCollectionDashboardController.DashboardData data =
            ProjectCollectionDashboardController.getDashboardData();

        ProjectCollectionDashboardController.ProjectRow row = rowByName(data, 'USD Bay Tower');
        System.assertEquals(5500000, row.totalValue, 'Value must read the AED rollup, no conversion');
        System.assertEquals(2000000, row.totalReceived, 'USD 500k received must convert at 0.25/AED (x4)');

        // Only the Sold unit has a deal; Published one must not count
        System.assertEquals(3300000, row.brsValue);
        System.assertEquals(2000000, row.brsReceived);
    }

    @IsTest
    static void soldTilesScopeToReservedAndSold() {
        ProjectCollectionDashboardController.DashboardData data =
            ProjectCollectionDashboardController.getDashboardData();

        // Reserved+Sold deal values (AED): blank 1.2M + AED (2M + 1M) + CHF (9M + 6.75M) + USD 3.3M
        System.assertEquals(1200000 + 3000000 + 15750000 + 3300000, data.soldValue,
            'Booked deals must be excluded from the Sold tiles');
        // Received: blank 400k + AED Sold/Reserved 1.2M + CHF 1.5M x5 + USD 500k x4
        Decimal expectedReceived = 400000 + 1200000 + 7500000 + 2000000;
        System.assertEquals(expectedReceived, data.soldReceived);
        System.assertEquals(data.soldValue - data.soldReceived, data.soldRemaining);
    }

    // ---------- helpers ----------

    private static ProjectCollectionDashboardController.ProjectRow rowByName(
        ProjectCollectionDashboardController.DashboardData data, String name
    ) {
        for (ProjectCollectionDashboardController.ProjectRow row : data.projects) {
            if (row.projectName == name) {
                return row;
            }
        }
        System.assert(false, 'Project row not found: ' + name);
        return null;
    }

    private static Project__c newProject(String name, String currencyIso) {
        return new Project__c(
            Name = name,
            Project_Currency__c = currencyIso,
            Project_Status__c = 'Off-Plan',
            Coordinates_Latitude__c = 25.08,
            Coordinates_Longitude__c = 55.14,
            Handover__c = Date.newInstance(2028, 6, 30)
        );
    }

    private static Unit__c aedUnit(Id projectId, Decimal cost) {
        return new Unit__c(Project__c = projectId, Status__c = 'Draft', Cost_AED__c = cost, Total_Received_Amount__c = 0);
    }

    private static Unit__c chfUnit(Id projectId, Decimal costChf, Decimal costAed) {
        return new Unit__c(
            Project__c = projectId, Status__c = 'Draft',
            Cost_CHF_Number__c = costChf, Cost_CHF__c = costChf, Cost_AED__c = costAed,
            Total_Received_Amount__c = 0
        );
    }

    private static Unit__c usdUnit(Id projectId, Decimal costUsd, Decimal costAed) {
        return new Unit__c(
            Project__c = projectId, Status__c = 'Draft',
            Cost_USD_Number__c = costUsd, Cost_USD__c = costUsd, Cost_AED__c = costAed,
            Total_Received_Amount__c = 0
        );
    }
}
