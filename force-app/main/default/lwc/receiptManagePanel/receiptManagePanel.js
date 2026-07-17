import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import getReceipt from '@salesforce/apex/ReceiptManageController.getReceipt';
import updateAllocationAmount from '@salesforce/apex/ReceiptManageController.updateAllocationAmount';
import removeAllocation from '@salesforce/apex/ReceiptManageController.removeAllocation';
import cancelReceipt from '@salesforce/apex/ReceiptManageController.cancelReceipt';

export default class ReceiptManagePanel extends LightningElement {
    @api recordId;
    @track view;
    @track isLoading = false;
    @track showCancelConfirm = false;
    error;
    edits = {}; // lineId -> edited amount

    connectedCallback() {
        this.load();
    }

    load() {
        this.isLoading = true;
        this.error = undefined;
        // getReceipt is cacheable; call imperatively so we can refresh after each action.
        getReceipt({ receiptId: this.recordId })
            .then((data) => {
                this.view = data;
                this.edits = {};
            })
            .catch((e) => {
                this.error = this.messageFrom(e);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get hasAllocations() {
        return this.view && this.view.allocations && this.view.allocations.length > 0;
    }

    get isCancelled() {
        return this.view && this.view.cancelled;
    }

    handleAmountChange(event) {
        this.edits[event.target.dataset.id] = event.target.value;
    }

    handleSave(event) {
        const lineId = event.target.dataset.id;
        const raw = this.edits[lineId];
        if (raw === undefined || raw === '') {
            return;
        }
        const amount = parseFloat(raw);
        if (isNaN(amount) || amount < 0) {
            this.toast('Invalid amount', 'Enter a number of zero or more.', 'error');
            return;
        }
        this.run(updateAllocationAmount({ lineId, newAmount: amount }), 'Amount updated.');
    }

    handleRemove(event) {
        const lineId = event.target.dataset.id;
        this.run(removeAllocation({ lineId }), 'Allocation removed.');
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

    // Run an action, then refresh both this panel and the standard record page.
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
