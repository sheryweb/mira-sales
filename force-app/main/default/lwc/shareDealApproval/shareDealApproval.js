import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getShareDealInfo from '@salesforce/apex/ShareDealApprovalController.getShareDealInfo';
import getEligibleSharedRmOptions from '@salesforce/apex/ShareDealApprovalController.getEligibleSharedRmOptions';
import getOpenShareDealRequest from '@salesforce/apex/ShareDealApprovalController.getOpenShareDealRequest';
import submitShareDealApproval from '@salesforce/apex/ShareDealApprovalController.submitShareDealApproval';

const MIN_JUSTIFICATION_LENGTH = 10;

export default class ShareDealApproval extends LightningElement {
    @api recordId;

    @track info;
    @track rmOptions = [];
    @track selectedSharedRmId;
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
            const [info, openRequest, options] = await Promise.all([
                getShareDealInfo({ opportunityId: this.recordId }),
                getOpenShareDealRequest({ opportunityId: this.recordId }),
                getEligibleSharedRmOptions({ opportunityId: this.recordId })
            ]);

            this.info = info;
            this.rmOptions = (options || []).map((opt) => ({
                label: opt.name,
                value: opt.id
            }));

            if (openRequest && openRequest.approvalRequestId) {
                this.approvalRequestId = openRequest.approvalRequestId;
                this.requestStatus = openRequest.status || null;
                this.approvalRequestName = openRequest.name || '';
                this.justification = openRequest.justification || '';
                this.selectedSharedRmId = openRequest.requestedSharedRmId || null;
                if (!silent && openRequest.status === 'Pending') {
                    this.showToast(
                        'Pending Approval',
                        `Request ${openRequest.name || ''} is awaiting approval.`.trim(),
                        'warning'
                    );
                }
            } else {
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

    get isEligible() {
        return this.info && this.info.eligible;
    }

    get ineligibleReason() {
        return this.info && this.info.ineligibleReason
            ? this.info.ineligibleReason
            : 'Share Deal is not available for this Opportunity.';
    }

    get isPendingApproval() {
        return this.requestStatus === 'Pending';
    }

    get isReadOnly() {
        return this.isPendingApproval;
    }

    get isAlreadyShareDeal() {
        return this.info && this.info.shareDeal;
    }

    get modalTitle() {
        return this.isReviewStep ? 'Review Share Deal' : 'Request Share Deal';
    }

    get unitPriceDisplay() {
        return this.formatMoney(this.info ? this.info.unitPrice : null);
    }

    get creditAmountDisplay() {
        if (!this.info || this.info.unitPrice == null) {
            return 'AED —';
        }
        return this.formatMoney(Number(this.info.unitPrice) * 0.5);
    }

    get selectedSharedRmName() {
        if (!this.selectedSharedRmId) {
            return '—';
        }
        const match = (this.rmOptions || []).find((opt) => opt.value === this.selectedSharedRmId);
        return match ? match.label : '—';
    }

    get approvalRequestUrl() {
        return this.approvalRequestId ? `/${this.approvalRequestId}` : '#';
    }

    get canContinue() {
        const justification = (this.justification || '').trim();
        return (
            this.isEligible &&
            !this.isReadOnly &&
            !!this.selectedSharedRmId &&
            justification.length >= MIN_JUSTIFICATION_LENGTH
        );
    }

    get disableContinue() {
        return !this.canContinue || this.loading;
    }

    get disableSubmit() {
        return this.loading || !this.selectedSharedRmId;
    }

    handleOpenModal() {
        this.isReviewStep = false;
        this.showMainModal = true;
    }

    handleCloseModal() {
        this.showMainModal = false;
        this.isReviewStep = false;
    }

    handleSharedRmChange(event) {
        this.selectedSharedRmId = event.detail.value;
    }

    handleJustificationChange(event) {
        this.justification = event.target.value;
    }

    validateBeforeContinue() {
        if (!this.isEligible) {
            this.showToast('Validation', this.ineligibleReason, 'error');
            return false;
        }
        if (!this.selectedSharedRmId) {
            this.showToast('Validation', 'Select a Shared RM.', 'error');
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
        if (!this.validateBeforeContinue()) {
            return;
        }
        this.loading = true;
        try {
            const submittedId = await submitShareDealApproval({
                opportunityId: this.recordId,
                requestedSharedRmId: this.selectedSharedRmId,
                justification: this.justification,
                approvalRequestId: this.approvalRequestId
            });

            this.approvalRequestId = submittedId;
            this.requestStatus = 'Pending';
            this.showMainModal = false;
            this.isReviewStep = false;

            this.showToast(
                'Submitted for Approval',
                'Your Share Deal request is now pending approval.',
                'success'
            );

            this.loadData(true);
        } catch (error) {
            this.showError(error);
        } finally {
            this.loading = false;
        }
    }

    formatMoney(value) {
        if (value == null || value === '') {
            return 'AED —';
        }
        const num = parseFloat(value);
        if (isNaN(num)) {
            return 'AED —';
        }
        return `AED ${Math.round(num).toLocaleString(undefined, {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        })}`;
    }

    showError(error) {
        const message = this.extractErrorMessage(error);
        // eslint-disable-next-line no-console
        console.error('Share Deal approval error', error);
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
        if (error.message) {
            return error.message;
        }
        return 'An unexpected error occurred.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
