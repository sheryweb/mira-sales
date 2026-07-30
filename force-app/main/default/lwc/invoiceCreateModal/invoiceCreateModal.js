import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import getContext from '@salesforce/apex/InvoiceCreateController.getContext';
import createInvoice from '@salesforce/apex/InvoiceCreateController.createInvoice';

const COLUMNS = [
    { label: 'Installment', fieldName: 'milestone', wrapText: true },
    { label: 'Date', fieldName: 'installmentDate', type: 'date-local' },
    { label: 'Amount', fieldName: 'amount', type: 'currency',
        typeAttributes: { currencyCode: 'AED' }, cellAttributes: { alignment: 'right' } },
    { label: 'VAT', fieldName: 'vat', type: 'currency',
        typeAttributes: { currencyCode: 'AED' }, cellAttributes: { alignment: 'right' } },
    { label: '%', fieldName: 'percent', type: 'percent', cellAttributes: { alignment: 'right' } }
];

/**
 * Create Invoice wizard — rendered as a ScreenAction quick action (popup modal) on Unit__c.
 * The platform provides the modal chrome + header (the action label) and passes recordId (the Unit).
 */
export default class InvoiceCreateModal extends LightningElement {
    // Unit Id — supplied automatically by the quick action framework. It can arrive either before or
    // after connectedCallback, so kick off the load from whichever sets it first (guarded by _loaded).
    _recordId;
    _loaded = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        this.maybeLoad();
    }

    columns = COLUMNS;
    isLoading = true;
    working = false;
    error;
    ctx;
    step = 'select'; // blocked | select | details | preview | done

    selectedIds = [];

    // details form
    invoiceDate;
    dueDate;
    financialDetailId;
    description = '';
    otherCurrency = false;
    secondaryCurrency;
    conversionRate;

    newInvoiceId;

    connectedCallback() {
        this.maybeLoad();
    }

    // Load once, as soon as we have a recordId (from the setter or connectedCallback).
    maybeLoad() {
        if (this._recordId && !this._loaded) {
            this._loaded = true;
            this.load();
        }
    }

    async load() {
        this.isLoading = true;
        this.error = undefined;
        try {
            const data = await getContext({ unitId: this.recordId });
            this.ctx = data;
            if (!data.canProceed) {
                this.step = 'blocked';
            } else {
                this.invoiceDate = data.defaultInvoiceDate;
                this.dueDate = data.defaultDueDate;
                this.step = 'select';
            }
        } catch (e) {
            this.error = this.messageFrom(e);
            this.step = 'blocked'; // render the message safely instead of a ctx-dependent step
        } finally {
            this.isLoading = false;
        }
    }

    // Safe accessors so the template never dereferences an undefined ctx.
    get unitName() { return this.ctx ? this.ctx.unitName : ''; }
    get blockReason() { return (this.ctx && this.ctx.blockReason) ? this.ctx.blockReason : this.error; }
    get projectName() { return this.ctx ? this.ctx.projectName : ''; }
    get propertyDetails() { return this.ctx ? this.ctx.propertyDetails : ''; }
    get previewUnitId() { return this.ctx ? this.ctx.unitId : this.recordId; }
    // Authoritative unit id for saving: prefer the server-loaded context, fall back to recordId.
    get unitIdForSave() { return (this.ctx && this.ctx.unitId) ? this.ctx.unitId : this._recordId; }

    // ---- derived ----
    get installments() {
        return (this.ctx && this.ctx.installments) ? this.ctx.installments : [];
    }
    get currencyOptions() {
        return (this.ctx && this.ctx.secondaryCurrencyOptions) ? this.ctx.secondaryCurrencyOptions : [];
    }
    get selectedInstallments() {
        const set = new Set(this.selectedIds);
        return this.installments.filter((i) => set.has(i.cashFlowId));
    }
    get subTotal() {
        return this.selectedInstallments.reduce((s, i) => s + (i.amount || 0), 0);
    }
    get vat() {
        return this.selectedInstallments.reduce((s, i) => s + (i.vat || 0), 0);
    }
    get grandTotal() {
        return this.subTotal + this.vat;
    }
    get secondaryAmount() {
        const rate = parseFloat(this.conversionRate);
        return (this.otherCurrency && rate > 0) ? this.subTotal / rate : 0;
    }
    get hasNoSelection() {
        return this.selectedIds.length === 0;
    }

    get isBlocked() { return this.step === 'blocked'; }
    // While blocked, blockReason already renders this.error - don't print it twice.
    get showInlineError() { return !!this.error && !this.isBlocked; }
    get isSelect() { return this.step === 'select'; }
    get isDetails() { return this.step === 'details'; }
    get isPreview() { return this.step === 'preview'; }
    get isDone() { return this.step === 'done'; }

    get pdfUrl() {
        return this.newInvoiceId ? `/apex/InvoicePDF?id=${this.newInvoiceId}` : '#';
    }

    // preview inputs (pre-insert JSON, same shape the flow fed invoicePreviewLWC)
    get invoicesJson() {
        return JSON.stringify([{
            Invoice_Date__c: this.invoiceDate,
            Sub_Total_Amount__c: this.subTotal,
            VAT_Amount__c: this.vat,
            Grand_Total_Amount__c: this.grandTotal,
            Secondary_Currency__c: this.otherCurrency ? this.secondaryCurrency : null,
            Secondary_Currency_Amount__c: this.otherCurrency ? this.secondaryAmount : 0,
            Financial_Detail__c: this.financialDetailId,
            Customer_Name__c: this.ctx ? this.ctx.customerName : null,
            Customer_Id__c: this.ctx ? this.ctx.customerId : null
        }]);
    }
    get lineItemsJson() {
        return JSON.stringify(this.selectedInstallments.map((i) => ({
            Name: i.milestone,
            Amount__c: i.amount,
            Installment_Date__c: i.installmentDate
        })));
    }
    get salePriceString() {
        return (this.ctx && this.ctx.salePrice != null) ? String(this.ctx.salePrice) : '';
    }

    // ---- handlers ----
    handleRowSelection(e) {
        this.selectedIds = e.detail.selectedRows.map((r) => r.cashFlowId);
    }
    handleInvoiceDate(e) { this.invoiceDate = e.target.value; }
    handleDueDate(e) { this.dueDate = e.target.value; }
    handleFinancialDetail(e) { this.financialDetailId = e.detail.recordId; }
    handleDescription(e) { this.description = e.target.value; }
    handleOtherCurrency(e) { this.otherCurrency = e.target.checked; }
    handleSecondaryCurrency(e) { this.secondaryCurrency = e.detail.value; }
    handleConversionRate(e) { this.conversionRate = e.target.value; }

    goToDetails() {
        if (this.hasNoSelection) {
            this.error = 'Select at least one installment to invoice.';
            return;
        }
        this.error = undefined;
        this.step = 'details';
    }
    backToSelect() { this.error = undefined; this.step = 'select'; }

    goToPreview() {
        if (!this.validateDetails()) return;
        this.error = undefined;
        this.step = 'preview';
    }
    backToDetails() { this.error = undefined; this.step = 'details'; }

    validateDetails() {
        if (!this.invoiceDate) { this.error = 'Invoice date is required.'; return false; }
        if (!this.dueDate) { this.error = 'Due date is required.'; return false; }
        if (!this.financialDetailId) { this.error = 'Financial details are required.'; return false; }
        if (!this.description || !this.description.trim()) { this.error = 'Description is required.'; return false; }
        if (this.otherCurrency) {
            if (!this.secondaryCurrency) { this.error = 'Select a secondary currency.'; return false; }
            const rate = parseFloat(this.conversionRate);
            if (isNaN(rate) || rate <= 0) { this.error = 'Conversion rate must be greater than zero.'; return false; }
        }
        return true;
    }

    async handleCreate() {
        if (!this.validateDetails()) { this.step = 'details'; return; }
        const uid = this.unitIdForSave;
        if (!uid) {
            this.error = 'Could not resolve the unit for this invoice. Please reopen and try again.';
            return;
        }
        this.working = true;
        this.error = undefined;
        try {
            const req = {
                unitId: uid,
                cashFlowIds: this.selectedIds,
                invoiceDate: this.invoiceDate,
                dueDate: this.dueDate,
                financialDetailId: this.financialDetailId,
                description: this.description,
                otherCurrency: this.otherCurrency,
                secondaryCurrency: this.otherCurrency ? this.secondaryCurrency : null,
                conversionRate: this.otherCurrency ? parseFloat(this.conversionRate) : null
            };
            this.newInvoiceId = await createInvoice({ payload: JSON.stringify(req) });
            this.step = 'done';
        } catch (e) {
            this.error = this.messageFrom(e);
        } finally {
            this.working = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    handleFinish() {
        if (this.newInvoiceId && this.unitIdForSave) {
            getRecordNotifyChange([{ recordId: this.unitIdForSave }]);
        }
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    messageFrom(e) {
        return (e && e.body && e.body.message) ? e.body.message : 'Unexpected error.';
    }
}
