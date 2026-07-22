/**
 * One-time migration: backfills the single-sequence fields (Invoice_Seq__c /
 * Voucher_Seq__c) from the legacy per-project counter fields
 * (Invoice_Number_To_Process_* / Voucher_Number_To_Process_*).
 *
 * IMPORTANT: the legacy data sometimes has MORE THAN ONE per-project counter
 * populated on a single record (stray values). The old number formula/trigger
 * always read the counter for the record's OWN project, so this batch must do the
 * same — pick the counter field that matches Unit.Project_Name_F__c, NOT the first
 * non-null one. (An earlier version took first-non-null and mis-set records that
 * carried a stray counter from another project.)
 *
 * WHEN: run once per object, BEFORE the numbering formula/trigger change goes live
 * in an org that already holds data (production). Idempotent — safe to re-run; it
 * only writes when the correct value differs from what's stored.
 *
 * Usage (anonymous Apex):
 *   Database.executeBatch(NumberingSeqBackfillBatch.forInvoices(), 200);
 *   Database.executeBatch(NumberingSeqBackfillBatch.forReceipts(), 200);
 */
public class NumberingSeqBackfillBatch implements Database.Batchable<SObject> {

    private final String objectName;
    private final String seqField;
    private final Map<String, String> counterByProject; // project name -> legacy counter field

    private static final Map<String, String> INVOICE_COUNTER_BY_PROJECT = new Map<String, String>{
        'Trussardi Residences'                 => 'Invoice_Number_To_Process_Trussardi__c',
        'Trussardi Residences 2'               => 'Invoice_Number_To_Process_Trussardi2__c',
        'MIRA Villas Designed by Bentley Home' => 'Invoice_Number_To_Process_Bentley__c',
        'POST HOTEL & RESIDENCES By ELIE SAAB' => 'Invoice_Number_To_Process_POST__c',
        'GIANFRANCO FERRE RESIDENCES'          => 'Invoice_Number_To_Process_Gianfranco__c',
        'Trussardi Residences 2 Offices'       => 'Invoice_Number_To_Process_T2_Offices__c',
        'Trussardi Residences MIRA VERDE'      => 'Invoice_Number_To_Process_MIRA_VERDE__c',
        'John Richmond Residences'             => 'Invoice_Number_To_Process_Richmond__c'
    };

    private static final Map<String, String> RECEIPT_COUNTER_BY_PROJECT = new Map<String, String>{
        'Trussardi Residences'                 => 'Voucher_Number_To_Process_Trussardi__c',
        'Trussardi Residences 2'               => 'Voucher_Number_To_Process_Trussardi2__c',
        'MIRA Villas Designed by Bentley Home' => 'Voucher_Number_To_Process_Bentley__c',
        'POST HOTEL & RESIDENCES By ELIE SAAB' => 'Voucher_Number_To_Process_POST__c',
        'GIANFRANCO FERRE RESIDENCES'          => 'Voucher_Number_To_Process_Gianfranco__c',
        'Trussardi Residences 2 Offices'       => 'Voucher_Number_To_Process_T2_Offices__c',
        'Trussardi Residences MIRA VERDE'      => 'Voucher_Number_To_Process_MIRA_VERDE__c',
        'John Richmond Residences'             => 'Voucher_Number_To_Process_Richmond__c'
    };

    private NumberingSeqBackfillBatch(String objectName, String seqField, Map<String, String> counterByProject) {
        this.objectName = objectName;
        this.seqField = seqField;
        this.counterByProject = counterByProject;
    }

    public static NumberingSeqBackfillBatch forInvoices() {
        return new NumberingSeqBackfillBatch('Invoice__c', 'Invoice_Seq__c', INVOICE_COUNTER_BY_PROJECT);
    }

    public static NumberingSeqBackfillBatch forReceipts() {
        return new NumberingSeqBackfillBatch('Receipt__c', 'Voucher_Seq__c', RECEIPT_COUNTER_BY_PROJECT);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Set<String> projectNames = counterByProject.keySet();
        Set<String> fieldSet = new Set<String>{ 'Id', seqField, 'Unit__r.Project_Name_F__c' };
        fieldSet.addAll(counterByProject.values());
        // Process every record that belongs to a recognized project; execute() only
        // writes when the correct (own-project) value differs from what is stored.
        String q = 'SELECT ' + String.join(new List<String>(fieldSet), ', ') +
                   ' FROM ' + objectName +
                   ' WHERE Unit__r.Project_Name_F__c IN :projectNames';
        return Database.getQueryLocator(q);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<SObject> toUpdate = new List<SObject>();
        for (SObject rec : scope) {
            SObject unit = rec.getSObject('Unit__r');
            String projectName = (unit == null) ? null : (String) unit.get('Project_Name_F__c');
            if (projectName == null || !counterByProject.containsKey(projectName)) {
                continue;
            }
            // The correct sequence is the counter for the record's OWN project (may be null,
            // which faithfully reproduces the old formula's blank-as-zero behavior).
            Object v = rec.get(counterByProject.get(projectName));
            Decimal correctSeq = (v == null) ? null : (Decimal) v;

            Object current = rec.get(seqField);
            Decimal currentSeq = (current == null) ? null : (Decimal) current;

            if (correctSeq != currentSeq) {
                rec.put(seqField, correctSeq);
                toUpdate.add(rec);
            }
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Intentionally empty. Run the two batches independently.
    }
}
