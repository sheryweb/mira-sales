import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import CURRENCY from '@salesforce/i18n/currency';
import getCommissionContext from '@salesforce/apex/CommissionInvoiceController.getCommissionContext';

export default class CommissionView extends NavigationMixin(LightningElement) {
    @api recordId;

    context;
    loading = true;
    currencyCode = CURRENCY;

    @wire(getCommissionContext, { recordId: '$recordId' })
    wiredContext(result) {
        if (result.data) {
            this.context = result.data;
            this.loading = false;
        } else if (result.error) {
            this.loading = false;
        }
    }

    get hasContext() {
        return !!(this.context && this.context.commissionId);
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
}