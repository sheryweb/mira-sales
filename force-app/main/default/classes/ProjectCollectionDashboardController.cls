/**
 * Backing controller for the multi-currency Project Collection Dashboard LWC.
 *
 * Sources every figure from two objects (business decision 2026-08-12):
 *  - Project__c: Project_Total_Value__c / Project_Received_Value__c /
 *    Project_Remaining_Value__c power the all-stage KPIs, bar chart and table.
 *    Project_Total_Value__c switches on Project_Currency__c over the per-currency
 *    DLRS rollups (Project_Value__c, Project_Value_USD__c, Project_Value_Post__c),
 *    so each project reads in its native currency.
 *  - Opportunity: Unit_Price__c / Received_Amount__c are currency-aware formulas;
 *    StageName scopes the Booked/Reserved/Sold figures. Cross-object formula
 *    fields cannot be aggregated or grouped in SOQL, so opportunity rows are
 *    summed in Apex.
 *
 * Projects with a blank Project_Currency__c are treated as AED (business default).
 *
 * Declared without sharing deliberately: Opportunity/Project OWDs are restricted
 * and this dashboard mirrors the org-wide standard dashboard, which runs as a
 * designated user. Only aggregate totals and project names are exposed.
 */
public without sharing class ProjectCollectionDashboardController {

    @TestVisible
    private static final String DEFAULT_CURRENCY = 'AED';

    /** Currencies with a native project value source behind Project_Total_Value__c. */
    private static final Set<String> SUPPORTED_CURRENCIES = new Set<String>{ 'AED', 'CHF', 'USD' };

    /** Donut scope: Booked / Reserved / Sold. */
    private static final Set<String> BRS_STAGES = new Set<String>{ 'Booked', 'Reserved', 'Sold' };
    /** "Sold" KPI tile scope: Reserved / Sold. */
    private static final Set<String> RS_STAGES = new Set<String>{ 'Reserved', 'Sold' };

    /**
     * Currencies offered in the dashboard dropdown: supported currencies that have
     * at least one project. Blank project currency counts as AED. AED always first.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getAvailableCurrencies() {
        try {
            Set<String> found = new Set<String>();
            for (AggregateResult ar : [
                SELECT Project_Currency__c cur
                FROM Project__c
                GROUP BY Project_Currency__c
            ]) {
                String cur = (String) ar.get('cur');
                found.add(String.isBlank(cur) ? DEFAULT_CURRENCY : cur.toUpperCase());
            }
            List<String> result = new List<String>();
            if (found.contains(DEFAULT_CURRENCY)) {
                result.add(DEFAULT_CURRENCY);
            }
            List<String> others = new List<String>();
            for (String cur : found) {
                if (cur != DEFAULT_CURRENCY && SUPPORTED_CURRENCIES.contains(cur)) {
                    others.add(cur);
                }
            }
            others.sort();
            result.addAll(others);
            return result;
        } catch (Exception e) {
            throw auraError(e, 'Failed to load available currencies');
        }
    }

    /**
     * All dashboard figures for one currency in a single round trip.
     * @param currencyIso ISO code from the dropdown; blank defaults to AED.
     */
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData(String currencyIso) {
        try {
            String cur = String.isBlank(currencyIso) ? DEFAULT_CURRENCY : currencyIso.toUpperCase();
            if (!SUPPORTED_CURRENCIES.contains(cur)) {
                throw new DashboardException('Unsupported currency: ' + cur);
            }
            Boolean includeBlank = (cur == DEFAULT_CURRENCY);

            DashboardData data = new DashboardData();
            data.currencyIso = cur;

            // Project-level figures straight from the project fields; a row per
            // project so projects without deals still appear with zeros.
            Map<Id, ProjectRow> rowsByProject = new Map<Id, ProjectRow>();
            List<Project__c> projects = includeBlank
                ? [SELECT Id, Name, Project_Total_Value__c, Project_Received_Value__c, Project_Remaining_Value__c
                   FROM Project__c
                   WHERE Project_Currency__c = :cur OR Project_Currency__c = null]
                : [SELECT Id, Name, Project_Total_Value__c, Project_Received_Value__c, Project_Remaining_Value__c
                   FROM Project__c
                   WHERE Project_Currency__c = :cur];
            for (Project__c project : projects) {
                ProjectRow row = new ProjectRow(project.Id, project.Name);
                row.totalValue = nvl(project.Project_Total_Value__c);
                row.totalReceived = nvl(project.Project_Received_Value__c);
                row.totalRemaining = nvl(project.Project_Remaining_Value__c);
                rowsByProject.put(project.Id, row);
                data.totalValue += row.totalValue;
                data.totalReceived += row.totalReceived;
                data.totalRemaining += row.totalRemaining;
            }

            // Stage-scoped figures from Opportunity rows, summed in Apex.
            List<Opportunity> deals = includeBlank
                ? [SELECT StageName, Unit_Price__c, Received_Amount__c, Unit__r.Project__c
                   FROM Opportunity
                   WHERE StageName IN :BRS_STAGES AND Unit__c != null
                     AND (Unit__r.Project__r.Project_Currency__c = :cur
                          OR Unit__r.Project__r.Project_Currency__c = null)]
                : [SELECT StageName, Unit_Price__c, Received_Amount__c, Unit__r.Project__c
                   FROM Opportunity
                   WHERE StageName IN :BRS_STAGES AND Unit__c != null
                     AND Unit__r.Project__r.Project_Currency__c = :cur];
            for (Opportunity deal : deals) {
                ProjectRow row = rowsByProject.get(deal.Unit__r.Project__c);
                if (row == null) {
                    continue; // deal whose project was deleted mid-flight; ignore
                }
                Decimal price = nvl(deal.Unit_Price__c);
                Decimal received = nvl(deal.Received_Amount__c);
                row.brsValue += price;
                row.brsReceived += received;
                if (RS_STAGES.contains(deal.StageName)) {
                    data.soldValue += price;
                    data.soldReceived += received;
                }
            }

            data.projects = rowsByProject.values();
            data.projects.sort();
            for (ProjectRow row : data.projects) {
                row.brsRemaining = row.brsValue - row.brsReceived;
            }
            data.soldRemaining = data.soldValue - data.soldReceived;
            return data;
        } catch (Exception e) {
            throw auraError(e, 'Failed to load dashboard data');
        }
    }

    private static Decimal nvl(Decimal value) {
        return value == null ? 0 : value;
    }

    private static AuraHandledException auraError(Exception e, String prefix) {
        String message = prefix + ': ' + e.getMessage();
        AuraHandledException aura = new AuraHandledException(message);
        aura.setMessage(message);
        return aura;
    }

    public class DashboardException extends Exception {}

    /** Full dashboard payload for one currency. */
    public class DashboardData {
        @AuraEnabled public String currencyIso;
        /** All-stage KPIs (tiles 1-3), from the Project__c value fields. */
        @AuraEnabled public Decimal totalValue = 0;
        @AuraEnabled public Decimal totalReceived = 0;
        @AuraEnabled public Decimal totalRemaining = 0;
        /** Reserved + Sold KPIs (tiles 4-6), from Opportunity rows. */
        @AuraEnabled public Decimal soldValue = 0;
        @AuraEnabled public Decimal soldReceived = 0;
        @AuraEnabled public Decimal soldRemaining = 0;
        /** Per-project rows powering donuts, bar chart and comparison table. */
        @AuraEnabled public List<ProjectRow> projects;
    }

    /** One project's figures; brs* = Booked/Reserved/Sold deal scope (donuts). */
    public class ProjectRow implements Comparable {
        @AuraEnabled public String projectId;
        @AuraEnabled public String projectName;
        @AuraEnabled public Decimal totalValue = 0;
        @AuraEnabled public Decimal totalReceived = 0;
        @AuraEnabled public Decimal totalRemaining = 0;
        @AuraEnabled public Decimal brsValue = 0;
        @AuraEnabled public Decimal brsReceived = 0;
        @AuraEnabled public Decimal brsRemaining = 0;

        public ProjectRow(Id projectId, String projectName) {
            this.projectId = projectId;
            this.projectName = projectName;
        }

        public Integer compareTo(Object other) {
            return projectName.compareTo(((ProjectRow) other).projectName);
        }
    }
}
