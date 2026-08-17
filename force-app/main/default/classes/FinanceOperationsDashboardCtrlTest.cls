/**
 * Tests for FinanceOperationsDashboardController, BulkSoaQueueable, and the SOA_Log__c
 * logging inside SOAEmailService.
 *
 * Data shape (@TestSetup) — engine OFF unless a test enables it:
 *  - ALPHA (AED): U1 Booked with a due instalment (stamped) + Account/Opportunity -> SOA target.
 *      Invoice 1000 dated today (volume). Receipt 500 dated today (volume).
 *      Cheque line 200 due +10d (PDC) and a bounced line 300 from an old receipt.
 *      Unallocated receipt 500 dated -100d (queue; outside the volume window).
 *      Cancelled invoice + cancelled receipt (panel). Over-receipt, negative remaining,
 *      duplicate numbers, snapshot DQ rows (data-quality panel).
 */
@IsTest
private class FinanceOperationsDashboardCtrlTest {

    @TestSetup
    static void setup() {
        insert new Currency_Exchange_Rate__c(
            Name = 'USD', Rate_Per_AED__c = 0.25, Last_Refreshed__c = System.now(), Source__c = 'Test'
        );
        Project__c alpha = new Project__c(
            Name = 'FOp Alpha', Description__c = 'Test', District__c = 'Meydan',
            Coordinates_Latitude__c = 1, Coordinates_Longitude__c = 1, Handover__c = Date.today()
        );
        insert alpha;

        Unit__c u1 = new Unit__c(Title__c = 'FOp-U1', Project__c = alpha.Id, Status__c = 'Draft', Cost_AED__c = 3000);
        insert u1;
        u1.Status__c = 'Booked';
        update u1;

        Cash_Flow_Sum__c s1 = new Cash_Flow_Sum__c(Name = 'CFS1', Unit__c = u1.Id);
        insert s1;
        insert new List<Cash_Flow__c>{
            new Cash_Flow__c(Name = 'M1', Unit__c = u1.Id, Cash_Flow_Sum__c = s1.Id,
                Date__c = Date.today().addDays(-40), Constant__c = 1000, Received_Amount__c = 0),
            // negative remaining: received above the price
            new Cash_Flow__c(Name = 'MNeg', Unit__c = u1.Id, Cash_Flow_Sum__c = s1.Id,
                Date__c = Date.today().addDays(-60), Constant__c = 100, Received_Amount__c = 200)
        };

        Account acct = new Account(Name = 'FOp Customer', Company_Email__c = 'fop.customer@example.com');
        insert acct;
        insert new Opportunity(Name = 'FOp Deal', StageName = 'Booked', CloseDate = Date.today(),
            AccountId = acct.Id, Unit__c = u1.Id);

        // volume: one invoice + one receipt dated today
        Invoice__c volInv = new Invoice__c(Unit__c = u1.Id, Account__c = acct.Id, Status__c = 'Pending',
            Invoice_Date__c = Date.today(), Due_Date__c = Date.today().addDays(30),
            Sub_Total_Amount__c = 1000, Paid_Amount__c = 0);
        // over-receipt: paid above total, dated in the past
        Invoice__c overInv = new Invoice__c(Unit__c = u1.Id, Status__c = 'Fully Paid',
            Invoice_Date__c = Date.today().addDays(-100), Due_Date__c = Date.today().addDays(-100),
            Sub_Total_Amount__c = 1000, Paid_Amount__c = 1500);
        // duplicate numbers (numbering trigger ignores unknown projects on insert; set via update)
        Invoice__c dupA = new Invoice__c(Unit__c = u1.Id, Status__c = 'Pending',
            Invoice_Date__c = Date.today().addDays(-100), Due_Date__c = Date.today().addDays(-100),
            Sub_Total_Amount__c = 10, Paid_Amount__c = 0);
        Invoice__c dupB = new Invoice__c(Unit__c = u1.Id, Status__c = 'Pending',
            Invoice_Date__c = Date.today().addDays(-100), Due_Date__c = Date.today().addDays(-100),
            Sub_Total_Amount__c = 10, Paid_Amount__c = 0);
        Invoice__c cancelledInv = new Invoice__c(Unit__c = u1.Id, Status__c = 'Cancelled',
            Invoice_Date__c = Date.today(), Grand_Total_Amount__c = 700,
            Sub_Total_Amount__c = 700, Paid_Amount__c = 0);
        insert new List<Invoice__c>{ volInv, overInv, dupA, dupB, cancelledInv };
        dupA.Invoice_Number__c = 'DUP-001';
        dupB.Invoice_Number__c = 'DUP-001';
        update new List<Invoice__c>{ dupA, dupB };

        Receipt__c volReceipt = new Receipt__c(Unit__c = u1.Id, Account__c = acct.Id, Description__c = 'Vol',
            Payment_Date__c = Date.today(), Received_Amount__c = 0,
            Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid');
        Receipt__c chequeReceipt = new Receipt__c(Unit__c = u1.Id, Account__c = acct.Id, Description__c = 'Chq',
            Payment_Date__c = Date.today(), Received_Amount__c = 0,
            Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid');
        Receipt__c oldReceipt = new Receipt__c(Unit__c = u1.Id, Account__c = acct.Id, Description__c = 'Old',
            Payment_Date__c = Date.today().addDays(-100), Received_Amount__c = 500,
            Status__c = 'Reconciled', Payment_Status__c = 'Partially Paid');
        Receipt__c cancelledReceipt = new Receipt__c(Unit__c = u1.Id, Description__c = 'Cxl',
            Payment_Date__c = Date.today().addDays(-5), Received_Amount__c = 0, Payable_Amount__c = 900,
            Status__c = 'Reconciled', Payment_Status__c = 'Cancelled',
            Cancellation_Reason__c = 'Posted against the wrong unit');
        insert new List<Receipt__c>{ volReceipt, chequeReceipt, oldReceipt, cancelledReceipt };
        // engine is off, so the stored 500 on volReceipt survives; set after insert to be explicit
        volReceipt.Received_Amount__c = 500;
        update volReceipt;

        insert new List<Receipt_Amount__c>{
            new Receipt_Amount__c(Receipt__c = chequeReceipt.Id, Invoice__c = volInv.Id, Amount__c = 200,
                Mode_of_Payment__c = 'Cheque', Cheque_Number__c = 'CHQ-100',
                Cheque_Date__c = Date.today().addDays(10), Bank_Name__c = 'Emirates NBD'),
            new Receipt_Amount__c(Receipt__c = oldReceipt.Id, Invoice__c = volInv.Id, Amount__c = 300,
                Mode_of_Payment__c = 'Cheque', Cheque_Number__c = 'CHQ-099',
                Cheque_Date__c = Date.today().addDays(-95), Bank_Name__c = 'Emirates NBD',
                Cheque_Status__c = 'Bounced')
        };

        insert new Finance_Daily_Snapshot__c(
            Snapshot_Key__c = alpha.Id + '|' + String.valueOf(Date.today().addDays(-1)),
            Snapshot_Date__c = Date.today().addDays(-1), Project__c = alpha.Id,
            DQ_Exception_Count__c = 2, Due_Not_Invoiced_Amount__c = 800
        );

        insert new SOA_Log__c(Opportunity__c = null, Account__c = acct.Id, Unit__c = u1.Id,
            Channel__c = 'Email', Sent_To__c = 'x@y.z', Result__c = 'Success: seeded', Is_Success__c = true);

        FinanceCollectionStateService.stampUnits(new Set<Id>{ u1.Id });
    }

    private static void enableEngine() {
        insert new Financial_Engine_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(), Engine_Owns_Totals__c = true
        );
    }

    @IsTest
    static void volumesMethodsAndPdc() {
        Test.startTest();
        FinanceOperationsDashboardController.DashboardData data =
            FinanceOperationsDashboardController.getDashboardData();
        Test.stopTest();

        for (FinanceOperationsDashboardController.VolumeRow row : data.volume) {
            System.assertEquals(1, row.invoices, row.scope + ': one non-cancelled invoice today');
            System.assertEquals(1000, row.invoicedAed, row.scope);
            System.assertEquals(2, row.receipts, row.scope + ': volume receipt + cheque receipt today');
            System.assertEquals(500, row.collectedAed, row.scope + ': only the stored 500');
        }

        FinanceOperationsDashboardController.MethodSlice cheque;
        for (FinanceOperationsDashboardController.MethodSlice slice : data.methodSplit) {
            if (slice.mode == 'Cheque') cheque = slice;
        }
        System.assertEquals(200, cheque.amountAed,
            'Only the current cheque line — the bounced one is 100 days old, outside the 90-day window');

        System.assertEquals(1, data.pdcUpcoming.size(), 'One PDC due in 30 days');
        System.assertEquals('CHQ-100', data.pdcUpcoming[0].chequeNumber);
        Decimal weekTotal = 0;
        for (FinanceOperationsDashboardController.PdcWeek wk : data.pdcWeeks) weekTotal += wk.amountAed;
        System.assertEquals(200, weekTotal, 'Bounced cheques never sit in the maturity calendar');
        System.assertEquals(1, data.bounced.size());
        System.assertEquals('CHQ-099', data.bounced[0].chequeNumber);
    }

    @IsTest
    static void queuesCancellationsLogAndDq() {
        FinanceOperationsDashboardController.DashboardData data =
            FinanceOperationsDashboardController.getDashboardData();

        System.assertEquals(2, data.unallocated.size(),
            'volReceipt (500, no lines) + oldReceipt (500 received vs 300 allocated)');
        System.assertEquals(1, data.cancelledInvoices);
        System.assertEquals(1, data.cancelledReceipts);
        Boolean foundReason = false;
        for (FinanceOperationsDashboardController.CancelRow row : data.cancellations) {
            if (row.kind == 'Receipt') foundReason = row.reason == 'Posted against the wrong unit';
        }
        System.assert(foundReason, 'Cancellation reason surfaces in the panel');

        System.assertEquals(1, data.soaLog.size());
        System.assertEquals(1, data.soaTargets.size(), 'U1 is due -> one bulk SOA target');
        System.assertEquals('FOp Customer', data.soaTargets[0].accountName);

        Map<String, FinanceOperationsDashboardController.DqCheck> byKey =
            new Map<String, FinanceOperationsDashboardController.DqCheck>();
        for (FinanceOperationsDashboardController.DqCheck check : data.dqChecks) byKey.put(check.key, check);
        System.assertEquals(1, byKey.get('overReceipt').count);
        System.assertEquals(1, byKey.get('negativeRemaining').count);
        System.assertEquals(1, byKey.get('duplicateNumbers').count);
        System.assert(byKey.get('receiptNoInvoice').count >= 1, 'volReceipt has money but no allocation');
        System.assertEquals(2, byKey.get('nightly').count);
        System.assert(byKey.get('nightly').examples[0].contains('800'), 'Unbilled due money named');
        System.assert(data.reconUnitsScanned > 0, 'Reconciliation sample ran');
    }

    @IsTest
    static void chequeStatusActionValidatesAndWrites() {
        Id lineId = [SELECT Id FROM Receipt_Amount__c WHERE Cheque_Number__c = 'CHQ-100'].Id;

        Test.startTest();
        FinanceOperationsDashboardController.setChequeStatus(lineId, 'Deposited');
        Test.stopTest();

        System.assertEquals('Deposited',
            [SELECT Cheque_Status__c FROM Receipt_Amount__c WHERE Id = :lineId].Cheque_Status__c);

        try {
            FinanceOperationsDashboardController.setChequeStatus(lineId, 'Lost');
            System.assert(false, 'Expected an exception for an unknown status');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Unknown cheque status'), e.getMessage());
        }
    }

    @IsTest
    static void bulkSoaQueuesAndLogsEveryAttempt() {
        enableEngine();
        Id oppId = [SELECT Id FROM Opportunity WHERE Name LIKE '%FOp%' OR Unit__r.Title__c = 'FOp-U1' LIMIT 1].Id;
        Integer logsBefore = [SELECT COUNT() FROM SOA_Log__c];

        Test.startTest();
        Integer queued = FinanceOperationsDashboardController.startBulkSoa(new List<String>{ oppId });
        Test.stopTest(); // the queueable runs one send here (chaining is guarded in tests)

        System.assertEquals(1, queued);
        System.assertEquals(logsBefore + 1, [SELECT COUNT() FROM SOA_Log__c],
            'The bulk send attempt was logged');
        List<SOA_Log__c> bulkLogs = [SELECT Result__c FROM SOA_Log__c WHERE Channel__c = 'Bulk Email'];
        System.assertEquals(1, bulkLogs.size(), 'Bulk channel recorded');
    }
}
