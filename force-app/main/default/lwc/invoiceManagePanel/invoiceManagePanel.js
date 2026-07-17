import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import getInvoice from '@salesforce/apex/InvoiceManageController.getInvoice';
import updateAmounts from '@salesforce/apex/InvoiceManageController.updateAmounts';
import addInstallment from '@salesforce/apex/InvoiceManageController.addInstallment';
import removeInstallment from '@salesforce/apex/InvoiceManageController.removeInstallment';

export default class InvoiceManagePanel extends LightningElement {
    @api recordId;
    @track view;
    @track isLoading = false;
    error;

    // edited amount fields
    editSubTotal;
    editVat;

    // add-installment form
    newCashFlowId;

    connectedCallback() {
        this.load();
    }

    load() {
        this.isLoading = true;
        this.error = undefined;
        getInvoice({ invoiceId: this.recordId })
            .then((data) => {
                this.view = data;
                this.editSubTotal = data.subTotal;
                this.editVat = data.vat;
                this.newCashFlowId = undefined;
            })
            .catch((e) => {
                this.error = this.messageFrom(e);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get hasInstallments() {
        return this.view && this.view.installments && this.view.installments.length > 0;
    }

    get cashFlowOptions() {
        return (this.view && this.view.cashFlowOptions) ? this.view.cashFlowOptions : [];
    }

    // Read-only preview of the cash flow chosen in the Add form.
    get selectedPreview() {
        if (!this.newCashFlowId) return undefined;
        return this.cashFlowOptions.find((o) => o.value === this.newCashFlowId);
    }

    handleSubTotalChange(e) {
        this.editSubTotal = e.target.value;
    }

    handleVatChange(e) {
        this.editVat = e.target.value;
    }

    handleSaveAmounts() {
        const sub = parseFloat(this.editSubTotal);
        const vat = parseFloat(this.editVat);
        if (isNaN(sub) || sub < 0 || isNaN(vat) || vat < 0) {
            this.toast('Invalid amount', 'Sub-total and VAT must be zero or greater.', 'error');
            return;
        }
        this.run(updateAmounts({ invoiceId: this.recordId, subTotal: sub, vat }), 'Invoice amount updated.');
    }

    handleRemoveInstallment(e) {
        this.run(removeInstallment({ milestoneId: e.target.dataset.id }), 'Installment removed.');
    }

    handleNewCashFlowChange(e) {
        this.newCashFlowId = e.detail.value;
    }

    handleAddInstallment() {
        if (!this.newCashFlowId) {
            this.toast('Pick an installment', 'Choose which cash-flow installment to cover.', 'error');
            return;
        }
        this.run(
            addInstallment({ invoiceId: this.recordId, cashFlowId: this.newCashFlowId }),
            'Installment added.'
        );
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
