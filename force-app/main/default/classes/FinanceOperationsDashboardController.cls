/**
 * FinanceOperationsDashboardController — data + actions for the Finance Center's
 * "Invoice & Receipt Operations" dashboard (financeOperationsDashboard LWC).
 *
 * WITHOUT SHARING, deliberately: org-wide operations view gated by the Finance_Center_Access
 * permission set (same justification as the other dashboard controllers).
 *
 * CURRENCY: volume tiles, the method split and DQ money totals combine projects -> AED at
 * read time; the PDC calendar rows, unallocated queue and cancellation rows are per record,
 * so they carry the project currency.
 *
 * The data-quality panel is the trust anchor: live targeted checks (over-receipt, negative
 * remaining, duplicate numbers, unbilled receipts, invoices without a unit), the nightly
 * snapshot's plan/instalment checks, and a live FinancialReconciliation dry-run over a sample
 * of recently-touched units (stored vs engine-derived).
 */
public without sharing class FinanceOperationsDashboardController {

    private static final Set<String> SALES_STATUSES = new Set<String>{ 'Booked', 'Reserved', 'Sold' };
    private static final Set<String> BRS_STAGES = new Set<String>{ 'Booked', 'Reserved', 'Sold' };
    private static final Decimal TOLERANCE = 0.005;
    private static final Integer METHOD_SPLIT_DAYS = 90;
    private static final Integer PDC_LIST_DAYS = 30;
    private static final Integer PDC_WEEKS = 8;
    private static final Integer CANCEL_WINDOW_DAYS = 90;
    private static final Integer LIST_LIMIT = 25;
    private static final Integer DQ_SAMPLE_LIMIT = 10;
    private static final Integer RECON_SAMPLE_UNITS = 20;
    private static final Set<String> CHEQUE_STATUSES =
        new Set<String>{ 'Received', 'Deposited', 'Cleared', 'Bounced', 'Replaced' };

    // ---------------------------------------------------------------- DTOs ----

    public class DashboardData {
        @AuraEnabled public Datetime ratesAsOf;
        @AuraEnabled public List<VolumeRow> volume = new List<VolumeRow>();
        @AuraEnabled public List<MethodSlice> methodSplit = new List<MethodSlice>();
        @AuraEnabled public List<PdcWeek> pdcWeeks = new List<PdcWeek>();
        @AuraEnabled public List<ChequeRow> pdcUpcoming = new List<ChequeRow>();
        @AuraEnabled public List<ChequeRow> bounced = new List<ChequeRow>();
        @AuraEnabled public List<UnallocRow> unallocated = new List<UnallocRow>();
        @AuraEnabled public Integer cancelledInvoices = 0;
        @AuraEnabled public Integer cancelledReceipts = 0;
        @AuraEnabled public Integer pendingApprovals = 0;
        @AuraEnabled public List<CancelRow> cancellations = new List<CancelRow>();
        @AuraEnabled public List<SoaLogRow> soaLog = new List<SoaLogRow>();
        @AuraEnabled public List<SoaTarget> soaTargets = new List<SoaTarget>();
        @AuraEnabled public List<DqCheck> dqChecks = new List<DqCheck>();
        @AuraEnabled public Integer reconUnitsScanned = 0;
        @AuraEnabled public Integer reconDiffCount = 0;
    }

    public class VolumeRow {
        @AuraEnabled public String scope;
        @AuraEnabled public Integer invoices = 0;
        @AuraEnabled public Decimal invoicedAed = 0;
        @AuraEnabled public Integer receipts = 0;
        @AuraEnabled public Decimal collectedAed = 0;
        public VolumeRow(String s) { scope = s; }
    }

    public class MethodSlice {
        @AuraEnabled public String mode;
        @AuraEnabled public Integer lines = 0;
        @AuraEnabled public Decimal amountAed = 0;
    }

    public class PdcWeek {
        @AuraEnabled public String label;
        @AuraEnabled public Date weekStart;
        @AuraEnabled public Integer cheques = 0;
        @AuraEnabled public Decimal amountAed = 0;
    }

    public class ChequeRow {
        @AuraEnabled public String lineId;
        @AuraEnabled public String chequeNumber;
        @AuraEnabled public String bank;
        @AuraEnabled public Date chequeDate;
        @AuraEnabled public Decimal amount = 0;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String unitName;
        @AuraEnabled public String accountName;
        @AuraEnabled public String status;
    }

    public class UnallocRow {
        @AuraEnabled public String receiptId;
        @AuraEnabled public String voucher;
        @AuraEnabled public String unitName;
        @AuraEnabled public String projectName;
        @AuraEnabled public String accountName;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public Decimal received = 0;
        @AuraEnabled public Decimal unapplied = 0;
        @AuraEnabled public Date paymentDate;
    }

    public class CancelRow {
        @AuraEnabled public String recordId;
        @AuraEnabled public String kind;   // Invoice / Receipt
        @AuraEnabled public String label;
        @AuraEnabled public String unitName;
        @AuraEnabled public Decimal amount = 0;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String reason;
        @AuraEnabled public Datetime cancelledOn;
    }

    public class SoaLogRow {
        @AuraEnabled public String name;
        @AuraEnabled public Datetime sentOn;
        @AuraEnabled public String sentBy;
        @AuraEnabled public String accountName;
        @AuraEnabled public String unitName;
        @AuraEnabled public String channel;
        @AuraEnabled public String result;
        @AuraEnabled public Boolean isSuccess = false;
    }

    public class SoaTarget {
        @AuraEnabled public String opportunityId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String unitName;
    }

    public class DqCheck {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public Integer count = 0;
        @AuraEnabled public String note;
        @AuraEnabled public List<String> examples = new List<String>();
        public DqCheck(String k, String l, String n) { key = k; label = l; note = n; }
    }

    // ------------------------------------------------------------- reads ----

    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        try {
            DashboardData data = new DashboardData();
            data.ratesAsOf = CurrencyService.lastRefreshed();
            Date today = Date.today();
            Date weekStart = today.toStartOfWeek();
            Date monthStart = today.toStartOfMonth();

            // ---- volume matrix: today / WTD / MTD ----
            VolumeRow vToday = new VolumeRow('Today');
            VolumeRow vWtd = new VolumeRow('WTD');
            VolumeRow vMtd = new VolumeRow('MTD');
            data.volume.add(vToday); data.volume.add(vWtd); data.volume.add(vMtd);
            Date volumeFrom = monthStart < weekStart ? monthStart : weekStart;
            for (Invoice__c inv : [
                SELECT Invoice_Date__c, Sub_Total_Amount__c, VAT_Amount__c,
                       Unit__r.Project__r.Project_Currency__c
                FROM Invoice__c
                WHERE Invoice_Date__c >= :volumeFrom AND Status__c != 'Cancelled'
            ]) {
                Decimal amountAed = toAed(nz(inv.Sub_Total_Amount__c) + nz(inv.VAT_Amount__c),
                    inv.Unit__r == null ? null : inv.Unit__r.Project__r.Project_Currency__c);
                if (inv.Invoice_Date__c >= monthStart) { vMtd.invoices++; vMtd.invoicedAed += amountAed; }
                if (inv.Invoice_Date__c >= weekStart) { vWtd.invoices++; vWtd.invoicedAed += amountAed; }
                if (inv.Invoice_Date__c == today) { vToday.invoices++; vToday.invoicedAed += amountAed; }
            }
            for (Receipt__c r : [
                SELECT Payment_Date__c, Received_Amount__c, Unit__r.Project__r.Project_Currency__c
                FROM Receipt__c
                WHERE Payment_Date__c >= :volumeFrom
                  AND Payment_Status__c != 'Cancelled' AND Status__c != 'Unreconciled'
            ]) {
                Decimal amountAed = toAed(nz(r.Received_Amount__c),
                    r.Unit__r == null ? null : r.Unit__r.Project__r.Project_Currency__c);
                if (r.Payment_Date__c >= monthStart) { vMtd.receipts++; vMtd.collectedAed += amountAed; }
                if (r.Payment_Date__c >= weekStart) { vWtd.receipts++; vWtd.collectedAed += amountAed; }
                if (r.Payment_Date__c == today) { vToday.receipts++; vToday.collectedAed += amountAed; }
            }

            // ---- receipt method split (last 90 days) + PDC calendar + bounced list ----
            Map<String, MethodSlice> sliceByMode = new Map<String, MethodSlice>();
            Map<Date, PdcWeek> weekByStart = new Map<Date, PdcWeek>();
            PdcWeek later = new PdcWeek();
            later.label = 'Beyond ' + PDC_WEEKS + ' weeks';
            for (Integer i = 0; i < PDC_WEEKS; i++) {
                Date ws = weekStart.addDays(i * 7);
                PdcWeek wk = new PdcWeek();
                wk.weekStart = ws;
                wk.label = 'Wk of ' + ws.format();
                weekByStart.put(ws, wk);
                data.pdcWeeks.add(wk);
            }
            data.pdcWeeks.add(later);
            for (Receipt_Amount__c line : [
                SELECT Id, Amount__c, Mode_of_Payment__c, Cheque_Number__c, Cheque_Date__c,
                       Bank_Name__c, Cheque_Status__c,
                       Receipt__r.Payment_Date__c, Receipt__r.Account__r.Name,
                       Receipt__r.Unit__r.Title__c, Receipt__r.Unit__r.Name,
                       Receipt__r.Unit__r.Project__r.Project_Currency__c
                FROM Receipt_Amount__c
                WHERE Receipt__r.Payment_Status__c != 'Cancelled'
                  AND Receipt__r.Status__c != 'Unreconciled'
                  AND (Receipt__r.Payment_Date__c >= :today.addDays(-METHOD_SPLIT_DAYS)
                       OR (Mode_of_Payment__c = 'Cheque' AND Cheque_Date__c >= :today)
                       OR Cheque_Status__c = 'Bounced')
            ]) {
                String ccy = line.Receipt__r.Unit__r == null ? null
                    : line.Receipt__r.Unit__r.Project__r.Project_Currency__c;

                // method split window
                if (line.Receipt__r.Payment_Date__c != null
                    && line.Receipt__r.Payment_Date__c >= today.addDays(-METHOD_SPLIT_DAYS)
                    && nz(line.Amount__c) > 0) {
                    String mode = String.isBlank(line.Mode_of_Payment__c) ? 'Unspecified' : line.Mode_of_Payment__c;
                    MethodSlice slice = sliceByMode.get(mode);
                    if (slice == null) {
                        slice = new MethodSlice();
                        slice.mode = mode;
                        sliceByMode.put(mode, slice);
                    }
                    slice.lines++;
                    slice.amountAed += toAed(line.Amount__c, ccy);
                }

                Boolean isCheque = line.Mode_of_Payment__c == 'Cheque';
                if (isCheque && line.Cheque_Date__c != null && line.Cheque_Date__c >= today
                    && line.Cheque_Status__c != 'Bounced' && line.Cheque_Status__c != 'Replaced'
                    && line.Cheque_Status__c != 'Cleared') {
                    Date ws = line.Cheque_Date__c.toStartOfWeek();
                    PdcWeek wk = weekByStart.containsKey(ws) ? weekByStart.get(ws) : later;
                    wk.cheques++;
                    wk.amountAed += toAed(nz(line.Amount__c), ccy);
                    if (line.Cheque_Date__c <= today.addDays(PDC_LIST_DAYS)
                        && data.pdcUpcoming.size() < LIST_LIMIT) {
                        data.pdcUpcoming.add(chequeRow(line, ccy));
                    }
                }
                if (line.Cheque_Status__c == 'Bounced' && data.bounced.size() < LIST_LIMIT) {
                    data.bounced.add(chequeRow(line, ccy));
                }
            }
            data.methodSplit = sliceByMode.values();

            // ---- unallocated / on-account work queue ----
            buildUnallocatedQueue(data);

            // ---- cancellations & approvals ----
            Datetime cancelWindow = Datetime.now().addDays(-CANCEL_WINDOW_DAYS);
            for (Invoice__c inv : [
                SELECT Id, Invoice_Number__c, Name, Grand_Total_Amount__c, LastModifiedDate,
                       Unit__r.Title__c, Unit__r.Project__r.Project_Currency__c
                FROM Invoice__c
                WHERE Status__c = 'Cancelled' AND LastModifiedDate >= :cancelWindow
                ORDER BY LastModifiedDate DESC
            ]) {
                data.cancelledInvoices++;
                if (data.cancellations.size() < LIST_LIMIT) {
                    CancelRow row = new CancelRow();
                    row.recordId = inv.Id;
                    row.kind = 'Invoice';
                    row.label = String.isBlank(inv.Invoice_Number__c) ? inv.Name : inv.Invoice_Number__c;
                    row.unitName = inv.Unit__r == null ? null : inv.Unit__r.Title__c;
                    row.amount = nz(inv.Grand_Total_Amount__c);
                    row.currencyCode = projectCcy(inv.Unit__r == null ? null : inv.Unit__r.Project__r.Project_Currency__c);
                    row.cancelledOn = inv.LastModifiedDate;
                    data.cancellations.add(row);
                }
            }
            for (Receipt__c r : [
                SELECT Id, Name, Voucher_Number__c, Received_Amount__c, Payable_Amount__c,
                       Cancellation_Reason__c, LastModifiedDate,
                       Unit__r.Title__c, Unit__r.Project__r.Project_Currency__c
                FROM Receipt__c
                WHERE Payment_Status__c = 'Cancelled' AND LastModifiedDate >= :cancelWindow
                ORDER BY LastModifiedDate DESC
            ]) {
                data.cancelledReceipts++;
                if (data.cancellations.size() < LIST_LIMIT * 2) {
                    CancelRow row = new CancelRow();
                    row.recordId = r.Id;
                    row.kind = 'Receipt';
                    row.label = String.isBlank(r.Voucher_Number__c) ? r.Name : r.Voucher_Number__c;
                    row.unitName = r.Unit__r == null ? null : r.Unit__r.Title__c;
                    row.amount = nz(r.Payable_Amount__c);
                    row.currencyCode = projectCcy(r.Unit__r == null ? null : r.Unit__r.Project__r.Project_Currency__c);
                    row.reason = r.Cancellation_Reason__c;
                    row.cancelledOn = r.LastModifiedDate;
                    data.cancellations.add(row);
                }
            }
            data.pendingApprovals = [
                SELECT COUNT() FROM Approval_Request__c WHERE Status__c IN ('Pending', 'In Process')
            ];

            // ---- SOA log + bulk targets ----
            for (SOA_Log__c log : [
                SELECT Name, CreatedDate, CreatedBy.Name, Account__r.Name, Unit__r.Title__c,
                       Channel__c, Result__c, Is_Success__c
                FROM SOA_Log__c
                ORDER BY CreatedDate DESC
                LIMIT 20
            ]) {
                SoaLogRow row = new SoaLogRow();
                row.name = log.Name;
                row.sentOn = log.CreatedDate;
                row.sentBy = log.CreatedBy.Name;
                row.accountName = log.Account__r == null ? null : log.Account__r.Name;
                row.unitName = log.Unit__r == null ? null : log.Unit__r.Title__c;
                row.channel = log.Channel__c;
                row.result = log.Result__c;
                row.isSuccess = log.Is_Success__c;
                data.soaLog.add(row);
            }
            buildSoaTargets(data);

            // ---- data-quality exceptions ----
            buildDqChecks(data);

            return data;
        } catch (Exception e) {
            throw auraError(e, 'Operations dashboard failed: ');
        }
    }

    // ------------------------------------------------------------ actions ----

    /** Update a cheque line's lifecycle status. Informational only — never touches money. */
    @AuraEnabled
    public static void setChequeStatus(String lineId, String status) {
        try {
            if (!CHEQUE_STATUSES.contains(status)) {
                throw new IllegalArgumentException('Unknown cheque status: ' + status);
            }
            update new Receipt_Amount__c(Id = Id.valueOf(lineId), Cheque_Status__c = status);
        } catch (Exception e) {
            throw auraError(e, 'Could not update the cheque status: ');
        }
    }

    /** Queue the bulk SOA generate & email run. Returns how many were queued. */
    @AuraEnabled
    public static Integer startBulkSoa(List<String> opportunityIds) {
        try {
            FinancialEngine.requireEnabled();
            Set<Id> unique = new Set<Id>();
            for (String oppId : opportunityIds) {
                if (String.isNotBlank(oppId)) unique.add(Id.valueOf(oppId));
            }
            if (unique.isEmpty()) return 0;
            System.enqueueJob(new BulkSoaQueueable(new List<Id>(unique)));
            return unique.size();
        } catch (Exception e) {
            throw auraError(e, 'Could not start the bulk SOA run: ');
        }
    }

    // ----------------------------------------------------------- builders ----

    private static ChequeRow chequeRow(Receipt_Amount__c line, String ccy) {
        ChequeRow row = new ChequeRow();
        row.lineId = line.Id;
        row.chequeNumber = line.Cheque_Number__c;
        row.bank = line.Bank_Name__c;
        row.chequeDate = line.Cheque_Date__c;
        row.amount = nz(line.Amount__c);
        row.currencyCode = projectCcy(ccy);
        row.unitName = line.Receipt__r.Unit__r == null ? null
            : (String.isBlank(line.Receipt__r.Unit__r.Title__c)
               ? line.Receipt__r.Unit__r.Name : line.Receipt__r.Unit__r.Title__c);
        row.accountName = line.Receipt__r.Account__r == null ? null : line.Receipt__r.Account__r.Name;
        row.status = String.isBlank(line.Cheque_Status__c) ? 'Received' : line.Cheque_Status__c;
        return row;
    }

    private static void buildUnallocatedQueue(DashboardData data) {
        Map<Id, Decimal> allocatedByReceipt = new Map<Id, Decimal>();
        Map<Id, Decimal> onAccountByReceipt = new Map<Id, Decimal>();
        // Summed in Apex, not GROUP BY: an aggregate query cannot queryMore past
        // 2000 rows and production exceeds that.
        for (Receipt_Amount__c line : [
            SELECT Receipt__c, Invoice__c, Amount__c
            FROM Receipt_Amount__c
            WHERE Receipt__r.Unit__c != null
        ]) {
            Map<Id, Decimal> target = line.Invoice__c == null ? onAccountByReceipt : allocatedByReceipt;
            target.put(line.Receipt__c, nz(target.get(line.Receipt__c)) + nz(line.Amount__c));
        }
        List<UnallocRow> rows = new List<UnallocRow>();
        for (Receipt__c r : [
            SELECT Id, Name, Voucher_Number__c, Received_Amount__c, Payment_Date__c,
                   Account__r.Name, Unit__r.Title__c, Unit__r.Name,
                   Unit__r.Project__r.Name, Unit__r.Project__r.Project_Currency__c
            FROM Receipt__c
            WHERE Unit__c != null
              AND Payment_Status__c != 'Cancelled' AND Status__c != 'Unreconciled'
        ]) {
            Decimal unapplied = Math.max(0, nz(r.Received_Amount__c) - nz(allocatedByReceipt.get(r.Id)))
                + Math.max(0, nz(onAccountByReceipt.get(r.Id)));
            if (unapplied <= TOLERANCE) continue;
            UnallocRow row = new UnallocRow();
            row.receiptId = r.Id;
            row.voucher = String.isBlank(r.Voucher_Number__c) ? r.Name : r.Voucher_Number__c;
            row.unitName = String.isBlank(r.Unit__r.Title__c) ? r.Unit__r.Name : r.Unit__r.Title__c;
            row.projectName = r.Unit__r.Project__r == null ? null : r.Unit__r.Project__r.Name;
            row.accountName = r.Account__r == null ? null : r.Account__r.Name;
            row.currencyCode = projectCcy(r.Unit__r.Project__r == null ? null
                : r.Unit__r.Project__r.Project_Currency__c);
            row.received = nz(r.Received_Amount__c);
            row.unapplied = unapplied;
            row.paymentDate = r.Payment_Date__c;
            rows.add(row);
            if (rows.size() >= LIST_LIMIT) break;
        }
        data.unallocated = rows;
    }

    private static void buildSoaTargets(DashboardData data) {
        Map<Id, SoaTarget> targetByUnit = new Map<Id, SoaTarget>();
        Map<Id, String> unitNames = new Map<Id, String>();
        for (Unit__c u : [
            SELECT Id, Title__c, Name FROM Unit__c
            WHERE Project__c != null AND Status__c IN :SALES_STATUSES AND Due_Amount__c > :TOLERANCE
        ]) {
            unitNames.put(u.Id, String.isBlank(u.Title__c) ? u.Name : u.Title__c);
        }
        if (unitNames.isEmpty()) return;
        Set<Id> unitsWithSellableDeal = new Set<Id>();
        for (Opportunity opp : [
            SELECT Id, Account.Name, StageName, Unit__c
            FROM Opportunity
            WHERE Unit__c IN :unitNames.keySet()
            ORDER BY CreatedDate ASC
        ]) {
            Boolean sellable = BRS_STAGES.contains(opp.StageName);
            if (!sellable && unitsWithSellableDeal.contains(opp.Unit__c)) continue;
            if (sellable) unitsWithSellableDeal.add(opp.Unit__c);
            SoaTarget target = new SoaTarget();
            target.opportunityId = opp.Id;
            target.accountName = opp.Account == null ? null : opp.Account.Name;
            target.unitName = unitNames.get(opp.Unit__c);
            targetByUnit.put(opp.Unit__c, target);
        }
        data.soaTargets = targetByUnit.values();
    }

    private static void buildDqChecks(DashboardData data) {
        // live targeted checks
        DqCheck overReceipt = new DqCheck('overReceipt', 'Over-receipt (paid above invoice total)', 'live');
        for (Invoice__c inv : [
            SELECT Invoice_Number__c, Name, Pending_Amount__c FROM Invoice__c
            WHERE Pending_Amount__c < :(-TOLERANCE) AND Status__c != 'Cancelled'
            LIMIT 200
        ]) {
            overReceipt.count++;
            if (overReceipt.examples.size() < DQ_SAMPLE_LIMIT) {
                overReceipt.examples.add((String.isBlank(inv.Invoice_Number__c) ? inv.Name : inv.Invoice_Number__c)
                    + ' (' + inv.Pending_Amount__c + ')');
            }
        }

        DqCheck negativeRemaining = new DqCheck('negativeRemaining', 'Negative remaining on instalments', 'live');
        for (Cash_Flow__c cf : [
            SELECT Name, Remaining_Amount__c, Unit__r.Title__c FROM Cash_Flow__c
            WHERE Remaining_Amount__c < :(-TOLERANCE)
            LIMIT 200
        ]) {
            negativeRemaining.count++;
            if (negativeRemaining.examples.size() < DQ_SAMPLE_LIMIT) {
                negativeRemaining.examples.add(cf.Unit__r.Title__c + ' / ' + cf.Name
                    + ' (' + cf.Remaining_Amount__c + ')');
            }
        }

        DqCheck noUnit = new DqCheck('invoiceWithoutUnit', 'Invoices without a unit', 'live');
        noUnit.count = [SELECT COUNT() FROM Invoice__c WHERE Unit__c = null AND Status__c != 'Cancelled'];

        DqCheck duplicates = new DqCheck('duplicateNumbers', 'Duplicate invoice numbers', 'live');
        for (AggregateResult ar : [
            SELECT Invoice_Number__c num, COUNT(Id) c FROM Invoice__c
            WHERE Invoice_Number__c != null AND Status__c != 'Cancelled'
            GROUP BY Invoice_Number__c HAVING COUNT(Id) > 1
            LIMIT 50
        ]) {
            duplicates.count++;
            if (duplicates.examples.size() < DQ_SAMPLE_LIMIT) {
                duplicates.examples.add((String) ar.get('num') + ' ×' + ar.get('c'));
            }
        }

        DqCheck unbilled = new DqCheck('receiptNoInvoice', 'Receipts with money but no invoice allocation', 'live');
        for (Receipt__c r : [
            SELECT Name, Voucher_Number__c, Received_Amount__c FROM Receipt__c
            WHERE Received_Amount__c > :TOLERANCE
              AND Payment_Status__c != 'Cancelled' AND Status__c != 'Unreconciled'
              AND Id NOT IN (SELECT Receipt__c FROM Receipt_Amount__c WHERE Invoice__c != null)
            LIMIT 200
        ]) {
            unbilled.count++;
            if (unbilled.examples.size() < DQ_SAMPLE_LIMIT) {
                unbilled.examples.add((String.isBlank(r.Voucher_Number__c) ? r.Name : r.Voucher_Number__c)
                    + ' (' + r.Received_Amount__c + ')');
            }
        }

        // nightly snapshot checks (plan mismatch, negative remaining, unbilled due money)
        DqCheck nightly = new DqCheck('nightly', 'Nightly sweep exceptions (plan vs price, unbilled due)', 'as of last night');
        Date latest = null;
        for (Finance_Daily_Snapshot__c snap : [
            SELECT Snapshot_Date__c, DQ_Exception_Count__c, Due_Not_Invoiced_Amount__c,
                   Project__r.Name, Project__r.Project_Currency__c
            FROM Finance_Daily_Snapshot__c
            ORDER BY Snapshot_Date__c DESC
            LIMIT 50
        ]) {
            if (latest == null) latest = snap.Snapshot_Date__c;
            if (snap.Snapshot_Date__c != latest) break;
            nightly.count += snap.DQ_Exception_Count__c == null ? 0 : snap.DQ_Exception_Count__c.intValue();
            if (nz(snap.Due_Not_Invoiced_Amount__c) > TOLERANCE
                && nightly.examples.size() < DQ_SAMPLE_LIMIT) {
                nightly.examples.add(snap.Project__r.Name + ': due but never invoiced '
                    + snap.Due_Not_Invoiced_Amount__c + ' '
                    + projectCcy(snap.Project__r.Project_Currency__c));
            }
        }

        data.dqChecks.add(overReceipt);
        data.dqChecks.add(negativeRemaining);
        data.dqChecks.add(noUnit);
        data.dqChecks.add(duplicates);
        data.dqChecks.add(unbilled);
        data.dqChecks.add(nightly);

        // engine reconciliation dry-run over recently touched units (stored vs derived)
        Set<Id> sample = new Set<Id>();
        for (Unit__c u : [
            SELECT Id FROM Unit__c
            WHERE Status__c IN :SALES_STATUSES
            ORDER BY LastModifiedDate DESC
            LIMIT :RECON_SAMPLE_UNITS
        ]) {
            sample.add(u.Id);
        }
        if (!sample.isEmpty()) {
            FinancialReconciliation.Report report = new FinancialReconciliation().reconcileUnits(sample);
            data.reconUnitsScanned = report.unitsScanned;
            data.reconDiffCount = report.diffCount();
        }
    }

    // ----------------------------------------------------------- helpers ----

    private static String projectCcy(String iso) {
        return String.isBlank(iso) ? CurrencyService.CORPORATE_ISO : iso;
    }

    private static Decimal toAed(Decimal amount, String iso) {
        return CurrencyService.convertToAed(amount, iso);
    }

    private static Decimal nz(Decimal d) { return d == null ? 0 : d; }

    private static AuraHandledException auraError(Exception e, String prefix) {
        AuraHandledException aura = new AuraHandledException(prefix + e.getMessage());
        aura.setMessage(prefix + e.getMessage());
        return aura;
    }
}
