@isTest
private class InvoiceCommissionPDFControllerTest {

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

    private static Account createAgency(String vatTrn) {
        Long suffix = Crypto.getRandomLong();
        Account a = new Account(
            Name = 'CommPDFTest Agency ' + suffix,
            Company_Email__c = 'commpdf_' + suffix + '@example.com',
            VAT_TRN__c = vatTrn,
            Skip_Trigger__c = true
        );
        Id rtId = getAccountRecordTypeId();
        if (rtId != null) a.RecordTypeId = rtId;
        insert a;
        return a;
    }

    private static Invoice__c createInvoice(Id agencyId, Decimal subTotal, Decimal paidAmount) {
        Invoice__c inv = new Invoice__c(
            Account__c = agencyId,
            Sub_Total_Amount__c = subTotal,
            Paid_Amount__c = paidAmount,
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today().addDays(30),
            Type__c = 'Commission'
        );
        insert inv;
        return inv;
    }

    private static Opportunity createOpportunity(Id agencyId) {
        Opportunity opp = new Opportunity(
            Name = 'CommPDFTest Opp ' + Crypto.getRandomLong(),
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = agencyId,
            Agency__c = agencyId,
            Amount = 1000000
        );
        insert opp;
        return opp;
    }

    private static void setPageParam(Id invoiceId) {
        Test.setCurrentPage(Page.InvoiceCommissionPDF);
        ApexPages.currentPage().getParameters().put('id', String.valueOf(invoiceId));
    }

    @isTest
    static void testVatRegisteredAgencyHappyPath() {
        Account agency = createAgency('Yes');
        Invoice__c inv = createInvoice(agency.Id, 40000, 0);
        setPageParam(inv.Id);

        Test.startTest();
        InvoiceCommissionPDFController ctrl = new InvoiceCommissionPDFController();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.invoice, 'Invoice should be loaded');
        System.assertEquals(true, ctrl.isVatRegistered, 'Agency with VAT_TRN__c=Yes should be flagged VAT registered');
        System.assertEquals(agency.Name, ctrl.agencyName);
        System.assertEquals('Sales Commission', ctrl.lineItemDescription, 'Without linked Commission, fallback to Sales Commission');
        System.assertEquals('5%', ctrl.getVatPercentDisplay());
        System.assertEquals('AED', ctrl.getCurrencySymbol(), 'No Unit linked → default AED');
        System.assertEquals('', ctrl.getFormattedSalePrice(), 'No Unit linked → empty sale price');
        System.assertNotEquals(null, ctrl.formattedInvoiceDate, 'Invoice_Date__c was set, formatted date should be populated');
        System.assertNotEquals(null, ctrl.getTotalInWords());
        System.assert(ctrl.getTotalInWords().contains('AED Only'), 'totalInWords should end with AED Only when not POST HOTEL');

        // Exercise all the formatted-amount getters
        System.assertNotEquals(null, ctrl.getFormattedSubTotal());
        System.assertNotEquals(null, ctrl.getFormattedVATAmount());
        System.assertNotEquals(null, ctrl.getFormattedGrandTotal());
        System.assert(String.isNotBlank(ctrl.getTotalInWords()),
            'totalInWords getter should be populated for Visualforce PDF binding');
        System.assertNotEquals(null, ctrl.getFormattedPaidAmount());
        System.assertNotEquals(null, ctrl.getFormattedAmountInclVat());
    }

    @isTest
    static void testNonVatAgencyShowsZeroVat() {
        Account agency = createAgency('No');
        Invoice__c inv = createInvoice(agency.Id, 40000, 0);
        setPageParam(inv.Id);

        Test.startTest();
        InvoiceCommissionPDFController ctrl = new InvoiceCommissionPDFController();
        Test.stopTest();

        System.assertEquals(false, ctrl.isVatRegistered, 'VAT_TRN__c=No → not VAT registered');
        System.assertEquals('0%', ctrl.getVatPercentDisplay(), 'Non-VAT → 0% display');
        System.assertEquals('0.00', ctrl.getFormattedVATAmount(), 'Non-VAT → 0 VAT amount');
        // For a 40,000 sub-total and no VAT, Amount Incl VAT == Sub Total
        System.assertEquals(ctrl.getFormattedSubTotal(), ctrl.getFormattedAmountInclVat(),
            'Non-VAT: Amount Incl VAT should equal Sub Total');
    }

    @isTest
    static void testCommissionDescriptionUsedWhenLinked() {
        Account agency = createAgency('Yes');
        Invoice__c inv = createInvoice(agency.Id, 50000, 0);
        Opportunity opp = createOpportunity(agency.Id);

        Commission__c c = new Commission__c(
            Agency__c = agency.Id,
            Opportunity__c = opp.Id,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 5,
            Description__c = 'Custom Sales Commission Description',
            Invoice__c = inv.Id
        );
        insert c;

        setPageParam(inv.Id);

        Test.startTest();
        InvoiceCommissionPDFController ctrl = new InvoiceCommissionPDFController();
        Test.stopTest();

        System.assertEquals('Custom Sales Commission Description', ctrl.lineItemDescription,
            'lineItemDescription should come from the linked Commission.Description__c');
    }

    @isTest
    static void testCommissionWithBlankDescriptionFallsBackToDefault() {
        Account agency = createAgency('Yes');
        Invoice__c inv = createInvoice(agency.Id, 30000, 0);
        Opportunity opp = createOpportunity(agency.Id);

        Commission__c c = new Commission__c(
            Agency__c = agency.Id,
            Opportunity__c = opp.Id,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 3,
            Description__c = '',
            Invoice__c = inv.Id
        );
        insert c;

        setPageParam(inv.Id);

        Test.startTest();
        InvoiceCommissionPDFController ctrl = new InvoiceCommissionPDFController();
        Test.stopTest();

        System.assertEquals('Sales Commission', ctrl.lineItemDescription,
            'Blank description should fall back to default Sales Commission');
    }

    @isTest
    static void testFinancialDetailDefaultsWhenNotSet() {
        Account agency = createAgency('Yes');
        Invoice__c inv = createInvoice(agency.Id, 25000, 0);
        setPageParam(inv.Id);

        Test.startTest();
        InvoiceCommissionPDFController ctrl = new InvoiceCommissionPDFController();
        Test.stopTest();

        System.assertEquals(null, ctrl.financialDetail, 'No Financial_Detail linked');
        System.assertEquals('________', ctrl.getBankName());
        System.assertEquals('________', ctrl.getAccountName());
        System.assertEquals('________', ctrl.getAccountNumber());
        System.assertEquals('________', ctrl.getIBAN());
        System.assertEquals('________', ctrl.getSwiftCode());
        System.assertEquals('', ctrl.getBranchName());
    }

    @isTest
    static void testNumberFormattingAcrossRanges() {
        Account agency = createAgency('Yes');
        // 1,234,567.89 → exercises numberToWords millions/thousands/hundreds/tens/ones/decimal paths
        Invoice__c inv = createInvoice(agency.Id, 1234567.89, 100.50);
        setPageParam(inv.Id);

        Test.startTest();
        InvoiceCommissionPDFController ctrl = new InvoiceCommissionPDFController();
        Test.stopTest();

        System.assert(String.isNotBlank(ctrl.getTotalInWords()), 'totalInWords should be populated');
        System.assert(ctrl.getTotalInWords().contains('Million'), 'Should contain Million for 1M+ grand total');
        System.assert(ctrl.getTotalInWords().contains('Thousand'), 'Should contain Thousand for 1K+ remainder');
        System.assert(ctrl.getTotalInWords().contains('Hundred'), 'Should contain Hundred');
        System.assert(ctrl.getTotalInWords().contains('Point'), 'Decimal portion should produce Point');

        // Format checks
        System.assert(ctrl.getFormattedSubTotal().contains('.'),
            'Formatted Sub Total should contain decimal separator');
        System.assert(ctrl.getFormattedVATAmount().contains('.'),
            'Formatted VAT Amount should contain decimal separator');
        System.assert(ctrl.getFormattedPaidAmount().contains('.'),
            'Formatted Paid Amount should contain decimal separator');
    }

    @isTest
    static void testGrandTotalAndTotalInWordsValues() {
        Account agency = createAgency('Yes');
        Invoice__c inv = createInvoice(agency.Id, 40000, 5000);
        setPageParam(inv.Id);

        Test.startTest();
        InvoiceCommissionPDFController ctrl = new InvoiceCommissionPDFController();
        Test.stopTest();

        System.assertEquals('42,000.00', ctrl.getFormattedGrandTotal(),
            'Grand total should be full invoice amount (subtotal + VAT), not reduced by paid amount');
        System.assertEquals(ctrl.getFormattedAmountInclVat(), ctrl.getFormattedGrandTotal(),
            'Grand total should match Amount Incl VAT');
        System.assert(ctrl.getTotalInWords().contains('Forty Two Thousand'),
            'Total in words should reflect the full invoice grand total');
        System.assert(ctrl.getTotalInWords().contains('AED Only'),
            'Total in words should include currency suffix');
    }

    @isTest
    static void testFullyPaidInvoiceStillShowsFullGrandTotal() {
        Account agency = createAgency('Yes');
        Invoice__c inv = createInvoice(agency.Id, 40000, 42000);
        Opportunity opp = createOpportunity(agency.Id);

        insert new Commission__c(
            Agency__c = agency.Id,
            Opportunity__c = opp.Id,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4,
            Commission_Amount__c = 40000,
            Invoice__c = inv.Id
        );

        setPageParam(inv.Id);

        Test.startTest();
        InvoiceCommissionPDFController ctrl = new InvoiceCommissionPDFController();
        Test.stopTest();

        System.assertEquals('42,000.00', ctrl.getFormattedGrandTotal(),
            'Fully paid invoice should still show full grand total on the PDF');
        System.assertEquals('42,000.00', ctrl.getFormattedPaidAmount(),
            'Paid amount line should still show the amount paid');
    }

    @isTest
    static void testGrandTotalUsesLinkedCommissionTotals() {
        Account agency = createAgency('Yes');
        Invoice__c inv = createInvoice(agency.Id, 40000, 5000);
        Opportunity opp = createOpportunity(agency.Id);

        insert new Commission__c(
            Agency__c = agency.Id,
            Opportunity__c = opp.Id,
            Base_Amount__c = 1000000,
            Commission_Rate__c = 4,
            Commission_Amount__c = 40000,
            Invoice__c = inv.Id
        );

        setPageParam(inv.Id);

        Test.startTest();
        InvoiceCommissionPDFController ctrl = new InvoiceCommissionPDFController();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.getFormattedGrandTotal(),
            'Grand total getter should be populated from linked commission totals');
        System.assert(ctrl.getFormattedGrandTotal().contains('.'),
            'Grand total should be formatted with decimals');
        System.assert(String.isNotBlank(ctrl.getTotalInWords()),
            'Total in words should be populated');
    }

    @isTest
    static void testMissingIdParameterIsHandled() {
        Test.setCurrentPage(Page.InvoiceCommissionPDF);
        // No id parameter set

        Test.startTest();
        InvoiceCommissionPDFController ctrl = new InvoiceCommissionPDFController();
        Test.stopTest();

        System.assertEquals(null, ctrl.invoice, 'Invoice should not be loaded when id is missing');
        System.assert(ApexPages.getMessages().size() > 0,
            'Constructor should add an error message when id is missing');
    }

    @isTest
    static void testNonExistentInvoiceIdIsHandled() {
        // Pass a fake (but well-formed) Id that doesn't exist in the test DB
        Id fakeId = '001000000000000AAA';
        Test.setCurrentPage(Page.InvoiceCommissionPDF);
        ApexPages.currentPage().getParameters().put('id', fakeId);

        Test.startTest();
        InvoiceCommissionPDFController ctrl = new InvoiceCommissionPDFController();
        Test.stopTest();

        System.assertEquals(null, ctrl.invoice, 'Invoice should not be loaded for non-existent Id');
        System.assert(ApexPages.getMessages().size() > 0,
            'Constructor should add an error message when invoice not found');
    }
}