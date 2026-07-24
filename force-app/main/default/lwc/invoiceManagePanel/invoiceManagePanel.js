import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import LightningConfirm from 'lightning/confirm';
import isFinanceUiEnabled from '@salesforce/apex/FinancialEngine.isFinanceUiEnabled';
import getInvoice from '@salesforce/apex/InvoiceManageController.getInvoice';
import updateCurrency from '@salesforce/apex/InvoiceManageController.updateCurrency';
import addInstallment from '@salesforce/apex/InvoiceManageController.addInstallment';
import removeInstallment from '@salesforce/apex/InvoiceManageController.removeInstallment';
import cancelInvoice from '@salesforce/apex/InvoiceManageController.cancelInvoice';

export default class InvoiceManagePanel extends LightningElement {
    @api recordId;
    @track view;
    @track isLoading = false;
    @track showCancelConfirm = false;
    error;

    // Self-hide when the Financial Engine master switch is off (default true to avoid a flash).
    engineEnabled = true;
    @wire(isFinanceUiEnabled)
    wiredEngineFlag({ data }) {
        if (data !== undefined) this.engineEnabled = data;
    }

    // currency fields (Sub-Total / VAT are derived and shown read-only)
    @track otherCurrency = false;
    secondaryCurrency;
    conversionRate;

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
                this.otherCurrency = data.otherCurrency;
                this.secondaryCurrency = data.secondaryCurrency;
                this.conversionRate = data.conversionRate;
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

    get isCancelled() {
        return this.view && this.view.cancelled;
    }

    get cashFlowOptions() {
        return (this.view && this.view.cashFlowOptions) ? this.view.cashFlowOptions : [];
    }

    get secondaryCurrencyOptions() {
        return (this.view && this.view.secondaryCurrencyOptions) ? this.view.secondaryCurrencyOptions : [];
    }

    // Read-only preview of the cash flow chosen in the Add form.
    get selectedPreview() {
        if (!this.newCashFlowId) return undefined;
        return this.cashFlowOptions.find((o) => o.value === this.newCashFlowId);
    }

    handleOtherCurrencyChange(e) {
        this.otherCurrency = e.target.checked;
    }

    handleSecondaryCurrencyChange(e) {
        this.secondaryCurrency = e.detail.value;
    }

    handleConversionRateChange(e) {
        this.conversionRate = e.target.value;
    }

    handleSaveCurrency() {
        if (this.otherCurrency) {
            if (!this.secondaryCurrency) {
                this.toast('Pick a currency', 'Select a secondary currency.', 'error');
                return;
            }
            const rate = parseFloat(this.conversionRate);
            if (isNaN(rate) || rate <= 0) {
                this.toast('Invalid rate', 'Conversion rate must be greater than zero.', 'error');
                return;
            }
        }
        this.run(
            updateCurrency({
                invoiceId: this.recordId,
                otherCurrency: this.otherCurrency,
                secondaryCurrency: this.otherCurrency ? this.secondaryCurrency : null,
                conversionRate: this.otherCurrency ? parseFloat(this.conversionRate) : null
            }),
            'Currency settings updated.'
        );
    }

    async handleRemoveInstallment(e) {
        const milestoneId = e.target.dataset.id;
        const ok = await LightningConfirm.open({
            message: 'Remove this installment from the invoice? The invoice sub-total will be recalculated from the remaining installments.',
            variant: 'header',
            label: 'Remove installment',
            theme: 'warning'
        });
        if (!ok) return;
        this.run(removeInstallment({ milestoneId }), 'Installment removed.');
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

    handleCancelClick() {
        this.showCancelConfirm = true;
    }

    handleCancelDismiss() {
        this.showCancelConfirm = false;
    }

    handleCancelConfirm() {
        this.showCancelConfirm = false;
        this.run(cancelInvoice({ invoiceId: this.recordId }), 'Invoice cancelled.');
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
