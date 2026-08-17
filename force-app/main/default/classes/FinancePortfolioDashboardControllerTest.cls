/**
 * Tests for FinancePortfolioDashboardController.
 *
 * Data shape (@TestSetup) — engine left OFF; the collection state is stamped directly via
 * FinanceCollectionStateService and invoice/ledger records carry explicit stored values, so
 * the assertions do not depend on the engine or on DLRS rollups (Total_Received_Amount__c is
 * DLRS-owned, so received-based figures are asserted dynamically against the stored values):
 *  - ALPHA (no currency -> AED):
 *      U1 Booked, Cost_AED 3000, Tower 1 / floor 2: CF -40d 1000 unpaid, CF +45d 2000 unpaid,
 *         invoice 1000 due -40d unpaid, receipt 500 with no allocation lines (unallocated).
 *      U3 Sold, Cost_AED 1000, Tower 1 / floor 3: CF -100d 1000 fully received, invoice paid,
 *         Milestone_Receipt 1000 paid 10 days late -> avg days to collect = 10.
 *  - BRAVO (USD, rate 0.25 per AED -> 1 USD = 4 AED):
 *      U2 Sold, Cost_USD 400: CF +45d 400 unpaid; on-account receipt line 200 (no invoice).
 */
@IsTest
private class FinancePortfolioDashboardControllerTest {

    @TestSetup
    static void setup() {
        insert new Currency_Exchange_Rate__c(
            Name = 'USD', Rate_Per_AED__c = 0.25, Last_Refreshed__c = System.now(), Source__c = 'Test'
        );

        Project__c alpha = new Project__c(
            Name = 'FPD Alpha', Description__c = 'Test', District__c = 'Meydan',
            Coordinates_Latitude__c = 1, Coordinates_Longitude__c = 1, Handover__c = Date.today()
        );
        Project__c bravo = new Project__c(
            Name = 'FPD Bravo', Description__c = 'Test', District__c = 'Meydan',
            Coordinates_Latitude__c = 1, Coordinates_Longitude__c = 1, Handover__c = Date.today(),
            Project_Currency__c = 'USD'
        );
        insert new List<Project__c>{ alpha, bravo };

        Unit__c u1 = new Unit__c(Title__c = 'FPD-U1', Project__c = alpha.Id, Status__c = 'Draft',
            Cost_AED__c = 3000, Tower__c = 'Tower 1', Floor__c = 2);
        Unit__c u2 = new Unit__c(Title__c = 'FPD-U2', Project__c = bravo.Id, Status__c = 'Draft',
            Cost_AED__c = 1470, Cost_USD__c = 400, Tower__c = 'A', Floor__c = 5);
        Unit__c u3 = new Unit__c(Title__c = 'FPD-U3', Project__c = alpha.Id, Status__c = 'Draft',
            Cost_AED__c = 1000, Tower__c = 'Tower 1', Floor__c = 3);
        insert new List<Unit__c>{ u1, u2, u3 };
        u1.Status__c = 'Booked';
        u2.Status__c = 'Sold';
        u3.Status__c = 'Sold';
        update new List<Unit__c>{ u1, u2, u3 };

        Cash_Flow_Sum__c s1 = new Cash_Flow_Sum__c(Name = 'CFS1', Unit__c = u1.Id);
        Cash_Flow_Sum__c s2 = new Cash_Flow_Sum__c(Name = 'CFS2', Unit__c = u2.Id);
        Cash_Flow_Sum__c s3 = new Cash_Flow_Sum__c(Name = 'CFS3', Unit__c = u3.Id);
        insert new List<Cash_Flow_Sum__c>{ s1, s2, s3 };

        Cash_Flow__c u3cf = cf(u3.Id, s3.Id, 'M1', -100, 1000, 1000);
        insert new List<Cash_Flow__c>{
            cf(u1.Id, s1.Id, 'M1', -40, 1000, 0),
            cf(u1.Id, s1.Id, 'M2', 45, 2000, 0),
            cf(u2.Id, s2.Id, 'M1', 45, 400, 0),
            u3cf
        };

        Invoice__c u1inv = new Invoice__c(Unit__c = u1.Id, Status__c = 'Pending',
            Invoice_Date__c = Date.today().addDays(-40), Due_Date__c = Date.today().addDays(-40),
            Sub_Total_Amount__c = 1000, Paid_Amount__c = 0, Invoice_Number__c = 'INV-FPD-1');
        Invoice__c u3inv = new Invoice__c(Unit__c = u3.Id, Status__c = 'Fully Paid',
            Invoice_Date__c = Date.today().addDays(-100), Due_Date__c = Date.today().addDays(-100),
            Sub_Total_Amount__c = 1000, Paid_Amount__c = 1000, Invoice_Number__c = 'INV-FPD-2');
        insert new List<Invoice__c>{ u1inv, u3inv };

        Receipt__c u1receipt = new Receipt__c(Unit__c = u1.Id, Description__c = 'No allocation',
            Payment_Date__c = Date.today(), Received_Amount__c = 500,
            Status__c = 'Reconciled', Payment_Status__c = 'Partially Paid');
        Receipt__c u2receipt = new Receipt__c(Unit__c = u2.Id, Description__c = 'On account',
            Payment_Date__c = Date.today().addDays(-10), Received_Amount__c = 0,
            Status__c = 'Reconciled', Payment_Status__c = 'Pending');
        Receipt__c u3receipt = new Receipt__c(Unit__c = u3.Id, Description__c = 'Paid late',
            Payment_Date__c = Date.today().addDays(-90), Received_Amount__c = 1000,
            Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid');
        insert new List<Receipt__c>{ u1receipt, u2receipt, u3receipt };

        insert new List<Receipt_Amount__c>{
            new Receipt_Amount__c(Receipt__c = u2receipt.Id, Amount__c = 200), // on-account
            new Receipt_Amount__c(Receipt__c = u3receipt.Id, Invoice__c = u3inv.Id, Amount__c = 1000)
        };

        // Engine allocation ledger row: instalment due -100d, paid -90d -> 10 days to collect.
        insert new Milestone_Receipt__c(Name = 'Allocation 1000', Receipt__c = u3receipt.Id,
            Invoice__c = u3inv.Id, Cash_Flow__c = u3cf.Id, Amount__c = 1000,
            Installment_Date__c = Date.today().addDays(-100));

        FinanceCollectionStateService.stampUnits(new Set<Id>{ u1.Id, u2.Id, u3.Id });
    }

    private static Cash_Flow__c cf(Id unitId, Id sumId, String name, Integer daysOffset,
                                   Decimal price, Decimal received) {
        return new Cash_Flow__c(Name = name, Unit__c = unitId, Cash_Flow_Sum__c = sumId,
            Date__c = Date.today().addDays(daysOffset), Constant__c = price,
            Received_Amount__c = received);
    }

    @IsTest
    static void portfolioTilesConvertToAedAtReadTime() {
        Test.startTest();
        FinancePortfolioDashboardController.DashboardData data =
            FinancePortfolioDashboardController.getDashboardData();
        Test.stopTest();

        System.assertEquals(2, data.projects.size(), 'One row per project');
        System.assertEquals(3, data.unitsTotal);
        // Contracted: alpha 3000 + 1000 AED, bravo 400 USD * 4 = 1600 AED
        System.assertEquals(5600, data.contractedAed);
        System.assertEquals(1000, data.dueAed, 'Only U1 has due money (AED)');
        System.assertEquals(3600, data.notYetDueAed, '2000 AED + 400 USD as 1600 AED');
        System.assertEquals(2000, data.invoicedAed, 'Two invoices of 1000 AED');
        System.assertEquals(1000, data.overdueInvoiceAed, 'U1 invoice past due and unpaid');
        System.assertEquals(1300, data.unallocatedAed, '500 AED no-allocation + 200 USD on-account as 800 AED');
        System.assertEquals(10.0, data.avgDaysToCollect, 'Single ledger row paid 10 days late');
        // Received depends on the DLRS rollup — assert consistency, not a fixed value.
        Decimal expectedReceivedAed = 0;
        for (Unit__c u : [SELECT Total_Received_Amount__c, Project__r.Project_Currency__c FROM Unit__c
                          WHERE Title__c LIKE 'FPD-U%']) {
            Decimal amt = u.Total_Received_Amount__c == null ? 0 : u.Total_Received_Amount__c;
            expectedReceivedAed += CurrencyService.convertToAed(amt, u.Project__r.Project_Currency__c);
        }
        System.assertEquals(expectedReceivedAed, data.receivedAed);
    }

    @IsTest
    static void projectRowsStayInProjectCurrency() {
        FinancePortfolioDashboardController.DashboardData data =
            FinancePortfolioDashboardController.getDashboardData();

        FinancePortfolioDashboardController.ProjectRow alpha;
        FinancePortfolioDashboardController.ProjectRow bravo;
        for (FinancePortfolioDashboardController.ProjectRow row : data.projects) {
            if (row.name == 'FPD Alpha') alpha = row;
            if (row.name == 'FPD Bravo') bravo = row;
        }
        System.assertEquals('AED', alpha.currencyCode);
        System.assertEquals(4000, alpha.contracted);
        System.assertEquals(1000, alpha.due);
        System.assertEquals(2000, alpha.invoiced);
        System.assertEquals(1000, alpha.overdueInvoice);
        System.assertEquals(10.0, alpha.avgDaysToCollect);
        System.assertEquals(2, alpha.units);
        System.assertEquals(1, alpha.unitsOverdue, 'U1 stamped Overdue');
        System.assertEquals(1, alpha.unitsFullyPaid, 'U3 stamped Fully Paid');

        System.assertEquals('USD', bravo.currencyCode);
        System.assertEquals(400, bravo.contracted, 'Unit_Cost_Number__c in USD, never converted');
        System.assertEquals(400, bravo.notYetDue);
        System.assertEquals(200, bravo.unallocated, 'On-account money in USD');
        System.assertEquals(1600, bravo.outstandingAed, 'Only the cross-project figure is AED');

        System.assertEquals('FPD Alpha', data.projects[0].name,
            'Sorted by outstanding AED descending: alpha 3000 vs bravo 1600');
    }

    @IsTest
    static void unitRowsForExpansion() {
        Id alphaId = [SELECT Id FROM Project__c WHERE Name = 'FPD Alpha'].Id;

        Test.startTest();
        List<FinancePortfolioDashboardController.UnitRow> rows =
            FinancePortfolioDashboardController.getUnitRows(String.valueOf(alphaId));
        Test.stopTest();

        System.assertEquals(2, rows.size());
        FinancePortfolioDashboardController.UnitRow u1;
        FinancePortfolioDashboardController.UnitRow u3;
        for (FinancePortfolioDashboardController.UnitRow row : rows) {
            if (row.name == 'FPD-U1') u1 = row;
            if (row.name == 'FPD-U3') u3 = row;
        }
        System.assertEquals(3000, u1.total);
        System.assertEquals(1000, u1.due);
        System.assertEquals(2000, u1.notYetDue);
        System.assertEquals(40, u1.overdueDays);
        System.assertEquals(FinanceCollectionStateService.HEALTH_OVERDUE, u1.health);
        System.assertEquals(FinanceCollectionStateService.HEALTH_FULLY_PAID, u3.health);
        System.assertEquals(0, u3.due);
    }

    @IsTest
    static void heatmapCellsCarryStructureAndHealth() {
        FinancePortfolioDashboardController.DashboardData data =
            FinancePortfolioDashboardController.getDashboardData();

        System.assertEquals(3, data.heatmap.size(), 'One cell per sellable unit');
        FinancePortfolioDashboardController.HeatCell u1;
        for (FinancePortfolioDashboardController.HeatCell cell : data.heatmap) {
            if (cell.unitName == 'FPD-U1') u1 = cell;
        }
        System.assertEquals('Tower 1', u1.tower);
        System.assertEquals('2', u1.floorLabel);
        System.assertEquals(FinanceCollectionStateService.HEALTH_OVERDUE, u1.health);
        System.assertEquals(1000, u1.due);
        System.assertEquals(40, u1.overdueDays);
    }
}
