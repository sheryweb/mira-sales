/**
 * Tests for SalesActivityDashboardController. Two agencies: one briefed today (covered),
 * one never touched (needs attention). Activities land in the current week/month so the
 * KPI and per-RM buckets are deterministic. The dashboard is tabbed (2026-08-21): every
 * section exists once per activity type, plus all-time totals of both types.
 */
@IsTest
private class SalesActivityDashboardControllerTest {
  @TestSetup
  static void setup() {
    Account briefed = new Account(
      Name = 'Dash Briefed Agency',
      Type = 'Agency',
      Status__c = 'Completed',
      Company_Email__c = 'dash.briefed@example.com'
    );
    Account untouched = new Account(
      Name = 'Dash Untouched Agency',
      Type = 'Agency',
      Status__c = 'Completed',
      Company_Email__c = 'dash.untouched@example.com'
    );
    insert new List<Account>{ briefed, untouched };

    Datetime today10 = Datetime.newInstance(
      Date.today(),
      Time.newInstance(10, 0, 0, 0)
    );
    insert new List<Sales_Activity_Tracker__c>{
      new Sales_Activity_Tracker__c(
        Activity__c = 'Agency Briefing',
        Type__c = 'Inbound',
        Agency__c = briefed.Id,
        Description__c = 'Dashboard test briefing',
        Outcome__c = 'Strong Interest',
        Start_Date_Time__c = today10,
        End_Date_Time__c = today10.addMinutes(90),
        Number_of_Agents__c = 5,
        Other_Project_Discussed__c = 'Marina Launch 2027'
      ),
      new Sales_Activity_Tracker__c(
        Activity__c = 'Client Meeting',
        Type__c = 'Online',
        Agency__c = briefed.Id,
        Description__c = 'Dashboard test meeting',
        Outcome__c = 'Strong Interest',
        Start_Date_Time__c = today10.addHours(3),
        End_Date_Time__c = today10.addHours(4),
        Other_Project_Discussed__c = 'marina launch 2027'
      ),
      new Sales_Activity_Tracker__c(
        Activity__c = 'Client Meeting',
        Type__c = 'Outbound',
        Agency__c = briefed.Id,
        Description__c = 'Dashboard test outbound visit',
        Outcome__c = 'Informational Only',
        Start_Date_Time__c = today10.addHours(5),
        End_Date_Time__c = today10.addHours(6),
        Other_Project_Discussed__c = 'MARINA launch 2027'
      ),
      // a second RM logging the SAME briefing (15 min start difference, same agency,
      // same day) — event-level numbers must count the pair as ONE event
      new Sales_Activity_Tracker__c(
        Activity__c = 'Agency Briefing',
        Type__c = 'Inbound',
        Agency__c = briefed.Id,
        Description__c = 'Duplicate log of the same briefing',
        Outcome__c = 'Needs Materials',
        Start_Date_Time__c = today10.addMinutes(15),
        End_Date_Time__c = today10.addMinutes(90),
        Number_of_Agents__c = 5,
        Other_Project_Discussed__c = 'marina LAUNCH 2027'
      )
    };
  }

  @IsTest
  static void dashboardSplitsByActivityTypeWithTotals() {
    SalesActivityDashboardController.TabbedDashboard t = SalesActivityDashboardController.getDashboard(
      null
    );

    // all-time totals, shown on every tab. The two meetings are 2h apart = two
    // events; the two briefing RECORDS are 15 min apart = ONE deduped event.
    System.assertEquals(2, t.totalClientMeetings);
    System.assertEquals(
      1,
      t.totalAgencyBriefings,
      'Duplicate joint-briefing logs count once'
    );
    System.assert(t.inboundTarget > 0, 'Inbound target read from CMDT');
    System.assert(t.outboundTarget > 0, 'Outbound target read from CMDT');

    // ---- Client Meetings tab -------------------------------------------------
    SalesActivityDashboardController.Dashboard m = t.clientMeetings;
    System.assertEquals(2, m.kpis.weekCount, 'Both meetings happened today');
    System.assertEquals(2, m.kpis.monthCount);
    System.assertEquals(1, m.kpis.activeRms, 'Single owner');
    System.assertEquals(2, m.kpis.monthHours, '1h + 1h of meetings');
    System.assertEquals(1, m.rmRows.size());
    System.assertEquals(1, m.rmRows[0].weekInbound, 'Online counts as inbound');
    System.assertEquals(1, m.rmRows[0].weekOutbound);
    System.assertEquals(2.0, m.rmRows[0].hours);

    // ---- Agency Briefings tab ------------------------------------------------
    SalesActivityDashboardController.Dashboard b = t.agencyBriefings;
    System.assertEquals(1, b.kpis.weekCount, 'Two records, one deduped event');
    System.assertEquals(1, b.kpis.monthCount);
    System.assertEquals(
      2,
      b.kpis.monthHours,
      'Only the representative record\'s 1.5h, rounded'
    );
    // per-RM stats deliberately keep BOTH records — every logger keeps personal credit
    System.assertEquals(
      2,
      b.rmRows[0].monthCount,
      'RM credit is per record, not per event'
    );
    System.assertEquals(
      2.8,
      b.rmRows[0].hours,
      '1.5h + 1.25h of the RM\'s own logs'
    );
    System.assertEquals(2, b.rmRows[0].weekInbound);
    System.assertEquals(0, b.rmRows[0].weekOutbound);

    // coverage is per type: the untouched agency is flagged on both tabs,
    // the briefed one on neither (it had a meeting AND a briefing today)
    for (
      SalesActivityDashboardController.Dashboard d : new List<SalesActivityDashboardController.Dashboard>{
        m,
        b
      }
    ) {
      Boolean untouchedFlagged = false;
      for (SalesActivityDashboardController.AgencyRow row : d.needsAttention) {
        System.assertNotEquals(
          'Dash Briefed Agency',
          row.name,
          'An agency visited today must not need attention'
        );
        if (row.name == 'Dash Untouched Agency') {
          untouchedFlagged = true;
          System.assertEquals(null, row.lastActivity, 'Never visited');
        }
      }
      System.assert(
        untouchedFlagged,
        'Never-visited agency appears in the attention list'
      );
      System.assert(d.kpis.agenciesTotal >= 2, 'Both test agencies counted');
      System.assert(d.kpis.agenciesCovered >= 1, 'Briefed agency is covered');
    }

    // outcomes are per type and per EVENT — the duplicate's differing outcome
    // ('Needs Materials') is ignored; the first-logged record's outcome wins
    System.assertEquals(
      2,
      m.outcomes.size(),
      'Meetings: Strong Interest + Informational Only'
    );
    System.assertEquals(
      1,
      b.outcomes.size(),
      'Briefings: the deduped event, once'
    );
    System.assertEquals('Strong Interest', b.outcomes[0].name);
    System.assertEquals(1, b.outcomes[0].count);

    // unlisted projects group case-insensitively, per type, once per EVENT
    System.assertEquals(1, m.otherProjects.size());
    System.assertEquals(
      2,
      m.otherProjects[0].count,
      'Two separate meetings mentioned the project — casing variants counted together'
    );
    System.assertEquals(1, b.otherProjects.size());
    System.assertEquals(
      1,
      b.otherProjects[0].count,
      'Both loggers of one briefing typed the name — counted once'
    );
  }
}
