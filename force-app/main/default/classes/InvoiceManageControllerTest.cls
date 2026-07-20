/**
 * Tests for InvoiceManageController (Step 7a). Runs with the engine flag ON so we confirm
 * status/pending re-derive when the invoice amount or its covered installments change.
 */
@IsTest
private class InvoiceManageControllerTest {

    private class Ctx {
        Unit__c u;
        Cash_Flow__c cf1;
        Cash_Flow__c cf2;
        Invoice__c inv;
        Receipt__c r;
    }

    private static Ctx build() {
        insert new Financial_Engine_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(), Engine_Owns_Totals__c = true
        );
        Ctx c = new Ctx();
        c.u = new Unit__c(Title__c = 'inv-mng');
        insert c.u;
        Cash_Flow_Sum__c s = new Cash_Flow_Sum__c(Name = 'CFS', Unit__c = c.u.Id);
        insert s;
        c.cf1 = new Cash_Flow__c(Name = 'Down Payment', Unit__c = c.u.Id, Cash_Flow_Sum__c = s.Id,
            Date__c = System.today().addMonths(-1), Constant__c = 1000, Received_Amount__c = 0);
        c.cf2 = new Cash_Flow__c(Name = 'Installment 1', Unit__c = c.u.Id, Cash_Flow_Sum__c = s.Id,
            Date__c = System.today().addMonths(1), Constant__c = 2000, Received_Amount__c = 0);
        insert new List<Cash_Flow__c>{ c.cf1, c.cf2 };
        c.inv = new Invoice__c(Status__c = 'Pending', Invoice_Date__c = System.today(),
            Sub_Total_Amount__c = 1000, VAT_Amount__c = 0, Paid_Amount__c = 0, Unit__c = c.u.Id);
        insert c.inv;
        insert new Milestone_Invoice__c(Invoice__c = c.inv.Id, Cash_Flow__c = c.cf1.Id, Amount__c = 1000);
        // a receipt paying 1000 so the invoice starts Fully Paid
        c.r = new Receipt__c(Description__c = 'R', Unit__c = c.u.Id, Payment_Date__c = System.today(),
            Received_Amount__c = 1000, Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid');
        insert c.r;
        insert new Receipt_Amount__c(Receipt__c = c.r.Id, Invoice__c = c.inv.Id, Amount__c = 1000);
        return c;
    }

    @IsTest
    static void getInvoiceReturnsSummaryAndInstallments() {
        Ctx c = build();
        Test.startTest();
        InvoiceManageController.InvoiceView v = InvoiceManageController.getInvoice(c.inv.Id);
        Test.stopTest();

        System.assertEquals(c.inv.Id, v.invoiceId, 'Invoice id');
        System.assertEquals(1000, v.subTotal, 'Sub-total');
        System.assertEquals(1000, v.paid, 'Paid reflects the receipt');
        System.assertEquals(1, v.installments.size(), 'One covered installment');
        System.assert(v.cashFlowOptions.size() >= 2, 'Unit cash flows offered');
    }

    @IsTest
    static void addInstallmentRederivesStatus() {
        Ctx c = build(); // starts Fully Paid at 1000 (one 1000 installment, 1000 receipt)
        Test.startTest();
        InvoiceManageController.addInstallment(c.inv.Id, c.cf2.Id); // +2000 -> sub-total 3000, now partly paid
        Test.stopTest();

        Invoice__c inv = [SELECT Sub_Total_Amount__c, Status__c, Pending_Amount__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals(3000, inv.Sub_Total_Amount__c, 'Sub-total recomputed from covered installments');
        System.assertEquals('Partially Paid', inv.Status__c, 'Status re-derived to Partially Paid');
        System.assertEquals(2000, inv.Pending_Amount__c, 'Pending re-derived to 2000');
    }

    @IsTest
    static void addInstallmentDerivesAmountAndUpdatesInvoiceSubTotal() {
        Ctx c = build(); // starts with one installment (cf1 = 1000); invoice sub-total 1000
        Test.startTest();
        InvoiceManageController.addInstallment(c.inv.Id, c.cf2.Id); // amount NOT passed — derived
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM Milestone_Invoice__c WHERE Invoice__c = :c.inv.Id],
            'Second installment added');
        Milestone_Invoice__c mi2 = [
            SELECT Amount__c FROM Milestone_Invoice__c WHERE Invoice__c = :c.inv.Id AND Cash_Flow__c = :c.cf2.Id LIMIT 1
        ];
        // cf2 has Constant 2000, no project -> Amount_on_Invoice = Price_Formula = 2000
        System.assertEquals(2000, mi2.Amount__c, 'Amount derived from the cash flow, not entered');

        // Invoice sub-total now reflects both installments (1000 + 2000).
        Invoice__c invAfterAdd = [SELECT Sub_Total_Amount__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals(3000, invAfterAdd.Sub_Total_Amount__c, 'Sub-total recomputed to sum of installments');

        InvoiceManageController.removeInstallment(mi2.Id);
        System.assertEquals(1, [SELECT COUNT() FROM Milestone_Invoice__c WHERE Invoice__c = :c.inv.Id],
            'Installment removed');
        Invoice__c invAfterRemove = [SELECT Sub_Total_Amount__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals(1000, invAfterRemove.Sub_Total_Amount__c, 'Sub-total recomputed back down after removal');
    }

    @IsTest
    static void installmentFromOtherUnitRejected() {
        Ctx c = build();
        Unit__c u2 = new Unit__c(Title__c = 'other');
        insert u2;
        Cash_Flow_Sum__c s2 = new Cash_Flow_Sum__c(Name = 'CFS2', Unit__c = u2.Id);
        insert s2;
        Cash_Flow__c foreign = new Cash_Flow__c(Name = 'Foreign', Unit__c = u2.Id, Cash_Flow_Sum__c = s2.Id,
            Date__c = System.today(), Constant__c = 500, Received_Amount__c = 0);
        insert foreign;

        Test.startTest();
        Boolean threw = false;
        try {
            InvoiceManageController.addInstallment(c.inv.Id, foreign.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Installment from a different unit should be rejected');
    }

    @IsTest
    static void badConversionRateThrows() {
        Ctx c = build();
        Test.startTest();
        Boolean threw = false;
        try {
            InvoiceManageController.updateCurrency(c.inv.Id, true, 'USD', 0);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'A conversion rate of zero should throw');
    }

    @IsTest
    static void otherCurrencySetAndCleared() {
        Ctx c = build();
        Test.startTest();
        // turn on other currency
        InvoiceManageController.updateCurrency(c.inv.Id, true, 'USD', 3.67);
        Test.stopTest();

        Invoice__c withCur = [SELECT Secondary_Currency__c, Conversion_Rate__c, Secondary_Currency_Amount__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals('USD', withCur.Secondary_Currency__c, 'Secondary currency saved');
        System.assertEquals(3.67, withCur.Conversion_Rate__c, 'Conversion rate saved');
        System.assertEquals(3670, withCur.Secondary_Currency_Amount__c, 'Secondary amount = grand total x rate');

        // turn it off — fields clear
        InvoiceManageController.updateCurrency(c.inv.Id, false, null, null);
        Invoice__c off = [SELECT Secondary_Currency__c, Conversion_Rate__c, Secondary_Currency_Amount__c FROM Invoice__c WHERE Id = :c.inv.Id];
        System.assertEquals(null, off.Secondary_Currency__c, 'Secondary currency cleared');
        System.assertEquals(null, off.Conversion_Rate__c, 'Conversion rate cleared');
    }

    @IsTest
    static void otherCurrencyRequiresFields() {
        Ctx c = build();
        Test.startTest();
        Boolean threw = false;
        try {
            InvoiceManageController.updateCurrency(c.inv.Id, true, null, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Other currency on without a currency/rate should throw');
    }
}
