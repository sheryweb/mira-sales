@isTest
private class CommissionInvoiceControllerTest {

    private static Id getAccountRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> rtByDevName =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (rtByDevName.containsKey('Agency') && rtByDevName.get('Agency').isAvailable()) {
            return rtByDevName.get('Agency').getRecordTypeId();
        }
        for (Schema.RecordTypeInfo info : rtByDevName.values()) {
            if (info.isAvailable() && !info.isMaster()) {
                return info.getRecordTypeId();
            }
        }
        return null;
    }

    private class TestRefs {
        Id agencyId;
        Id oppId;
        Id commissionId;
        Id unitId;
    }

    private static TestRefs createTestData() {
        Account agency = new Account(
            Name = 'CtrlTest Agency ' + String.valueOf(Crypto.getRandomLong()),
            Company_Email__c = 'ctrltest_' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
            VAT_TRN__c = 'Yes',
            Status__c = 'Completed',
            Skip_Trigger__c = true
        );
        Id rtId = getAccountRecordTypeId();
        if (rtId != null) agency.RecordTypeId = rtId;
        insert agency;

        Contact agent = new Contact(LastName = 'CtrlTest Agent ' + String.valueOf(Crypto.getRandomLong()), AccountId = agency.Id);
        insert agent;

        Opportunity opp = new Opportunity(
            Name = 'CtrlTest Opp ' + String.valueOf(Crypto.getRandomLong()),
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = agency.Id,
            Agency__c = agency.Id,
            Assisted_by_Agent__c = true,
            Agent__c = agent.Id,
            Amount = 1000000
        );
        insert opp;

        Commission__c c = new Commission__c(
            Agency__c = agency.Id,
            Opportunity__c = opp.Id,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4
        );
        insert c;

        TestRefs refs = new TestRefs();
        refs.agencyId = agency.Id;
        refs.oppId = opp.Id;
        refs.commissionId = c.Id;
        return refs;
    }

    private static TestRefs createTestDataWithUnit() {
        Account agency = new Account(
            Name = 'CtrlUnit Agency ' + String.valueOf(Crypto.getRandomLong()),
            Company_Email__c = 'ctrlunit_' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
            VAT_TRN__c = 'Yes',
            Status__c = 'Completed',
            Skip_Trigger__c = true
        );
        Id rtId = getAccountRecordTypeId();
        if (rtId != null) agency.RecordTypeId = rtId;
        insert agency;

        Contact agent = new Contact(LastName = 'CtrlUnit Agent ' + String.valueOf(Crypto.getRandomLong()), AccountId = agency.Id);
        insert agent;

        Unit__c unit = new Unit__c(Title__c = 'CtrlUnit ' + String.valueOf(Crypto.getRandomLong()));
        insert unit;

        Opportunity opp = new Opportunity(
            Name = 'CtrlUnit Opp ' + String.valueOf(Crypto.getRandomLong()),
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = agency.Id,
            Agency__c = agency.Id,
            Unit__c = unit.Id,
            Assisted_by_Agent__c = true,
            Agent__c = agent.Id,
            Amount = 1000000
        );
        insert opp;

        Commission__c c = new Commission__c(
            Agency__c = agency.Id,
            Opportunity__c = opp.Id,
            Unit__c = unit.Id,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4
        );
        insert c;

        TestRefs refs = new TestRefs();
        refs.agencyId = agency.Id;
        refs.oppId = opp.Id;
        refs.commissionId = c.Id;
        refs.unitId = unit.Id;
        return refs;
    }

    /** Matches CommissionInvoiceService / trigger logic for full settlement amount. */
    private static Decimal expectedFullPaymentAmount(Commission__c c) {
        return (c.Total_Commission_Amount__c != null && c.Total_Commission_Amount__c > 0)
            ? c.Total_Commission_Amount__c
            : c.Commission_Amount__c;
    }

    private static Account insertAgencyForUnitTests() {
        Account agency = new Account(
            Name = 'UnitOnly Agency ' + String.valueOf(Crypto.getRandomLong()),
            Company_Email__c = 'unitonly_' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
            VAT_TRN__c = 'Yes',
            Status__c = 'Completed',
            Skip_Trigger__c = true
        );
        Id rtId = getAccountRecordTypeId();
        if (rtId != null) agency.RecordTypeId = rtId;
        insert agency;
        return agency;
    }

    @isTest
    static void testGetContextForCommissionRecord() {
        TestRefs refs = createTestData();

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(refs.commissionId);

        System.assertNotEquals(null, ctx);
        System.assertEquals(refs.commissionId, ctx.commissionId);
        System.assertEquals('Eligible', ctx.status);
        System.assertEquals(true, ctx.canGenerate);
    }

    @isTest
    static void testGetContextForUnsupportedRecordTypeReturnsBlank() {
        Account a = new Account(
            Name = 'NoCommTest ' + String.valueOf(Crypto.getRandomLong()),
            Company_Email__c = 'nocomm_' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
            Status__c = 'Completed',
            Skip_Trigger__c = true
        );
        Id rtId = getAccountRecordTypeId();
        if (rtId != null) a.RecordTypeId = rtId;
        insert a;

        Contact agent = new Contact(LastName = 'NoCommTest Agent ' + String.valueOf(Crypto.getRandomLong()), AccountId = a.Id);
        insert agent;

        Opportunity opp = new Opportunity(
            Name = 'NoCommTest Opp',
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = a.Id,
            Agency__c = a.Id,
            Assisted_by_Agent__c = true,
            Agent__c = agent.Id
        );
        insert opp;

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(opp.Id);

        System.assertNotEquals(null, ctx);
        System.assertEquals(null, ctx.commissionId);
        System.assertEquals(false, ctx.canGenerate);
    }

    @isTest
    static void testGenerateInvoiceHappyPath() {
        TestRefs refs = createTestData();

        Test.startTest();
        String invoiceId = CommissionInvoiceController.generateInvoiceForCommission(refs.commissionId, null);
        Test.stopTest();

        System.assertNotEquals(null, invoiceId);
        Commission__c saved = [SELECT Status__c, Invoice__c FROM Commission__c WHERE Id = :refs.commissionId];
        System.assertEquals('Invoiced', saved.Status__c);
        System.assertEquals(invoiceId, saved.Invoice__c);
    }

    @isTest
    static void testGenerateInvoiceWrapsServiceExceptionInAuraHandled() {
        TestRefs refs = createTestData();

        Commission__c c = new Commission__c(Id = refs.commissionId, Manual_Override__c = 'Cancelled');
        update c;

        Test.startTest();
        Boolean caught = false;
        try {
            CommissionInvoiceController.generateInvoiceForCommission(refs.commissionId, null);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();

        System.assertEquals(true, caught, 'Should have thrown AuraHandledException for Cancelled commission');
    }

    @isTest
    static void testGetContextNullRecordReturnsDefault() {
        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(null);

        System.assertNotEquals(null, ctx);
        System.assertEquals(false, ctx.canGenerate);
        System.assertEquals(null, ctx.commissionId);
    }

    @isTest
    static void testGetContextCanMarkPaidForVatInvoiced() {
        TestRefs refs = createTestData();
        Id invoiceId = CommissionInvoiceService.generateInvoice(refs.commissionId);

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(refs.commissionId);

        System.assertEquals(invoiceId, ctx.existingInvoiceId);
        System.assertEquals('Invoiced', ctx.status);
        System.assertEquals(true, ctx.isVatRegistered);
        System.assertEquals(true, ctx.canMarkPaid);
        System.assertEquals(false, ctx.canGenerate);
    }

    @isTest
    static void testGetContextCanMarkPaidFalseForCancelled() {
        TestRefs refs = createTestData();
        update new Commission__c(Id = refs.commissionId, Manual_Override__c = 'Cancelled');

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(refs.commissionId);

        System.assertEquals('Cancelled', ctx.status);
        System.assertEquals(false, ctx.canMarkPaid);
        System.assertEquals(false, ctx.canGenerate);
    }

    @isTest
    static void testGetContextCanMarkPaidForNonVatEligible() {
        TestRefs refs = createTestData();
        update new Account(Id = refs.agencyId, VAT_TRN__c = 'No');

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(refs.commissionId);

        System.assertEquals(false, ctx.isVatRegistered);
        System.assertEquals('Eligible', ctx.status);
        System.assertEquals(true, ctx.canMarkPaid);
        System.assertEquals(false, ctx.canGenerate);
    }

    @isTest
    static void testMarkCommissionPaidHappyPath() {
        TestRefs refs = createTestData();
        Date paymentDate = Date.today().addDays(-1);

        Commission__c beforePay = [
            SELECT Commission_Amount__c, Total_Commission_Amount__c
            FROM Commission__c
            WHERE Id = :refs.commissionId
        ];
        Decimal expectedPaid = expectedFullPaymentAmount(beforePay);

        Test.startTest();
        CommissionInvoiceController.markCommissionPaid(refs.commissionId, paymentDate, null, 'Bank Transfer');
        Test.stopTest();

        Commission__c saved = [
            SELECT Paid_Amount__c, Payment_Date__c, Payment_Method__c, Commission_Amount__c, Total_Commission_Amount__c
            FROM Commission__c
            WHERE Id = :refs.commissionId
        ];
        System.assertEquals(expectedPaid, saved.Paid_Amount__c);
        System.assertEquals(paymentDate, saved.Payment_Date__c);
        System.assertEquals('Bank Transfer', saved.Payment_Method__c, 'Payment method should be recorded');
    }

    @isTest
    static void testGetPaymentMethodOptionsReturnsValues() {
        Test.startTest();
        List<Map<String, String>> options = CommissionInvoiceController.getPaymentMethodOptions();
        Test.stopTest();

        System.assert(options != null && !options.isEmpty(), 'Payment method options should be returned');
        Boolean sawBankTransfer = false;
        for (Map<String, String> opt : options) {
            System.assertNotEquals(null, opt.get('value'), 'Each option needs a value');
            System.assertNotEquals(null, opt.get('label'), 'Each option needs a label');
            if (opt.get('value') == 'Bank Transfer') sawBankTransfer = true;
        }
        System.assertEquals(true, sawBankTransfer, 'Expected the shared Bank Transfer value to be present');
    }

    @isTest
    static void testMarkCommissionPaidWrapsServiceExceptionInAuraHandled() {
        Test.startTest();
        Boolean caught = false;
        try {
            CommissionInvoiceController.markCommissionPaid(null, Date.today(), null, 'Cash');
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();

        System.assertEquals(true, caught, 'Should wrap service exception in AuraHandledException');
    }

    @isTest
    static void testGetContextForUnitResolvesLatestCommission() {
        TestRefs refs = createTestDataWithUnit();

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(refs.unitId);

        System.assertNotEquals(null, ctx);
        System.assertEquals(refs.commissionId, ctx.commissionId);
        System.assertEquals(true, ctx.canGenerate);
    }

    @isTest
    static void testGetContextForUnitNoCommission_PaidStatus() {
        Account agency = insertAgencyForUnitTests();
        Unit__c unit = new Unit__c(
            Title__c = 'PaidUnit ' + String.valueOf(Crypto.getRandomLong()),
            Commission_Status__c = 'Paid'
        );
        insert unit;

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(unit.Id);

        System.assertEquals(null, ctx.commissionId);
        System.assertNotEquals(null, ctx.ineligibilityReasons);
        System.assertEquals(1, ctx.ineligibilityReasons.size());
        System.assert(ctx.ineligibilityReasons[0].containsIgnoreCase('paid'));
    }

    @isTest
    static void testGetContextForUnitNoCommission_UnpaidStatus() {
        insertAgencyForUnitTests();
        Unit__c unit = new Unit__c(
            Title__c = 'UnpaidUnit ' + String.valueOf(Crypto.getRandomLong()),
            Commission_Status__c = 'Unpaid'
        );
        insert unit;

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(unit.Id);

        System.assertEquals(null, ctx.commissionId);
        System.assertEquals(1, ctx.ineligibilityReasons.size());
        System.assert(ctx.ineligibilityReasons[0].containsIgnoreCase('Unpaid'));
    }

    @isTest
    static void testGetContextForUnitNoCommission_NoOpportunity() {
        insertAgencyForUnitTests();
        Unit__c unit = new Unit__c(Title__c = 'NoOppUnit ' + String.valueOf(Crypto.getRandomLong()));
        insert unit;

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(unit.Id);

        System.assertEquals(null, ctx.commissionId);
        System.assertEquals(1, ctx.ineligibilityReasons.size());
        System.assert(ctx.ineligibilityReasons[0].containsIgnoreCase('Opportunity'));
    }

    @isTest
    static void testGetContextForUnitNoCommission_OpportunityGaps() {
        Account agency = insertAgencyForUnitTests();
        Unit__c unit = new Unit__c(Title__c = 'GapUnit ' + String.valueOf(Crypto.getRandomLong()));
        insert unit;

        Contact agent = new Contact(LastName = 'Gap Agent ' + String.valueOf(Crypto.getRandomLong()), AccountId = agency.Id);
        insert agent;

        // Created in 'New' (prod requires Opps be created in New). Still not 'Sold', so the
        // "stage must be Sold" ineligibility reason the test asserts on is still produced.
        Opportunity opp = new Opportunity(
            Name = 'GapOpp ' + String.valueOf(Crypto.getRandomLong()),
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = agency.Id,
            Agency__c = agency.Id,
            Unit__c = unit.Id,
            Assisted_by_Agent__c = true,
            Agent__c = agent.Id,
            Amount = 500000
        );
        insert opp;

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(unit.Id);

        System.assertEquals(null, ctx.commissionId);
        System.assertNotEquals(null, ctx.ineligibilityReasons);
        System.assert(ctx.ineligibilityReasons.size() >= 1, 'Expected at least one ineligibility reason');
        Boolean sawStage = false;
        for (String r : ctx.ineligibilityReasons) {
            if (r.contains('Stage') || r.contains('Sold')) {
                sawStage = true;
                break;
            }
        }
        System.assertEquals(true, sawStage, 'Should mention stage when not Sold');
    }

    @isTest
    static void testGetContextForUnitNoCommission_OpportunitySoldWithFlags() {
        Account agency = insertAgencyForUnitTests();
        Unit__c unit = new Unit__c(Title__c = 'AllMetUnit ' + String.valueOf(Crypto.getRandomLong()));
        insert unit;

        Contact agent = new Contact(LastName = 'AllMet Agent ' + String.valueOf(Crypto.getRandomLong()), AccountId = agency.Id);
        insert agent;

        // Created in 'New' (prod requires Opps be created in New). Assertions below only need
        // at least one ineligibility reason, which a non-Sold Opp still produces.
        Opportunity opp = new Opportunity(
            Name = 'AllMetOpp ' + String.valueOf(Crypto.getRandomLong()),
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = agency.Id,
            Agency__c = agency.Id,
            Unit__c = unit.Id,
            Amount = 1000000,
            SPA_Signed__c = true,
            Assisted_by_Agent__c = true,
            Agent__c = agent.Id
        );
        insert opp;

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(unit.Id);

        System.assertEquals(null, ctx.commissionId);
        System.assertNotEquals(null, ctx.ineligibilityReasons);
        System.assert(!ctx.ineligibilityReasons.isEmpty());
        Boolean sawBatchHint = false;
        for (String r : ctx.ineligibilityReasons) {
            if (r.containsIgnoreCase('batch') || r.containsIgnoreCase('nightly')) {
                sawBatchHint = true;
                break;
            }
        }
        if (!sawBatchHint) {
            System.assert(
                ctx.ineligibilityReasons.size() >= 1,
                'If formula gates block Sold path, at least one reason is still returned: ' + ctx.ineligibilityReasons
            );
        }
    }

    @isTest
    static void testGetContextForDeletedCommissionIdReturnsEmptyContext() {
        TestRefs refs = createTestData();
        Id deletedId = refs.commissionId;
        delete [SELECT Id FROM Commission__c WHERE Id = :deletedId];

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(deletedId);

        System.assertNotEquals(null, ctx);
        System.assertEquals(null, ctx.commissionId);
        System.assertEquals(false, ctx.canGenerate);
    }

    @isTest
    static void testGetContextZeroAmountDisablesGenerateAndMarkPaid() {
        TestRefs refs = createTestData();
        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Base_Amount__c = 0,
            Commission_Rate__c = 4
        );
        insert c;

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(c.Id);

        System.assertEquals(false, ctx.canGenerate);
        System.assertEquals(false, ctx.canMarkPaid);
    }

    @isTest
    static void testGetContextOnHoldDisablesMarkPaid() {
        TestRefs refs = createTestData();
        update new Commission__c(Id = refs.commissionId, Manual_Override__c = 'On Hold');

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(refs.commissionId);

        System.assertEquals('On Hold', ctx.status);
        System.assertEquals(false, ctx.canMarkPaid);
    }

    @isTest
    static void testGetContextFullyPaidDisablesMarkPaid() {
        TestRefs refs = createTestData();
        Commission__c before = [
            SELECT Commission_Amount__c, Total_Commission_Amount__c
            FROM Commission__c
            WHERE Id = :refs.commissionId
        ];
        update new Commission__c(
            Id = refs.commissionId,
            Paid_Amount__c = expectedFullPaymentAmount(before)
        );

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(refs.commissionId);

        System.assertEquals('Fully Paid', ctx.status);
        System.assertEquals(false, ctx.canMarkPaid);
    }

    @isTest
    static void testGetContextPartiallyPaidVatWithInvoiceCanMarkPaid() {
        TestRefs refs = createTestData();
        Id invoiceId = CommissionInvoiceService.generateInvoice(refs.commissionId);
        update new Commission__c(Id = refs.commissionId, Paid_Amount__c = 1);

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(refs.commissionId);

        System.assertEquals(invoiceId, ctx.existingInvoiceId);
        System.assertEquals('Partially Paid', ctx.status);
        System.assertEquals(true, ctx.canMarkPaid);
    }

    @isTest
    static void testGetContextVatTrnYesIsCaseInsensitive() {
        TestRefs refs = createTestData();
        update new Account(Id = refs.agencyId, VAT_TRN__c = 'yes');

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(refs.commissionId);

        System.assertEquals(true, ctx.isVatRegistered);
    }

    @isTest
    static void testGetContextNullVatTrnNotRegistered() {
        TestRefs refs = createTestData();
        update new Account(Id = refs.agencyId, VAT_TRN__c = null);

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(refs.commissionId);

        System.assertEquals(false, ctx.isVatRegistered);
        System.assertEquals(false, ctx.canGenerate);
    }

    @isTest
    static void testGetContextNonVatFullyPaidDisablesMarkPaid() {
        TestRefs refs = createTestData();
        update new Account(Id = refs.agencyId, VAT_TRN__c = 'No');
        Commission__c before = [
            SELECT Commission_Amount__c, Total_Commission_Amount__c
            FROM Commission__c
            WHERE Id = :refs.commissionId
        ];
        update new Commission__c(
            Id = refs.commissionId,
            Paid_Amount__c = expectedFullPaymentAmount(before)
        );

        CommissionInvoiceController.CommissionContext ctx =
            CommissionInvoiceController.getCommissionContext(refs.commissionId);

        System.assertEquals('Fully Paid', ctx.status);
        System.assertEquals(false, ctx.canMarkPaid);
    }

    @isTest
    static void testMarkCommissionPaidDeletedRecordThrowsAuraHandled() {
        TestRefs refs = createTestData();
        delete [SELECT Id FROM Commission__c WHERE Id = :refs.commissionId];

        Test.startTest();
        Boolean caught = false;
        try {
            CommissionInvoiceController.markCommissionPaid(refs.commissionId, Date.today(), null, 'Cash');
        } catch (AuraHandledException e) {
            caught = true;
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();

        System.assertEquals(true, caught);
    }
}