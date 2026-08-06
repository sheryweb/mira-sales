import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTransferContext from '@salesforce/apex/InvoiceReceiptTransferController.getTransferContext';
import searchOpportunities from '@salesforce/apex/InvoiceReceiptTransferController.searchOpportunities';
import submitTransferRequest from '@salesforce/apex/InvoiceReceiptTransferController.submitTransferRequest';

export default class InvoiceReceiptTransferModal extends LightningElement {
    _recordId;
    _loaded = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        this.maybeLoad();
    }

    isLoading = true;
    working = false;
    error;
    ctx;
    opportunities = [];
    selectedOpportunityId;
    selectedAccount;
    justification = '';

    connectedCallback() {
        this.maybeLoad();
    }

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
            const [ctx, opps] = await Promise.all([
                getTransferContext({ unitId: this.recordId }),
                searchOpportunities({ unitId: this.recordId, searchTerm: null })
            ]);
            this.ctx = ctx;
            this.opportunities = opps || [];
        } catch (e) {
            this.error = this.messageFrom(e);
            this.ctx = { canSubmit: false, blockReason: this.error };
        } finally {
            this.isLoading = false;
        }
    }

    get isBlocked() {
        return this.ctx && this.ctx.canSubmit === false;
    }

    get blockReason() {
        return this.ctx && this.ctx.blockReason;
    }

    get unitTitle() {
        return (this.ctx && this.ctx.unitTitle) || '';
    }

    get invoiceCount() {
        return (this.ctx && this.ctx.invoiceCount) || 0;
    }

    get receiptCount() {
        return (this.ctx && this.ctx.receiptCount) || 0;
    }

    get opportunityOptions() {
        return (this.opportunities || []).map((o) => ({
            label: `${o.opportunityName} — ${o.accountName || 'No Account'} (${o.stageName})`,
            value: o.opportunityId
        }));
    }

    get hasSelection() {
        return !!this.selectedOpportunityId && !!this.selectedAccount;
    }

    get canRequest() {
        return (
            !this.isBlocked &&
            !this.working &&
            this.hasSelection &&
            (this.justification || '').trim().length >= 10
        );
    }

    get disableRequest() {
        return !this.canRequest;
    }

    get showInlineError() {
        return !!this.error && !this.isBlocked;
    }

    handleOpportunityChange(event) {
        this.selectedOpportunityId = event.detail.value;
        const match = (this.opportunities || []).find(
            (o) => o.opportunityId === this.selectedOpportunityId
        );
        this.selectedAccount = match || null;
        this.error = undefined;
    }

    handleJustificationChange(event) {
        this.justification = event.target.value;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleSubmit() {
        if (!this.canRequest) {
            return;
        }
        this.working = true;
        this.error = undefined;
        try {
            await submitTransferRequest({
                unitId: this.recordId,
                targetOpportunityId: this.selectedOpportunityId,
                justification: this.justification
            });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Transfer requested',
                    message: 'Approval request submitted for Invoice Receipt Transfer.',
                    variant: 'success'
                })
            );
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (e) {
            this.error = this.messageFrom(e);
        } finally {
            this.working = false;
        }
    }

    messageFrom(e) {
        return (e && e.body && e.body.message) || (e && e.message) || 'Unexpected error';
    }
}
