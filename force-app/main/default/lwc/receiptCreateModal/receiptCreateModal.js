import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import getContext from '@salesforce/apex/ReceiptCreateController.getContext';
import createReceipt from '@salesforce/apex/ReceiptCreateController.createReceipt';

const INVOICE_COLUMNS = [
    { label: 'Invoice', fieldName: 'label' },
    { label: 'Date', fieldName: 'invoiceDate', type: 'date-local' },
    { label: 'Pending', fieldName: 'pending', type: 'currency',
        typeAttributes: { currencyCode: 'AED' }, cellAttributes: { alignment: 'right' } },
    { label: 'Status', fieldName: 'status' }
];

/**
 * Generate Receipt wizard — a ScreenAction quick action (popup) on Unit__c. Line-based: each payment
 * line targets one invoice with an amount + mode of payment. Receipt/Receipt_Amount/Receipt_Invoice
 * are created server-side; the engine derives the totals.
 */
export default class ReceiptCreateModal extends LightningElement {
    _recordId;
    _loaded = false;
    _seq = 0;

    @api
    get recordId() { return this._recordId; }
    set recordId(value) { this._recordId = value; this.maybeLoad(); }

    invoiceColumns = INVOICE_COLUMNS;
    isLoading = true;
    working = false;
    error;
    ctx;
    step = 'lines'; // blocked | lines | details | preview | done

    lines = [];

    // details
    paymentDate;
    depositedTo;
    status = 'Reconciled';
    description = '';

    newReceiptId;

    connectedCallback() { this.maybeLoad(); }

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
            const data = await getContext({ unitId: this._recordId });
            this.ctx = data;
            if (!data.canProceed) {
                this.step = 'blocked';
            } else {
                this.paymentDate = data.defaultPaymentDate;
                this.lines = [this.newLine()];
                this.step = 'lines';
            }
        } catch (e) {
            this.error = this.messageFrom(e);
            this.step = 'blocked';
        } finally {
            this.isLoading = false;
        }
    }

    newLine() {
        return {
            key: `l${this._seq++}`,
            invoiceId: '',
            amount: null,
            modeOfPayment: 'Cash',
            referenceNumber: '',
            chequeNumber: '',
            chequeDate: null,
            bankName: '',
            posReceiptNumber: '',
            isCheque: false,
            isPos: false
        };
    }

    // ---- option getters ----
    get invoiceOptions() {
        return (this.ctx && this.ctx.invoices)
            ? this.ctx.invoices.map((i) => ({ label: `${i.label} — ${this.money(i.pending)} pending`, value: i.invoiceId }))
            : [];
    }
    get payableInvoices() {
        return (this.ctx && this.ctx.invoices) ? this.ctx.invoices : [];
    }
    get depositToOptions() { return (this.ctx && this.ctx.depositToOptions) ? this.ctx.depositToOptions : []; }
    get modeOptions() { return (this.ctx && this.ctx.modeOfPaymentOptions) ? this.ctx.modeOfPaymentOptions : []; }
    get bankOptions() { return (this.ctx && this.ctx.bankOptions) ? this.ctx.bankOptions : []; }
    get statusOptions() { return (this.ctx && this.ctx.statusOptions) ? this.ctx.statusOptions : []; }

    // ---- derived ----
    get received() {
        return this.lines.reduce((s, l) => s + (parseFloat(l.amount) || 0), 0);
    }
    get payable() {
        const ids = new Set(this.lines.map((l) => l.invoiceId).filter(Boolean));
        return this.payableInvoices
            .filter((i) => ids.has(i.invoiceId))
            .reduce((s, i) => s + (i.pending || 0), 0);
    }
    get paymentStatusPreview() {
        return this.received >= this.payable && this.received > 0 ? 'Fully Paid' : 'Partially Paid';
    }
    // Recap of the payment lines (invoices selected on step 1) for the details step.
    get selectedLinesView() {
        const byId = new Map(this.payableInvoices.map((i) => [i.invoiceId, i]));
        return this.lines.map((l) => {
            const inv = byId.get(l.invoiceId);
            return {
                key: l.key,
                invoiceLabel: inv ? inv.label : '—',
                amount: parseFloat(l.amount) || 0,
                pending: inv ? (inv.pending || 0) : 0,
                mode: l.modeOfPayment
            };
        });
    }
    get unitName() { return this.ctx ? this.ctx.unitName : ''; }
    get blockReason() { return (this.ctx && this.ctx.blockReason) ? this.ctx.blockReason : this.error; }
    get unitIdForSave() { return (this.ctx && this.ctx.unitId) ? this.ctx.unitId : this._recordId; }

    get isBlocked() { return this.step === 'blocked'; }
    get isLines() { return this.step === 'lines'; }
    get isDetails() { return this.step === 'details'; }
    get isPreview() { return this.step === 'preview'; }
    get isDone() { return this.step === 'done'; }

    get pdfUrl() { return this.newReceiptId ? `/apex/ReceiptPDF?id=${this.newReceiptId}` : '#'; }

    // ---- preview JSON (pre-insert; matches receiptPreviewLWC expectations) ----
    get receiptsJson() {
        return JSON.stringify([{
            Receipt_Added_Date__c: this.paymentDate,
            Payment_Date__c: this.paymentDate,
            Payable_Amount__c: this.payable,
            Received_Amount__c: this.received,
            Customer_Name__c: this.ctx ? this.ctx.customerName : null,
            Project_Name__c: this.ctx ? this.ctx.projectName : null,
            Unit_No__c: this.ctx ? this.ctx.unitName : null,
            Description__c: this.description
        }]);
    }
    get paymentsJson() {
        return JSON.stringify(this.lines.map((l) => ({
            Invoice__c: l.invoiceId,
            Amount__c: parseFloat(l.amount) || 0,
            Amount_Text__c: this.money(parseFloat(l.amount) || 0),
            Mode_of_Payment__c: l.modeOfPayment,
            Cheque_Date__c: l.isCheque ? l.chequeDate : null
        })));
    }
    get invoicesJson() {
        const ids = [...new Set(this.lines.map((l) => l.invoiceId).filter(Boolean))];
        return JSON.stringify(ids.map((id) => ({ Invoice__c: id })));
    }

    // ---- line handlers ----
    handleLineChange(e) {
        const idx = parseInt(e.currentTarget.dataset.index, 10);
        const field = e.currentTarget.dataset.field;
        const value = e.target.type === 'checkbox' ? e.target.checked : e.detail && e.detail.value !== undefined ? e.detail.value : e.target.value;
        const lines = [...this.lines];
        const line = { ...lines[idx], [field]: value };
        if (field === 'modeOfPayment') {
            line.isCheque = value === 'Cheque';
            line.isPos = value === 'POS Machine';
        }
        lines[idx] = line;
        this.lines = lines;
    }
    addLine() {
        this.lines = [...this.lines, this.newLine()];
    }
    removeLine(e) {
        const idx = parseInt(e.currentTarget.dataset.index, 10);
        const lines = this.lines.filter((l, i) => i !== idx);
        this.lines = lines.length ? lines : [this.newLine()];
    }

    // ---- details handlers ----
    handlePaymentDate(e) { this.paymentDate = e.target.value; }
    handleDepositedTo(e) { this.depositedTo = e.detail.value; }
    handleStatus(e) { this.status = e.detail.value; }
    handleDescription(e) { this.description = e.target.value; }

    // ---- navigation ----
    goToDetails() {
        if (!this.validateLines()) return;
        this.error = undefined;
        this.step = 'details';
    }
    backToLines() { this.error = undefined; this.step = 'lines'; }

    goToPreview() {
        if (!this.validateDetails()) return;
        this.error = undefined;
        this.step = 'preview';
    }
    backToDetails() { this.error = undefined; this.step = 'details'; }

    validateLines() {
        if (!this.lines.length) { this.error = 'Add at least one payment line.'; return false; }
        for (const l of this.lines) {
            if (!l.invoiceId) { this.error = 'Every payment line needs an invoice.'; return false; }
            if (!(parseFloat(l.amount) > 0)) { this.error = 'Every payment line needs an amount greater than zero.'; return false; }
            if (!l.modeOfPayment) { this.error = 'Every payment line needs a mode of payment.'; return false; }
            if (l.isCheque) {
                if (!l.chequeNumber) { this.error = 'Cheque number is required for cheque payments.'; return false; }
                if (!l.chequeDate) { this.error = 'Cheque date is required for cheque payments.'; return false; }
                if (!l.bankName) { this.error = 'Bank name is required for cheque payments.'; return false; }
            }
            if (l.isPos && !l.posReceiptNumber) { this.error = 'POS receipt number is required for POS payments.'; return false; }
        }
        return true;
    }
    validateDetails() {
        if (!this.paymentDate) { this.error = 'Payment date is required.'; return false; }
        if (!this.depositedTo) { this.error = 'Deposited-to account is required.'; return false; }
        if (!this.status) { this.error = 'Status is required.'; return false; }
        if (!this.description || !this.description.trim()) { this.error = 'Description is required.'; return false; }
        return true;
    }

    async handleCreate() {
        if (!this.validateLines()) { this.step = 'lines'; return; }
        if (!this.validateDetails()) { this.step = 'details'; return; }
        const uid = this.unitIdForSave;
        if (!uid) { this.error = 'Could not resolve the unit. Please reopen and try again.'; return; }
        this.working = true;
        this.error = undefined;
        try {
            const req = {
                unitId: uid,
                paymentDate: this.paymentDate,
                depositedTo: this.depositedTo,
                status: this.status,
                description: this.description,
                lines: this.lines.map((l) => ({
                    invoiceId: l.invoiceId,
                    amount: parseFloat(l.amount),
                    modeOfPayment: l.modeOfPayment,
                    referenceNumber: l.referenceNumber,
                    chequeNumber: l.isCheque ? l.chequeNumber : null,
                    chequeDate: l.isCheque ? l.chequeDate : null,
                    bankName: l.isCheque ? l.bankName : null,
                    posReceiptNumber: l.isPos ? l.posReceiptNumber : null
                }))
            };
            this.newReceiptId = await createReceipt({ payload: JSON.stringify(req) });
            this.step = 'done';
        } catch (e) {
            this.error = this.messageFrom(e);
        } finally {
            this.working = false;
        }
    }

    handleCancel() { this.dispatchEvent(new CloseActionScreenEvent()); }
    handleFinish() {
        if (this.newReceiptId && this.unitIdForSave) {
            getRecordNotifyChange([{ recordId: this.unitIdForSave }]);
        }
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    money(v) {
        const n = Number(v || 0);
        return n.toFixed(2).replace(/\d(?=(\d{3})+\.)/g, '$&,');
    }
    messageFrom(e) {
        return (e && e.body && e.body.message) ? e.body.message : 'Unexpected error.';
    }
}
