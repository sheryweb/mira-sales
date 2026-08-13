/**
 * Backing controller for the Project Collection Dashboard LWC.
 *
 * Every figure is reported in AED (business decision 2026-08-13, replacing the
 * earlier per-currency filter):
 *  - Values are already AED at the source: Project__c.Project_Value__c is the
 *    DLRS Sum of Unit__c.Cost_AED__c, and Opportunity.Unit_Price_Dashboard__c
 *    is a formula on Unit__r.Cost_AED__c. No conversion applied.
 *  - Received amounts are stored in the project's own currency
 *    (Project_Received_Value__c / Opportunity.Received_Amount__c) and are
 *    converted to AED at runtime through CurrencyService — the org's central
 *    conversion facility (daily market rates, org-table fallback, unknown
 *    currencies pass through unchanged).
 *  - Remaining = Value - converted Received, at both levels.
 *
 * Cross-object formula fields cannot be aggregated or grouped in SOQL, so
 * opportunity rows are summed in Apex. StageName scopes the deal figures
 * (Booked/Reserved/Sold; Reserved+Sold = the "Sold" tiles).
 *
 * Declared without sharing deliberately: Opportunity/Project OWDs are restricted
 * and this dashboard mirrors the org-wide standard dashboard, which runs as a
 * designated user. Only aggregate totals and project names are exposed.
 */
public without sharing class ProjectCollectionDashboardController {

    /** Donut scope: Booked / Reserved / Sold. */
    private static final Set<String> BRS_STAGES = new Set<String>{ 'Booked', 'Reserved', 'Sold' };
    /** "Sold" KPI tile scope: Reserved / Sold. */
    private static final Set<String> RS_STAGES = new Set<String>{ 'Reserved', 'Sold' };

    /** All dashboard figures, AED, in a single round trip. */
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        try {
            DashboardData data = new DashboardData();
            data.ratesAsOf = CurrencyService.lastRefreshed();

            // Project-level figures; a row per project so projects without
            // deals still appear with zeros.
            Map<Id, Project__c> projectsById = new Map<Id, Project__c>([
                SELECT Id, Name, Project_Currency__c,
                       Project_Value__c, Project_Received_Value__c
                FROM Project__c
            ]);
            Map<Id, ProjectRow> rowsByProject = new Map<Id, ProjectRow>();
            for (Project__c project : projectsById.values()) {
                ProjectRow row = new ProjectRow(project.Id, project.Name);
                row.totalValue = nvl(project.Project_Value__c);
                row.totalReceived = CurrencyService.convertToAed(
                    nvl(project.Project_Received_Value__c), project.Project_Currency__c);
                row.totalRemaining = row.totalValue - row.totalReceived;
                rowsByProject.put(project.Id, row);
                data.totalValue += row.totalValue;
                data.totalReceived += row.totalReceived;
                data.totalRemaining += row.totalRemaining;
            }

            // Stage-scoped figures from Opportunity rows, summed in Apex.
            for (Opportunity deal : [
                SELECT StageName, Unit_Price_Dashboard__c, Received_Amount__c, Unit__r.Project__c
                FROM Opportunity
                WHERE StageName IN :BRS_STAGES AND Unit__c != null
            ]) {
                Project__c project = projectsById.get(deal.Unit__r.Project__c);
                ProjectRow row = rowsByProject.get(deal.Unit__r.Project__c);
                if (project == null || row == null) {
                    continue; // deal whose project was deleted mid-flight; ignore
                }
                Decimal price = nvl(deal.Unit_Price_Dashboard__c); // already AED
                Decimal received = CurrencyService.convertToAed(
                    nvl(deal.Received_Amount__c), project.Project_Currency__c);
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

    /** Full dashboard payload, all amounts AED. */
    public class DashboardData {
        /** Newest market-rate refresh stamp (null until the FX job first runs). */
        @AuraEnabled public Datetime ratesAsOf;
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
