/**
 * Tests for FinanceCollectionStateBatch — nightly sweep, daily snapshot, forecast rebuild.
 *
 * Data shape (@TestSetup). All snapshot amounts stay in the PROJECT CURRENCY — never converted:
 *  - Project ALPHA (no currency -> AED): unit U1 Booked, Cost_AED 3000.
 *      CF -40d 1000 unpaid (due, overdue 40 days, not invoiced),
 *      CF +45d 2000 unpaid (future). Plan total 3000 = Unit_Cost_Number -> no DQ mismatch.
 *      Invoice 1000 due -40d unpaid -> overdue, aging bucket 31-60.
 *      Receipt 500 reconciled with no allocation lines -> unallocated 500 + 1 DQ hit.
 *  - Project BRAVO (USD): unit U2 Sold, Cost_USD 400 (Unit_Cost_Number resolves to it).
 *      CF +45d 400 USD unpaid -> Not Yet Due 400 (USD, as-is).
 *  - U3 on ALPHA but Draft -> stamped, excluded from snapshot aggregates.
 */
// isParallel=false: these tests run real batch jobs; under parallel test execution
// (deployment runs) the org's concurrent-batch limit can shunt the job into the flex
// queue, which Test.stopTest() never executes — the snapshots then silently never write.
@IsTest(isParallel=false)
private class FinanceCollectionStateBatchTest {

    @TestSetup
    static void setup() {
        Project__c alpha = new Project__c(
            Name = 'FCS Alpha', Description__c = 'Test', District__c = 'Meydan',
            Coordinates_Latitude__c = 1, Coordinates_Longitude__c = 1, Handover__c = Date.today()
        );
        Project__c bravo = new Project__c(
            Name = 'FCS Bravo', Description__c = 'Test', District__c = 'Meydan',
            Coordinates_Latitude__c = 1, Coordinates_Longitude__c = 1, Handover__c = Date.today(),
            Project_Currency__c = 'USD'
        );
        insert new List<Project__c>{ alpha, bravo };

        // Validation rule: new units must be created as Draft, then the status may change.
        Unit__c u1 = new Unit__c(Title__c = 'FCS-U1', Project__c = alpha.Id, Status__c = 'Draft', Cost_AED__c = 3000);
        Unit__c u2 = new Unit__c(Title__c = 'FCS-U2', Project__c = bravo.Id, Status__c = 'Draft', Cost_AED__c = 1470, Cost_USD__c = 400);
        Unit__c u3 = new Unit__c(Title__c = 'FCS-U3', Project__c = alpha.Id, Status__c = 'Draft', Cost_AED__c = 100);
        insert new List<Unit__c>{ u1, u2, u3 };
        u1.Status__c = 'Booked';
        u2.Status__c = 'Sold';
        update new List<Unit__c>{ u1, u2 };

        Cash_Flow_Sum__c s1 = new Cash_Flow_Sum__c(Name = 'CFS1', Unit__c = u1.Id);
        Cash_Flow_Sum__c s2 = new Cash_Flow_Sum__c(Name = 'CFS2', Unit__c = u2.Id);
        Cash_Flow_Sum__c s3 = new Cash_Flow_Sum__c(Name = 'CFS3', Unit__c = u3.Id);
        insert new List<Cash_Flow_Sum__c>{ s1, s2, s3 };

        insert new List<Cash_Flow__c>{
            cf(u1.Id, s1.Id, 'M1', -40, 1000, 0),
            cf(u1.Id, s1.Id, 'M2', 45, 2000, 0),
            cf(u2.Id, s2.Id, 'M1', 45, 400, 0),
            cf(u3.Id, s3.Id, 'M1', 10, 100, 0)
        };

        insert new Invoice__c(
            Status__c = 'Pending', Invoice_Date__c = Date.today().addDays(-40),
            Due_Date__c = Date.today().addDays(-40),
            Sub_Total_Amount__c = 1000, Paid_Amount__c = 0,
            Unit__c = u1.Id, Invoice_Number__c = 'INV-FCB-1'
        );

        insert new Receipt__c(
            Description__c = 'R', Unit__c = u1.Id, Payment_Date__c = Date.today(),
            Received_Amount__c = 500, Status__c = 'Reconciled', Payment_Status__c = 'Partially Paid'
        );

        // On-account money on BRAVO: a receipt line with no invoice (engine excludes it from
        // Received_Amount, so the unallocated figure must pick it up separately).
        Receipt__c onAccount = new Receipt__c(
            Description__c = 'R2', Unit__c = u2.Id, Payment_Date__c = Date.today(),
            Received_Amount__c = 0, Status__c = 'Reconciled', Payment_Status__c = 'Pending'
        );
        insert onAccount;
        insert new Receipt_Amount__c(Receipt__c = onAccount.Id, Amount__c = 200);
    }

    private static Cash_Flow__c cf(Id unitId, Id sumId, String name, Integer daysOffset,
                                   Decimal price, Decimal received) {
        return new Cash_Flow__c(
            Name = name, Unit__c = unitId, Cash_Flow_Sum__c = sumId,
            Date__c = Date.today().addDays(daysOffset),
            Constant__c = price, Received_Amount__c = received
        );
    }

    private static Map<Id, Finance_Daily_Snapshot__c> snapshotsByProject() {
        Map<Id, Finance_Daily_Snapshot__c> byProject = new Map<Id, Finance_Daily_Snapshot__c>();
        for (Finance_Daily_Snapshot__c snap : [
            SELECT Project__c, Project__r.Name, Snapshot_Date__c, Contracted_Value__c,
                   Invoiced_To_Date__c, Received_To_Date__c, Due_Amount__c, Not_Yet_Due_Amount__c,
                   Overdue_Invoice_Amount__c, Unallocated_Amount__c, Due_Not_Invoiced_Amount__c,
                   Aging_Current__c, Aging_1_30__c, Aging_31_60__c, Aging_61_90__c,
                   Aging_91_180__c, Aging_180_Plus__c,
                   Units_Total__c, Units_Fully_Paid__c, Units_On_Track__c, Units_Overdue__c,
                   Units_Defaulted__c, DQ_Exception_Count__c
            FROM Finance_Daily_Snapshot__c
        ]) {
            byProject.put(snap.Project__c, snap);
        }
        return byProject;
    }

    @IsTest
    static void nightlyRunStampsUnitsAndWritesSnapshotsAndForecast() {
        Test.startTest();
        Database.executeBatch(new FinanceCollectionStateBatch(), 200);
        Test.stopTest();

        Id alphaId = [SELECT Id FROM Project__c WHERE Name = 'FCS Alpha'].Id;
        Id bravoId = [SELECT Id FROM Project__c WHERE Name = 'FCS Bravo'].Id;

        // ---- unit stamps (all units, including Draft) ----
        Map<String, Unit__c> units = new Map<String, Unit__c>();
        for (Unit__c u : [SELECT Title__c, Due_Amount__c, Not_Yet_Due_Amount__c,
                                 Overdue_Days_Max__c, Missed_Instalments__c, Collection_Health__c
                          FROM Unit__c]) {
            units.put(u.Title__c, u);
        }
        System.assertEquals(1000, units.get('FCS-U1').Due_Amount__c);
        System.assertEquals(2000, units.get('FCS-U1').Not_Yet_Due_Amount__c);
        System.assertEquals(40, units.get('FCS-U1').Overdue_Days_Max__c);
        System.assertEquals(FinanceCollectionStateService.HEALTH_OVERDUE,
            units.get('FCS-U1').Collection_Health__c);
        System.assertEquals(FinanceCollectionStateService.HEALTH_ON_TRACK,
            units.get('FCS-U2').Collection_Health__c);
        System.assertEquals(FinanceCollectionStateService.HEALTH_ON_TRACK,
            units.get('FCS-U3').Collection_Health__c, 'Draft units are stamped too');

        // ---- snapshots: one per project, Draft unit excluded ----
        Map<Id, Finance_Daily_Snapshot__c> snaps = snapshotsByProject();
        System.assertEquals(2, snaps.size(), 'One snapshot per project with sellable units');

        Finance_Daily_Snapshot__c alpha = snaps.get(alphaId);
        System.assertEquals(Date.today(), alpha.Snapshot_Date__c);
        System.assertEquals(3000, alpha.Contracted_Value__c);
        System.assertEquals(1000, alpha.Due_Amount__c);
        System.assertEquals(2000, alpha.Not_Yet_Due_Amount__c);
        System.assertEquals(1000, alpha.Invoiced_To_Date__c);
        System.assertEquals(1000, alpha.Overdue_Invoice_Amount__c);
        System.assertEquals(1000, alpha.Aging_31_60__c, '40 days overdue lands in the 31-60 bucket');
        System.assertEquals(0, alpha.Aging_Current__c);
        System.assertEquals(500, alpha.Unallocated_Amount__c, 'Receipt money with no allocation');
        System.assertEquals(1000, alpha.Due_Not_Invoiced_Amount__c, 'Due CF was never invoiced');
        System.assertEquals(1, alpha.Units_Total__c, 'Draft unit not counted');
        System.assertEquals(1, alpha.Units_Overdue__c);
        System.assert(alpha.DQ_Exception_Count__c >= 1, 'Unallocated receipt is a DQ hit');

        Finance_Daily_Snapshot__c bravo = snaps.get(bravoId);
        System.assertEquals(400, bravo.Contracted_Value__c,
            'Unit_Cost_Number__c resolves to Cost_USD__c for a USD project — never converted');
        System.assertEquals(400, bravo.Not_Yet_Due_Amount__c, 'Kept in USD, the project currency');
        System.assertEquals(1, bravo.Units_On_Track__c);
        System.assertEquals(200, bravo.Unallocated_Amount__c, 'On-account line kept in USD');

        // ---- forecast lines ----
        String futureMonth = FinanceCollectionStateService.monthKey(Date.today().addDays(45));
        Map<String, Finance_Forecast_Line__c> byKey = new Map<String, Finance_Forecast_Line__c>();
        for (Finance_Forecast_Line__c line : [
            SELECT Line_Key__c, Expected_Amount__c, Is_Frozen__c FROM Finance_Forecast_Line__c
        ]) {
            byKey.put(line.Line_Key__c, line);
        }
        System.assertEquals(2000, byKey.get(alphaId + '|' + futureMonth + '|LIVE').Expected_Amount__c);
        System.assertEquals(400, byKey.get(bravoId + '|' + futureMonth + '|LIVE').Expected_Amount__c,
            'Forecast kept in USD, the project currency');

        String currentMonth = FinanceCollectionStateService.monthKey(Date.today());
        System.assertEquals(0, byKey.get(alphaId + '|' + currentMonth + '|FROZEN').Expected_Amount__c,
            'Month-start baseline frozen even at zero');
        System.assertEquals(0, byKey.get(bravoId + '|' + currentMonth + '|FROZEN').Expected_Amount__c);
    }

    @IsTest
    static void rerunSameDayIsIdempotent() {
        Test.startTest();
        Database.executeBatch(new FinanceCollectionStateBatch(), 200);
        Database.executeBatch(new FinanceCollectionStateBatch(), 200);
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM Finance_Daily_Snapshot__c],
            'Same-day rerun upserts, never duplicates');
        System.assertEquals(2, [SELECT COUNT() FROM Finance_Forecast_Line__c WHERE Is_Frozen__c = true],
            'Frozen lines created once per project per month');
    }

    @IsTest
    static void schedulableEntryLaunchesTheBatch() {
        Test.startTest();
        new FinanceCollectionStateBatch().execute((SchedulableContext) null);
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM Finance_Daily_Snapshot__c],
            'Schedulable entry point ran the sweep. DIAG units='
            + JSON.serialize([SELECT Title__c, Status__c, Project__c FROM Unit__c])
            + ' jobs=' + JSON.serialize([SELECT Status, JobType, NumberOfErrors, ExtendedStatus,
                                                TotalJobItems, JobItemsProcessed
                                         FROM AsyncApexJob])
            + ' forecastLines=' + [SELECT COUNT() FROM Finance_Forecast_Line__c]);
    }

    @IsTest
    static void bucketIndexFollowsCustomMetadata() {
        System.assertEquals(0, FinanceCollectionStateBatch.bucketIndexFor(0), 'Current');
        System.assertEquals(1, FinanceCollectionStateBatch.bucketIndexFor(15), '1-30');
        System.assertEquals(2, FinanceCollectionStateBatch.bucketIndexFor(45), '31-60');
        System.assertEquals(3, FinanceCollectionStateBatch.bucketIndexFor(75), '61-90');
        System.assertEquals(4, FinanceCollectionStateBatch.bucketIndexFor(120), '91-180');
        System.assertEquals(5, FinanceCollectionStateBatch.bucketIndexFor(200), '180+');
        System.assertEquals(5, FinanceCollectionStateBatch.bucketIndexFor(4000), 'Open-ended last bucket');
    }
}
