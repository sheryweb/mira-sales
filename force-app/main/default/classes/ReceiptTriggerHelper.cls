public class ReceiptTriggerHelper {
    @TestVisible private static Boolean skipTrigger = false;

    /**
     * Assigns the per-project voucher sequence (Voucher_Seq__c) on before-insert.
     *
     * The human voucher number is built by the Voucher_Number__c formula:
     *   'RV-' & Unit.Project.Voucher_Code__c & '-' & TEXT(Voucher_Seq__c)
     * so the receipt code (e.g. TR2, GF) is data on the Project, independent of
     * the invoice prefix. Recognized projects are those with an active
     * Project_Numbering_Setting__mdt row; onboarding a new project = add one CMDT
     * row + set Voucher_Code__c on the Project.
     *
     * Behavior parity with the legacy per-project implementation: the sequence is
     * per project, continuing from the current MAX(Voucher_Seq__c); receipts whose
     * Unit / project is missing or not configured get no number.
     */
    public static void handleVoucherNumberAssignment(List<Receipt__c> newReceipts) {
        if (skipTrigger) {
            return;
        }

        // 1. Collect the Units referenced by this batch.
        Set<Id> unitIds = new Set<Id>();
        for (Receipt__c rec : newReceipts) {
            if (rec.Unit__c != null) {
                unitIds.add(rec.Unit__c);
            }
        }
        if (unitIds.isEmpty()) {
            return;
        }

        Map<Id, Unit__c> unitsById = new Map<Id, Unit__c>([
            SELECT Id, Project_Name_F__c
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

        // 4. Seed the running sequence per project from existing receipts.
        //    Project_Name_F__c is a formula field and cannot be used in GROUP BY,
        //    so the max is computed in memory (as the legacy implementation did).
        Map<String, Decimal> nextByProject = new Map<String, Decimal>();
        for (String pn : projectNames) {
            nextByProject.put(pn, 0);
        }
        if (!projectNames.isEmpty()) {
            for (Receipt__c existing : [
                SELECT Unit__r.Project_Name_F__c, Voucher_Seq__c
                FROM Receipt__c
                WHERE Unit__r.Project_Name_F__c IN :projectNames
                  AND Voucher_Seq__c != null
            ]) {
                String pn = existing.Unit__r.Project_Name_F__c;
                if (nextByProject.containsKey(pn) && existing.Voucher_Seq__c > nextByProject.get(pn)) {
                    nextByProject.put(pn, existing.Voucher_Seq__c);
                }
            }
        }

        // 5. Assign sequence to each new receipt.
        for (Receipt__c rec : newReceipts) {
            // Reset first: an unmapped receipt must not carry stale numbering.
            rec.Voucher_Seq__c = null;

            if (rec.Unit__c == null) {
                continue;
            }
            Unit__c u = unitsById.get(rec.Unit__c);
            if (u == null || u.Project_Name_F__c == null) {
                continue;
            }
            if (!configByProject.containsKey(u.Project_Name_F__c)) {
                // Project not recognized -> no auto-number (legacy behavior).
                continue;
            }

            Decimal nextSeq = nextByProject.get(u.Project_Name_F__c) + 1;
            nextByProject.put(u.Project_Name_F__c, nextSeq);
            rec.Voucher_Seq__c = nextSeq;
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
