/**
 * Tests for InvoiceCreateController (Create Invoice popup wizard backend). Runs with the engine flag
 * ON so we confirm Paid/Status derive after the invoice + milestones are inserted.
 *
 * The guard + validation tests deliberately avoid inserting an Opportunity; only the happy-path
 * tests create the booking (Opportunity insertion fires several record-triggered flows in this org).
 */
@IsTest
private class InvoiceCreateControllerTest {

    private class Ctx {
        Unit__c unit;
        Account acc;
        Opportunity opp;
        Cash_Flow__c cf1;
        Cash_Flow__c cf2;
        Financial_Detail__c fd;
    }

    /** First active Opportunity stage that isn't one the create guard excludes. */
    private static String pickBookingStage() {
        for (Schema.PicklistEntry e : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                String v = e.getValue();
                if (v != 'New' && v != 'Cancelled' && v != 'Transferred') return v;
            }
        }
        return null;
    }

    private static Ctx buildBase(Boolean dldDone) {
        insert new Financial_Engine_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(), Engine_Owns_Totals__c = true
        );
        Ctx c = new Ctx();
        c.unit = new Unit__c(Title__c = 'inv-create', DLD_Fee_Setup__c = dldDone);
        insert c.unit;

        Cash_Flow_Sum__c s = new Cash_Flow_Sum__c(Name = 'CFS', Unit__c = c.unit.Id);
        insert s;
        c.cf1 = new Cash_Flow__c(Name = 'Down Payment', Unit__c = c.unit.Id, Cash_Flow_Sum__c = s.Id,
            Date__c = Date.today().addMonths(-1), Constant__c = 1000, Received_Amount__c = 0,
            Installment_Milestone__c = '1st Installment', Percent__c = 10,
            Is_Invoiced__c = false, Waived_Off__c = false);
        c.cf2 = new Cash_Flow__c(Name = 'Installment 1', Unit__c = c.unit.Id, Cash_Flow_Sum__c = s.Id,
            Date__c = Date.today().addMonths(1), Constant__c = 2000, Received_Amount__c = 0,
            Installment_Milestone__c = '2nd Installment', Percent__c = 20,
            Is_Invoiced__c = false, Waived_Off__c = false);
        insert new List<Cash_Flow__c>{ c.cf1, c.cf2 };

        c.fd = new Financial_Detail__c(Name = 'Emirates NBD');
        insert c.fd;
        return c;
    }

    private static void addBooking(Ctx c) {
        c.acc = new Account(Name = 'Test Client');
        insert c.acc;
        // On create, Add_Opportunity_Default_Values_on_Creation forces StageName = 'New', so the
        // booking stage must be applied via a follow-up update (mirrors the real Book Unit process).
        c.opp = new Opportunity(Name = 'Booking Opp', StageName = pickBookingStage(),
            CloseDate = Date.today().addDays(30), AccountId = c.acc.Id, Unit__c = c.unit.Id);
        insert c.opp;
        c.opp.StageName = 'Booked';
        update c.opp;
    }

    private static InvoiceCreateController.CreateRequest baseRequest(Ctx c, List<String> cfIds) {
        InvoiceCreateController.CreateRequest req = new InvoiceCreateController.CreateRequest();
        req.unitId = c.unit.Id;
        req.cashFlowIds = cfIds;
        req.invoiceDate = Date.today();
        req.dueDate = Date.today().addDays(2);
        req.financialDetailId = c.fd.Id;
        req.description = 'Test invoice';
        req.otherCurrency = false;
        return req;
    }

    // ---- guard tests (no Opportunity needed) -----------------------------------------------------

    @IsTest
    static void getContextBlocksWhenDldMissing() {
        Ctx c = buildBase(false);
        Test.startTest();
        InvoiceCreateController.CreateContext ctx = InvoiceCreateController.getContext(c.unit.Id);
        Test.stopTest();

        System.assertEquals(false, ctx.canProceed, 'Should be blocked when DLD setup is not done');
        System.assert(ctx.blockReason != null && ctx.blockReason.containsIgnoreCase('DLD'),
            'Block reason should mention DLD: ' + ctx.blockReason);
    }

    @IsTest
    static void getContextBlocksWhenNoBooking() {
        Ctx c = buildBase(true); // DLD done, but no Opportunity created
        Test.startTest();
        InvoiceCreateController.CreateContext ctx = InvoiceCreateController.getContext(c.unit.Id);
        Test.stopTest();

        System.assertEquals(false, ctx.canProceed, 'Should be blocked when there is no booking');
        System.assert(ctx.blockReason != null && ctx.blockReason.containsIgnoreCase('booking'),
            'Block reason should mention booking: ' + ctx.blockReason);
    }

    @IsTest
    static void createInvoiceRejectsNoInstallments() {
        Ctx c = buildBase(true);
        Boolean threw = false;
        Test.startTest();
        try {
            InvoiceCreateController.createInvoice(JSON.serialize(baseRequest(c, new List<String>())));
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Creating with no selected installments should throw');
    }

    @IsTest
    static void createInvoiceRejectsBadConversionRate() {
        Ctx c = buildBase(true);
        InvoiceCreateController.CreateRequest req = baseRequest(c, new List<String>{ c.cf1.Id });
        req.otherCurrency = true;
        req.secondaryCurrency = 'USD';
        req.conversionRate = 0;
        Boolean threw = false;
        Test.startTest();
        try {
            InvoiceCreateController.createInvoice(JSON.serialize(req));
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'A conversion rate of zero should throw');
    }

    // ---- happy-path tests (create a booking Opportunity) -----------------------------------------

    @IsTest
    static void getContextReturnsInstallmentsAndContext() {
        Ctx c = buildBase(true);
        addBooking(c);
        Test.startTest();
        InvoiceCreateController.CreateContext ctx = InvoiceCreateController.getContext(c.unit.Id);
        Test.stopTest();

        System.assertEquals(true, ctx.canProceed, 'Should proceed when DLD done and booking exists');
        System.assertEquals(c.opp.Id, ctx.opportunityId, 'Booking opportunity resolved');
        System.assert(ctx.installments.size() >= 2, 'Both uninvoiced installments offered');
        System.assert(ctx.secondaryCurrencyOptions.size() > 0, 'Currency options provided');
        System.assertEquals(Date.today(), ctx.defaultInvoiceDate, 'Default invoice date is today');
    }

    @IsTest
    static void createInvoiceInsertsInvoiceMilestonesAndMarksCashFlows() {
        Ctx c = buildBase(true);
        addBooking(c);

        // Expected sub-total/VAT taken from the DB (Amount_on_Invoice__c / VAT_Amount__c are formulas).
        Map<Id, Cash_Flow__c> byId = new Map<Id, Cash_Flow__c>([
            SELECT Amount_on_Invoice__c, VAT_Amount__c FROM Cash_Flow__c
            WHERE Id IN (:c.cf1.Id, :c.cf2.Id)
        ]);
        Decimal expectedSub = 0, expectedVat = 0;
        for (Cash_Flow__c cf : byId.values()) {
            expectedSub += (cf.Amount_on_Invoice__c == null ? 0 : cf.Amount_on_Invoice__c);
            expectedVat += (cf.VAT_Amount__c == null ? 0 : cf.VAT_Amount__c);
        }

        Test.startTest();
        Id invId = InvoiceCreateController.createInvoice(JSON.serialize(
            baseRequest(c, new List<String>{ c.cf1.Id, c.cf2.Id })
        ));
        Test.stopTest();

        System.assertNotEquals(null, invId, 'Invoice created');
        Invoice__c inv = [
            SELECT Unit__c, Opportunity__c, Account__c, Status__c, Type__c,
                   Sub_Total_Amount__c, VAT_Amount__c, Grand_Total_Amount__c, Paid_Amount__c,
                   Financial_Detail__c, Description__c
            FROM Invoice__c WHERE Id = :invId
        ];
        System.assertEquals(c.unit.Id, inv.Unit__c, 'Unit set');
        System.assertEquals(c.opp.Id, inv.Opportunity__c, 'Opportunity set');
        System.assertEquals(c.acc.Id, inv.Account__c, 'Account set');
        System.assertEquals('Proforma Invoice', inv.Type__c, 'Type is Proforma Invoice');
        System.assertEquals(expectedSub, inv.Sub_Total_Amount__c, 'Sub-total = sum of covered installments');
        System.assertEquals(expectedVat, inv.VAT_Amount__c, 'VAT = sum of covered installments');
        System.assertEquals(expectedSub + expectedVat, inv.Grand_Total_Amount__c, 'Grand = sub + VAT');
        System.assertEquals(0, inv.Paid_Amount__c == null ? 0 : inv.Paid_Amount__c,
            'Nothing paid yet (engine-derived)');
        System.assertEquals('Pending', inv.Status__c, 'Status Pending');

        System.assertEquals(2, [SELECT COUNT() FROM Milestone_Invoice__c WHERE Invoice__c = :invId],
            'One milestone per covered installment');

        System.assertEquals(2, [
            SELECT COUNT() FROM Cash_Flow__c
            WHERE Id IN (:c.cf1.Id, :c.cf2.Id) AND Is_Invoiced__c = true
        ], 'Covered cash flows marked invoiced');
    }

    @IsTest
    static void createInvoiceStoresSecondaryCurrency() {
        Ctx c = buildBase(true);
        addBooking(c);
        InvoiceCreateController.CreateRequest req = baseRequest(c, new List<String>{ c.cf1.Id });
        req.otherCurrency = true;
        req.secondaryCurrency = 'USD';
        req.conversionRate = 3.67;

        Test.startTest();
        Id invId = InvoiceCreateController.createInvoice(JSON.serialize(req));
        Test.stopTest();

        Invoice__c inv = [
            SELECT Sub_Total_Amount__c, Secondary_Currency__c, Conversion_Rate__c, Secondary_Currency_Amount__c
            FROM Invoice__c WHERE Id = :invId
        ];
        System.assertEquals('USD', inv.Secondary_Currency__c, 'Secondary currency stored');
        System.assertEquals(3.67, inv.Conversion_Rate__c, 'Conversion rate stored');
        // Follows the existing flow: Sub-Total / rate.
        Decimal expected = (inv.Sub_Total_Amount__c / 3.67).setScale(2);
        System.assertEquals(expected, inv.Secondary_Currency_Amount__c.setScale(2),
            'Secondary amount = Sub-Total / rate');
    }
}
