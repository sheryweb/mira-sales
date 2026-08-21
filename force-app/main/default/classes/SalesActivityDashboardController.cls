/**
 * SalesActivityDashboardController — Apex for the salesActivityDashboard LWC (its own
 * Sales_Activity_Dashboard tab; deliberately NOT part of the dashboard hub / Performance
 * Center — Sheraz 2026-08-19).
 *
 * TABBED (Sheraz 2026-08-21): the dashboard is split into Client Meetings and Agency
 * Briefings tabs — every section is computed twice, once per Activity__c value — plus
 * all-time totals of each type shown on every tab. One call returns both datasets so a
 * tab switch never waits on the server. (A third "Summarized Reports" tab is a UI
 * placeholder for later work.)
 *
 * DUPLICATE EVENTS (Sheraz 2026-08-21): a joint meeting/briefing is logged separately by
 * each attending RM, so one real-world event can be several tracker records. All
 * EVENT-level numbers (the all-time totals, KPI counts/hours, agency coverage, outcomes,
 * unlisted projects) therefore count unique EVENTS: records of the same type + same
 * agency + same day whose start times fall within EVENT_WINDOW_MINUTES of the group's
 * first start are one event, represented by the earliest-logged record. Per-RM numbers
 * (the leaderboard and the RM matrix) deliberately still count every RM's own records —
 * each attendee keeps individual credit toward the weekly target.
 *
 * Sharing (Sheraz 2026-08-19): the dashboard is scoped BY THE VIEWER'S RECORD ACCESS.
 * System Administrator (Modify All) and Agency Relationship Manager - Limited (sharing
 * rule: all internal users' records → their role) see org-wide data; Sales Director MIRA
 * sees only their team via the role hierarchy. The ONE exception is the agency universe
 * (Account is Private OWD too): the coverage list must always span every active agency,
 * so agency NAMES are fetched without sharing — a director's coverage therefore reads
 * "which agencies has MY team (not) visited", over the full agency list.
 *
 * All date math keys off Start_Date_Time__c (when the activity happened), not CreatedDate
 * (when it was logged) — 30% of records are logged a day or more late.
 */
public with sharing class SalesActivityDashboardController {
  @TestVisible
  private static final String CLIENT_MEETING = 'Client Meeting';
  @TestVisible
  private static final String AGENCY_BRIEFING = 'Agency Briefing';
  @TestVisible
  private static final Integer EVENT_WINDOW_MINUTES = 60;

  /** Account OWD is Private; the coverage list still needs the full agency universe. */
  private without sharing class AgencyUniverse {
    List<Account> fetch() {
      return [
        SELECT Id, Name
        FROM Account
        WHERE Type = 'Agency' AND Status__c = 'Completed'
        ORDER BY Name
        LIMIT 5000
      ];
    }
  }

  @TestVisible
  private static final Integer STALE_DAYS = 60;
  private static final Integer COVERAGE_WINDOW_DAYS = 90;
  private static final Integer MAX_ATTENTION_ROWS = 100;
  private static final Integer MAX_OTHER_PROJECTS = 10;
  // ~7.5k records/year at current pace — this cap outlasts the object by years, and
  // two types are queried per call (well under the 50k transaction row limit).
  private static final Integer MAX_ROWS_PER_TYPE = 20000;

  public class Kpis {
    @AuraEnabled
    public Integer weekCount = 0; // unique events
    @AuraEnabled
    public Integer monthCount = 0; // unique events
    @AuraEnabled
    public Decimal monthHours = 0; // unique events' duration
    @AuraEnabled
    public Integer activeRms = 0;
    @AuraEnabled
    public Integer agenciesTotal = 0;
    @AuraEnabled
    public Integer agenciesCovered = 0; // touched in the last 90 days
    @AuraEnabled
    public Integer agenciesAttention = 0; // never touched, or stale > 60 days
  }

  public class RmRow {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Integer weekCount = 0;
    @AuraEnabled
    public Integer weekInbound = 0; // Type__c Inbound/Online/blank
    @AuraEnabled
    public Integer weekOutbound = 0; // Type__c Outbound
    @AuraEnabled
    public Integer monthCount = 0;
    @AuraEnabled
    public Decimal hours = 0;
    @AuraEnabled
    public String lastLogged;
  }

  public class AgencyRow {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String lastActivity; // null = never
    @AuraEnabled
    public Integer daysSince; // null = never
    @AuraEnabled
    public Integer count90 = 0; // unique events in the window
  }

  public class CountRow {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Integer count = 0;
  }

  /** One activity type's view — every section of the board, filtered to that type. */
  public class Dashboard {
    @AuraEnabled
    public Integer totalEvents = 0; // all-time unique events, viewer-scoped
    @AuraEnabled
    public Kpis kpis;
    @AuraEnabled
    public List<RmRow> rmRows;
    @AuraEnabled
    public List<AgencyRow> needsAttention;
    @AuraEnabled
    public List<CountRow> outcomes;
    @AuraEnabled
    public List<CountRow> otherProjects;
  }

  public class TabbedDashboard {
    @AuraEnabled
    public Integer totalClientMeetings = 0; // all-time unique events
    @AuraEnabled
    public Integer totalAgencyBriefings = 0; // all-time unique events
    @AuraEnabled
    public Integer inboundTarget;
    @AuraEnabled
    public Integer outboundTarget;
    @AuraEnabled
    public Dashboard clientMeetings;
    @AuraEnabled
    public Dashboard agencyBriefings;
  }

  /** One real-world meeting/briefing, possibly logged by several RMs. */
  private class EventGroup {
    Sales_Activity_Tracker__c rep; // earliest-logged record of the group
    Datetime anchorStart; // the group's first start time
    Set<String> projectKeys = new Set<String>(); // distinct unlisted-project names (lowercased)
    Map<String, String> projectNames = new Map<String, String>(); // key → first-seen casing
  }

  /** cacheable=true keeps LWC happy; the `stamp` param is unused server-side — the LWC
   *  passes a fresh timestamp per call so the client cache never serves stale data. */
  @AuraEnabled(cacheable=true)
  public static TabbedDashboard getDashboard(String stamp) {
    TabbedDashboard t = new TabbedDashboard();
    t.inboundTarget = weeklyTarget('Weekly_Inbound_Target__c', 12);
    t.outboundTarget = weeklyTarget('Weekly_Outbound_Target__c', 4);
    List<Account> universe = new AgencyUniverse().fetch();
    t.clientMeetings = buildFor(CLIENT_MEETING, universe);
    t.agencyBriefings = buildFor(AGENCY_BRIEFING, universe);
    t.totalClientMeetings = t.clientMeetings.totalEvents;
    t.totalAgencyBriefings = t.agencyBriefings.totalEvents;
    return t;
  }

  private static Dashboard buildFor(String activity, List<Account> universe) {
    Date today = Date.today();
    Datetime monthStart = Datetime.newInstance(
      today.toStartOfMonth(),
      Time.newInstance(0, 0, 0, 0)
    );
    Datetime weekStart = Datetime.newInstance(
      today.toStartOfWeek(),
      Time.newInstance(0, 0, 0, 0)
    );
    Datetime windowStart = Datetime.now().addDays(-COVERAGE_WINDOW_DAYS);

    // One all-time query feeds both the raw per-RM stats and the deduped event metrics.
    List<Sales_Activity_Tracker__c> records = [
      SELECT
        OwnerId,
        Owner.Name,
        Type__c,
        Agency__c,
        Outcome__c,
        Other_Project_Discussed__c,
        Start_Date_Time__c,
        End_Date_Time__c,
        CreatedDate
      FROM Sales_Activity_Tracker__c
      WHERE Activity__c = :activity
      ORDER BY Agency__c, Start_Date_Time__c
      LIMIT :MAX_ROWS_PER_TYPE
    ];
    List<EventGroup> events = groupIntoEvents(records);

    Dashboard d = new Dashboard();
    d.totalEvents = events.size();
    d.kpis = new Kpis();
    d.rmRows = buildRmRows(records, monthStart, weekStart, d.kpis);
    applyEventKpis(events, monthStart, weekStart, d.kpis);
    d.needsAttention = buildAgencyCoverage(
      events,
      windowStart,
      d.kpis,
      universe
    );
    d.outcomes = buildOutcomes(events, monthStart);
    d.otherProjects = buildOtherProjects(events, windowStart);
    return d;
  }

  /** Weekly per-RM targets from the Sales_Activity_Target.Default CMDT record;
   *  every RM shares the same numbers (Sheraz 2026-08-20). Online counts as Inbound. */
  private static Integer weeklyTarget(String fieldName, Integer fallback) {
    Sales_Activity_Target__mdt config = Sales_Activity_Target__mdt.getInstance(
      'Default'
    );
    if (config == null || config.get(fieldName) == null)
      return fallback;
    return ((Decimal) config.get(fieldName)).intValue();
  }

  // ---- event grouping ---------------------------------------------------------------

  /** Records arrive ordered by Agency__c then Start_Date_Time__c. Same agency + same day
   *  + start within EVENT_WINDOW_MINUTES of the group's first start = one event. Records
   *  with no agency or no start time cannot be matched and each stand alone. */
  private static List<EventGroup> groupIntoEvents(
    List<Sales_Activity_Tracker__c> records
  ) {
    List<EventGroup> events = new List<EventGroup>();
    EventGroup current;
    Id currentAgency;
    for (Sales_Activity_Tracker__c t : records) {
      Boolean joinsCurrent =
        current != null &&
        t.Agency__c != null &&
        t.Agency__c == currentAgency &&
        t.Start_Date_Time__c != null &&
        current.anchorStart != null &&
        t.Start_Date_Time__c.date() == current.anchorStart.date() &&
        (t.Start_Date_Time__c.getTime() - current.anchorStart.getTime()) <=
        EVENT_WINDOW_MINUTES * 60000L;
      if (!joinsCurrent) {
        current = new EventGroup();
        current.anchorStart = t.Start_Date_Time__c;
        current.rep = t;
        currentAgency = t.Agency__c;
        events.add(current);
      } else if (t.CreatedDate < current.rep.CreatedDate) {
        current.rep = t; // the first-logged record represents the event
      }
      if (String.isNotBlank(t.Other_Project_Discussed__c)) {
        String key = t.Other_Project_Discussed__c.trim().toLowerCase();
        if (key != '' && !current.projectKeys.contains(key)) {
          current.projectKeys.add(key);
          current.projectNames.put(key, t.Other_Project_Discussed__c.trim());
        }
      }
    }
    return events;
  }

  private static void applyEventKpis(
    List<EventGroup> events,
    Datetime monthStart,
    Datetime weekStart,
    Kpis kpis
  ) {
    for (EventGroup e : events) {
      Datetime start = e.anchorStart;
      if (start == null || start < monthStart)
        continue;
      kpis.monthCount++;
      if (start >= weekStart)
        kpis.weekCount++;
      Sales_Activity_Tracker__c rep = e.rep;
      if (
        rep.End_Date_Time__c != null &&
        rep.Start_Date_Time__c != null &&
        rep.End_Date_Time__c > rep.Start_Date_Time__c
      ) {
        kpis.monthHours +=
          (Decimal) (rep.End_Date_Time__c.getTime() -
          rep.Start_Date_Time__c.getTime()) / 3600000;
      }
    }
    kpis.monthHours = kpis.monthHours.setScale(0);
  }

  // ---- per-RM month matrix (raw records — every RM keeps individual credit) ---------

  private static List<RmRow> buildRmRows(
    List<Sales_Activity_Tracker__c> records,
    Datetime monthStart,
    Datetime weekStart,
    Kpis kpis
  ) {
    Map<Id, RmRow> byOwner = new Map<Id, RmRow>();
    Map<Id, Datetime> lastByOwner = new Map<Id, Datetime>();
    for (Sales_Activity_Tracker__c t : records) {
      if (t.Start_Date_Time__c == null || t.Start_Date_Time__c < monthStart)
        continue;
      RmRow row = byOwner.get(t.OwnerId);
      if (row == null) {
        row = new RmRow();
        row.name = t.Owner.Name;
        byOwner.put(t.OwnerId, row);
      }
      row.monthCount++;
      if (t.Start_Date_Time__c >= weekStart) {
        row.weekCount++;
        if (t.Type__c == 'Outbound')
          row.weekOutbound++;
        else
          row.weekInbound++; // Inbound, Online and legacy blanks all count as inbound
      }
      if (
        t.End_Date_Time__c != null &&
        t.End_Date_Time__c > t.Start_Date_Time__c
      ) {
        row.hours +=
          (Decimal) (t.End_Date_Time__c.getTime() -
          t.Start_Date_Time__c.getTime()) / 3600000;
      }
      Datetime prev = lastByOwner.get(t.OwnerId);
      if (prev == null || t.Start_Date_Time__c > prev) {
        lastByOwner.put(t.OwnerId, t.Start_Date_Time__c);
      }
    }
    List<RmRow> rows = new List<RmRow>();
    for (Id ownerId : byOwner.keySet()) {
      RmRow row = byOwner.get(ownerId);
      row.hours = row.hours.setScale(1);
      row.lastLogged = lastByOwner.get(ownerId).format('d MMM');
      rows.add(row);
    }
    sortRmRows(rows);
    kpis.activeRms = rows.size();
    return rows;
  }

  /** Insertion sort by monthCount desc — row counts are small (active RMs). */
  private static void sortRmRows(List<RmRow> rows) {
    for (Integer i = 1; i < rows.size(); i++) {
      RmRow current = rows[i];
      Integer j = i - 1;
      while (j >= 0 && rows[j].monthCount < current.monthCount) {
        rows[j + 1] = rows[j];
        j--;
      }
      rows[j + 1] = current;
    }
  }

  // ---- agency coverage (unique events) ------------------------------------------------

  private static List<AgencyRow> buildAgencyCoverage(
    List<EventGroup> events,
    Datetime windowStart,
    Kpis kpis,
    List<Account> universe
  ) {
    Map<Id, AgencyRow> agencies = new Map<Id, AgencyRow>();
    Map<Id, Datetime> lastByAgency = new Map<Id, Datetime>();
    for (Account a : universe) {
      AgencyRow row = new AgencyRow();
      row.id = a.Id;
      row.name = a.Name;
      agencies.put(a.Id, row);
    }
    kpis.agenciesTotal = agencies.size();

    for (EventGroup e : events) {
      Id agencyId = e.rep.Agency__c;
      if (agencyId == null || e.anchorStart == null)
        continue;
      AgencyRow row = agencies.get(agencyId);
      if (row == null)
        continue; // agency no longer matches the Type/Status filter
      Datetime prev = lastByAgency.get(agencyId);
      if (prev == null || e.anchorStart > prev)
        lastByAgency.put(agencyId, e.anchorStart);
      if (e.anchorStart >= windowStart)
        row.count90++;
    }
    for (Id agencyId : lastByAgency.keySet()) {
      AgencyRow row = agencies.get(agencyId);
      Datetime lastAct = lastByAgency.get(agencyId);
      row.lastActivity = lastAct.format('d MMM yyyy');
      row.daysSince = lastAct.date().daysBetween(Date.today());
    }

    List<AgencyRow> attention = new List<AgencyRow>();
    for (AgencyRow row : agencies.values()) {
      if (row.count90 > 0)
        kpis.agenciesCovered++;
      if (row.daysSince == null || row.daysSince > STALE_DAYS)
        attention.add(row);
    }
    kpis.agenciesAttention = attention.size();
    sortAttention(attention);
    while (attention.size() > MAX_ATTENTION_ROWS)
      attention.remove(attention.size() - 1);
    return attention;
  }

  /** Never-visited agencies first, then the longest-stale. Small list; insertion sort. */
  private static void sortAttention(List<AgencyRow> rows) {
    for (Integer i = 1; i < rows.size(); i++) {
      AgencyRow current = rows[i];
      Integer j = i - 1;
      while (j >= 0 && staleRank(rows[j]) < staleRank(current)) {
        rows[j + 1] = rows[j];
        j--;
      }
      rows[j + 1] = current;
    }
  }

  private static Integer staleRank(AgencyRow row) {
    return row.daysSince == null ? 1000000 : row.daysSince;
  }

  // ---- outcomes + unlisted projects (unique events) -----------------------------------

  /** The event's outcome is the first-logged record's — attendees occasionally judge the
   *  same meeting differently, and the first logger wins. */
  private static List<CountRow> buildOutcomes(
    List<EventGroup> events,
    Datetime monthStart
  ) {
    Map<String, CountRow> byName = new Map<String, CountRow>();
    for (EventGroup e : events) {
      if (e.anchorStart == null || e.anchorStart < monthStart)
        continue;
      String outcome = e.rep.Outcome__c;
      if (String.isBlank(outcome))
        continue;
      CountRow row = byName.get(outcome);
      if (row == null) {
        row = new CountRow();
        row.name = outcome;
        byName.put(outcome, row);
      }
      row.count++;
    }
    List<CountRow> rows = byName.values();
    sortCountRows(rows);
    return rows;
  }

  /** A project name mentioned by several attendees of ONE event counts once; casing
   *  variants group case-insensitively across events (first-seen casing wins). */
  private static List<CountRow> buildOtherProjects(
    List<EventGroup> events,
    Datetime windowStart
  ) {
    Map<String, CountRow> byKey = new Map<String, CountRow>();
    for (EventGroup e : events) {
      if (e.anchorStart == null || e.anchorStart < windowStart)
        continue;
      for (String key : e.projectKeys) {
        CountRow row = byKey.get(key);
        if (row == null) {
          row = new CountRow();
          row.name = e.projectNames.get(key);
          byKey.put(key, row);
        }
        row.count++;
      }
    }
    List<CountRow> rows = byKey.values();
    sortCountRows(rows);
    while (rows.size() > MAX_OTHER_PROJECTS)
      rows.remove(rows.size() - 1);
    return rows;
  }

  /** Insertion sort by count desc — both lists are small. */
  private static void sortCountRows(List<CountRow> rows) {
    for (Integer i = 1; i < rows.size(); i++) {
      CountRow current = rows[i];
      Integer j = i - 1;
      while (j >= 0 && rows[j].count < current.count) {
        rows[j + 1] = rows[j];
        j--;
      }
      rows[j + 1] = current;
    }
  }
}
