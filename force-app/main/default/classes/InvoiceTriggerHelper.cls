public class InvoiceTriggerHelper {
    @TestVisible private static Boolean skipTrigger = false;

    /**
     * Assigns the per-project invoice sequence (Invoice_Seq__c) and the human
     * invoice number (Invoice_Number__c) on before-insert.
     *
     * Project-specific configuration (prefix, optional retail prefix) lives in
     * the Project_Numbering_Setting__mdt custom metadata, keyed by the Unit's
     * Project_Name_F__c. Onboarding a new project = add one CMDT row; no Apex,
     * field, or formula change required.
     *
     * Behavior parity with the legacy per-project implementation:
     *  - Invoice_Number__c = <Invoice_Prefix__c> + <seq>, e.g. INV-TRD2-86.
     *  - Sequence is per project, continuing from the current MAX(Invoice_Seq__c).
     *  - Invoices whose Unit / project is missing or not configured get no number.
     */
    public static void handleInvoiceNumberAssignment(List<Invoice__c> newInvoices) {
        if (skipTrigger) {
            return;
        }

        // 1. Collect the Units referenced by this batch.
        Set<Id> unitIds = new Set<Id>();
        for (Invoice__c inv : newInvoices) {
            if (inv.Unit__c != null) {
                unitIds.add(inv.Unit__c);
            }
        }

        Map<Id, Unit__c> unitsById = new Map<Id, Unit__c>([
            SELECT Id, Project_Name_F__c, Type__c
            FROM Unit__c
            WHERE Id IN :unitIds
        ]);

        // 2. Load active project numbering config, keyed by project name.
        Map<String, Project_Numbering_Setting__mdt> configByProject = getActiveConfigByProject();

        // 3. Determine which configured projects appear in this batch.
        Set<String> projectNames = new Set<String>();
        for (Unit__c u : unitsById.values()) {
            if (u.Project_Name_F__c != null && configByProject.containsKey(u.Project_Name_F__c)) {
                projectNames.add(u.Project_Name_F__c);
            }
        }

        // 4. Seed the running sequence per project from existing invoices.
        //    Project_Name_F__c is a formula field and cannot be used in GROUP BY,
        //    so the max is computed in memory (as the legacy implementation did).
        Map<String, Decimal> nextByProject = new Map<String, Decimal>();
        for (String pn : projectNames) {
            nextByProject.put(pn, 0);
        }
        if (!projectNames.isEmpty()) {
            for (Invoice__c existing : [
                SELECT Unit__r.Project_Name_F__c, Invoice_Seq__c
                FROM Invoice__c
                WHERE Unit__r.Project_Name_F__c IN :projectNames
                  AND Invoice_Seq__c != null
            ]) {
                String pn = existing.Unit__r.Project_Name_F__c;
                if (nextByProject.containsKey(pn) && existing.Invoice_Seq__c > nextByProject.get(pn)) {
                    nextByProject.put(pn, existing.Invoice_Seq__c);
                }
            }
        }

        // 5. Assign sequence + number to each new invoice.
        for (Invoice__c inv : newInvoices) {
            // Reset first: an unmapped invoice must not carry stale numbering.
            inv.Invoice_Seq__c = null;
            inv.Invoice_Number__c = null;

            if (inv.Unit__c == null) {
                continue;
            }
            Unit__c u = unitsById.get(inv.Unit__c);
            if (u == null || u.Project_Name_F__c == null) {
                continue;
            }

            Project_Numbering_Setting__mdt cfg = configByProject.get(u.Project_Name_F__c);
            if (cfg == null) {
                // Project not recognized -> no auto-number (legacy behavior).
                continue;
            }

            Decimal nextSeq = nextByProject.get(u.Project_Name_F__c) + 1;
            nextByProject.put(u.Project_Name_F__c, nextSeq);
            inv.Invoice_Seq__c = nextSeq;

            String prefix = cfg.Invoice_Prefix__c;
            if (u.Type__c == 'Retail' && String.isNotBlank(cfg.Invoice_Prefix_Retail__c)) {
                prefix = cfg.Invoice_Prefix_Retail__c;
            }
            inv.Invoice_Number__c = (prefix == null ? '' : prefix) + String.valueOf(nextSeq);
        }
    }

    private static Map<String, Project_Numbering_Setting__mdt> getActiveConfigByProject() {
        Map<String, Project_Numbering_Setting__mdt> byProject =
            new Map<String, Project_Numbering_Setting__mdt>();
        for (Project_Numbering_Setting__mdt s : Project_Numbering_Setting__mdt.getAll().values()) {
            if (s.Active__c && String.isNotBlank(s.Project_Name__c)) {
                byProject.put(s.Project_Name__c, s);
            }
        }
        return byProject;
    }
}
