/**
 * FinancialEngineTriggerHandler — routes DML on the engine's INPUT objects to
 * FinancialEngine.applyForUnits so the four totals + the Milestone_Receipt ledger self-heal.
 *
 * Inputs: Receipt__c, Receipt_Amount__c, Receipt_Invoice__c, Milestone_Invoice__c, Invoice__c.
 * (Cash_Flow__c is an OUTPUT of the engine, so it is deliberately NOT wired here — that would recurse.)
 *
 * Each entry point resolves the affected Unit ids and delegates. It short-circuits when the engine
 * is disabled (prod) or already running (recursion guard), so there is near-zero overhead when off.
 */
public without sharing class FinancialEngineTriggerHandler {

    private static Boolean skip() {
        return FinancialEngine.bypass || !FinancialEngine.isEngineEnabled();
    }

    public static void handleReceipts(List<Receipt__c> newList, List<Receipt__c> oldList) {
        if (skip()) return;
        Set<Id> unitIds = new Set<Id>();
        addUnitFromReceipts(newList, unitIds);
        addUnitFromReceipts(oldList, unitIds);
        FinancialEngine.applyForUnits(unitIds);
    }

    public static void handleInvoices(List<Invoice__c> newList, List<Invoice__c> oldList) {
        if (skip()) return;
        Set<Id> unitIds = new Set<Id>();
        addUnitFromInvoices(newList, unitIds);
        addUnitFromInvoices(oldList, unitIds);
        FinancialEngine.applyForUnits(unitIds);
    }

    public static void handleReceiptAmounts(List<Receipt_Amount__c> newList, List<Receipt_Amount__c> oldList) {
        if (skip()) return;
        Set<Id> receiptIds = new Set<Id>();
        Set<Id> invoiceIds = new Set<Id>();
        collectReceiptAmountRefs(newList, receiptIds, invoiceIds);
        collectReceiptAmountRefs(oldList, receiptIds, invoiceIds);
        FinancialEngine.applyForUnits(resolveUnits(receiptIds, invoiceIds));
    }

    public static void handleReceiptInvoices(List<Receipt_Invoice__c> newList, List<Receipt_Invoice__c> oldList) {
        if (skip()) return;
        Set<Id> receiptIds = new Set<Id>();
        Set<Id> invoiceIds = new Set<Id>();
        collectReceiptInvoiceRefs(newList, receiptIds, invoiceIds);
        collectReceiptInvoiceRefs(oldList, receiptIds, invoiceIds);
        FinancialEngine.applyForUnits(resolveUnits(receiptIds, invoiceIds));
    }

    public static void handleMilestoneInvoices(List<Milestone_Invoice__c> newList, List<Milestone_Invoice__c> oldList) {
        if (skip()) return;
        Set<Id> invoiceIds = new Set<Id>();
        collectMilestoneInvoiceRefs(newList, invoiceIds);
        collectMilestoneInvoiceRefs(oldList, invoiceIds);
        FinancialEngine.applyForUnits(resolveUnits(new Set<Id>(), invoiceIds));
    }

    // ---- collectors ----------------------------------------------------------

    private static void addUnitFromReceipts(List<Receipt__c> recs, Set<Id> unitIds) {
        if (recs == null) return;
        for (Receipt__c r : recs) {
            if (r.Unit__c != null) unitIds.add(r.Unit__c);
        }
    }

    private static void addUnitFromInvoices(List<Invoice__c> invs, Set<Id> unitIds) {
        if (invs == null) return;
        for (Invoice__c i : invs) {
            if (i.Unit__c != null) unitIds.add(i.Unit__c);
        }
    }

    private static void collectReceiptAmountRefs(List<Receipt_Amount__c> lines, Set<Id> receiptIds, Set<Id> invoiceIds) {
        if (lines == null) return;
        for (Receipt_Amount__c ra : lines) {
            if (ra.Receipt__c != null) receiptIds.add(ra.Receipt__c);
            if (ra.Invoice__c != null) invoiceIds.add(ra.Invoice__c);
        }
    }

    private static void collectReceiptInvoiceRefs(List<Receipt_Invoice__c> links, Set<Id> receiptIds, Set<Id> invoiceIds) {
        if (links == null) return;
        for (Receipt_Invoice__c ri : links) {
            if (ri.Receipt__c != null) receiptIds.add(ri.Receipt__c);
            if (ri.Invoice__c != null) invoiceIds.add(ri.Invoice__c);
        }
    }

    private static void collectMilestoneInvoiceRefs(List<Milestone_Invoice__c> links, Set<Id> invoiceIds) {
        if (links == null) return;
        for (Milestone_Invoice__c mi : links) {
            if (mi.Invoice__c != null) invoiceIds.add(mi.Invoice__c);
        }
    }

    /** Resolve the units behind a set of receipts and/or invoices. */
    private static Set<Id> resolveUnits(Set<Id> receiptIds, Set<Id> invoiceIds) {
        Set<Id> unitIds = new Set<Id>();
        if (!receiptIds.isEmpty()) {
            for (Receipt__c r : [SELECT Unit__c FROM Receipt__c WHERE Id IN :receiptIds AND Unit__c != null]) {
                unitIds.add(r.Unit__c);
            }
        }
        if (!invoiceIds.isEmpty()) {
            for (Invoice__c i : [SELECT Unit__c FROM Invoice__c WHERE Id IN :invoiceIds AND Unit__c != null]) {
                unitIds.add(i.Unit__c);
            }
        }
        return unitIds;
    }
}
