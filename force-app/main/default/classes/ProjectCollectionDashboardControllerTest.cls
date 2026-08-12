/**
 * Tests for ProjectCollectionDashboardController.
 *
 * The controller reads project-level figures from the Project__c value fields
 * (populated by the realtime DLRS rollups when units change) and stage-scoped
 * figures from Opportunity formula fields, so the test data builds the full
 * chain: units are inserted as Draft (validation rule), updated to their target
 * status with received amounts, then a deal (Opportunity) is created per
 * Booked/Reserved/Sold unit with a matching stage.
 * Currency landscape: one blank-currency project (must count as AED), one AED,
 * one CHF, one USD.
 */
@IsTest
private class ProjectCollectionDashboardControllerTest {

    @TestSetup
    static void makeData() {
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

        // Blank-currency project (AED bucket): 2,000,000 total; Sold 1,200,000 / rec 400,000
        units.add(aedUnit(blankCur.Id, 1200000)); statuses.add('Sold');      received.add(400000);
        units.add(aedUnit(blankCur.Id, 800000));  statuses.add('Published'); received.add(0);

        // AED project: 6,000,000 total; B/R/S 4,500,000; R/S 3,000,000
        units.add(aedUnit(aed.Id, 2000000)); statuses.add('Sold');      received.add(1000000);
        units.add(aedUnit(aed.Id, 1000000)); statuses.add('Reserved');  received.add(200000);
        units.add(aedUnit(aed.Id, 1500000)); statuses.add('Booked');    received.add(150000);
        units.add(aedUnit(aed.Id, 1500000)); statuses.add('Draft');     received.add(0);

        // CHF project: 3,500,000 total; R/S 3,500,000
        units.add(chfUnit(chf.Id, 2000000)); statuses.add('Sold');     received.add(1200000);
        units.add(chfUnit(chf.Id, 1500000)); statuses.add('Reserved'); received.add(300000);

        // USD project: 1,500,000 total; R/S 900,000
        units.add(usdUnit(usd.Id, 900000)); statuses.add('Sold');      received.add(500000);
        units.add(usdUnit(usd.Id, 600000)); statuses.add('Published'); received.add(0);

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
    static void blankCurrencyDefaultsToAedAndIncludesBlankProjects() {
        Test.startTest();
        ProjectCollectionDashboardController.DashboardData data =
            ProjectCollectionDashboardController.getDashboardData(null);
        Test.stopTest();

        System.assertEquals('AED', data.currencyIso, 'Blank input must default to AED');
        // 3 AED-bucket projects: blank-currency, AED, and the empty AED project
        System.assertEquals(3, data.projects.size(), 'AED view must include blank-currency and empty projects');

        // Project_Total_Value__c sums: 2,000,000 (blank) + 6,000,000 (AED) + 0 (empty)
        System.assertEquals(8000000, data.totalValue);
        // Project_Received_Value__c excludes Draft/Published units: 400k + (1,000k + 200k + 150k)
        System.assertEquals(1750000, data.totalReceived);
        System.assertEquals(8000000 - 1750000, data.totalRemaining);

        // Reserved+Sold deals: blank Sold 1.2M + AED (2M Sold + 1M Reserved)
        System.assertEquals(4200000, data.soldValue);
        System.assertEquals(400000 + 1000000 + 200000, data.soldReceived);
        System.assertEquals(data.soldValue - data.soldReceived, data.soldRemaining);

        // Rows sorted by name; empty project shows zeros
        System.assertEquals('AED Empty Project', data.projects[0].projectName);
        System.assertEquals(0, data.projects[0].totalValue);
        System.assertEquals(0, data.projects[0].brsValue);

        // Blank-currency project row: BRS = the Sold deal only
        ProjectCollectionDashboardController.ProjectRow blankRow = rowByName(data, 'Blank Currency Towers');
        System.assertEquals(2000000, blankRow.totalValue);
        System.assertEquals(1200000, blankRow.brsValue);
        System.assertEquals(400000, blankRow.brsReceived);
        System.assertEquals(800000, blankRow.brsRemaining);
    }

    @IsTest
    static void chfReadsNativeChfValues() {
        ProjectCollectionDashboardController.DashboardData data =
            ProjectCollectionDashboardController.getDashboardData('CHF');

        System.assertEquals('CHF', data.currencyIso);
        System.assertEquals(1, data.projects.size(), 'Only the CHF project must be included');
        System.assertEquals(3500000, data.totalValue, 'Project_Total_Value__c must read the CHF rollup');
        System.assertEquals(1500000, data.totalReceived);
        System.assertEquals(3500000, data.soldValue, 'Both CHF deals are Reserved/Sold and must read Unit_Price__c in CHF');
        System.assertEquals(1500000, data.soldReceived);
    }

    @IsTest
    static void usdLowercaseInputIsNormalized() {
        ProjectCollectionDashboardController.DashboardData data =
            ProjectCollectionDashboardController.getDashboardData('usd');

        System.assertEquals('USD', data.currencyIso);
        System.assertEquals(1, data.projects.size());
        System.assertEquals(1500000, data.totalValue, 'Project_Total_Value__c must read the USD rollup');
        System.assertEquals(900000, data.soldValue, 'Published unit has no deal and must not count');
        System.assertEquals(500000, data.soldReceived);
        System.assertEquals(400000, data.soldRemaining);
    }

    @IsTest
    static void unsupportedCurrencyThrows() {
        try {
            ProjectCollectionDashboardController.getDashboardData('GBP');
            System.assert(false, 'Expected AuraHandledException for unsupported currency');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Unsupported currency'), 'Got: ' + e.getMessage());
        }
    }

    @IsTest
    static void availableCurrenciesAedFirstSupportedOnly() {
        List<String> currencies = ProjectCollectionDashboardController.getAvailableCurrencies();
        System.assertEquals(new List<String>{ 'AED', 'CHF', 'USD' }, currencies,
            'AED first (covers blank), then supported currencies alphabetically');
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

    private static Unit__c chfUnit(Id projectId, Decimal cost) {
        return new Unit__c(Project__c = projectId, Status__c = 'Draft', Cost_CHF_Number__c = cost, Cost_CHF__c = cost, Total_Received_Amount__c = 0);
    }

    private static Unit__c usdUnit(Id projectId, Decimal cost) {
        return new Unit__c(Project__c = projectId, Status__c = 'Draft', Cost_USD_Number__c = cost, Cost_USD__c = cost, Total_Received_Amount__c = 0);
    }
}
