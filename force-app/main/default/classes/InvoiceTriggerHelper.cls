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

    /**
     * Before-delete guard + cleanup.
     *  - BLOCKS deletion of any invoice that has money on it (Paid_Amount > 0) or any receipt
     *    allocation (Receipt_Amount__c / Receipt_Invoice__c). Such an invoice must be Cancelled
     *    (soft) instead, or have its receipt allocations removed first. Enforced here so it holds
     *    for every delete path (UI, list view, API, mass delete).
     *  - For an allowed (unpaid, unallocated) delete, frees the covered installments: resets
     *    Cash_Flow__c.Is_Invoiced__c = false and removes the Milestone_Invoice__c links (which are
     *    Lookup/SetNull and would otherwise orphan, leaving the installments stuck as invoiced).
     */
    public static void handleInvoiceDelete(List<Invoice__c> oldInvoices) {
        Set<Id> invoiceIds = new Set<Id>();
        for (Invoice__c inv : oldInvoices) {
            invoiceIds.add(inv.Id);
        }

        // Invoices that carry any receipt allocation (either junction).
        Set<Id> allocated = new Set<Id>();
        for (Receipt_Amount__c ra : [SELECT Invoice__c FROM Receipt_Amount__c WHERE Invoice__c IN :invoiceIds]) {
            if (ra.Invoice__c != null) allocated.add(ra.Invoice__c);
        }
        for (Receipt_Invoice__c ri : [SELECT Invoice__c FROM Receipt_Invoice__c WHERE Invoice__c IN :invoiceIds]) {
            if (ri.Invoice__c != null) allocated.add(ri.Invoice__c);
        }

        Set<Id> deletableIds = new Set<Id>();
        for (Invoice__c inv : oldInvoices) {
            Boolean hasPayment = (inv.Paid_Amount__c != null && inv.Paid_Amount__c > 0) || allocated.contains(inv.Id);
            if (hasPayment) {
                inv.addError(
                    'This invoice has payments allocated to it and cannot be deleted. ' +
                    'Cancel it instead (set Status to Cancelled), or remove its receipt allocations first.'
                );
            } else {
                deletableIds.add(inv.Id);
            }
        }
        if (deletableIds.isEmpty()) {
            return;
        }

        // Free the covered installments for the invoices that are actually being deleted.
        List<Milestone_Invoice__c> links = [
            SELECT Id, Cash_Flow__c FROM Milestone_Invoice__c WHERE Invoice__c IN :deletableIds
        ];
        Set<Id> cashFlowIds = new Set<Id>();
        for (Milestone_Invoice__c mi : links) {
            if (mi.Cash_Flow__c != null) cashFlowIds.add(mi.Cash_Flow__c);
        }
        if (!cashFlowIds.isEmpty()) {
            List<Cash_Flow__c> cfUpdates = new List<Cash_Flow__c>();
            for (Id cfId : cashFlowIds) {
                cfUpdates.add(new Cash_Flow__c(Id = cfId, Is_Invoiced__c = false));
            }
            update cfUpdates;
        }
        if (!links.isEmpty()) {
            delete links;
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
