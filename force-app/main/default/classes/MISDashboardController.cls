/**
 * Backing controller for the MIS Dashboard LWC (Performance Center hub).
 * Faithful rebuild of the standard "MIS Dashoboard" (20 flex tables, no
 * dashboard-level filter) whose report definitions were extracted from
 * production 2026-08-14.
 *
 * Universal rules (from those reports):
 *  - Everything is Opportunity-based; the measure is SUM(Unit_Price_Dashboard__c)
 *    (already AED for every project) plus a unit count; every component
 *    excludes resells (Is_it_a_Resell__c = false).
 *  - Time windows are calendar TODAY / THIS MONTH / THIS YEAR over the
 *    DATETIME stamps Booking/Reserved/Sold_Date_Time__c, evaluated in the
 *    running user's timezone — the same semantics as the reports' literals.
 *  - The originals carry asymmetries that are mimicked deliberately:
 *    "Agent vs Direct – Today" and every YTD channel/agency/team table window
 *    on the BOOKING date only, while their MTD siblings use any-activity
 *    (booked OR reserved OR sold this month); "Managers – YTD" uses
 *    booking >= this year (future bookings count).
 *  - Manager tables: 'Management' rows split out into the Management Sale
 *    tables; owner 'Ali Alali' is excluded from the manager tables (both
 *    hardcoded in the standard reports). Note Manager_Name__c's formula
 *    currently never yields 'Management', so those tables stay empty until
 *    the formula maps a Management role — same behaviour as the original.
 *
 * Unit_Price_Dashboard__c is a cross-object formula (cannot be aggregated or
 * grouped in SOQL), so one query fetches every row that touches this year and
 * all twenty tables are computed in a single pass in Apex.
 *
 * Declared without sharing deliberately: mirrors the org-wide standard
 * dashboard (restricted OWDs); only aggregates and grouping names are exposed.
 */
public without sharing class MISDashboardController {

    private static final Set<String> RS_STAGES = new Set<String>{ 'Reserved', 'Sold' };

    /** Hardcoded buckets/exclusions carried over from the standard reports. */
    private static final String MANAGEMENT_BUCKET = 'Management';
    private static final Set<String> MANAGER_TABLE_EXCLUDED_OWNERS = new Set<String>{ 'Ali Alali' };
    private static final String UNASSIGNED_MANAGER = 'Not Assigned';

    private static final Integer TOP_AGENCIES_LIMIT = 10;

    /** All twenty tables in a single round trip. */
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        try {
            List<Opportunity> deals = [
                SELECT StageName, Booking_Date_Time__c, Reserved_Date_Time__c, Sold_Date_Time__c,
                       Project_Name__c, Direct_Agent__c, Agency_Name__c, Assisted_by_Agent__c,
                       Owner_Name__c, Manager_Name__c, Unit_Price_Dashboard__c
                FROM Opportunity
                WHERE StageName IN ('Booked', 'Reserved', 'Sold')
                  AND Is_it_a_Resell__c = false
                  AND (Booking_Date_Time__c >= THIS_YEAR
                       OR Reserved_Date_Time__c = THIS_YEAR
                       OR Sold_Date_Time__c = THIS_YEAR)
            ];

            Date today = Date.today();

            Aggregator todayBooked = new Aggregator();
            Aggregator todayReserved = new Aggregator();
            Aggregator todaySold = new Aggregator();
            Aggregator todayAgentDirect = new Aggregator();
            Aggregator mtdBooked = new Aggregator();
            Aggregator mtdReserved = new Aggregator();
            Aggregator mtdSold = new Aggregator();
            Aggregator mtdAllStatus = new Aggregator();
            Aggregator mtdTopAgencies = new Aggregator();
            Aggregator mtdAgentDirect = new Aggregator();
            Aggregator mtdManagers = new Aggregator();
            Aggregator mtdManagementSale = new Aggregator();
            Aggregator ytdReserved = new Aggregator();
            Aggregator ytdSold = new Aggregator();
            Aggregator ytdCombined = new Aggregator();
            Aggregator ytdTeam = new Aggregator();
            Aggregator ytdTopAgencies = new Aggregator();
            Aggregator ytdAgentDirect = new Aggregator();
            Aggregator ytdManagers = new Aggregator();
            Aggregator ytdManagementSale = new Aggregator();

            for (Opportunity deal : deals) {
                Decimal price = deal.Unit_Price_Dashboard__c == null ? 0 : deal.Unit_Price_Dashboard__c;
                String project = String.isBlank(deal.Project_Name__c) ? '—' : deal.Project_Name__c;
                String channel = String.isBlank(deal.Direct_Agent__c) ? '—' : deal.Direct_Agent__c;
                String manager = String.isBlank(deal.Manager_Name__c) ? UNASSIGNED_MANAGER : deal.Manager_Name__c;
                String owner = String.isBlank(deal.Owner_Name__c) ? '—' : deal.Owner_Name__c;
                Boolean isSold = deal.StageName == 'Sold';
                Boolean isReservedOrSold = RS_STAGES.contains(deal.StageName);
                Boolean isAgencyDeal = deal.Assisted_by_Agent__c == true && String.isNotBlank(deal.Agency_Name__c);
                Boolean managerRowAllowed = manager != MANAGEMENT_BUCKET
                    && !MANAGER_TABLE_EXCLUDED_OWNERS.contains(deal.Owner_Name__c);

                Date bookedOn = localDate(deal.Booking_Date_Time__c);
                Date reservedOn = localDate(deal.Reserved_Date_Time__c);
                Date soldOn = localDate(deal.Sold_Date_Time__c);

                Boolean bookedThisMonth = inMonth(bookedOn, today);
                Boolean reservedThisMonth = inMonth(reservedOn, today);
                Boolean soldThisMonth = inMonth(soldOn, today);
                Boolean anyThisMonth = bookedThisMonth || reservedThisMonth || soldThisMonth;
                Boolean bookedThisYear = bookedOn != null && bookedOn.year() == today.year();

                // ---- Today ----
                if (deal.StageName == 'Booked' && bookedOn == today) {
                    todayBooked.add(project, price);
                }
                if (isReservedOrSold && reservedOn == today) {
                    todayReserved.add(project, price);
                }
                if (isSold && soldOn == today) {
                    todaySold.add(project, price);
                }
                if (bookedOn == today) {
                    // booking date only — the original report's quirk
                    todayAgentDirect.add(channel, price);
                }

                // ---- Month to date ----
                if (bookedThisMonth) {
                    mtdBooked.add(project, price);
                }
                if (isReservedOrSold && reservedThisMonth) {
                    mtdReserved.add(project, price);
                }
                if (isSold && soldThisMonth) {
                    mtdSold.add(project, price);
                }
                if (anyThisMonth) {
                    mtdAllStatus.add(project, price);
                    mtdAgentDirect.add(channel, price);
                    if (isAgencyDeal) {
                        mtdTopAgencies.add(deal.Agency_Name__c, price);
                    }
                    if (manager == MANAGEMENT_BUCKET) {
                        mtdManagementSale.add(manager, price);
                    } else if (managerRowAllowed) {
                        mtdManagers.add(manager, price);
                    }
                }

                // ---- Year to date ----
                if (isReservedOrSold && reservedOn != null && reservedOn.year() == today.year()) {
                    ytdReserved.add(project, price);
                }
                if (isSold && soldOn != null && soldOn.year() == today.year()) {
                    ytdSold.add(project, price);
                }
                if (bookedThisYear) {
                    // every YTD table below windows on the booking date only,
                    // unlike the MTD any-activity pattern — original's quirk
                    ytdCombined.add(project, price);
                    ytdTeam.add(owner, price);
                    ytdAgentDirect.add(channel, price);
                    if (isAgencyDeal) {
                        ytdTopAgencies.add(deal.Agency_Name__c, price);
                    }
                    if (manager == MANAGEMENT_BUCKET) {
                        ytdManagementSale.add(manager, price);
                    }
                }
                if (bookedOn != null && bookedOn.year() >= today.year() && managerRowAllowed) {
                    // booking >= this year (future bookings count) — quirk
                    ytdManagers.add(manager, price);
                }
            }

            DashboardData data = new DashboardData();
            data.todayBooked = todayBooked.rowsByNameAsc();
            data.todayReserved = todayReserved.rowsByNameAsc();
            data.todaySold = todaySold.rowsByNameAsc();
            data.todayAgentDirect = todayAgentDirect.rowsByNameAsc();
            data.mtdBooked = mtdBooked.rowsByNameAsc();
            data.mtdReserved = mtdReserved.rowsByNameAsc();
            data.mtdSold = mtdSold.rowsByNameAsc();
            data.mtdAllStatus = mtdAllStatus.rowsByNameAsc();
            data.mtdTopAgencies = mtdTopAgencies.rowsByValueDesc(TOP_AGENCIES_LIMIT);
            data.mtdAgentDirect = mtdAgentDirect.rowsByNameAsc();
            data.mtdManagers = mtdManagers.rowsByValueDesc(null);
            data.mtdManagementSale = mtdManagementSale.rowsByValueDesc(null);
            data.ytdReserved = ytdReserved.rowsByNameAsc();
            data.ytdSold = ytdSold.rowsByNameAsc();
            data.ytdCombined = ytdCombined.rowsByNameAsc();
            data.ytdTeam = ytdTeam.rowsByValueDesc(null);
            data.ytdTopAgencies = ytdTopAgencies.rowsByValueDesc(TOP_AGENCIES_LIMIT);
            data.ytdAgentDirect = ytdAgentDirect.rowsByNameAsc();
            data.ytdManagers = ytdManagers.rowsByValueDesc(null);
            data.ytdManagementSale = ytdManagementSale.rowsByValueDesc(null);
            return data;
        } catch (Exception e) {
            throw auraError(e, 'Failed to load MIS dashboard data');
        }
    }

    /** Datetime → date in the running user's timezone (matches report literals). */
    private static Date localDate(Datetime value) {
        return value == null ? null : value.date();
    }

    private static Boolean inMonth(Date value, Date today) {
        return value != null && value.year() == today.year() && value.month() == today.month();
    }

    private static AuraHandledException auraError(Exception e, String prefix) {
        String message = prefix + ': ' + e.getMessage();
        AuraHandledException aura = new AuraHandledException(message);
        aura.setMessage(message);
        return aura;
    }

    /** Accumulates units + value per grouping key. */
    private class Aggregator {
        Map<String, GroupRow> rows = new Map<String, GroupRow>();

        void add(String key, Decimal value) {
            GroupRow row = rows.get(key);
            if (row == null) {
                row = new GroupRow(key);
                rows.put(key, row);
            }
            row.units++;
            row.value += value;
        }

        List<GroupRow> rowsByNameAsc() {
            List<String> keys = new List<String>(rows.keySet());
            keys.sort();
            List<GroupRow> sorted = new List<GroupRow>();
            for (String key : keys) {
                sorted.add(rows.get(key));
            }
            return sorted;
        }

        List<GroupRow> rowsByValueDesc(Integer capAt) {
            List<GroupRow> sorted = rows.values();
            sorted.sort();
            if (capAt != null && sorted.size() > capAt) {
                List<GroupRow> capped = new List<GroupRow>();
                for (Integer i = 0; i < capAt; i++) {
                    capped.add(sorted[i]);
                }
                return capped;
            }
            return sorted;
        }
    }

    /** All twenty tables; every amount AED. */
    public class DashboardData {
        @AuraEnabled public List<GroupRow> todayBooked;
        @AuraEnabled public List<GroupRow> todayReserved;
        @AuraEnabled public List<GroupRow> todaySold;
        @AuraEnabled public List<GroupRow> todayAgentDirect;
        @AuraEnabled public List<GroupRow> mtdBooked;
        @AuraEnabled public List<GroupRow> mtdReserved;
        @AuraEnabled public List<GroupRow> mtdSold;
        @AuraEnabled public List<GroupRow> mtdAllStatus;
        @AuraEnabled public List<GroupRow> mtdTopAgencies;
        @AuraEnabled public List<GroupRow> mtdAgentDirect;
        @AuraEnabled public List<GroupRow> mtdManagers;
        @AuraEnabled public List<GroupRow> mtdManagementSale;
        @AuraEnabled public List<GroupRow> ytdReserved;
        @AuraEnabled public List<GroupRow> ytdSold;
        @AuraEnabled public List<GroupRow> ytdCombined;
        @AuraEnabled public List<GroupRow> ytdTeam;
        @AuraEnabled public List<GroupRow> ytdTopAgencies;
        @AuraEnabled public List<GroupRow> ytdAgentDirect;
        @AuraEnabled public List<GroupRow> ytdManagers;
        @AuraEnabled public List<GroupRow> ytdManagementSale;
    }

    /** One grouping bucket: label + unit count + AED value. */
    public class GroupRow implements Comparable {
        @AuraEnabled public String name;
        @AuraEnabled public Integer units = 0;
        @AuraEnabled public Decimal value = 0;

        public GroupRow(String name) {
            this.name = name;
        }

        /** Descending by value. */
        public Integer compareTo(Object other) {
            Decimal otherValue = ((GroupRow) other).value;
            return value == otherValue ? 0 : (value < otherValue ? 1 : -1);
        }
    }
}
