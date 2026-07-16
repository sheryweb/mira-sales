import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getEligibleAgencyAccounts from '@salesforce/apex/AgencyTradeLicenseExpiryEmailController.getEligibleAgencyAccounts';
import sendExpiryNotificationEmails from '@salesforce/apex/AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmails';

export default class AgencyTradeLicenseExpiryBulkSender extends NavigationMixin(LightningElement) {
    @track accounts = [];
    @track isLoading = true;
    @track isSending = false;
    @track showConfirmModal = false;
    @track error;

    wiredAccountsResult;
    pageRef;

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        this.pageRef = pageRef;
    }

    get isQuickActionContext() {
        return this.pageRef?.type === 'standard__quickAction';
    }

    get closeButtonLabel() {
        return this.isQuickActionContext ? 'Close' : 'Back to Accounts';
    }

    @wire(getEligibleAgencyAccounts)
    wiredAccounts(result) {
        this.wiredAccountsResult = result;
        this.isLoading = false;
        const { data, error } = result;
        if (data) {
            this.accounts = data.map((account) => ({
                ...account,
                accountId: account.accountId || account.id,
                selected: true,
                emailDisplay: this.formatEmails(account),
                rowClass: 'account-row selected-row'
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.accounts = [];
        }
    }

    get hasAccounts() {
        return this.accounts.length > 0;
    }

    get selectedCount() {
        return this.accounts.filter((account) => account.selected).length;
    }

    get isAllSelected() {
        return this.hasAccounts && this.selectedCount === this.accounts.length;
    }

    get isIndeterminate() {
        return this.selectedCount > 0 && !this.isAllSelected;
    }

    get isSendDisabled() {
        return this.selectedCount === 0 || this.isSending;
    }

    get confirmMessage() {
        return 'Are you sure to send Trade License Expiry Notification to the Selected Agencies?';
    }

    get totalAccountCount() {
        return this.accounts.length;
    }

    renderedCallback() {
        const selectAllCheckbox = this.template.querySelector('[data-select-all]');
        if (selectAllCheckbox) {
            selectAllCheckbox.indeterminate = this.isIndeterminate;
        }
    }

    formatEmails(account) {
        const emails = [account.companyEmail, account.contactEmail2].filter(Boolean);
        return emails.length ? emails.join(', ') : 'No email on record';
    }

    handleSelectAll(event) {
        const isChecked = event.target.checked;
        this.accounts = this.accounts.map((account) => ({
            ...account,
            selected: isChecked,
            rowClass: isChecked ? 'account-row selected-row' : 'account-row'
        }));
    }

    getFirstErrorMessage(errorMessages) {
        if (!errorMessages || !errorMessages.length) {
            return null;
        }
        return errorMessages[0];
    }

    handleRowSelect(event) {
        const accountId = event.currentTarget.dataset.accountId;
        const isChecked = event.currentTarget.checked;
        this.accounts = this.accounts.map((account) => {
            if (account.accountId === accountId) {
                return {
                    ...account,
                    selected: isChecked,
                    rowClass: isChecked ? 'account-row selected-row' : 'account-row'
                };
            }
            return account;
        });
    }

    handleSendClick() {
        if (this.selectedCount === 0) {
            this.showToast('Error', 'Please select at least one agency', 'error');
            return;
        }
        this.showConfirmModal = true;
    }

    handleCancelConfirm() {
        this.showConfirmModal = false;
    }

    async handleConfirmSend() {
        this.showConfirmModal = false;
        this.isSending = true;

        const selectedIds = this.accounts
            .filter((account) => account.selected)
            .map((account) => account.accountId)
            .filter((accountId) => !!accountId);

        if (selectedIds.length === 0) {
            this.showToast('Error', 'No valid agencies selected. Please refresh and try again.', 'error');
            this.isSending = false;
            return;
        }

        try {
            const result = await sendExpiryNotificationEmails({ accountIds: selectedIds });
            const successCount = result.successCount || 0;
            const failureCount = result.failureCount || 0;
            const errorDetail = this.getFirstErrorMessage(result.errorMessages);

            if (successCount > 0 && failureCount === 0) {
                this.showToast(
                    'Success',
                    `Trade License Expiry Notification sent to ${successCount} ${successCount === 1 ? 'agency' : 'agencies'}.`,
                    'success'
                );
            } else if (successCount > 0) {
                this.showToast(
                    'Partial Success',
                    `Sent to ${successCount} agencies. ${failureCount} failed.${errorDetail ? ' ' + errorDetail : ''}`,
                    'warning'
                );
            } else {
                this.showToast(
                    'Error',
                    errorDetail || 'No notifications were sent. Verify agency emails and org-wide email setup.',
                    'error'
                );
            }

            if (result.errorMessages && result.errorMessages.length) {
                console.error('Bulk send errors:', result.errorMessages);
            }

            await refreshApex(this.wiredAccountsResult);
        } catch (error) {
            this.showToast(
                'Error',
                error.body?.message || error.message || 'An error occurred while sending notifications.',
                'error'
            );
        } finally {
            this.isSending = false;
        }
    }

    handleClose() {
        if (this.isQuickActionContext) {
            this.dispatchEvent(new CloseActionScreenEvent());
            return;
        }
        this.navigateToAccountList();
    }

    navigateToAccountList() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Account',
                actionName: 'list'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}