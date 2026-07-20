import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import LightningConfirm from 'lightning/confirm';
import getReceipt from '@salesforce/apex/ReceiptManageController.getReceipt';
import saveAllocation from '@salesforce/apex/ReceiptManageController.saveAllocation';
import addAllocation from '@salesforce/apex/ReceiptManageController.addAllocation';
import removeAllocation from '@salesforce/apex/ReceiptManageController.removeAllocation';
import cancelReceipt from '@salesforce/apex/ReceiptManageController.cancelReceipt';

export default class ReceiptManagePanel extends LightningElement {
    @api recordId;
    @track view;
    @track rows = [];
    @track isLoading = false;
    @track showCancelConfirm = false;
    error;

    // add-allocation form
    @track newLine = {};

    connectedCallback() {
        this.load();
    }

    load() {
        this.isLoading = true;
        this.error = undefined;
        getReceipt({ receiptId: this.recordId })
            .then((data) => {
                this.view = data;
                this.rows = (data.allocations || []).map((a) => this.decorate({
                    lineId: a.lineId,
                    invoiceId: a.invoiceId,
                    invoiceLabel: a.invoiceLabel,
                    mode: a.modeOfPayment,
                    amount: a.amount,
                    referenceNumber: a.referenceNumber,
                    chequeNumber: a.chequeNumber,
                    chequeDate: a.chequeDate,
                    bankName: a.bankName,
                    posReceiptNumber: a.posReceiptNumber,
                    expanded: false
                }));
                this.newLine = { mode: 'Cash' };
            })
            .catch((e) => {
                this.error = this.messageFrom(e);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Attach derived flags used by the template (LWC can't call helpers with args in markup).
    decorate(row) {
        row.showCheque = row.mode === 'Cheque';
        row.showPos = row.mode === 'POS Machine';
        row.chevron = row.expanded ? 'utility:chevrondown' : 'utility:chevronright';
        return row;
    }

    get hasAllocations() {
        return this.rows && this.rows.length > 0;
    }

    get isCancelled() {
        return this.view && this.view.cancelled;
    }

    get invoiceOptions() {
        return (this.view && this.view.invoiceOptions) ? this.view.invoiceOptions : [];
    }

    get modeOptions() {
        return (this.view && this.view.modeOptions) ? this.view.modeOptions : [];
    }

    get bankNameOptions() {
        return (this.view && this.view.bankNameOptions) ? this.view.bankNameOptions : [];
    }

    get hasUnapplied() {
        return this.view && this.view.unappliedAmount && Math.abs(this.view.unappliedAmount) > 0.005;
    }

    get unappliedClass() {
        return this.hasUnapplied
            ? 'tile tile_alert slds-box slds-box_x-small'
            : 'tile slds-box slds-box_x-small';
    }

    get newShowCheque() {
        return this.newLine.mode === 'Cheque';
    }

    get newShowPos() {
        return this.newLine.mode === 'POS Machine';
    }

    rowFor(id) {
        return this.rows.find((r) => r.lineId === id);
    }

    // ---- existing rows ----

    handleToggle(event) {
        const row = this.rowFor(event.target.dataset.id);
        row.expanded = !row.expanded;
        this.decorate(row);
        this.rows = [...this.rows];
    }

    handleRowField(event) {
        const row = this.rowFor(event.target.dataset.id);
        const field = event.target.dataset.field;
        const value = (field === 'invoiceId' || field === 'mode' || field === 'bankName')
            ? event.detail.value
            : event.target.value;
        row[field] = value;
        if (field === 'mode') {
            this.decorate(row);
            this.rows = [...this.rows];
        }
    }

    handleSave(event) {
        const row = this.rowFor(event.target.dataset.id);
        const amount = parseFloat(row.amount);
        if (isNaN(amount) || amount < 0) {
            this.toast('Invalid amount', 'Enter a number of zero or more.', 'error');
            return;
        }
        this.run(saveAllocation({ payload: JSON.stringify(this.toInput(row, amount)) }), 'Allocation saved.');
    }

    async handleRemove(event) {
        const lineId = event.target.dataset.id;
        const ok = await LightningConfirm.open({
            message: 'Remove this allocation? The money will return to the receipt as unapplied — you can reassign or re-add it afterwards.',
            variant: 'header',
            label: 'Remove allocation',
            theme: 'warning'
        });
        if (!ok) return;
        this.run(removeAllocation({ lineId }), 'Allocation removed. The money is now unapplied on the receipt.');
    }

    // ---- add form ----

    handleNewField(event) {
        const field = event.target.dataset.field;
        const value = (field === 'invoiceId' || field === 'mode' || field === 'bankName')
            ? event.detail.value
            : event.target.value;
        this.newLine = { ...this.newLine, [field]: value };
    }

    handleAdd() {
        if (!this.newLine.invoiceId) {
            this.toast('Pick an invoice', 'Choose which invoice to apply the money to.', 'error');
            return;
        }
        const amount = parseFloat(this.newLine.amount);
        if (isNaN(amount) || amount <= 0) {
            this.toast('Invalid amount', 'Enter an amount greater than zero.', 'error');
            return;
        }
        this.run(addAllocation({ receiptId: this.recordId, payload: JSON.stringify(this.toInput(this.newLine, amount)) }), 'Allocation added.');
    }

    toInput(row, amount) {
        return {
            lineId: row.lineId,
            invoiceId: row.invoiceId,
            modeOfPayment: row.mode,
            amount,
            referenceNumber: row.referenceNumber,
            chequeNumber: row.mode === 'Cheque' ? row.chequeNumber : null,
            chequeDate: row.mode === 'Cheque' ? row.chequeDate : null,
            bankName: row.mode === 'Cheque' ? row.bankName : null,
            posReceiptNumber: row.mode === 'POS Machine' ? row.posReceiptNumber : null
        };
    }

    // ---- cancel receipt ----

    handleCancelClick() {
        this.showCancelConfirm = true;
    }

    handleCancelDismiss() {
        this.showCancelConfirm = false;
    }

    handleCancelConfirm() {
        this.showCancelConfirm = false;
        this.run(cancelReceipt({ receiptId: this.recordId }), 'Receipt cancelled.');
    }

    run(promise, successMessage) {
        this.isLoading = true;
        promise
            .then(() => {
                this.toast('Done', successMessage, 'success');
                getRecordNotifyChange([{ recordId: this.recordId }]);
                this.load();
            })
            .catch((e) => {
                this.toast('Could not complete the action', this.messageFrom(e), 'error');
                this.isLoading = false;
            });
    }

    messageFrom(e) {
        return (e && e.body && e.body.message) ? e.body.message : 'Unexpected error.';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
