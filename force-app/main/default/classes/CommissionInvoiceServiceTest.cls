@isTest
private class CommissionInvoiceServiceTest {

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
    }

    private static TestRefs createTestData() {
        Account agency = new Account(
            Name = 'InvSvcTest Agency ' + String.valueOf(Crypto.getRandomLong()),
            Company_Email__c = 'invsvctest_' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
            Status__c = 'Completed',
            Skip_Trigger__c = true
        );
        Id rtId = getAccountRecordTypeId();
        if (rtId != null) agency.RecordTypeId = rtId;
        insert agency;

        Contact agent = new Contact(LastName = 'InvSvc Agent ' + String.valueOf(Crypto.getRandomLong()), AccountId = agency.Id);
        insert agent;

        Opportunity opp = new Opportunity(
            Name = 'InvSvcTest Opp ' + String.valueOf(Crypto.getRandomLong()),
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = agency.Id,
            Agency__c = agency.Id,
            Assisted_by_Agent__c = true,
            Agent__c = agent.Id,
            Amount = 1000000
        );
        insert opp;

        TestRefs refs = new TestRefs();
        refs.agencyId = agency.Id;
        refs.oppId = opp.Id;
        return refs;
    }

    private static Commission__c insertEligibleCommission(TestRefs refs) {
        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4
        );
        insert c;
        return c;
    }

    @isTest
    static void testHappyPathCreatesInvoiceAndFlipsStatus() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);

        Test.startTest();
        Id invoiceId = CommissionInvoiceService.generateInvoice(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, invoiceId, 'Service should return the new Invoice Id');

        Commission__c saved = [
            SELECT Status__c, Invoice__c, Invoice_Generated_Date__c
            FROM Commission__c
            WHERE Id = :c.Id
        ];
        System.assertEquals(invoiceId, saved.Invoice__c, 'Commission should be linked to the new invoice');
        System.assertEquals('Invoiced', saved.Status__c, 'Status should flip to Invoiced (via trigger)');
        System.assertEquals(Date.today(), saved.Invoice_Generated_Date__c);

        Invoice__c inv = [SELECT Sub_Total_Amount__c, Invoice_Date__c, Due_Date__c, Type__c FROM Invoice__c WHERE Id = :invoiceId];
        System.assertEquals(40000, inv.Sub_Total_Amount__c, 'Invoice sub-total should match Commission Amount');
        System.assertEquals(Date.today(), inv.Invoice_Date__c);
        System.assertEquals(Date.today().addDays(30), inv.Due_Date__c);
        System.assertEquals('Commission', inv.Type__c, 'Generated invoice should be flagged as Commission type so the sync flow runs');
    }

    @isTest
    static void testAlreadyInvoicedThrows() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);

        Invoice__c existing = new Invoice__c();
        insert existing;
        c.Invoice__c = existing.Id;
        update c;

        Test.startTest();
        try {
            CommissionInvoiceService.generateInvoice(c.Id);
            System.assert(false, 'Should have thrown for already-invoiced commission');
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            System.assert(e.getMessage().contains('already has an invoice'), 'Expected already-invoiced error, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testCancelledCommissionThrows() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);
        c.Manual_Override__c = 'Cancelled';
        update c;

        Test.startTest();
        try {
            CommissionInvoiceService.generateInvoice(c.Id);
            System.assert(false, 'Should have thrown for cancelled commission');
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            System.assert(e.getMessage().contains('Cancelled'), 'Expected status error, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testZeroAmountThrows() {
        TestRefs refs = createTestData();
        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Commission_Amount__c = 0
        );
        insert c;

        Test.startTest();
        try {
            CommissionInvoiceService.generateInvoice(c.Id);
            System.assert(false, 'Should have thrown for zero-amount commission');
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            System.assert(e.getMessage().contains('greater than 0'), 'Expected amount error, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testGenerateInvoiceNullIdThrows() {
        Test.startTest();
        try {
            CommissionInvoiceService.generateInvoice(null);
            System.assert(false, 'Should have thrown for null commission id');
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            System.assert(e.getMessage().contains('Commission Id is required'), 'Expected null-id error, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testGenerateInvoiceMissingRecordThrows() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);
        Id missingId = c.Id;
        delete c;

        Test.startTest();
        try {
            CommissionInvoiceService.generateInvoice(missingId);
            System.assert(false, 'Should have thrown for missing commission');
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            System.assert(e.getMessage().contains('Commission not found'), 'Expected not-found error, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testMarkPaidWithInvoiceUsesInvoiceSubtotalAndPaymentDate() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);
        Id invoiceId = CommissionInvoiceService.generateInvoice(c.Id);
        Date paymentDate = Date.today().addDays(-2);

        Test.startTest();
        CommissionInvoiceService.markPaid(c.Id, paymentDate);
        Test.stopTest();

        Commission__c saved = [
            SELECT Paid_Amount__c, Payment_Date__c
            FROM Commission__c
            WHERE Id = :c.Id
        ];
        System.assertEquals(40000, saved.Paid_Amount__c, 'Paid amount should follow invoice subtotal when available');
        System.assertEquals(paymentDate, saved.Payment_Date__c, 'Provided payment date should be used');

        Invoice__c inv = [
            SELECT Paid_Amount__c, Status__c
            FROM Invoice__c
            WHERE Id = :invoiceId
        ];
        System.assertEquals(40000, inv.Paid_Amount__c, 'Invoice paid amount should match subtotal');
        System.assertEquals('Fully Paid', inv.Status__c, 'Invoice should be marked fully paid');
    }

    @isTest
    static void testMarkPaidWithInvoiceFallsBackToCommissionAmount() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);
        Id invoiceId = CommissionInvoiceService.generateInvoice(c.Id);
        Invoice__c inv = new Invoice__c(Id = invoiceId, Sub_Total_Amount__c = 0);
        update inv;

        Test.startTest();
        CommissionInvoiceService.markPaid(c.Id);
        Test.stopTest();

        Commission__c saved = [
            SELECT Paid_Amount__c, Payment_Date__c, Commission_Amount__c
            FROM Commission__c
            WHERE Id = :c.Id
        ];
        System.assertEquals(saved.Commission_Amount__c, saved.Paid_Amount__c, 'Should fall back to commission amount when invoice subtotal is non-positive');
        System.assertEquals(Date.today(), saved.Payment_Date__c, 'Default payment date should be today');

        Invoice__c updatedInv = [
            SELECT Paid_Amount__c
            FROM Invoice__c
            WHERE Id = :invoiceId
        ];
        System.assertEquals(saved.Commission_Amount__c, updatedInv.Paid_Amount__c);
    }

    @isTest
    static void testMarkPaidWithoutInvoiceUsesCommissionAmount() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);

        Test.startTest();
        CommissionInvoiceService.markPaid(c.Id);
        Test.stopTest();

        Commission__c saved = [
            SELECT Paid_Amount__c, Commission_Amount__c, Payment_Date__c
            FROM Commission__c
            WHERE Id = :c.Id
        ];
        System.assertEquals(saved.Commission_Amount__c, saved.Paid_Amount__c, 'Without invoice, paid amount should equal commission amount');
        System.assertEquals(Date.today(), saved.Payment_Date__c);
    }

    @isTest
    static void testMarkPaidNullIdThrows() {
        Test.startTest();
        try {
            CommissionInvoiceService.markPaid(null);
            System.assert(false, 'Should have thrown for null commission id');
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            System.assert(e.getMessage().contains('Commission Id is required'), 'Expected null-id error, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testMarkPaidMissingRecordThrows() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);
        Id missingId = c.Id;
        delete c;

        Test.startTest();
        try {
            CommissionInvoiceService.markPaid(missingId);
            System.assert(false, 'Should have thrown for missing commission');
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            System.assert(e.getMessage().contains('Commission not found'), 'Expected not-found error, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testMarkPaidFullyPaidThrows() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);
        CommissionInvoiceService.markPaid(c.Id);

        Test.startTest();
        try {
            CommissionInvoiceService.markPaid(c.Id);
            System.assert(false, 'Should have thrown for fully paid commission');
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            System.assert(e.getMessage().contains('already Fully Paid'), 'Expected fully-paid error, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testMarkPaidCancelledThrows() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);
        c.Manual_Override__c = 'Cancelled';
        update c;

        Test.startTest();
        try {
            CommissionInvoiceService.markPaid(c.Id);
            System.assert(false, 'Should have thrown for cancelled commission');
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            System.assert(e.getMessage().contains('Cannot record payment: Commission is Cancelled'), 'Expected cancelled error, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testMarkPaidOnHoldThrows() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);
        c.Manual_Override__c = 'On Hold';
        update c;

        Test.startTest();
        try {
            CommissionInvoiceService.markPaid(c.Id);
            System.assert(false, 'Should have thrown for on-hold commission');
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            System.assert(e.getMessage().contains('Cannot record payment: Commission is On Hold'), 'Expected on-hold error, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testMarkPaidZeroAmountThrows() {
        TestRefs refs = createTestData();
        Commission__c c = new Commission__c(
            Agency__c = refs.agencyId,
            Opportunity__c = refs.oppId,
            Commission_Amount__c = 0
        );
        insert c;

        Test.startTest();
        try {
            CommissionInvoiceService.markPaid(c.Id);
            System.assert(false, 'Should have thrown for zero-amount commission');
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            System.assert(e.getMessage().contains('greater than 0 to record a payment'), 'Expected amount error, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testMarkPaidExplicitZeroPaymentAmountThrows() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);

        Test.startTest();
        try {
            CommissionInvoiceService.markPaid(c.Id, Date.today(), 0);
            System.assert(false, 'Should have thrown for zero payment amount');
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            System.assert(e.getMessage().contains('Payment Amount must be greater than 0'), 'Expected zero-payment error, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testMarkPaidExplicitAmountExceedsRemainingThrows() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);

        Test.startTest();
        try {
            CommissionInvoiceService.markPaid(c.Id, Date.today(), 50000);
            System.assert(false, 'Should have thrown when payment exceeds balance');
        } catch (CommissionInvoiceService.CommissionInvoiceException e) {
            System.assert(e.getMessage().contains('exceeds the remaining balance'), 'Expected overpayment error, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testMarkPaidPartialPaymentLeavesInvoicePartiallyPaid() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);
        Id invoiceId = CommissionInvoiceService.generateInvoice(c.Id);

        Test.startTest();
        CommissionInvoiceService.markPaid(c.Id, Date.today(), 10000);
        Test.stopTest();

        Invoice__c inv = [SELECT Paid_Amount__c, Status__c FROM Invoice__c WHERE Id = :invoiceId];
        System.assertEquals(10000, inv.Paid_Amount__c);
        System.assertEquals('Partially Paid', inv.Status__c);
    }

    @isTest
    static void testMarkPaidStoresPaymentMethod() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);

        Test.startTest();
        CommissionInvoiceService.markPaid(c.Id, Date.today(), 15000, 'Cheque');
        Test.stopTest();

        Commission__c saved = [SELECT Paid_Amount__c, Payment_Method__c FROM Commission__c WHERE Id = :c.Id];
        System.assertEquals(15000, saved.Paid_Amount__c);
        System.assertEquals('Cheque', saved.Payment_Method__c, 'Payment method should be stored on the commission');
    }

    @isTest
    static void testMarkPaidNullPaymentDateUsesToday() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);

        Test.startTest();
        CommissionInvoiceService.markPaid(c.Id, null, 20000);
        Test.stopTest();

        Commission__c saved = [SELECT Payment_Date__c, Paid_Amount__c FROM Commission__c WHERE Id = :c.Id];
        System.assertEquals(Date.today(), saved.Payment_Date__c);
        System.assertEquals(20000, saved.Paid_Amount__c);
    }

    @isTest
    static void testGenerateInvoiceBackfillsPaidAmountAndPartialStatus() {
        TestRefs refs = createTestData();
        Commission__c c = insertEligibleCommission(refs);
        c.Paid_Amount__c = 10000;
        update c;

        Test.startTest();
        Id invoiceId = CommissionInvoiceService.generateInvoice(c.Id);
        Test.stopTest();

        Invoice__c inv = [SELECT Paid_Amount__c, Status__c FROM Invoice__c WHERE Id = :invoiceId];
        System.assertEquals(10000, inv.Paid_Amount__c, 'Invoice should backfill paid amount from commission');
        System.assertEquals('Partially Paid', inv.Status__c, 'Invoice status should reflect partial payment');
    }

    @isTest
    static void testMarkPaidUpdatesLinkedUnitCommissionStatus() {
        Account agency = new Account(
            Name = 'InvSvcUnit Agency ' + String.valueOf(Crypto.getRandomLong()),
            Company_Email__c = 'invsvcunit_' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
            Status__c = 'Completed',
            Skip_Trigger__c = true
        );
        Id rtId = getAccountRecordTypeId();
        if (rtId != null) {
            agency.RecordTypeId = rtId;
        }
        insert agency;

        Contact agent = new Contact(LastName = 'InvSvcUnit Agent ' + String.valueOf(Crypto.getRandomLong()), AccountId = agency.Id);
        insert agent;

        Unit__c unit = new Unit__c(Title__c = 'InvSvcUnit ' + String.valueOf(Crypto.getRandomLong()));
        insert unit;

        Opportunity opp = new Opportunity(
            Name = 'InvSvcUnit Opp ' + String.valueOf(Crypto.getRandomLong()),
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

        Id invoiceId = CommissionInvoiceService.generateInvoice(c.Id);

        Test.startTest();
        CommissionInvoiceService.markPaid(c.Id, Date.today(), 10000);
        Test.stopTest();

        Commission__c updated = [
            SELECT Status__c, Paid_Amount__c
            FROM Commission__c
            WHERE Id = :c.Id
        ];
        System.assertEquals('Partially Paid', updated.Status__c, 'Commission status should reflect partial payment');
        System.assertEquals(10000, updated.Paid_Amount__c);

        Unit__c u = [SELECT Commission_Status__c FROM Unit__c WHERE Id = :unit.Id];
        System.assertEquals(
            'Partially Paid',
            u.Commission_Status__c,
            'Unit commission status is synced from commission via CommissionTriggerHandler'
        );

        Invoice__c inv = [SELECT Status__c FROM Invoice__c WHERE Id = :invoiceId];
        System.assertEquals('Partially Paid', inv.Status__c);
    }
}