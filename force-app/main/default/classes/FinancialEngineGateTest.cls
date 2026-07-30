/**
 * Verifies what the Financial Engine master switch does — and does NOT — gate.
 *
 * The switch gates BEHAVIOUR only. When it is off the finance buttons and LWCs stay on the page
 * and read-only loads still succeed (so the pages look normal); every action that creates, edits,
 * allocates, generates or emails throws ENGINE_DISABLED_MESSAGE instead.
 */
@IsTest
private class FinancialEngineGateTest {

    private class Ctx {
        Unit__c u;
        Cash_Flow__c cf;
        Invoice__c inv;
        Receipt__c r;
        Receipt_Amount__c ra;
    }

    /** Invoice + receipt + one allocation, with the engine switch left OFF (no settings row). */
    private static Ctx buildWithEngineOff() {
        Ctx c = new Ctx();
        c.u = new Unit__c(Title__c = 'gate');
        insert c.u;
        Cash_Flow_Sum__c s = new Cash_Flow_Sum__c(Name = 'CFS', Unit__c = c.u.Id);
        insert s;
        c.cf = new Cash_Flow__c(
            Name = 'M1', Unit__c = c.u.Id, Cash_Flow_Sum__c = s.Id,
            Date__c = System.today().addDays(-5), Constant__c = 1000, Received_Amount__c = 0
        );
        insert c.cf;
        c.inv = new Invoice__c(
            Status__c = 'Pending', Invoice_Date__c = System.today(), Sub_Total_Amount__c = 1000,
            Paid_Amount__c = 0, Unit__c = c.u.Id, Invoice_Number__c = 'INV-GATE'
        );
        insert c.inv;
        insert new Milestone_Invoice__c(Invoice__c = c.inv.Id, Cash_Flow__c = c.cf.Id);
        c.r = new Receipt__c(
            Description__c = 'R', Unit__c = c.u.Id, Payment_Date__c = System.today(),
            Received_Amount__c = 1000, Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid'
        );
        insert c.r;
        c.ra = new Receipt_Amount__c(
            Receipt__c = c.r.Id, Invoice__c = c.inv.Id, Amount__c = 1000, Mode_of_Payment__c = 'Cash'
        );
        insert c.ra;
        return c;
    }

    @IsTest
    static void requireEnabledThrowsWhenDisabled() {
        // No Financial_Engine_Settings__c row => disabled by default.
        Boolean threw = false;
        Test.startTest();
        try {
            FinancialEngine.requireEnabled();
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'requireEnabled must throw when the engine is disabled');
        System.assertEquals(false, FinancialEngine.isFinanceUiEnabled(), 'UI flag should be false when disabled');
    }

    @IsTest
    static void requireEnabledPassesWhenEnabled() {
        insert new Financial_Engine_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(), Engine_Owns_Totals__c = true);
        Test.startTest();
        FinancialEngine.requireEnabled(); // must not throw
        Test.stopTest();
        System.assertEquals(true, FinancialEngine.isFinanceUiEnabled(), 'UI flag should be true when enabled');
    }

    /** The wording users see — pinned so it cannot drift silently. */
    @IsTest
    static void disabledMessageWording() {
        System.assertEquals(
            'Financial Engine seems to be off. Please contact Mr. Sheraz - The ultimate Master Mind',
            FinancialEngine.ENGINE_DISABLED_MESSAGE,
            'Users must be told the engine is off, and who to contact'
        );
    }

    /**
     * Appearance must be unaffected: the manage panels load their data with the engine off, so
     * they render normally instead of showing an error banner on page load.
     */
    @IsTest
    static void panelReadsStayOpenWhenDisabled() {
        Ctx c = buildWithEngineOff();
        Test.startTest();
        ReceiptManageController.ReceiptView rv = ReceiptManageController.getReceipt(c.r.Id);
        InvoiceManageController.InvoiceView iv = InvoiceManageController.getInvoice(c.inv.Id);
        Test.stopTest();

        System.assertEquals(c.r.Id, rv.receiptId, 'Receipt panel still loads when the engine is off');
        System.assertEquals(1, rv.allocations.size(), 'Allocations still listed');
        System.assertEquals(c.inv.Id, iv.invoiceId, 'Invoice panel still loads when the engine is off');
    }

    /** Clicking Create Invoice / Generate Receipt must fail while the engine is off. */
    @IsTest
    static void createWizardsBlockedWhenDisabled() {
        Ctx c = buildWithEngineOff();
        Boolean receiptBlocked = false, invoiceBlocked = false;

        Test.startTest();
        try {
            ReceiptCreateController.getContext(c.u.Id);
        } catch (AuraHandledException e) {
            receiptBlocked = true;
        }
        try {
            InvoiceCreateController.getContext(c.u.Id);
        } catch (AuraHandledException e) {
            invoiceBlocked = true;
        }
        Test.stopTest();

        System.assertEquals(true, receiptBlocked, 'Generate Receipt must be blocked when the engine is off');
        System.assertEquals(true, invoiceBlocked, 'Create Invoice must be blocked when the engine is off');
    }

    /** Editing an amount, removing an allocation, cancelling — all blocked, and nothing changes. */
    @IsTest
    static void editActionsBlockedWhenDisabled() {
        Ctx c = buildWithEngineOff();
        Boolean editBlocked = false, removeBlocked = false;
        Boolean cancelReceiptBlocked = false, cancelInvoiceBlocked = false;

        Test.startTest();
        try {
            ReceiptManageController.updateAllocationAmount(c.ra.Id, 600);
        } catch (AuraHandledException e) {
            editBlocked = true;
        }
        try {
            ReceiptManageController.removeAllocation(c.ra.Id);
        } catch (AuraHandledException e) {
            removeBlocked = true;
        }
        try {
            ReceiptManageController.cancelReceipt(c.r.Id, 'gate test');
        } catch (AuraHandledException e) {
            cancelReceiptBlocked = true;
        }
        try {
            InvoiceManageController.cancelInvoice(c.inv.Id);
        } catch (AuraHandledException e) {
            cancelInvoiceBlocked = true;
        }
        Test.stopTest();

        System.assertEquals(true, editBlocked, 'Allocation edit must be blocked');
        System.assertEquals(true, removeBlocked, 'Allocation removal must be blocked');
        System.assertEquals(true, cancelReceiptBlocked, 'Receipt cancel must be blocked');
        System.assertEquals(true, cancelInvoiceBlocked, 'Invoice cancel must be blocked');

        System.assertEquals(1000, [SELECT Amount__c FROM Receipt_Amount__c WHERE Id = :c.ra.Id].Amount__c,
            'A blocked action must not have changed the allocation');
        System.assertEquals(1, [SELECT COUNT() FROM Receipt_Amount__c WHERE Id = :c.ra.Id],
            'A blocked removal must not have deleted the line');
    }
}
