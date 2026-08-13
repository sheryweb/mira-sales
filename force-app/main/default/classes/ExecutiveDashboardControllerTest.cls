/**
 * Tests for ExecutiveDashboardController.
 *
 * Data model notes (same org automation as ProjectCollectionDashboardControllerTest):
 * units are inserted as Draft then updated to their target status; opportunities
 * are forced to stage 'New' on insert, so the real stage is set in a second
 * update, and the booking/sold datetimes (which drive Target_Year__c /
 * Quarter_Booked__c / the month groupings) are stamped in a third update so
 * stage automation cannot overwrite them.
 *
 * Years are relative to today so the suite doesn't age: "this year" is the
 * main cohort, "last year" holds one deal that SOLD this year — proving the
 * booking-year cohort semantics (it must appear only under last year's filter).
 */
@IsTest
private class ExecutiveDashboardControllerTest {

    private static final Integer THIS_YEAR = Date.today().year();
    private static final Integer LAST_YEAR = THIS_YEAR - 1;

    private static final List<String> MONTH_NAMES = new List<String>{
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
    };

    @TestSetup
    static void makeData() {
        Project__c project = new Project__c(
            Name = 'Exec Test Towers',
            Project_Currency__c = 'AED',
            Project_Status__c = 'Off-Plan',
            Coordinates_Latitude__c = 25.08,
            Coordinates_Longitude__c = 55.14,
            Handover__c = Date.newInstance(THIS_YEAR + 2, 6, 30)
        );
        insert project;

        // Nationality__c is a restricted picklist whose VALUES are flag emoji
        // (labels carry the country names; the controller selects toLabel()).
        Account russia = client('Exec Client Russia', '🇷🇺');
        Account uk = client('Exec Client UK', '🇬🇧');
        Account spain = client('Exec Client Spain', '🇪🇸');
        // Agent__c's lookup filter demands an Agency-record-type account;
        // the agency trigger demands a (unique) Company_Email__c
        Account agency = new Account(
            Name = 'Exec Test Agency LLC',
            RecordTypeId = Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName().get('Agency').getRecordTypeId(),
            Company_Email__c = 'exec.test.agency.' + Crypto.getRandomInteger() + '@example.invalid',
            Status__c = 'Completed' // Agency__c lookup filter requires a Completed agency
        );
        insert new List<Account>{ russia, uk, spain, agency };
        // Assisted deals require BOTH Agency__c and Agent__c (validation rule)
        Contact agent = new Contact(LastName = 'Exec Test Agent', AccountId = agency.Id);
        insert agent;

        // A Sold 10M / B Sold 6M (assisted) / C Reserved 4M / D Booked 3M /
        // E Sold 5M resell / F Sold 8M booked LAST year
        List<Decimal> costs = new List<Decimal>{ 10000000, 6000000, 4000000, 3000000, 5000000, 8000000 };
        List<String> statuses = new List<String>{ 'Sold', 'Sold', 'Reserved', 'Booked', 'Sold', 'Sold' };
        List<Unit__c> units = new List<Unit__c>();
        for (Decimal cost : costs) {
            units.add(new Unit__c(Project__c = project.Id, Status__c = 'Draft',
                Cost_AED__c = cost, Total_Received_Amount__c = 0));
        }
        insert units;
        for (Integer i = 0; i < units.size(); i++) {
            units[i].Status__c = statuses[i];
        }
        update units;

        List<Opportunity> deals = new List<Opportunity>();
        for (Integer i = 0; i < units.size(); i++) {
            deals.add(new Opportunity(
                Name = 'Exec Deal ' + i,
                StageName = statuses[i],
                CloseDate = Date.today(),
                Unit__c = units[i].Id
            ));
        }
        insert deals; // automation forces stage 'New'
        for (Integer i = 0; i < deals.size(); i++) {
            deals[i].StageName = statuses[i];
        }
        update deals; // forward stage transitions

        deals[0].Booking_Date_Time__c = dt(THIS_YEAR, 2, 10);
        deals[0].Sold_Date_Time__c = dt(THIS_YEAR, 3, 5);
        deals[0].AccountId = russia.Id;

        deals[1].Booking_Date_Time__c = dt(THIS_YEAR, 5, 20);
        deals[1].Sold_Date_Time__c = dt(THIS_YEAR, 6, 15);
        deals[1].AccountId = uk.Id;
        deals[1].Agency__c = agency.Id;
        deals[1].Agent__c = agent.Id;
        deals[1].Assisted_by_Agent__c = true;

        deals[2].Booking_Date_Time__c = dt(THIS_YEAR, 4, 1);

        deals[3].Booking_Date_Time__c = dt(THIS_YEAR, 7, 7);

        deals[4].Booking_Date_Time__c = dt(THIS_YEAR, 1, 15);
        deals[4].Sold_Date_Time__c = dt(THIS_YEAR, 2, 20);
        deals[4].AccountId = spain.Id;
        deals[4].Is_it_a_Resell__c = true;

        deals[5].Booking_Date_Time__c = dt(LAST_YEAR, 11, 30);
        deals[5].Sold_Date_Time__c = dt(THIS_YEAR, 1, 10);

        update deals; // dates after stage automation so they stick
    }

    @IsTest
    static void thisYearCohortAggregates() {
        Test.startTest();
        ExecutiveDashboardController.DashboardData data =
            ExecutiveDashboardController.getDashboardData(String.valueOf(THIS_YEAR));
        Test.stopTest();

        System.assertEquals(new List<String>{ String.valueOf(THIS_YEAR), String.valueOf(LAST_YEAR) },
            data.yearOptions, 'Years newest first');

        // Gauge: Sold non-resell booked this year = A 10M + B 6M
        System.assertEquals(16000000, data.soldValue);
        // Big numbers: B/R/S non-resell count; R/S non-resell value
        System.assertEquals(4, data.totalUnits, 'A, B, C, D (E resell, F last year)');
        System.assertEquals(20000000, data.totalValue, 'A + B + C');

        // Pipeline fixed order with zero-safe rows
        System.assertEquals('Booked', data.pipeline[0].name);
        System.assertEquals(1, data.pipeline[0].units);
        System.assertEquals(3000000, data.pipeline[0].value);
        System.assertEquals(4000000, data.pipeline[1].value);
        System.assertEquals(16000000, data.pipeline[2].value);
        System.assertEquals(2, data.pipeline[2].units);
    }

    @IsTest
    static void chartGroupingsAreChronological() {
        ExecutiveDashboardController.DashboardData data =
            ExecutiveDashboardController.getDashboardData(String.valueOf(THIS_YEAR));

        System.assertEquals(2, data.monthlySold.size());
        System.assertEquals(MONTH_NAMES[2] + ' ' + THIS_YEAR, data.monthlySold[0].name, 'A sold in March');
        System.assertEquals(10000000, data.monthlySold[0].value);
        System.assertEquals(MONTH_NAMES[5] + ' ' + THIS_YEAR, data.monthlySold[1].name, 'B sold in June');

        // Monthly Booked covers all B/R/S non-resell: Feb A, Apr C, May B, Jul D
        System.assertEquals(4, data.monthlyBooked.size());
        System.assertEquals(MONTH_NAMES[1] + ' ' + THIS_YEAR, data.monthlyBooked[0].name);
        System.assertEquals(MONTH_NAMES[6] + ' ' + THIS_YEAR, data.monthlyBooked[3].name);

        // Quarterly = booking quarter of sold deals: A Q1, B Q2
        System.assertEquals(2, data.quarterlySold.size());
        System.assertEquals('Q1 ' + THIS_YEAR, data.quarterlySold[0].name);
        System.assertEquals(10000000, data.quarterlySold[0].value);
        System.assertEquals('Q2 ' + THIS_YEAR, data.quarterlySold[1].name);

        System.assertEquals(1, data.projectSold.size());
        System.assertEquals(16000000, data.projectSold[0].value);
        System.assertEquals(2, data.projectSold[0].units);
    }

    @IsTest
    static void breakdownAndNationalitiesIncludeResells() {
        ExecutiveDashboardController.DashboardData data =
            ExecutiveDashboardController.getDashboardData(String.valueOf(THIS_YEAR));

        // Breakdown mimics the standard report: resell E counts, last-year F doesn't
        System.assertEquals(1, data.projectBreakdown.size());
        ExecutiveDashboardController.BreakdownGroup grp = data.projectBreakdown[0];
        System.assertEquals('Exec Test Towers', grp.projectName);
        System.assertEquals(28000000, grp.subtotal, 'Booked 3M + Reserved 4M + Sold 21M (A+B+E)');
        System.assertEquals(5, grp.units);
        System.assertEquals(3, grp.rows.size());
        System.assertEquals(21000000, grp.rows[2].value, 'Sold row includes the resell');

        // Nationalities: Sold incl. resells, desc by value
        System.assertEquals(3, data.topNationalities.size());
        System.assertEquals('Russia', data.topNationalities[0].name);
        System.assertEquals(10000000, data.topNationalities[0].value);
        System.assertEquals('United Kingdom', data.topNationalities[1].name);
        System.assertEquals('Spain', data.topNationalities[2].name, 'Resell still counts here');
    }

    @IsTest
    static void teamTablesApplyStandardReportFilters() {
        ExecutiveDashboardController.DashboardData data =
            ExecutiveDashboardController.getDashboardData(String.valueOf(THIS_YEAR));

        // Agencies: only assisted deals with an agency
        System.assertEquals(1, data.topAgencies.size());
        System.assertEquals('Exec Test Agency LLC', data.topAgencies[0].name);
        System.assertEquals(6000000, data.topAgencies[0].value);

        // Sales team: both sold deals belong to the running user
        System.assertEquals(1, data.salesTeam.size());
        System.assertEquals(16000000, data.salesTeam[0].value);
        System.assertEquals(2, data.salesTeam[0].units);

        // Managers table must never show the 'Not Assigned' bucket
        for (ExecutiveDashboardController.GroupRow row : data.managers) {
            System.assertNotEquals('Not Assigned', row.name);
        }
    }

    @IsTest
    static void lastYearCohortOwnsDealsSoldThisYear() {
        ExecutiveDashboardController.DashboardData data =
            ExecutiveDashboardController.getDashboardData(String.valueOf(LAST_YEAR));

        System.assertEquals(8000000, data.soldValue, 'F booked last year, sold this year');
        System.assertEquals(1, data.totalUnits);
        System.assertEquals(1, data.monthlySold.size());
        System.assertEquals(MONTH_NAMES[0] + ' ' + THIS_YEAR, data.monthlySold[0].name,
            'Sold-month label is this year even though the cohort is last year');
        System.assertEquals('Q4 ' + LAST_YEAR, data.quarterlySold[0].name);
    }

    @IsTest
    static void blankYearDefaultsToCurrentYear() {
        ExecutiveDashboardController.DashboardData data =
            ExecutiveDashboardController.getDashboardData(null);
        System.assertEquals(String.valueOf(THIS_YEAR), data.selectedYear);
    }

    // ---------- helpers ----------

    private static Account client(String name, String nationality) {
        return new Account(Name = name, Nationality__c = nationality);
    }

    private static Datetime dt(Integer year, Integer month, Integer day) {
        return Datetime.newInstance(year, month, day, 12, 0, 0);
    }
}
