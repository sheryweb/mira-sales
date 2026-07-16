import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getUnitPriceInfo from '@salesforce/apex/UnitPriceApprovalController.getUnitPriceInfo';
import getOpenUnitPriceRequestForUnit from '@salesforce/apex/UnitPriceApprovalController.getOpenUnitPriceRequestForUnit';
import submitUnitPriceApproval from '@salesforce/apex/UnitPriceApprovalController.submitUnitPriceApproval';

const MIN_JUSTIFICATION_LENGTH = 10;

export default class UnitPriceChangeApproval extends LightningElement {
    @api recordId;

    @track info;
    @track discountPercent;
    @track justification = '';
    @track loading = false;
    @track showMainModal = false;
    @track isReviewStep = false;

    @track approvalRequestId;
    @track requestStatus = null;
    @track approvalRequestName = '';

    connectedCallback() {
        if (this.recordId) {
            this.loadData();
        }
    }

    async loadData(silent = false) {
        this.loading = true;
        try {
            const [info, openRequest] = await Promise.all([
                getUnitPriceInfo({ unitId: this.recordId }),
                getOpenUnitPriceRequestForUnit({ unitId: this.recordId })
            ]);

            this.info = info;

            if (openRequest && openRequest.approvalRequestId) {
                this.approvalRequestId = openRequest.approvalRequestId;
                this.requestStatus = openRequest.status || null;
                this.approvalRequestName = openRequest.name || '';
                this.justification = openRequest.justification || '';
                if (!silent && openRequest.status === 'Pending') {
                    this.showToast(
                        'Pending Approval',
                        `Request ${openRequest.name || ''} is awaiting approval. Changes are locked.`.trim(),
                        'warning'
                    );
                }
            } else {
                // No open request (new, or the previous one was approved/rejected) —
                // always clear stale state so a fresh request can be submitted.
                this.approvalRequestId = null;
                this.requestStatus = null;
                this.approvalRequestName = '';
            }
        } catch (error) {
            this.showError(error);
        } finally {
            this.loading = false;
        }
    }

    get currencyCode() {
        return this.info ? this.info.currencyCode : 'AED';
    }

    get isForeignCurrency() {
        return this.currencyCode !== 'AED';
    }

    get isEligible() {
        return this.info && this.info.eligible;
    }

    get isPendingApproval() {
        return this.requestStatus === 'Pending';
    }

    get isReadOnly() {
        return this.isPendingApproval;
    }

    get discountOptions() {
        return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((value) => ({
            label: `${value}%`,
            value: String(value)
        }));
    }

    get modalTitle() {
        return this.isReviewStep ? 'Review Unit Price Change' : 'Request Unit Price Change';
    }

    get currentPriceDisplay() {
        return this.formatMoney(this.currencyCode, this.info ? this.info.currentPrice : null);
    }

    get currentCostAedDisplay() {
        return this.formatMoney('AED', this.info ? this.info.currentCostAED : null);
    }

    get discountPercentDisplay() {
        return this.discountPercent ? `${this.discountPercent}%` : '—';
    }

    get calculatedProposedPrice() {
        if (!this.info || this.discountPercent == null || this.discountPercent === '') {
            return null;
        }
        const currentPrice = parseFloat(this.info.currentPrice);
        const percent = parseInt(this.discountPercent, 10);
        if (isNaN(currentPrice) || isNaN(percent)) {
            return null;
        }
        const multiplier = 1 - percent / 100;
        return Math.round(currentPrice * multiplier);
    }

    get proposedPriceDisplay() {
        return this.formatMoney(this.currencyCode, this.calculatedProposedPrice);
    }

    get proposedCostAed() {
        const price = this.calculatedProposedPrice;
        if (price == null) {
            return null;
        }
        if (!this.isForeignCurrency) {
            return price;
        }
        const rate = this.info ? parseFloat(this.info.conversionRate) : null;
        if (!rate || rate === 0) {
            return null;
        }
        return Math.round(price / rate);
    }

    get proposedCostAedDisplay() {
        return this.formatMoney('AED', this.proposedCostAed);
    }

    get conversionRateDisplay() {
        if (!this.isForeignCurrency || !this.info || !this.info.conversionRate) {
            return '';
        }
        return `1 AED = ${this.info.conversionRate} ${this.currencyCode} (Currency Management)`;
    }

    get approvalRequestUrl() {
        return this.approvalRequestId ? `/${this.approvalRequestId}` : '#';
    }

    get canContinue() {
        const justification = (this.justification || '').trim();
        return (
            this.isEligible &&
            !this.isReadOnly &&
            this.discountPercent != null &&
            this.discountPercent !== '' &&
            justification.length >= MIN_JUSTIFICATION_LENGTH
        );
    }

    get disableContinue() {
        return !this.canContinue || this.loading;
    }

    get disableSubmit() {
        return this.loading || this.calculatedProposedPrice == null;
    }

    handleOpenModal() {
        this.isReviewStep = false;
        this.showMainModal = true;
    }

    handleCloseModal() {
        this.showMainModal = false;
        this.isReviewStep = false;
        this.discountPercent = null;
    }

    handleDiscountChange(event) {
        this.discountPercent = event.detail.value;
    }

    handleJustificationChange(event) {
        this.justification = event.target.value;
    }

    validateBeforeContinue() {
        if (!this.isEligible) {
            this.showToast('Validation', 'Unit price changes are only allowed for Booked units.', 'error');
            return false;
        }
        const percent = parseInt(this.discountPercent, 10);
        if (isNaN(percent) || percent < 1 || percent > 10) {
            this.showToast('Validation', 'Select a discount percentage between 1 and 10.', 'error');
            return false;
        }
        if (!this.justification || this.justification.trim().length < MIN_JUSTIFICATION_LENGTH) {
            this.showToast('Validation', 'Justification must be at least 10 characters.', 'error');
            return false;
        }
        return true;
    }

    handleContinueToReview() {
        if (!this.validateBeforeContinue()) {
            return;
        }
        this.isReviewStep = true;
    }

    handleBackFromReview() {
        this.isReviewStep = false;
    }

    async handleSubmitForApproval() {
        if (this.calculatedProposedPrice == null) {
            this.showToast('Validation', 'Unable to calculate proposed price. Please go back and try again.', 'error');
            return;
        }
        this.loading = true;
        try {
            const submittedId = await submitUnitPriceApproval({
                unitId: this.recordId,
                justification: this.justification,
                discountPercent: parseInt(this.discountPercent, 10),
                approvalRequestId: this.approvalRequestId
            });

            this.approvalRequestId = submittedId;
            this.requestStatus = 'Pending';
            this.showMainModal = false;
            this.isReviewStep = false;
            this.discountPercent = null;

            this.showToast(
                'Submitted for Approval',
                'Your unit price change request is now pending approval.',
                'success'
            );

            this.loadData(true);
        } catch (error) {
            this.showError(error);
        } finally {
            this.loading = false;
        }
    }

    formatMoney(currencyCode, value) {
        if (value == null || value === '') {
            return `${currencyCode} —`;
        }
        const num = parseFloat(value);
        if (isNaN(num)) {
            return `${currencyCode} —`;
        }
        return `${currencyCode} ${Math.round(num).toLocaleString(undefined, {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        })}`;
    }

    showError(error) {
        const message = this.extractErrorMessage(error);
        // eslint-disable-next-line no-console
        console.error('Unit price approval error', error);
        this.showToast('Error', message, 'error');
    }

    extractErrorMessage(error) {
        if (!error) {
            return 'An unexpected error occurred.';
        }
        const body = error.body;
        if (typeof body === 'string' && body.trim()) {
            return body;
        }
        if (body && body.message) {
            return body.message;
        }
        if (Array.isArray(body) && body[0] && body[0].message) {
            return body[0].message;
        }
        if (body && body.pageErrors && body.pageErrors.length) {
            return body.pageErrors[0].message;
        }
        if (error.message) {
            return error.message;
        }
        return 'An unexpected error occurred.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}