/**
 * One-time migration: backfills the single-sequence fields (Invoice_Seq__c /
 * Voucher_Seq__c) from the legacy per-project counter fields
 * (Invoice_Number_To_Process_* / Voucher_Number_To_Process_*).
 *
 * WHY: the CMDT-driven numbering (InvoiceTriggerHelper / ReceiptTriggerHelper)
 * continues each project's sequence from MAX(Invoice_Seq__c|Voucher_Seq__c), and
 * the Voucher_Number__c formula now reads Voucher_Seq__c. Existing records must
 * carry their current counter value in the new field so that (a) new numbers keep
 * counting up instead of colliding at 1, and (b) existing receipt vouchers
 * recompute to the exact same string.
 *
 * WHEN: run once per object, BEFORE the numbering formula/trigger change goes live
 * in an org that already holds data (production). The working sandbox has no
 * invoice/receipt data, so this is a no-op there.
 *
 * Usage (anonymous Apex):
 *   Database.executeBatch(NumberingSeqBackfillBatch.forInvoices(), 200);
 *   Database.executeBatch(NumberingSeqBackfillBatch.forReceipts(), 200);
 */
public class NumberingSeqBackfillBatch implements Database.Batchable<SObject> {

    private final String objectName;
    private final String seqField;
    private final List<String> legacyFields;

    private NumberingSeqBackfillBatch(String objectName, String seqField, List<String> legacyFields) {
        this.objectName = objectName;
        this.seqField = seqField;
        this.legacyFields = legacyFields;
    }

    public static NumberingSeqBackfillBatch forInvoices() {
        return new NumberingSeqBackfillBatch(
            'Invoice__c',
            'Invoice_Seq__c',
            new List<String>{
                'Invoice_Number_To_Process_Trussardi__c',
                'Invoice_Number_To_Process_Trussardi2__c',
                'Invoice_Number_To_Process_Bentley__c',
                'Invoice_Number_To_Process_POST__c',
                'Invoice_Number_To_Process_Gianfranco__c',
                'Invoice_Number_To_Process_T2_Offices__c',
                'Invoice_Number_To_Process_MIRA_VERDE__c',
                'Invoice_Number_To_Process_Richmond__c'
            }
        );
    }

    public static NumberingSeqBackfillBatch forReceipts() {
        return new NumberingSeqBackfillBatch(
            'Receipt__c',
            'Voucher_Seq__c',
            new List<String>{
                'Voucher_Number_To_Process_Trussardi__c',
                'Voucher_Number_To_Process_Trussardi2__c',
                'Voucher_Number_To_Process_Bentley__c',
                'Voucher_Number_To_Process_POST__c',
                'Voucher_Number_To_Process_Gianfranco__c',
                'Voucher_Number_To_Process_T2_Offices__c',
                'Voucher_Number_To_Process_MIRA_VERDE__c',
                'Voucher_Number_To_Process_Richmond__c'
            }
        );
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        List<String> selectFields = new List<String>{ 'Id', seqField };
        selectFields.addAll(legacyFields);

        List<String> notNullClauses = new List<String>();
        for (String f : legacyFields) {
            notNullClauses.add(f + ' != null');
        }

        String q = 'SELECT ' + String.join(selectFields, ', ') +
                   ' FROM ' + objectName +
                   ' WHERE ' + seqField + ' = null' +
                   ' AND (' + String.join(notNullClauses, ' OR ') + ')';
        return Database.getQueryLocator(q);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        // Numbering only runs on before-insert; this batch does updates, so the
        // numbering helpers never fire. Bypass the financial engine so a pure
        // numbering backfill does not recompute stored totals.
        FinancialEngine.bypass = true;

        List<SObject> toUpdate = new List<SObject>();
        for (SObject rec : scope) {
            // A record only ever has one project's legacy counter populated;
            // take the first non-null.
            Decimal seq = null;
            for (String f : legacyFields) {
                Object v = rec.get(f);
                if (v != null) {
                    seq = (Decimal) v;
                    break;
                }
            }
            if (seq != null) {
                rec.put(seqField, seq);
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
