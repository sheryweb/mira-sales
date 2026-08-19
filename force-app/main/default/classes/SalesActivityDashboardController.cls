/**
 * SalesActivityDashboardController — Apex for the salesActivityDashboard LWC (its own
 * Sales_Activity_Dashboard tab; deliberately NOT part of the dashboard hub / Performance
 * Center — Sheraz 2026-08-19).
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

    /** Account OWD is Private; the coverage list still needs the full agency universe. */
    private without sharing class AgencyUniverse {
        List<Account> fetch() {
            return [
                SELECT Id, Name FROM Account
                WHERE Type = 'Agency' AND Status__c = 'Completed'
                ORDER BY Name LIMIT 5000
            ];
        }
    }

    @TestVisible private static final Integer STALE_DAYS = 60;
    private static final Integer COVERAGE_WINDOW_DAYS = 90;
    private static final Integer MAX_ATTENTION_ROWS = 100;
    private static final Integer MAX_OTHER_PROJECTS = 10;

    public class Kpis {
        @AuraEnabled public Integer weekCount = 0;
        @AuraEnabled public Integer monthCount = 0;
        @AuraEnabled public Decimal monthHours = 0;
        @AuraEnabled public Integer activeRms = 0;
        @AuraEnabled public Integer agenciesTotal = 0;
        @AuraEnabled public Integer agenciesCovered = 0;   // touched in the last 90 days
        @AuraEnabled public Integer agenciesAttention = 0; // never touched, or stale > 60 days
    }

    public class RmRow {
        @AuraEnabled public String name;
        @AuraEnabled public Integer weekCount = 0;
        @AuraEnabled public Integer monthCount = 0;
        @AuraEnabled public Decimal hours = 0;
        @AuraEnabled public Integer briefings = 0;
        @AuraEnabled public Integer meetings = 0;
        @AuraEnabled public String lastLogged;
    }

    public class AgencyRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String lastActivity;   // null = never
        @AuraEnabled public Integer daysSince;     // null = never
        @AuraEnabled public Integer count90 = 0;
    }

    public class CountRow {
        @AuraEnabled public String name;
        @AuraEnabled public Integer count = 0;
    }

    public class Dashboard {
        @AuraEnabled public Kpis kpis;
        @AuraEnabled public List<RmRow> rmRows;
        @AuraEnabled public List<AgencyRow> needsAttention;
        @AuraEnabled public List<CountRow> outcomes;
        @AuraEnabled public List<CountRow> otherProjects;
    }

    /** cacheable=true keeps LWC happy; the `stamp` param is unused server-side — the LWC
     *  passes a fresh timestamp per call so the client cache never serves stale data. */
    @AuraEnabled(cacheable=true)
    public static Dashboard getDashboard(String stamp) {
        Date today = Date.today();
        Datetime monthStart = Datetime.newInstance(today.toStartOfMonth(), Time.newInstance(0, 0, 0, 0));
        Datetime weekStart = Datetime.newInstance(today.toStartOfWeek(), Time.newInstance(0, 0, 0, 0));
        Datetime windowStart = Datetime.now().addDays(-COVERAGE_WINDOW_DAYS);

        Dashboard d = new Dashboard();
        d.kpis = new Kpis();
        d.rmRows = buildRmRows(monthStart, weekStart, d.kpis);
        d.needsAttention = buildAgencyCoverage(windowStart, d.kpis);
        d.outcomes = buildOutcomes(monthStart);
        d.otherProjects = buildOtherProjects(windowStart);
        return d;
    }

    // ---- per-RM month matrix -------------------------------------------------------

    private static List<RmRow> buildRmRows(Datetime monthStart, Datetime weekStart, Kpis kpis) {
        Map<Id, RmRow> byOwner = new Map<Id, RmRow>();
        Map<Id, Datetime> lastByOwner = new Map<Id, Datetime>();
        for (Sales_Activity_Tracker__c t : [
            SELECT OwnerId, Owner.Name, Activity__c, Start_Date_Time__c, End_Date_Time__c
            FROM Sales_Activity_Tracker__c
            WHERE Start_Date_Time__c >= :monthStart
            LIMIT 10000
        ]) {
            RmRow row = byOwner.get(t.OwnerId);
            if (row == null) {
                row = new RmRow();
                row.name = t.Owner.Name;
                byOwner.put(t.OwnerId, row);
            }
            row.monthCount++;
            kpis.monthCount++;
            if (t.Start_Date_Time__c >= weekStart) {
                row.weekCount++;
                kpis.weekCount++;
            }
            if (t.End_Date_Time__c != null && t.End_Date_Time__c > t.Start_Date_Time__c) {
                Decimal hrs = (Decimal) (t.End_Date_Time__c.getTime() - t.Start_Date_Time__c.getTime()) / 3600000;
                row.hours += hrs;
                kpis.monthHours += hrs;
            }
            if (t.Activity__c == 'Agency Briefing') row.briefings++;
            else row.meetings++;
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
        kpis.monthHours = kpis.monthHours.setScale(0);
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

    // ---- agency coverage -----------------------------------------------------------

    private static List<AgencyRow> buildAgencyCoverage(Datetime windowStart, Kpis kpis) {
        Map<Id, AgencyRow> agencies = new Map<Id, AgencyRow>();
        for (Account a : new AgencyUniverse().fetch()) {
            AgencyRow row = new AgencyRow();
            row.id = a.Id;
            row.name = a.Name;
            agencies.put(a.Id, row);
        }
        kpis.agenciesTotal = agencies.size();

        for (AggregateResult ar : [
            SELECT Agency__c agencyId, MAX(Start_Date_Time__c) lastAct
            FROM Sales_Activity_Tracker__c
            WHERE Agency__c != null AND Start_Date_Time__c != null
            GROUP BY Agency__c
            LIMIT 2000
        ]) {
            AgencyRow row = agencies.get((Id) ar.get('agencyId'));
            if (row == null) continue; // agency no longer matches the Type/Status filter
            Datetime lastAct = (Datetime) ar.get('lastAct');
            row.lastActivity = lastAct.format('d MMM yyyy');
            row.daysSince = lastAct.date().daysBetween(Date.today());
        }

        for (AggregateResult ar : [
            SELECT Agency__c agencyId, COUNT(Id) c
            FROM Sales_Activity_Tracker__c
            WHERE Agency__c != null AND Start_Date_Time__c >= :windowStart
            GROUP BY Agency__c
            LIMIT 2000
        ]) {
            AgencyRow row = agencies.get((Id) ar.get('agencyId'));
            if (row != null) row.count90 = (Integer) ar.get('c');
        }

        List<AgencyRow> attention = new List<AgencyRow>();
        for (AgencyRow row : agencies.values()) {
            if (row.count90 > 0) kpis.agenciesCovered++;
            if (row.daysSince == null || row.daysSince > STALE_DAYS) attention.add(row);
        }
        kpis.agenciesAttention = attention.size();
        sortAttention(attention);
        while (attention.size() > MAX_ATTENTION_ROWS) attention.remove(attention.size() - 1);
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

    // ---- outcomes + unlisted projects ------------------------------------------------

    private static List<CountRow> buildOutcomes(Datetime monthStart) {
        List<CountRow> rows = new List<CountRow>();
        for (AggregateResult ar : [
            SELECT Outcome__c o, COUNT(Id) c
            FROM Sales_Activity_Tracker__c
            WHERE Outcome__c != null AND Start_Date_Time__c >= :monthStart
            GROUP BY Outcome__c
            ORDER BY COUNT(Id) DESC
        ]) {
            CountRow row = new CountRow();
            row.name = (String) ar.get('o');
            row.count = (Integer) ar.get('c');
            rows.add(row);
        }
        return rows;
    }

    private static List<CountRow> buildOtherProjects(Datetime windowStart) {
        Map<String, CountRow> byKey = new Map<String, CountRow>();
        for (Sales_Activity_Tracker__c t : [
            SELECT Other_Project_Discussed__c
            FROM Sales_Activity_Tracker__c
            WHERE Other_Project_Discussed__c != null AND Start_Date_Time__c >= :windowStart
            LIMIT 10000
        ]) {
            String key = t.Other_Project_Discussed__c.trim().toLowerCase();
            if (key == '') continue;
            CountRow row = byKey.get(key);
            if (row == null) {
                row = new CountRow();
                row.name = t.Other_Project_Discussed__c.trim(); // first-seen casing wins
                byKey.put(key, row);
            }
            row.count++;
        }
        List<CountRow> rows = byKey.values();
        for (Integer i = 1; i < rows.size(); i++) {
            CountRow current = rows[i];
            Integer j = i - 1;
            while (j >= 0 && rows[j].count < current.count) {
                rows[j + 1] = rows[j];
                j--;
            }
            rows[j + 1] = current;
        }
        while (rows.size() > MAX_OTHER_PROJECTS) rows.remove(rows.size() - 1);
        return rows;
    }
}
