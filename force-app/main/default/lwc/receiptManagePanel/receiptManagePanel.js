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
    @track rows = []; // working copy of allocations, edited in place
    @track isLoading = false;
    @track showCancelConfirm = false;
    error;

    // add-allocation form
    newInvoiceId;
    newAmount;
    newMode;

    connectedCallback() {
        this.load();
    }

    load() {
        this.isLoading = true;
        this.error = undefined;
        getReceipt({ receiptId: this.recordId })
            .then((data) => {
                this.view = data;
                this.rows = (data.allocations || []).map((a) => ({
                    lineId: a.lineId,
                    invoiceId: a.invoiceId,
                    invoiceLabel: a.invoiceLabel,
                    mode: a.modeOfPayment,
                    amount: a.amount
                }));
                this.newInvoiceId = undefined;
                this.newAmount = undefined;
                this.newMode = undefined;
            })
            .catch((e) => {
                this.error = this.messageFrom(e);
            })
            .finally(() => {
                this.isLoading = false;
            });
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

    get hasUnapplied() {
        return this.view && this.view.unappliedAmount && Math.abs(this.view.unappliedAmount) > 0.005;
    }

    get unappliedClass() {
        return this.hasUnapplied
            ? 'tile tile_alert slds-box slds-box_x-small'
            : 'tile slds-box slds-box_x-small';
    }

    rowFor(lineId) {
        return this.rows.find((r) => r.lineId === lineId);
    }

    handleRowInvoice(event) {
        this.rowFor(event.target.dataset.id).invoiceId = event.detail.value;
    }

    handleRowMode(event) {
        this.rowFor(event.target.dataset.id).mode = event.detail.value;
    }

    handleRowAmount(event) {
        this.rowFor(event.target.dataset.id).amount = event.target.value;
    }

    handleSave(event) {
        const row = this.rowFor(event.target.dataset.id);
        const amount = parseFloat(row.amount);
        if (isNaN(amount) || amount < 0) {
            this.toast('Invalid amount', 'Enter a number of zero or more.', 'error');
            return;
        }
        this.run(
            saveAllocation({ lineId: row.lineId, invoiceId: row.invoiceId, modeOfPayment: row.mode, amount }),
            'Allocation saved.'
        );
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
        this.run(
            removeAllocation({ lineId }),
            'Allocation removed. The money is now unapplied on the receipt.'
        );
    }

    handleNewInvoiceChange(event) {
        this.newInvoiceId = event.detail.value;
    }

    handleNewModeChange(event) {
        this.newMode = event.detail.value;
    }

    handleNewAmountChange(event) {
        this.newAmount = event.target.value;
    }

    handleAdd() {
        if (!this.newInvoiceId) {
            this.toast('Pick an invoice', 'Choose which invoice to apply the money to.', 'error');
            return;
        }
        const amount = parseFloat(this.newAmount);
        if (isNaN(amount) || amount <= 0) {
            this.toast('Invalid amount', 'Enter an amount greater than zero.', 'error');
            return;
        }
        this.run(
            addAllocation({ receiptId: this.recordId, invoiceId: this.newInvoiceId, amount, modeOfPayment: this.newMode }),
            'Allocation added.'
        );
    }

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
