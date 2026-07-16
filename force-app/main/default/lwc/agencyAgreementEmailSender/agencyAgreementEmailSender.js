import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import ISSUING_AUTHORITY_FIELD from '@salesforce/schema/Account.Issuing_Authority__c';

import sendEmailWithPdfAttachmentFromLWC from '@salesforce/apex/AgencyAgreementEmail.sendEmailWithPdfAttachmentFromLWC';
import updateAccountRegisteredIn from '@salesforce/apex/AgencyAgreementEmail.updateAccountRegisteredIn';
import sendEmailWithContentVersion from '@salesforce/apex/SignedAgreementController.sendEmailWithContentVersion';

export default class AgencyAgreementEmailSender extends LightningElement {
    @api recordId;
    isLoading = false;
    @track showModal = false;
    @track showFileModal = false;
    @track modalStage = 'confirm';
    @track registeredInValue = '';
    @track issuingAuthorityValue = '';
    @track issuingAuthorityOptions = [];
    isLoadingModalAction = false;
    isLoadingFileAction = false;
    @track uploadedContentVersionId;

    get acceptedFormats() {
        return ['.pdf', '.doc', '.docx'];
    }

    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    accountObjectInfo;

    @wire(getPicklistValues, { recordTypeId: '$accountObjectInfo.data.defaultRecordTypeId', fieldApiName: ISSUING_AUTHORITY_FIELD })
    wiredIssuingAuthorityPicklist({ error, data }) {
        if (data) {
            this.issuingAuthorityOptions = data.values;
        } else if (error) {
            console.error('Error fetching Issuing Authority picklist values:', error);
        }
    }

    get isConfirmationStage() {
        return this.modalStage === 'confirm';
    }

    handleOpenModal() {
        if (!this.recordId) {
            this.showToast('Error', 'Record ID is missing', 'error');
            return;
        }
        this.modalStage = 'confirm';
        this.registeredInValue = '';
        this.issuingAuthorityValue = '';
        this.showModal = true;
    }

    handleOpenSignedModal() {
        if (!this.recordId) {
            this.showToast('Error', 'Record ID is missing', 'error');
            return;
        }
        console.log('Opening file modal for recordId:', this.recordId);
        this.uploadedContentVersionId = null;
        this.showFileModal = true;
    }

    closeModal() {
        this.showModal = false;
        this.isLoadingModalAction = false;
    }

    closeFileModal() {
        this.showFileModal = false;
        this.isLoadingFileAction = false;
        this.uploadedContentVersionId = null;
    }

    handleConfirmClick() {
        this.modalStage = 'input';
    }

    handleRegisteredInChange(event) {
        this.registeredInValue = event.target.value;
    }

    handleIssuingAuthorityChange(event) {
        this.issuingAuthorityValue = event.target.value;
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.uploadedContentVersionId = uploadedFiles[0].contentVersionId;
            console.log('File uploaded successfully. ContentVersionId:', this.uploadedContentVersionId);
        }
    }

    async handleSendSignedClick() {
        if (!this.uploadedContentVersionId) {
            this.showToast('Error', 'Please upload a file first', 'error');
            return;
        }

        this.isLoadingFileAction = true;
        this.isLoading = true;

        try {
            await sendEmailWithContentVersion({
                recordId: this.recordId,
                contentVersionId: this.uploadedContentVersionId
            });

            console.log('Email sent successfully');
            this.showToast('Success', 'Signed agreement has been uploaded and emailed', 'success');
            this.closeFileModal();

        } catch (error) {
            console.error('Complete error details:', error);
            let errorMsg = this.extractErrorMessage(error);
            console.error('Extracted error message:', errorMsg);
            this.showToast('Error', `Operation failed: ${errorMsg}`, 'error');
        } finally {
            this.isLoadingFileAction = false;
            this.isLoading = false;
        }
    }

    async handleIssueClick() {
        const allValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')]
            .reduce((valid, input) => {
                input.reportValidity();
                return valid && input.checkValidity();
            }, true);

        if (!allValid) {
            this.showToast('Error', 'Please fill all required fields.', 'error');
            return;
        }

        this.isLoadingModalAction = true;
        this.isLoading = true;

        try {
            await updateAccountRegisteredIn({
                recordId: this.recordId,
                registeredIn: this.registeredInValue,
                issuingAuthority: this.issuingAuthorityValue
            });

            await sendEmailWithPdfAttachmentFromLWC({
                recordId: this.recordId,
                isRenewal: true
            });

            this.showToast('Success', 'Account updated and email sent successfully', 'success');
            this.closeModal();

        } catch (error) {
            console.error('Error during issue process:', error);
            this.showToast('Error', `Process failed: ${this.extractErrorMessage(error)}`, 'error');
        } finally {
            this.isLoadingModalAction = false;
            this.isLoading = false;
        }
    }

    extractErrorMessage(error) {
        let message = 'Unknown error';
        if (typeof error === 'string') {
            message = error;
        } else if (error.body && typeof error.body.message === 'string') {
            message = error.body.message;
        } else if (error.message) {
            message = error.message;
        } else if (error.body && Array.isArray(error.body) && error.body.length > 0 && error.body[0].message) {
            message = error.body[0].message;
        }
        return message;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}