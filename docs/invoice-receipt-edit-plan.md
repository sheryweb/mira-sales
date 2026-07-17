# Invoice & Receipt System — Edit Functionality & Centralized Calculation Engine

**Status:** Planning / analysis complete. No code written yet. Direction chosen (see §0.1). Some business decisions still open (§7).
**Last updated:** 2026-07-17
**Org:** `working` sandbox (`sheraz.h@miradevelopments.ae.working`, Org Id `00DU9000009K7jJMAS`)
**Repo:** `sheryweb/mira-sales` (branch `main`)

---

## 0.1 Chosen approach — parallel system, shared objects, flag-gated authority (decided 2026-07-17)

Do **not** refactor the live create flows. Build a **parallel system in code** on the **same objects / same records** (no new objects, no cloned/shadow records — that guarantees reports & SOA never mismatch):

- **New, additive code:** a single `FinancialEngine` Apex service (idempotent — re-derives every total from facts, never `current + new`); self-healing triggers on `Receipt__c`, `Receipt_Amount__c`, `Receipt_Invoice__c`, `Milestone_Invoice__c`, `Invoice__c` (insert/update/delete/undelete); new guided edit/remove/delete UI (LWC + flows) with `...RecordUpdate` invocables. The existing create flows and `ReceiptRecordInsert` stay in place, untouched.
- **Authority over the four stored totals is gated by a feature flag** (custom setting / custom metadata, evaluated per-org):
  - **`working` sandbox → flag ON from day one.** The engine + triggers own the four totals immediately so we develop and test real behavior. The old create flow's incremental total-writes are harmlessly re-derived on top (correct value wins).
  - **Production → flag OFF.** Existing processes keep authoring the four totals exactly as today; the engine's trigger writes are suppressed. Zero production risk.
- **Cutover = a single deliberate flip** of the flag per-org, only after sandbox proof + an approved reconciliation report (§4). This transfers authority from the old processes to the new engine with instant rollback (flip back off).

This supersedes the "refactor the create flows to call the engine" framing in §3.5 — that becomes an *optional later* step, not part of the initial parallel build.

---

## 0.2 Architecture facts confirmed by user (2026-07-17)

1. **An invoice is a *collection of Cash Flow items*.** One invoice can cover multiple installments (`Milestone_Invoice__c` = Invoice↔Cash_Flow, many rows per invoice).
2. **Receipts never touch Cash Flow / milestones directly. A receipt contains *invoices*.** Money path is **Receipt → Invoice → (that invoice's) Cash Flow items** — never Receipt → arbitrary installment. This resolves the allocation rule (§7.3): a receipt's money stays *within the invoices it pays*, and inside each invoice maps to that invoice's own Cash Flow items. **No spilling onto unrelated unit installments.** (The old engine's "spill onto the unit's other installments / dump on the last one" behavior is a bug to drop, not preserve.)
3. **UI selection model:**
   - Invoice screen → shows the **Cash Flow items of the Unit** for selection (invoice = chosen installments).
   - Receipt screen → shows the **list of Invoices on the Unit** for selection (receipt = chosen invoices + amounts).
4. **Entry point:** invoice & receipt creation launch from the **Unit record page** (as today). Open to a better surface if one emerges, but Unit is the default.
5. **Commission invoices are OUT OF SCOPE** — separate system (`CommissionInvoiceService` etc.), not part of the invoice/receipt engine.

**Working style (hard requirement):** build **step by step**; every step is announced ("this is the step I'm doing") and done in isolation — never everything in one go. See [[working-style-step-by-step]].

---

## 0. The goal (in the user's words)

Finance can currently only **create** invoices and receipts — never edit them — because creating touches many objects and data, and there is no safe way to edit. Whenever finance needs to edit an invoice/receipt, remove an invoice from a receipt, or reduce/remove a receipt amount on an invoice, they ask the admin (Sheraz), who fixes it **manually**.

The ask is **not just** to add update functionality. It is to **fix the structural flaws and gaps** in the existing invoice/receipt system by building a **centralized system, over the existing metadata**, that owns **all calculation/math on insert, update, and delete** — without destroying existing data, even if flows must be changed.

All five edit scenarios are **common** and must be first-class:
1. Correct an invoice amount (sub-total / VAT)
2. Remove an invoice from a receipt (un-allocate)
3. Reduce / remove a receipt amount applied to an invoice
4. Delete an invoice or receipt entirely
5. Re-parent an invoice (different Unit / Opportunity / Milestone)

---

## 1. The system as it exists today (full study)

### Core objects (7)
| Object | Role |
|---|---|
| `Invoice__c` | Hub. 39 fields. AutoNumber `INV-{0000}` + human `Invoice_Number__c` per project. |
| `Receipt__c` | Hub. 32 fields. AutoNumber `RV-{0}` ("Journal No.") + per-project voucher counters. |
| `Receipt_Amount__c` | **Junction Receipt↔Invoice — the real money.** Amount + cheque/POS/bank detail + `Cumulative_Paid_Amount__c`. |
| `Receipt_Invoice__c` | Junction Receipt↔Invoice — the *allocation link* (Amount + Status). Parallel to the above. |
| `Milestone_Invoice__c` | Junction Invoice↔`Cash_Flow__c` (which installments an invoice covers). |
| `Milestone_Receipt__c` | Junction Receipt↔`Cash_Flow__c` (Amount, Installment_Date, Status). **Created by the payment flow but NEVER read by any Apex — currently dead weight.** |
| `Invoice_Amount__c` | Line-item children of an invoice (Amount breakdown). |

`Cash_Flow__c` = the payment-plan **installment** ("milestone"). It belongs to `Unit__c`.

### Relationship diagram
```
        Opportunity ──┐        ┌── Unit__c ──── Cash_Flow__c (installments; SOA reads these)
                 (lookups)  (lookups)              ▲                ▲
                      ▼        ▼         Milestone_Invoice__c   Milestone_Receipt__c
                    Invoice__c ◄══ Receipt_Invoice__c  ══► Receipt__c
                    (hub)     ◄══ Receipt_Amount__c    ══► (hub)
                      │            (2 parallel junctions)     │
              Invoice_Amount__c                        (payment lines w/ cumulative)
```

### Three facts that cause every problem
1. **All relationships are plain Lookup (`SetNull`). No master-detail anywhere.** → no cascade delete, children orphan, reparenting unrestricted.
2. **Zero native roll-up summary fields.** Every money aggregate is written imperatively by Apex/flow.
3. **The system is WRITE-ONCE.** Totals are computed and stored **only at create time**. Nothing recomputes on edit/delete. **No validation rules, no workflow, no approvals, no guards** exist on any of the 7 objects.

### Four stored aggregates that go stale on any edit/delete
| Field | Written by | Breaks how |
|---|---|---|
| `Invoice__c.Paid_Amount__c` (+ `Status__c`) | `ReceiptRecordInsert` (create only) | Stays inflated; `Pending_Amount__c` (formula off it) and status all wrong |
| `Cash_Flow__c.Received_Amount__c` | `ReceiptRecordInsert.updateCashFlowReceivedAmounts` (create only) | SOA installments stay "received"; wrong Unit/Project totals |
| `Receipt_Amount__c.Cumulative_Paid_Amount__c` | `ReceiptRecordInsert` (create only) | Running-total chain breaks for later payments |
| `Unit__c.Total_Received_Amount__c` | **DLRS rollup** (only self-healing one) | Self-corrects on receipt DML — but reads `Receipt__c.Received_Amount__c`, a *different* number than the per-line amounts, so it can **disagree** with the others |

### Automation inventory
- **Triggers:** `InvoiceTrigger` (before insert only → numbering), `ReceiptTrigger` (before insert only → voucher numbering), `dlrs_ReceiptTrigger` (DLRS rollup, all events). No custom triggers on the junctions. No update/delete logic anywhere.
- **DLRS:** exactly ONE rule touches this system — `Unit_Total_Receipts_Amounts`: SUM of `Receipt__c.Received_Amount__c` → `Unit__c.Total_Received_Amount__c`, filter `Payment_Status__c != 'Cancelled' AND Status__c != 'Unreconciled'`, Realtime.
- **Flows (all Screen flows, finance-launched — none record-triggered):**
  - `Add_New_Invoice_Screen_Flow` — "Create Invoice" quick action on `Unit__c`. Calls Apex `InvoiceRecordInsert`.
  - `Add_New_Payment_Screen_Flow` — "Generate Receipt" quick action on `Unit__c`. Calls Apex `ReceiptRecordInsert` (the real allocation engine). Also builds `Milestone_Receipt__c` rows.
  - `Add_an_Installment_to_Existing_Invoice` — "Add to Invoice" quick action on `Invoice__c`. The only existing write-to-existing pattern.
- **No validation rules / workflow / approvals / Process Builder** on the 7 objects.

### Key Apex
- `ReceiptRecordInsert.cls` — the allocation engine (create only, `@InvocableMethod`). Increments invoice paid amount, sets status, computes cumulative chain, and **waterfalls** each invoice payment across cash-flow installments. **Errors silently swallowed** (line 568).
- `InvoiceRecordInsert.cls` — inserts invoice + `Milestone_Invoice__c` children; no totaling.
- `CommissionInvoiceService` / `CommissionInvoiceController` / `commissionGenerateInvoice` LWC — a **separate** commission-invoice creation path.

### UI surfaces
- Preview LWCs used inside the create flows: `invoicePreviewLWC`, `receiptPreviewLWC`.
- Record-page LWCs: `invoiceEmailSender`, `receiptEmailSender`, `invoicePDFViewer`, `receiptPDFViewer`.
- VF pages (PDF): `InvoicePDF`, `ReceiptPDF`, `InvoiceCommissionPDF`, `BrokerCommissionInvoice`.
- **No edit UI exists** anywhere for invoices/receipts.

---

## 2. The root-cause flaw (the important realization)

The SOA is driven **entirely** by `Cash_Flow__c.Received_Amount__c` — deliberately, because the SOA must show each installment with paid vs. remaining. Meanwhile the actual money lives in `Receipt_Amount__c`. **These two are computed independently, once, at create time, and then forgotten.** They "each carry their own business and don't affect each other" — so they can silently drift, and neither can be reversed.

Reading `ReceiptRecordInsert.updateCashFlowReceivedAmounts` (lines 176–573) confirms the mechanism:

> The engine waterfalls each invoice's payment across installments (first those linked via `Milestone_Invoice__c` in date order; then the unit's other installments chronologically; then dumps leftover on the last installment with a balance) and **stores only the resulting `Received_Amount__c` number. It never records which receipt money landed on which installment.** That mapping is computed and discarded. And every number is **incremental** (`current + new`), so the logic can never simply be re-run without double-counting.

**That discarded mapping is exactly why manual cleanup is required:** on edit/delete there is no record of which installments a receipt's money touched, so it can't be reversed automatically.

---

## 3. Proposed solution — one centralized engine + a durable allocation ledger

Built entirely on existing metadata.

**1. A single Financial Engine (Apex service) — the only place money math happens.** Create flows, edits, deletes, manual corrections, and data-loader imports all route through it. Create and edit stop being separate code paths that can disagree.

**2. Stop incrementing; derive from facts, from scratch (idempotent).** The engine never does `current + new`; it recomputes each total from source records every time:
- `Invoice.Paid_Amount__c` = SUM of its `Receipt_Amount__c` lines (excluding cancelled/unreconciled) → drives `Status__c`; `Pending_Amount__c` self-corrects (formula).
- `Receipt.Received_Amount__c` = SUM of its own lines.
- `Receipt_Amount__c.Cumulative_Paid_Amount__c` = rebuilt by re-ordering that invoice's lines by date.
- Idempotent → running once or ten times yields the same result → update/delete become safe.

**3. Turn `Milestone_Receipt__c` into the allocation ledger — the structural fix.** Instead of discarding the waterfall result, the engine **persists** it as `Milestone_Receipt__c` rows ("X of Receipt R applied to installment C"). Then:
- `Cash_Flow__c.Received_Amount__c` becomes a **derived rollup of `Milestone_Receipt__c.Amount__c`** per installment — recomputable AND reversible.
- **The SOA does not change** — it keeps reading `Cash_Flow.Received_Amount__c`, but that number is now provably reconciled to the receipts instead of floating independently.
- Delete a receipt → its ledger rows vanish → affected installments recompute correctly, automatically.
- This welds the "two separate businesses" back together **without merging them**: Cash Flow stays its own SOA view, but becomes a *consequence* of the receipts, not a parallel guess.

**4. Triggers make it self-healing** on insert/update/delete/undelete for `Receipt__c`, `Receipt_Amount__c`, `Receipt_Invoice__c`, `Milestone_Invoice__c`, `Invoice__c`. However a change arrives, totals converge to correct. (Reuse the existing `skipTrigger` recursion-guard pattern.)

**5. Refactor the create flows to call the engine.** Flows keep the UI/data-gathering; the engine owns the math. (User has approved changing flows.)

With this, all five edit scenarios and SOA correctness fall out automatically — each is just *"facts changed → re-derive."*

---

## 4. Data-safety boundary ("without affecting existing data")

Two tiers:
- **Facts / real records — never touched destructively:** receipts, invoices, amounts, payment details, junctions, invoice numbers, voucher numbers — preserved exactly.
- **Derived totals — recomputed to correct values.** Where a total has drifted (likely, given write-once), the engine corrects it. That is the intended fix.

**Guarantee:** before any production data is written, run the engine in **dry-run mode** and produce a **reconciliation report** — every record whose recomputed value differs from stored, old → new — **for user review and approval**. Nothing changes silently.

---

## 5. Phased plan (all built & verified in `working` sandbox first)

- **Phase 0 — Safety net.** Characterization tests capturing *current* create behavior + a dry-run reconciliation harness. Prove the refactor changes nothing about creation.
- **Phase 1 — Engine + allocation ledger + self-healing triggers.** Biggest payoff: most manual cleanup disappears here. Extract forward math out of `ReceiptRecordInsert` into the shared engine.
- **Phase 2 — Guided edit / remove / delete UI** (LWC + flows) on the Invoice and Receipt record pages, reusing `invoicePreviewLWC` / `receiptPreviewLWC`. New `...RecordUpdate` invocables paralleling the `...RecordInsert` ones.
- **Phase 3 — Controlled permissions + validation rules.** A permission set giving finance edit only via guided actions; FLS locks numbering fields; add the guardrail validation rules that don't exist today (no negatives, no overpay, locked fields).
- **Phase 4 — Backfill existing data** (after approving the reconciliation report), then deploy to production.

---

## 6. Notable risks / things to fix along the way
- `ReceiptRecordInsert` **swallows all cash-flow errors** (line 568) — must surface/handle properly in the engine.
- **Two parallel Receipt↔Invoice junctions** (`Receipt_Amount__c` + `Receipt_Invoice__c`) must be kept in sync by the engine (recommend `Receipt_Amount__c` as the money source of truth).
- Cross-currency invoices (POST/CHF, `Secondary_Currency__c`) must be preserved on edit.
- Numbering gaps on delete are acceptable (don't reuse numbers — preserves audit trail).
- Commission-invoice path is separate — decide if in scope (§7.4).

---

## 7. OPEN DECISIONS

> **RESOLVED 2026-07-17 — coexistence model:** parallel code on shared objects, four totals' authority flag-gated (sandbox ON, production OFF until cutover). See §0.1.

Still open:

1. **Reconciliation report before backfill** — confirm the tiered data-safety approach in §4 is acceptable (facts preserved; drifted totals corrected only after you approve a diff report).

2. **`Milestone_Receipt__c` as the allocation ledger** — OK to make it the durable receipt→installment record (currently unused in code)? Any existing reason it's populated the way it is that must be preserved?

3. **The allocation rule** — **RESOLVED 2026-07-17 (§0.2.2):** money stays within the invoices a receipt pays; inside each invoice it maps to that invoice's own Cash Flow items (via `Milestone_Invoice__c`), no spilling onto unrelated unit installments. *Still to confirm: ordering within an invoice's own items (oldest-installment-first) and behavior when a receipt over-pays an invoice.*

4. **Delete vs. Cancel** — Recommend soft-**cancel** (keep record + number, set `Cancelled`, which the DLRS filter already respects) as the default, with hard-delete reserved for genuine mistakes. *(Commission invoices: RESOLVED — out of scope, §0.2.5.)*

---

## 8. Where we left off / next step
**STEP 1 (metadata ground-truth) DONE 2026-07-17** — field map in Appendix A.
**STEP 2 (feature flag) DONE 2026-07-17** — created `Financial_Engine_Settings__c` (Hierarchy Custom Setting) with checkbox `Engine_Owns_Totals__c` (default `false`). Deployed to `working`; org-default set to `true` there (verified). Prod defaults `false`. Nothing reads it yet — inert until the engine references it. The engine/triggers must gate all total-writes on `Financial_Engine_Settings__c.getOrgDefaults().Engine_Owns_Totals__c`.
**Next: Step 3 — Phase 0 safety net** (characterization tests of current create behavior + dry-run reconciliation harness). Remaining behavioral micro-decisions (§7.1, §7.3 ordering/overpay, §7.4 delete-vs-cancel) settle at their build step. No product code written yet.

---

## Appendix A — Metadata field map (Step 1, 2026-07-17)

**Engine WRITE surface (plain stored fields — must be maintained by the engine):**
- `Invoice__c.Paid_Amount__c` (Currency) + `Invoice__c.Status__c` (**picklist, restricted global valueset `Payment_Status` — NOT a formula, engine must set it**)
- `Receipt__c.Received_Amount__c` (Currency)
- `Receipt_Amount__c.Amount__c` + `Receipt_Amount__c.Cumulative_Paid_Amount__c` (both Currency, plain stored)
- `Cash_Flow__c.Received_Amount__c` (Currency) — **the only stored field on Cash Flow the engine touches**

**Auto-correcting (formula — engine never writes):**
- `Invoice__c.Pending_Amount__c` = `(VAT_Amount__c + Sub_Total_Amount__c) - Paid_Amount__c`; `Grand_Total_Formula__c` identical.
- `Receipt__c.Balance__c` = `IF(Payable_Amount__c - Received_Amount__c < 0, 0, Payable_Amount__c - Received_Amount__c)`
- `Cash_Flow__c.Balance__c` = `Price_Formula__c - Received_Amount__c`; `Remaining_Amount__c`, `Status__c`, `Payment_Status_Formula__c`, `Installment_Status__c` all derive Pending/Partially/Fully Paid from `Received_Amount__c` vs `Price_Formula__c`.

**Relationships (all Lookup/SetNull unless noted):**
- `Receipt_Amount__c`: `Receipt__c`→Receipt__c, `Invoice__c`→Invoice__c. Money source of truth (`Amount__c`, `Cumulative_Paid_Amount__c`).
- `Receipt_Invoice__c`: `Receipt__c`→Receipt__c, `Invoice__c`→Invoice__c. Also carries `Amount__c` + `Status__c` picklist — engine keeps in sync with Receipt_Amount__c.
- `Milestone_Invoice__c`: `Invoice__c`→Invoice__c, `Cash_Flow__c`→Cash_Flow__c. `Amount__c`, `Installment_Date__c`. (Invoice = collection of cash-flow items lives here.)
- `Milestone_Receipt__c`: `Receipt__c`→Receipt__c, `Cash_Flow__c`→Cash_Flow__c. `Amount__c`, `Status__c`, `Installment_Date__c`. **No Invoice lookup today → likely ADD `Invoice__c` lookup to use it as the reversible allocation ledger (Receipt→Invoice→Cash Flow).**
- `Cash_Flow__c`: `Unit__c` **MasterDetail** (cascade) + `Cash_Flow_Sum__c` MasterDetail. Only master-detail in the set.
- `Invoice__c`: Lookups Account, Opportunity, Unit__c, Financial_Detail__c (all SetNull). `Receipt__c`: Lookups Account, Opportunity, Unit__c.

**Feature-flag home:** none exists. Two Hierarchy custom settings present (`Broker_Portal_Settings__c`, `In_App_Checklist_Settings__c`). **Decision: create a NEW Hierarchy Custom Setting for the engine flag** — its value is data (not deployed metadata), so sandbox=ON / prod=OFF is set per-org with no deploy leaking the value. (A CMDT record would deploy its value across orgs — wrong for a per-org switch.)
