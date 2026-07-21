# Project Numbering (Custom Metadata driven)

Invoice numbers and receipt voucher numbers are per-project sequences. This used
to require hardcoded Apex + a per-project formula branch for every project. It is
now driven by the **`Project_Numbering_Setting__mdt`** custom metadata plus a
single sequence field per object, so onboarding a new project is configuration,
not code.

## How numbering works now

| | Field that stores the number | How it's built |
|---|---|---|
| **Invoice** | `Invoice__c.Invoice_Number__c` (Text) | Set on before-insert by `InvoiceTriggerHelper`: `Invoice_Prefix__c` + `Invoice_Seq__c`, e.g. `INV-TRD2-86`. |
| **Receipt** | `Receipt__c.Voucher_Number__c` (Formula) | `'RV-' & Unit.Project.Voucher_Code__c & '-' & TEXT(Voucher_Seq__c)`, e.g. `RV-TR2-87`. Sequence assigned on before-insert by `ReceiptTriggerHelper`. |

Key points:
- **`Invoice_Seq__c` / `Voucher_Seq__c`** (Number, 18,0) are the single per-project
  counters. They replace the old per-project `Invoice_Number_To_Process_*` /
  `Voucher_Number_To_Process_*` fields.
- The sequence for a project continues from `MAX(seq)` across existing records for
  that project (matched by `Unit__r.Project_Name_F__c`), incremented per new record.
- The **invoice prefix** and the **receipt code** are independent per project
  (e.g. Trussardi 2 = invoice `INV-TRD2-`, receipt code `TR2`; Gianfranco =
  invoice `INV-GFF-`, receipt code `GF`).
- A record whose Unit/project is missing or has **no active CMDT row** gets no
  number — same as the legacy behavior for unrecognized projects.
- The numbering is trigger-driven, so it applies identically whether a record is
  created by the legacy Flows or the new LWC create wizards.

## `Project_Numbering_Setting__mdt` fields

| Field | Purpose |
|---|---|
| `Project_Name__c` | Join key — must exactly equal the Unit's `Project_Name_F__c` value. |
| `Invoice_Prefix__c` | Invoice number prefix, e.g. `INV-TRD2-`. |
| `Invoice_Prefix_Retail__c` | Optional. Used instead of `Invoice_Prefix__c` when the Unit's `Type__c` is `Retail`. See "T2 retail" below. |
| `Active__c` | Only active rows are recognized. |

The **receipt code lives on `Project__c.Voucher_Code__c`** (data on the Project),
because the `Voucher_Number__c` formula reads it directly (formulas can't read
custom metadata). Presence of an active CMDT row is what makes a project eligible
for a voucher sequence.

## Onboarding a new project

1. **Add a `Project_Numbering_Setting__mdt` record** (Setup → Custom Metadata Types
   → Project Numbering Setting → Manage Records, or deploy a `.md-meta.xml`):
   - `Project_Name__c` = the exact project name as it appears in `Project_Name_F__c`.
   - `Invoice_Prefix__c` = the invoice prefix (include the trailing `-`), e.g. `INV-XYZ-`.
   - `Active__c` = true.
2. **Set `Voucher_Code__c` on the `Project__c` record** = the receipt code, e.g. `XYZ`.
   Receipt vouchers will read `RV-<code>-<seq>`.
3. Done — no Apex, field, or formula change.

That's the whole change: **1 CMDT row + 1 Project field**.

## T2 Offices "retail" special case

`Trussardi Residences 2 Offices` has two invoice prefixes historically:
`INV-TR2-Office-` and `INV-TR2-Retail-`, and receipts use `RV-TR2-Retail-` for
Retail-type units.

- **Receipts**: the `Voucher_Number_Retail__c` formula still emits
  `RV-TR2-Retail-<seq>` for Retail-type T2 units (preserved).
- **Invoices**: the legacy retail branch never actually fired (it read an
  unpopulated parent relationship on before-insert), so every T2 invoice was
  `INV-TR2-Office-`. To keep exact parity, the T2 CMDT row leaves
  `Invoice_Prefix_Retail__c` **empty**, so T2 invoices continue to use the Office
  prefix. To enable retail invoice numbering later, simply set
  `Invoice_Prefix_Retail__c = INV-TR2-Retail-` on that row (no code change).

## Production cutover sequence (org with existing data)

The `working` sandbox has no invoice/receipt data, so nothing below applies there —
it was validated with test data only. For **production** (or any org with existing
records), run the steps **in this order**, because existing receipt vouchers are a
formula that will recompute the moment the new formula is deployed:

1. **Deploy the new fields first**: `Invoice_Seq__c`, `Voucher_Seq__c`, and the
   `Project_Numbering_Setting__mdt` type + records. (Safe: nothing reads them yet.)
2. **Backfill the sequences** from the legacy counters, via `NumberingSeqBackfillBatch`:
   ```apex
   Database.executeBatch(NumberingSeqBackfillBatch.forInvoices(), 200);
   Database.executeBatch(NumberingSeqBackfillBatch.forReceipts(), 200);
   ```
   This copies each record's populated per-project counter into the new single
   field. Existing invoice numbers (frozen Text) are untouched; the backfill only
   preserves sequence continuity so the next new invoice doesn't restart at 1.
3. **Verify** the backfill: no receipt with a legacy counter should have a null
   `Voucher_Seq__c`; spot-check that `Voucher_Number__c` still renders the same
   string it did before.
4. **Deploy the code + formula change**: `InvoiceTriggerHelper`,
   `ReceiptTriggerHelper`, `Voucher_Number__c`, `Voucher_Number_Retail__c`.
   After this, existing receipts recompute from `Voucher_Seq__c` (identical output),
   and new records number via the CMDT.

Doing step 4 before step 2 would leave existing receipts briefly showing
`RV-<code>-0`, so keep the order.

## After cutover (optional cleanup)

The legacy per-project fields (`Invoice_Number_To_Process_*`,
`Voucher_Number_To_Process_*`) are no longer written or read by code once the
backfill is done. They can be retired in a later release; they are kept for now so
the backfill can read them and for rollback safety.

## Notes

- The new `*_Seq__c` fields are internal counters; formulas don't need field-level
  security, and `Invoice_Number__c` is set in Apex. Grant FLS on the seq fields
  only if you want admins/finance to see them on layouts.
- Tests: `InvoiceTriggerHelperTest`, `ReceiptTriggerHelperTest`,
  `NumberingSeqBackfillBatchTest`.
