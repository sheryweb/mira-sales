import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from 'lightning/confirm';
import CURRENCY from '@salesforce/i18n/currency';
import getCommissionContext from '@salesforce/apex/CommissionInvoiceController.getCommissionContext';
import generateInvoiceForCommission from '@salesforce/apex/CommissionInvoiceController.generateInvoiceForCommission';
import markCommissionPaid from '@salesforce/apex/CommissionInvoiceController.markCommissionPaid';
import getPaymentMethodOptions from '@salesforce/apex/CommissionInvoiceController.getPaymentMethodOptions';

export default class CommissionGenerateInvoice extends NavigationMixin(LightningElement) {
    @api recordId;

    contextResult;
    context;
    loading = true;
    generating = false;
    currencyCode = CURRENCY;
    showPaymentDateModal = false;
    paymentDate = null;
    paidAmountInput = null;
    selectedPaymentMethod = null;
    paymentMethodOptions = [];
    showGenerateModal = false;
    selectedFinancialDetailId = null;

    @wire(getCommissionContext, { recordId: '$recordId' })
    wiredContext(result) {
        this.contextResult = result;
        if (result.data) {
            this.context = result.data;
            this.loading = false;
        } else if (result.error) {
            this.loading = false;
            this.showToast('Error', this.parseError(result.error), 'error');
        }
    }

    @wire(getPaymentMethodOptions)
    wiredPaymentMethods({ data }) {
        if (data) {
            this.paymentMethodOptions = data.map((o) => ({ label: o.label, value: o.value }));
        }
    }

    get hasContext() {
        return !!(this.context && this.context.commissionId);
    }

    get hasInvoice() {
        return !!(this.context && this.context.existingInvoiceId);
    }

    get canGenerate() {
        return !!(this.context && this.context.canGenerate);
    }

    get canMarkPaid() {
        return !!(this.context && this.context.canMarkPaid);
    }

    get hasNoActions() {
        return this.hasContext && !this.canGenerate && !this.canMarkPaid && !this.hasInvoice;
    }

    get commissionName() {
        return this.context ? this.context.commissionName : '';
    }

    get status() {
        return this.context ? this.context.status : '';
    }

    get agencyDisplay() {
        return (this.context && this.context.agencyName) ? this.context.agencyName : '—';
    }

    get rateDisplay() {
        if (!this.context || this.context.commissionRate == null) return '—';
        return this.context.commissionRate + '%';
    }

    get commissionAmount() {
        return this.context ? this.context.commissionAmount : 0;
    }

    get vatAmount() {
        return (this.context && this.context.vatAmount != null) ? this.context.vatAmount : 0;
    }

    get totalCommissionAmount() {
        return (this.context && this.context.totalCommissionAmount != null) ? this.context.totalCommissionAmount : 0;
    }

    get paidAmount() {
        return (this.context && this.context.paidAmount != null) ? this.context.paidAmount : 0;
    }

    get paymentMethodDisplay() {
        return (this.context && this.context.paymentMethod) ? this.context.paymentMethod : '—';
    }

    get ineligibilityReasons() {
        return (this.context && this.context.ineligibilityReasons) ? this.context.ineligibilityReasons : [];
    }

    get hasIneligibilityReasons() {
        return this.ineligibilityReasons.length > 0;
    }

    get statusBadgeClass() {
        const raw = (this.context && this.context.status) ? this.context.status : 'Eligible';
        const slug = raw.toLowerCase().replace(/ /g, '-');
        return 'status-badge status-' + slug;
    }

    handleGenerate() {
        this.selectedFinancialDetailId = null;
        this.showGenerateModal = true;
    }

    handleFinancialDetailChange(event) {
        this.selectedFinancialDetailId = event.detail.recordId;
    }

    closeGenerateModal() {
        this.showGenerateModal = false;
    }

    async submitGenerate() {
        if (!this.selectedFinancialDetailId) {
            this.showToast('Error', 'Please select a bank before generating the invoice.', 'error');
            return;
        }
        const confirmed = await LightningConfirm.open({
            message: 'Generate a new commission invoice for ' + this.commissionName + '? This will create an Invoice record and lock the commission for editing.',
            label: 'Confirm Invoice Generation',
            variant: 'header',
            theme: 'info'
        });
        if (!confirmed) return;

        this.showGenerateModal = false;
        this.generating = true;
        try {
            await generateInvoiceForCommission({
                commissionId: this.context.commissionId,
                financialDetailId: this.selectedFinancialDetailId
            });
            this.showToast('Success', 'Invoice generated', 'success');
            await refreshApex(this.contextResult);
        } catch (e) {
            this.showToast('Error', this.parseError(e), 'error');
        } finally {
            this.generating = false;
        }
    }

    handleMarkPaid() {
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');
        this.paymentDate = `${yyyy}-${mm}-${dd}`;
        this.paidAmountInput = this.remainingAmount;
        this.selectedPaymentMethod = null;
        this.showPaymentDateModal = true;
    }

    handlePaymentMethodChange(event) {
        this.selectedPaymentMethod = event.detail.value;
    }

    get remainingAmount() {
        if (!this.context) return 0;
        if (this.context.remainingAmount != null) {
            return this.context.remainingAmount > 0 ? this.context.remainingAmount : 0;
        }
        const total = (this.context.totalCommissionAmount != null) ? this.context.totalCommissionAmount : 0;
        const paid = (this.context.paidAmount != null) ? this.context.paidAmount : 0;
        const r = total - paid;
        return r > 0 ? r : 0;
    }

    handlePaymentDateChange(event) {
        this.paymentDate = event.target.value;
    }

    handlePaidAmountChange(event) {
        const raw = event.target.value;
        this.paidAmountInput = (raw === '' || raw === null) ? null : Number(raw);
    }

    closePaymentDateModal() {
        this.showPaymentDateModal = false;
    }

    async confirmMarkAsPaid() {
        if (!this.paymentDate) {
            this.showToast('Error', 'Payment date is required.', 'error');
            return;
        }
        if (this.paidAmountInput == null || this.paidAmountInput <= 0) {
            this.showToast('Error', 'Payment amount must be greater than 0.', 'error');
            return;
        }
        if (this.paidAmountInput > this.remainingAmount + 0.005) {
            this.showToast('Error', 'Payment amount exceeds the remaining balance.', 'error');
            return;
        }
        if (!this.selectedPaymentMethod) {
            this.showToast('Error', 'Please select a payment method.', 'error');
            return;
        }
        const willBeFullyPaid = (this.paidAmountInput >= this.remainingAmount - 0.005);
        this.showPaymentDateModal = false;
        this.generating = true;
        try {
            await markCommissionPaid({
                commissionId: this.context.commissionId,
                paymentDate: this.paymentDate,
                paidAmount: this.paidAmountInput,
                paymentMethod: this.selectedPaymentMethod
            });
            this.showToast(
                'Success',
                willBeFullyPaid ? 'Payment recorded — Commission Fully Paid' : 'Payment recorded — Commission Partially Paid',
                'success'
            );
            await refreshApex(this.contextResult);
        } catch (e) {
            this.showToast('Error', this.parseError(e), 'error');
        } finally {
            this.generating = false;
        }
    }

    navigateToInvoice() {
        if (this.context && this.context.existingInvoiceId) {
            const url = '/apex/InvoiceCommissionPDF?id=' + this.context.existingInvoiceId;
            window.open(url, '_blank');
        }
    }

    async handleCommissionClick(event) {
        event.preventDefault();
        if (this.context && this.context.commissionId) {
            const url = await this[NavigationMixin.GenerateUrl]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.context.commissionId,
                    actionName: 'view'
                }
            });
            window.open(url, '_blank');
        }
    }

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    parseError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'Unknown error';
    }
}