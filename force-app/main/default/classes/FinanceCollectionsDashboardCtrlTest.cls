/**
 * Tests for FinanceCollectionsDashboardController.
 *
 * Data shape (@TestSetup) — engine OFF; collection state stamped via the service:
 *  - ALPHA (AED): U1 Booked — CF -40d 1000 unpaid; invoice 1000 due -40d with Account KAREEM;
 *    Opportunity (Booked) linking KAREEM + U1. -> overdue row with actions context,
 *    customer matrix row in the 31-60 bucket, project aging in bucket index 2.
 *  - ALPHA: U4 Sold — 3 CFs (-100/-95/-91) unpaid -> Defaulted (termination candidate).
 *  - BRAVO (USD, rate 0.25/AED): snapshot rows only, to prove the trend converts at read time.
 */
@IsTest
private class FinanceCollectionsDashboardCtrlTest {

    @TestSetup
    static void setup() {
        insert new Currency_Exchange_Rate__c(
            Name = 'USD', Rate_Per_AED__c = 0.25, Last_Refreshed__c = System.now(), Source__c = 'Test'
        );

        Project__c alpha = new Project__c(
            Name = 'FCol Alpha', Description__c = 'Test', District__c = 'Meydan',
            Coordinates_Latitude__c = 1, Coordinates_Longitude__c = 1, Handover__c = Date.today()
        );
        Project__c bravo = new Project__c(
            Name = 'FCol Bravo', Description__c = 'Test', District__c = 'Meydan',
            Coordinates_Latitude__c = 1, Coordinates_Longitude__c = 1, Handover__c = Date.today(),
            Project_Currency__c = 'USD'
        );
        insert new List<Project__c>{ alpha, bravo };

        Unit__c u1 = new Unit__c(Title__c = 'FCol-U1', Project__c = alpha.Id, Status__c = 'Draft', Cost_AED__c = 3000);
        Unit__c u4 = new Unit__c(Title__c = 'FCol-U4', Project__c = alpha.Id, Status__c = 'Draft', Cost_AED__c = 300);
        insert new List<Unit__c>{ u1, u4 };
        u1.Status__c = 'Booked';
        u4.Status__c = 'Sold';
        update new List<Unit__c>{ u1, u4 };

        Cash_Flow_Sum__c s1 = new Cash_Flow_Sum__c(Name = 'CFS1', Unit__c = u1.Id);
        Cash_Flow_Sum__c s4 = new Cash_Flow_Sum__c(Name = 'CFS4', Unit__c = u4.Id);
        insert new List<Cash_Flow_Sum__c>{ s1, s4 };
        insert new List<Cash_Flow__c>{
            cf(u1.Id, s1.Id, 'M1', -40, 1000),
            cf(u1.Id, s1.Id, 'M2', 45, 2000),
            cf(u4.Id, s4.Id, 'M1', -100, 100),
            cf(u4.Id, s4.Id, 'M2', -95, 100),
            cf(u4.Id, s4.Id, 'M3', -91, 100)
        };

        Account kareem = new Account(Name = 'Kareem Holdings');
        insert kareem;
        insert new Opportunity(Name = 'FCol Deal U1', StageName = 'Booked',
            CloseDate = Date.today(), AccountId = kareem.Id, Unit__c = u1.Id);

        insert new Invoice__c(Unit__c = u1.Id, Account__c = kareem.Id, Status__c = 'Pending',
            Invoice_Date__c = Date.today().addDays(-40), Due_Date__c = Date.today().addDays(-40),
            Sub_Total_Amount__c = 1000, Paid_Amount__c = 0, Invoice_Number__c = 'INV-FCOL-1');

        // trend fixture: same day, one AED project row + one USD project row
        insert new List<Finance_Daily_Snapshot__c>{
            new Finance_Daily_Snapshot__c(
                Snapshot_Key__c = alpha.Id + '|' + String.valueOf(Date.today().addDays(-1)),
                Snapshot_Date__c = Date.today().addDays(-1), Project__c = alpha.Id,
                Due_Amount__c = 1000, Received_To_Date__c = 3000, Invoiced_To_Date__c = 2000,
                Aging_Current__c = 0, Aging_1_30__c = 0, Aging_31_60__c = 1000,
                Aging_61_90__c = 0, Aging_91_180__c = 0, Aging_180_Plus__c = 0
            ),
            new Finance_Daily_Snapshot__c(
                Snapshot_Key__c = bravo.Id + '|' + String.valueOf(Date.today().addDays(-1)),
                Snapshot_Date__c = Date.today().addDays(-1), Project__c = bravo.Id,
                Due_Amount__c = 100, Received_To_Date__c = 100, Invoiced_To_Date__c = 250,
                Aging_Current__c = 0, Aging_1_30__c = 100, Aging_31_60__c = 0,
                Aging_61_90__c = 0, Aging_91_180__c = 0, Aging_180_Plus__c = 0
            )
        };

        FinanceCollectionStateService.stampUnits(new Set<Id>{ u1.Id, u4.Id });
    }

    private static Cash_Flow__c cf(Id unitId, Id sumId, String name, Integer daysOffset, Decimal price) {
        return new Cash_Flow__c(Name = name, Unit__c = unitId, Cash_Flow_Sum__c = sumId,
            Date__c = Date.today().addDays(daysOffset), Constant__c = price, Received_Amount__c = 0);
    }

    @IsTest
    static void agingBucketsProjectsAndCustomers() {
        Test.startTest();
        FinanceCollectionsDashboardController.DashboardData data =
            FinanceCollectionsDashboardController.getDashboardData();
        Test.stopTest();

        System.assertEquals(6, data.bucketLabels.size(), 'Buckets come from Aging_Bucket__mdt');
        System.assertEquals(1000, data.totalOverdueAed, 'One overdue invoice of 1000 AED');
        System.assertEquals(1000, data.totalOpenAed);

        System.assertEquals(1, data.projectAging.size());
        FinanceCollectionsDashboardController.ProjectAging alpha = data.projectAging[0];
        System.assertEquals('FCol Alpha', alpha.name);
        System.assertEquals(1000, alpha.bucketsAed[2], '40 days overdue -> 31-60 bucket');
        System.assertEquals(0, alpha.bucketsAed[0]);

        System.assertEquals(1, data.customers.size());
        FinanceCollectionsDashboardController.CustomerRow cust = data.customers[0];
        System.assertEquals('Kareem Holdings', cust.name);
        System.assertEquals(1000, cust.bucketsAed[2]);
        System.assertEquals(1000, cust.overdueAed);
        System.assertEquals(40, cust.oldestDays);
        System.assertEquals(1, data.overdueCustomers);
    }

    @IsTest
    static void actionRowsCarryCustomerAndDealContext() {
        FinanceCollectionsDashboardController.DashboardData data =
            FinanceCollectionsDashboardController.getDashboardData();

        System.assertEquals(1, data.overdueRows.size(), 'U1 is overdue (U4 sits in the defaulted list)');
        FinanceCollectionsDashboardController.ActionRow u1 = data.overdueRows[0];
        System.assertEquals('FCol-U1', u1.unitName);
        System.assertEquals(1000, u1.due);
        System.assertEquals('AED', u1.currencyCode);
        System.assertEquals('Kareem Holdings', u1.accountName);
        System.assertNotEquals(null, u1.opportunityId, 'Deal context for the SOA action');
        System.assertEquals(40, u1.overdueDays);

        System.assertEquals(1, data.defaultedRows.size());
        System.assertEquals('FCol-U4', data.defaultedRows[0].unitName);
        System.assertEquals(FinanceCollectionStateService.HEALTH_DEFAULTED, data.defaultedRows[0].health);
        System.assertEquals(1, data.defaultedUnits);
    }

    @IsTest
    static void trendConvertsSnapshotsAtReadTime() {
        FinanceCollectionsDashboardController.DashboardData data =
            FinanceCollectionsDashboardController.getDashboardData();

        System.assertEquals(1, data.trend.size(), 'Two project rows fold into one dated point');
        FinanceCollectionsDashboardController.TrendPoint pt = data.trend[0];
        System.assertEquals(1400, pt.dueAed, '1000 AED + 100 USD as 400 AED');
        System.assertEquals(3400, pt.receivedAed);
        System.assertEquals(3000, pt.invoicedAed, '2000 AED + 250 USD as 1000 AED');
        System.assertEquals(1400, pt.arAed, 'Aging buckets: 1000 AED + 100 USD as 400 AED');
        System.assertEquals((365 * 1400.0 / 3000).setScale(1), pt.dso);
        System.assertEquals(70.8, pt.efficiencyPct, '3400 / 4800');
    }

    @IsTest
    static void followUpTaskIsCreatedOnTheAccount() {
        Id accountId = [SELECT Id FROM Account WHERE Name = 'Kareem Holdings'].Id;

        Test.startTest();
        Id taskId = FinanceCollectionsDashboardController.createFollowUpTask(
            String.valueOf(accountId), 'FCol-U1', 'Customer promised payment by Friday.');
        Test.stopTest();

        Task created = [SELECT Subject, WhatId, Description, Status FROM Task WHERE Id = :taskId];
        System.assertEquals(accountId, created.WhatId);
        System.assert(created.Subject.contains('FCol-U1'));
        System.assertEquals('Customer promised payment by Friday.', created.Description);
        System.assertEquals('Not Started', created.Status);
    }

    @IsTest
    static void collectionFlagSetAndClear() {
        Id unitId = [SELECT Id FROM Unit__c WHERE Title__c = 'FCol-U1'].Id;

        FinanceCollectionsDashboardController.setCollectionFlag(String.valueOf(unitId), 'Legal Notice');
        Unit__c flagged = [SELECT Collection_Flag__c, Collection_Flag_Date__c FROM Unit__c WHERE Id = :unitId];
        System.assertEquals('Legal Notice', flagged.Collection_Flag__c);
        System.assertEquals(Date.today(), flagged.Collection_Flag_Date__c);

        FinanceCollectionsDashboardController.setCollectionFlag(String.valueOf(unitId), '');
        Unit__c cleared = [SELECT Collection_Flag__c, Collection_Flag_Date__c FROM Unit__c WHERE Id = :unitId];
        System.assertEquals(null, cleared.Collection_Flag__c);
        System.assertEquals(null, cleared.Collection_Flag_Date__c);

        try {
            FinanceCollectionsDashboardController.setCollectionFlag(String.valueOf(unitId), 'Nonsense');
            System.assert(false, 'Expected an exception for an unknown flag');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Unknown collection flag'));
        }
    }
}
