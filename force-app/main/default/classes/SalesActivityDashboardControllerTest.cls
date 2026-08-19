/**
 * Tests for SalesActivityDashboardController. Two agencies: one briefed today (covered),
 * one never touched (needs attention). Activities land in the current week/month so the
 * KPI and per-RM buckets are deterministic.
 */
@IsTest
private class SalesActivityDashboardControllerTest {

    @TestSetup
    static void setup() {
        Account briefed = new Account(Name = 'Dash Briefed Agency', Type = 'Agency',
            Status__c = 'Completed', Company_Email__c = 'dash.briefed@example.com');
        Account untouched = new Account(Name = 'Dash Untouched Agency', Type = 'Agency',
            Status__c = 'Completed', Company_Email__c = 'dash.untouched@example.com');
        insert new List<Account>{ briefed, untouched };

        Datetime today10 = Datetime.newInstance(Date.today(), Time.newInstance(10, 0, 0, 0));
        insert new List<Sales_Activity_Tracker__c>{
            new Sales_Activity_Tracker__c(
                Activity__c = 'Agency Briefing', Type__c = 'Inbound', Agency__c = briefed.Id,
                Description__c = 'Dashboard test briefing', Outcome__c = 'Strong Interest',
                Start_Date_Time__c = today10, End_Date_Time__c = today10.addMinutes(90),
                Number_of_Agents__c = 5,
                Other_Project_Discussed__c = 'Marina Launch 2027'
            ),
            new Sales_Activity_Tracker__c(
                Activity__c = 'Client Meeting', Type__c = 'Online', Agency__c = briefed.Id,
                Description__c = 'Dashboard test meeting', Outcome__c = 'Strong Interest',
                Start_Date_Time__c = today10.addHours(3), End_Date_Time__c = today10.addHours(4),
                Other_Project_Discussed__c = 'marina launch 2027'
            )
        };
    }

    @IsTest
    static void dashboardAggregatesActivitiesAndCoverage() {
        SalesActivityDashboardController.Dashboard d =
            SalesActivityDashboardController.getDashboard(null);

        System.assertEquals(2, d.kpis.weekCount, 'Both activities happened today');
        System.assertEquals(2, d.kpis.monthCount);
        System.assertEquals(1, d.kpis.activeRms, 'Single owner');
        System.assert(d.kpis.monthHours >= 2, '1.5h + 1h rounded');
        System.assert(d.kpis.agenciesTotal >= 2, 'Both test agencies counted');
        System.assert(d.kpis.agenciesCovered >= 1, 'Briefed agency is covered');

        // per-RM matrix
        System.assertEquals(1, d.rmRows.size());
        SalesActivityDashboardController.RmRow rm = d.rmRows[0];
        System.assertEquals(2, rm.monthCount);
        System.assertEquals(1, rm.briefings);
        System.assertEquals(1, rm.meetings);
        System.assertEquals(2.5, rm.hours);

        // the untouched agency is flagged, the briefed one is not
        Boolean untouchedFlagged = false;
        for (SalesActivityDashboardController.AgencyRow row : d.needsAttention) {
            System.assertNotEquals('Dash Briefed Agency', row.name,
                'An agency briefed today must not need attention');
            if (row.name == 'Dash Untouched Agency') {
                untouchedFlagged = true;
                System.assertEquals(null, row.lastActivity, 'Never visited');
            }
        }
        System.assert(untouchedFlagged, 'Never-visited agency appears in the attention list');

        // outcomes this month
        Boolean strongInterest = false;
        for (SalesActivityDashboardController.CountRow row : d.outcomes) {
            if (row.name == 'Strong Interest') {
                strongInterest = true;
                System.assertEquals(2, row.count);
            }
        }
        System.assert(strongInterest, 'Outcome bucket present');

        // unlisted projects group case-insensitively
        Boolean marinaFound = false;
        for (SalesActivityDashboardController.CountRow row : d.otherProjects) {
            if (row.name.equalsIgnoreCase('Marina Launch 2027')) {
                marinaFound = true;
                System.assertEquals(2, row.count, 'Casing variants counted together');
            }
        }
        System.assert(marinaFound, 'Unlisted project surfaced');
    }
}
