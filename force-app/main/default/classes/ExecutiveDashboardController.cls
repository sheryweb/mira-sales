/**
 * Backing controller for the Executive Management Dashboard LWC (Performance
 * Center hub). Faithful rebuild of the standard "Executive Management
 * Dashboard" (12 components) whose report definitions were extracted from
 * production 2026-08-13.
 *
 * Universal rules (from those reports):
 *  - Everything is Opportunity-based; the measure is SUM(Unit_Price_Dashboard__c),
 *    which is already AED for every project.
 *  - Target_Year__c is THE master filter: the year of Unit_Booked_Date_Only__c.
 *    The dashboard is a booking-year cohort view — a deal booked Dec 2025 and
 *    sold Jan 2026 belongs to 2025 regardless of its current stage.
 *  - Most components exclude resells (Is_it_a_Resell__c = false). Two mimic
 *    the standard reports and do NOT: Project Breakdown and Top Nationalities.
 *  - The team tables carry the same hardcoded person exclusions as the
 *    standard reports (see constants).
 *
 * Unit_Price_Dashboard__c is a cross-object formula (cannot be aggregated or
 * grouped in SOQL), so one query fetches the Booked/Reserved/Sold rows and all
 * aggregates are computed in Apex. Year options come from the same rows.
 *
 * Declared without sharing deliberately: mirrors the org-wide standard
 * dashboard (restricted OWDs); only aggregates and grouping names are exposed.
 */
public without sharing class ExecutiveDashboardController {

    private static final Set<String> BRS_STAGES = new Set<String>{ 'Booked', 'Reserved', 'Sold' };
    private static final Set<String> RS_STAGES = new Set<String>{ 'Reserved', 'Sold' };

    /** Gauge scale of the standard dashboard: 0 → 1B AED, bands at 600M / 800M. */
    private static final Decimal GAUGE_MAX = 1000000000;
    private static final Decimal GAUGE_BREAKPOINT_1 = 600000000;
    private static final Decimal GAUGE_BREAKPOINT_2 = 800000000;
    /** Total Units big-number bands of the standard dashboard. */
    private static final Decimal UNITS_BREAKPOINT_1 = 45;
    private static final Decimal UNITS_BREAKPOINT_2 = 70;

    /** Hardcoded exclusions carried over from the standard reports. */
    private static final Set<String> SALES_TEAM_EXCLUDED_OWNERS = new Set<String>{ 'Muaed Alakaev' };
    private static final Set<String> MANAGER_TABLE_EXCLUDED_OWNERS = new Set<String>{ 'Ali Alali' };
    private static final String UNASSIGNED_MANAGER = 'Not Assigned';

    private static final Integer TOP_AGENCIES_LIMIT = 10;

    private static final List<String> MONTH_NAMES = new List<String>{
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
    };

    /**
     * All dashboard figures for one target year in a single round trip.
     * @param targetYear booking year ("2026"); blank defaults to the current
     *        year when it has data, otherwise the newest year available.
     */
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData(String targetYear) {
        try {
            List<Opportunity> deals = [
                SELECT StageName, Is_it_a_Resell__c, Target_Year__c, Unit_Price_Dashboard__c,
                       Unit_Sold_Date_Only__c, Unit_Booked_Date_Only__c, Quarter_Booked__c,
                       Project_Name__c, Agency_Name__c, Assisted_by_Agent__c,
                       Owner_Name__c, Manager_Name__c, toLabel(Account.Nationality__c)
                FROM Opportunity
                WHERE StageName IN :BRS_STAGES
            ];

            DashboardData data = new DashboardData();
            data.yearOptions = collectYears(deals);
            data.selectedYear = resolveYear(targetYear, data.yearOptions);

            Aggregator monthlySold = new Aggregator();
            Aggregator monthlyBooked = new Aggregator();
            Aggregator quarterlySold = new Aggregator();
            Aggregator projectSold = new Aggregator();
            Aggregator nationalities = new Aggregator();
            Aggregator agencies = new Aggregator();
            Aggregator salesTeam = new Aggregator();
            Aggregator managers = new Aggregator();
            Aggregator pipeline = new Aggregator();
            Map<String, Aggregator> breakdownByProject = new Map<String, Aggregator>();

            for (Opportunity deal : deals) {
                if (deal.Target_Year__c != data.selectedYear) {
                    continue; // master filter: booking-year cohort only
                }
                Decimal price = deal.Unit_Price_Dashboard__c == null ? 0 : deal.Unit_Price_Dashboard__c;
                Boolean isResell = deal.Is_it_a_Resell__c == true;
                Boolean isSold = deal.StageName == 'Sold';

                // Project Breakdown mimics the standard report: resells included.
                String project = String.isBlank(deal.Project_Name__c) ? '—' : deal.Project_Name__c;
                if (!breakdownByProject.containsKey(project)) {
                    breakdownByProject.put(project, new Aggregator());
                }
                breakdownByProject.get(project).add(deal.StageName, price);

                // Top Nationalities mimics the standard report: resells included.
                // Nationality__c values are flag emoji; toLabel() in the query
                // turns them into country names, matching the report display.
                if (isSold && String.isNotBlank(deal.Account?.Nationality__c)) {
                    nationalities.add(deal.Account.Nationality__c, price);
                }

                if (isResell) {
                    continue; // every remaining component excludes resells
                }

                pipeline.add(deal.StageName, price);
                data.totalUnits++;
                if (RS_STAGES.contains(deal.StageName)) {
                    data.totalValue += price;
                }
                monthlyBooked.add(monthKey(deal.Unit_Booked_Date_Only__c), price);

                if (!isSold) {
                    continue;
                }
                data.soldValue += price;
                monthlySold.add(monthKey(deal.Unit_Sold_Date_Only__c), price);
                quarterlySold.add(quarterKey(deal.Quarter_Booked__c), price);
                projectSold.add(project, price);
                if (String.isNotBlank(deal.Agency_Name__c) && deal.Assisted_by_Agent__c == true) {
                    agencies.add(deal.Agency_Name__c, price);
                }
                if (!SALES_TEAM_EXCLUDED_OWNERS.contains(deal.Owner_Name__c)) {
                    salesTeam.add(deal.Owner_Name__c, price);
                }
                if (deal.Manager_Name__c != UNASSIGNED_MANAGER
                    && !MANAGER_TABLE_EXCLUDED_OWNERS.contains(deal.Owner_Name__c)) {
                    managers.add(deal.Manager_Name__c, price);
                }
            }

            data.pipeline = stageRows(pipeline);
            data.monthlySold = chronologicalRows(monthlySold, true);
            data.monthlyBooked = chronologicalRows(monthlyBooked, true);
            data.quarterlySold = chronologicalRows(quarterlySold, false);
            data.projectSold = projectSold.rowsByValueDesc(null);
            data.topNationalities = nationalities.rowsByValueDesc(null);
            data.topAgencies = agencies.rowsByValueDesc(TOP_AGENCIES_LIMIT);
            data.salesTeam = salesTeam.rowsByValueDesc(null);
            data.managers = managers.rowsByValueDesc(null);
            data.projectBreakdown = breakdownGroups(breakdownByProject);

            data.gaugeMax = GAUGE_MAX;
            data.gaugeBreakpoint1 = GAUGE_BREAKPOINT_1;
            data.gaugeBreakpoint2 = GAUGE_BREAKPOINT_2;
            data.unitsBreakpoint1 = UNITS_BREAKPOINT_1;
            data.unitsBreakpoint2 = UNITS_BREAKPOINT_2;
            return data;
        } catch (Exception e) {
            throw auraError(e, 'Failed to load executive dashboard data');
        }
    }

    /** First year the business tracks; the filter always starts here. */
    private static final Integer FIRST_TARGET_YEAR = 2024;

    /**
     * Year filter options, ascending: the fixed 2024 → next-year range
     * (so future planning years are selectable), merged with any booking
     * years present in the data outside that range.
     */
    private static List<String> collectYears(List<Opportunity> deals) {
        Set<String> years = new Set<String>();
        for (Integer y = FIRST_TARGET_YEAR; y <= Date.today().year() + 1; y++) {
            years.add(String.valueOf(y));
        }
        for (Opportunity deal : deals) {
            if (String.isNotBlank(deal.Target_Year__c) && deal.Target_Year__c.isNumeric()) {
                years.add(deal.Target_Year__c);
            }
        }
        List<String> sorted = new List<String>(years);
        sorted.sort();
        return sorted;
    }

    private static String resolveYear(String requested, List<String> options) {
        if (String.isNotBlank(requested)) {
            return requested;
        }
        String currentYear = String.valueOf(Date.today().year());
        if (options.contains(currentYear) || options.isEmpty()) {
            return currentYear;
        }
        return options[options.size() - 1];
    }

    /** "2026-03" sort key for a date; null dates fold into a trailing bucket. */
    private static String monthKey(Date value) {
        if (value == null) {
            return 'zzz|No date';
        }
        String month = String.valueOf(value.month()).leftPad(2, '0');
        return value.year() + '-' + month + '|' + MONTH_NAMES[value.month() - 1] + ' ' + value.year();
    }

    /** "2026-3" sort key for a "Q3 2026" label; malformed values trail. */
    private static String quarterKey(String quarterLabel) {
        if (String.isBlank(quarterLabel) || !quarterLabel.startsWith('Q') || !quarterLabel.contains(' ')) {
            return 'zzz|' + (String.isBlank(quarterLabel) ? 'No quarter' : quarterLabel);
        }
        List<String> parts = quarterLabel.split(' ');
        return parts[1] + '-' + parts[0].removeStart('Q') + '|' + quarterLabel;
    }

    /** Pipeline rows in fixed Booked / Reserved / Sold order. */
    private static List<GroupRow> stageRows(Aggregator aggregator) {
        List<GroupRow> rows = new List<GroupRow>();
        for (String stage : new List<String>{ 'Booked', 'Reserved', 'Sold' }) {
            GroupRow row = aggregator.rows.get(stage);
            rows.add(row != null ? row : new GroupRow(stage));
        }
        return rows;
    }

    /** Rows sorted by their embedded "sortKey|label" key; label is unpacked. */
    private static List<GroupRow> chronologicalRows(Aggregator aggregator, Boolean skipDatelessBucket) {
        List<String> keys = new List<String>(aggregator.rows.keySet());
        keys.sort();
        List<GroupRow> rows = new List<GroupRow>();
        for (String key : keys) {
            if (skipDatelessBucket == true && key.startsWith('zzz|')) {
                continue;
            }
            GroupRow row = aggregator.rows.get(key);
            row.name = key.substringAfter('|');
            rows.add(row);
        }
        return rows;
    }

    private static List<BreakdownGroup> breakdownGroups(Map<String, Aggregator> byProject) {
        List<String> projects = new List<String>(byProject.keySet());
        projects.sort();
        List<BreakdownGroup> groups = new List<BreakdownGroup>();
        for (String project : projects) {
            BreakdownGroup grp = new BreakdownGroup();
            grp.projectName = project;
            grp.rows = stageRowsPresent(byProject.get(project));
            for (GroupRow row : grp.rows) {
                grp.subtotal += row.value;
                grp.units += row.units;
            }
            groups.add(grp);
        }
        return groups;
    }

    /** Stage rows for one breakdown project — only stages that have deals. */
    private static List<GroupRow> stageRowsPresent(Aggregator aggregator) {
        List<GroupRow> rows = new List<GroupRow>();
        for (String stage : new List<String>{ 'Booked', 'Reserved', 'Sold' }) {
            GroupRow row = aggregator.rows.get(stage);
            if (row != null) {
                rows.add(row);
            }
        }
        return rows;
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

    /** Full dashboard payload for one target year; all amounts AED. */
    public class DashboardData {
        @AuraEnabled public List<String> yearOptions;
        @AuraEnabled public String selectedYear;
        /** Gauge: YTD sold value vs the standard dashboard's static scale. */
        @AuraEnabled public Decimal soldValue = 0;
        @AuraEnabled public Decimal gaugeMax;
        @AuraEnabled public Decimal gaugeBreakpoint1;
        @AuraEnabled public Decimal gaugeBreakpoint2;
        /** Big numbers. */
        @AuraEnabled public Integer totalUnits = 0;
        @AuraEnabled public Decimal totalValue = 0;
        @AuraEnabled public Decimal unitsBreakpoint1;
        @AuraEnabled public Decimal unitsBreakpoint2;
        /** Tables and charts. */
        @AuraEnabled public List<GroupRow> pipeline;
        @AuraEnabled public List<GroupRow> monthlySold;
        @AuraEnabled public List<GroupRow> monthlyBooked;
        @AuraEnabled public List<GroupRow> quarterlySold;
        @AuraEnabled public List<GroupRow> projectSold;
        @AuraEnabled public List<GroupRow> topNationalities;
        @AuraEnabled public List<GroupRow> topAgencies;
        @AuraEnabled public List<GroupRow> salesTeam;
        @AuraEnabled public List<GroupRow> managers;
        @AuraEnabled public List<BreakdownGroup> projectBreakdown;
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

    /** Project Breakdown group: per-stage rows + project subtotal. */
    public class BreakdownGroup {
        @AuraEnabled public String projectName;
        @AuraEnabled public Integer units = 0;
        @AuraEnabled public Decimal subtotal = 0;
        @AuraEnabled public List<GroupRow> rows;
    }
}
