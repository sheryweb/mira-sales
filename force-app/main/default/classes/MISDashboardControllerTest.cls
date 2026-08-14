/**
 * Tests for MISDashboardController.
 *
 * Data model notes (same org automation as ExecutiveDashboardControllerTest):
 * units are inserted as Draft then updated to their target status; opportunities
 * are forced to stage 'New' on insert, so the real stage is set in a second
 * update, and ALL THREE window datetimes are stamped explicitly in a third
 * update (nulling the ones a deal shouldn't have) so stage automation cannot
 * leak dates into windows a deal doesn't belong to.
 *
 * Dates are relative to today so the suite doesn't age, with boundary guards:
 * "this month, not today" picks day 1 unless today IS the 1st (then day 2),
 * and "this year, not this month" picks January unless it's January (then
 * February) — both stay inside the right calendar windows either way.
 *
 * The deals (all in one project, AED):
 *  A 10M Sold     booked today, sold today, agency-assisted
 *  B  3M Booked   booked today
 *  C  4M Reserved booked this month (not today), reserved today
 *  D  6M Sold     booked + sold this year (not this month)
 *  E  8M Sold     booked LAST year, sold this year (not this month)
 *  F  5M Booked   booked NEXT year (future) — Managers-YTD >= quirk
 *  G  7M Sold     booked + sold today, RESELL — excluded everywhere
 */
@IsTest
private class MISDashboardControllerTest {

    private static final Date TODAY = Date.today();
    private static final Integer THIS_YEAR = TODAY.year();

    @TestSetup
    static void makeData() {
        Project__c project = new Project__c(
            Name = 'MIS Test Towers',
            Project_Currency__c = 'AED',
            Project_Status__c = 'Off-Plan',
            Coordinates_Latitude__c = 25.08,
            Coordinates_Longitude__c = 55.14,
            Handover__c = Date.newInstance(THIS_YEAR + 2, 6, 30)
        );
        insert project;

        // Agent__c's lookup filter demands a Completed Agency-record-type
        // account; the agency trigger demands a unique Company_Email__c
        Account agency = new Account(
            Name = 'MIS Test Agency LLC',
            RecordTypeId = Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName().get('Agency').getRecordTypeId(),
            Company_Email__c = 'mis.test.agency.' + Crypto.getRandomInteger() + '@example.invalid',
            Status__c = 'Completed'
        );
        insert agency;
        Contact agent = new Contact(LastName = 'MIS Test Agent', AccountId = agency.Id);
        insert agent;

        List<Decimal> costs = new List<Decimal>{ 10000000, 3000000, 4000000, 6000000, 8000000, 5000000, 7000000 };
        List<String> statuses = new List<String>{ 'Sold', 'Booked', 'Reserved', 'Sold', 'Sold', 'Booked', 'Sold' };
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
                Name = 'MIS Deal ' + i,
                StageName = statuses[i],
                CloseDate = TODAY,
                Unit__c = units[i].Id
            ));
        }
        insert deals; // automation forces stage 'New'
        for (Integer i = 0; i < deals.size(); i++) {
            deals[i].StageName = statuses[i];
        }
        update deals; // forward stage transitions

        // boundary-safe "same window, different day" picks
        Datetime todayNoon = dt(TODAY);
        Datetime monthNotToday = dt(Date.newInstance(THIS_YEAR, TODAY.month(), TODAY.day() == 1 ? 2 : 1));
        Integer otherMonth = TODAY.month() == 1 ? 2 : 1;
        Datetime yearNotMonth = dt(Date.newInstance(THIS_YEAR, otherMonth, 15));
        Datetime yearNotMonthLater = dt(Date.newInstance(THIS_YEAR, otherMonth, 20));

        // A: booked + sold today, assisted
        deals[0].Booking_Date_Time__c = todayNoon;
        deals[0].Reserved_Date_Time__c = null;
        deals[0].Sold_Date_Time__c = todayNoon;
        deals[0].Agency__c = agency.Id;
        deals[0].Agent__c = agent.Id;
        deals[0].Assisted_by_Agent__c = true;

        // B: booked today
        deals[1].Booking_Date_Time__c = todayNoon;
        deals[1].Reserved_Date_Time__c = null;
        deals[1].Sold_Date_Time__c = null;

        // C: booked this month (not today), reserved today
        deals[2].Booking_Date_Time__c = monthNotToday;
        deals[2].Reserved_Date_Time__c = todayNoon;
        deals[2].Sold_Date_Time__c = null;

        // D: booked + sold this year, outside this month
        deals[3].Booking_Date_Time__c = yearNotMonth;
        deals[3].Reserved_Date_Time__c = null;
        deals[3].Sold_Date_Time__c = yearNotMonthLater;

        // E: booked last year, sold this year outside this month
        deals[4].Booking_Date_Time__c = dt(Date.newInstance(THIS_YEAR - 1, 11, 30));
        deals[4].Reserved_Date_Time__c = null;
        deals[4].Sold_Date_Time__c = yearNotMonth;

        // F: booked NEXT year (future booking)
        deals[5].Booking_Date_Time__c = dt(Date.newInstance(THIS_YEAR + 1, 1, 15));
        deals[5].Reserved_Date_Time__c = null;
        deals[5].Sold_Date_Time__c = null;

        // G: resell booked + sold today — must not appear anywhere
        deals[6].Booking_Date_Time__c = todayNoon;
        deals[6].Reserved_Date_Time__c = null;
        deals[6].Sold_Date_Time__c = todayNoon;
        deals[6].Is_it_a_Resell__c = true;

        update deals; // dates after stage automation so they stick
    }

    @IsTest
    static void todayTables() {
        Test.startTest();
        MISDashboardController.DashboardData data = MISDashboardController.getDashboardData();
        Test.stopTest();

        System.assertEquals(1, data.todayBooked.size());
        System.assertEquals(3000000, data.todayBooked[0].value, 'B only (stage Booked, booked today)');

        System.assertEquals(1, data.todayReserved.size());
        System.assertEquals(4000000, data.todayReserved[0].value, 'C reserved today');

        System.assertEquals(1, data.todaySold.size());
        System.assertEquals(10000000, data.todaySold[0].value, 'A sold today; resell G excluded');

        // Booking-date-only quirk: C (booked earlier, reserved today) is absent
        System.assertEquals(2, data.todayAgentDirect.size());
        System.assertEquals('Agent', data.todayAgentDirect[0].name);
        System.assertEquals(10000000, data.todayAgentDirect[0].value);
        System.assertEquals('Direct', data.todayAgentDirect[1].name);
        System.assertEquals(3000000, data.todayAgentDirect[1].value, 'B only — C booked before today');
    }

    @IsTest
    static void monthToDateTables() {
        MISDashboardController.DashboardData data = MISDashboardController.getDashboardData();

        System.assertEquals(17000000, totalValue(data.mtdBooked), 'A + B + C booked this month');
        System.assertEquals(3, totalUnits(data.mtdBooked));

        System.assertEquals(4000000, totalValue(data.mtdReserved), 'C only');
        System.assertEquals(10000000, totalValue(data.mtdSold), 'A only');

        System.assertEquals(17000000, totalValue(data.mtdAllStatus), 'any activity this month: A, B, C');
        System.assertEquals(3, totalUnits(data.mtdAllStatus));

        System.assertEquals(1, data.mtdTopAgencies.size());
        System.assertEquals('MIS Test Agency LLC', data.mtdTopAgencies[0].name);
        System.assertEquals(10000000, data.mtdTopAgencies[0].value);

        System.assertEquals(2, data.mtdAgentDirect.size());
        System.assertEquals(10000000, data.mtdAgentDirect[0].value, 'Agent = A');
        System.assertEquals(7000000, data.mtdAgentDirect[1].value, 'Direct = B + C');

        // manager names come from the running user's role; assert the sums
        System.assertEquals(17000000, totalValue(data.mtdManagers));
        for (MISDashboardController.GroupRow row : data.mtdManagers) {
            System.assertNotEquals('Management', row.name);
        }
        System.assertEquals(0, data.mtdManagementSale.size(),
            'Manager_Name__c formula never yields Management (mimics original)');
    }

    @IsTest
    static void yearToDateTables() {
        MISDashboardController.DashboardData data = MISDashboardController.getDashboardData();

        System.assertEquals(4000000, totalValue(data.ytdReserved), 'C only');

        System.assertEquals(24000000, totalValue(data.ytdSold), 'A + D + E sold this year');
        System.assertEquals(3, totalUnits(data.ytdSold));

        System.assertEquals(23000000, totalValue(data.ytdCombined),
            'A+B+C+D booked this year; E booked last year, F booked next year');
        System.assertEquals(4, totalUnits(data.ytdCombined));

        System.assertEquals(1, data.ytdTeam.size(), 'single owner (running user)');
        System.assertEquals(23000000, data.ytdTeam[0].value, 'same booking-year window as combined');

        System.assertEquals(1, data.ytdTopAgencies.size());
        System.assertEquals(10000000, data.ytdTopAgencies[0].value, 'A only');

        System.assertEquals(10000000, data.ytdAgentDirect[0].value, 'Agent = A');
        System.assertEquals(13000000, data.ytdAgentDirect[1].value, 'Direct = B + C + D');
    }

    @IsTest
    static void managersYtdIncludesFutureBookingsQuirk() {
        MISDashboardController.DashboardData data = MISDashboardController.getDashboardData();

        System.assertEquals(28000000, totalValue(data.ytdManagers),
            'A+B+C+D (23M) plus future-booked F (5M) via the >= this-year quirk');
        System.assertEquals(5, totalUnits(data.ytdManagers));
        System.assertEquals(0, data.ytdManagementSale.size());
    }

    // ---------- helpers ----------

    private static Decimal totalValue(List<MISDashboardController.GroupRow> rows) {
        Decimal total = 0;
        for (MISDashboardController.GroupRow row : rows) {
            total += row.value;
        }
        return total;
    }

    private static Integer totalUnits(List<MISDashboardController.GroupRow> rows) {
        Integer total = 0;
        for (MISDashboardController.GroupRow row : rows) {
            total += row.units;
        }
        return total;
    }

    private static Datetime dt(Date day) {
        return Datetime.newInstance(day.year(), day.month(), day.day(), 12, 0, 0);
    }
}
