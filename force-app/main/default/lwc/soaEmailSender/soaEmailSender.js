import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import sendSOAEmail from '@salesforce/apex/SOAEmailService.sendSOAEmail';

// Fields to retrieve
import ACCOUNT_EMAIL_FIELD from '@salesforce/schema/Opportunity.Account_Email__c';

export default class SoaEmailSender extends LightningElement {
    @api recordId;
    customerEmail;
    @track isLoading = false;
    @track showConfirmDialog = false;
    @track showSuccess = false;

    // Wire the record to get the account email
    @wire(getRecord, { recordId: '$recordId', fields: [ACCOUNT_EMAIL_FIELD] })
    wiredOpportunity({ error, data }) {
        if (data) {
            this.customerEmail = data.fields.Account_Email__c.value;
        } else if (error) {
            console.error('Error loading opportunity data', error);
            this.showToast('Error', 'Unable to load opportunity information', 'error');
        }
    }

    // Show confirmation dialog
    handleSendSOA() {
        if (!this.customerEmail) {
            this.showToast('Error', 'No customer email address found', 'error');
            return;
        }

        // Show the confirmation dialog
        this.showConfirmDialog = true;
    }
    
    // Handle confirmation dialog "Cancel" button
    handleCancel() {
        this.showConfirmDialog = false;
    }
    
    // Handle confirmation dialog "Confirm" button
    handleConfirm() {
        // Close the dialog
        this.showConfirmDialog = false;
        
        // Send the email
        this.sendEmail();
    }

    // Send the SOA email
    async sendEmail() {
        if (!this.recordId) return;
        
        this.isLoading = true;
        this.showSuccess = false;
        
        try {
            const result = await sendSOAEmail({ opportunityId: this.recordId });
            
            if (result.startsWith('Success')) {
                this.showSuccess = true;
                this.showToast('Success', 'SOA email sent successfully', 'success');
                
                // Hide success message after 5 seconds
                setTimeout(() => {
                    this.showSuccess = false;
                }, 5000);
            } else {
                this.showToast('Error', result, 'error');
            }
        } catch (error) {
            console.error('Error sending SOA email', error);
            this.showToast('Error', 'Failed to send SOA email: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Helper method to display toast notifications
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    // Helper for error reduction
    reduceErrors(errors) {
        if (!Array.isArray(errors)) {
            errors = [errors];
        }
        
        return errors
            .filter(error => !!error)
            .map(error => {
                if (typeof error === 'string') {
                    return error;
                } else if (error.body && typeof error.body.message === 'string') {
                    return error.body.message;
                } else if (error.message) {
                    return error.message;
                } else {
                    return JSON.stringify(error);
                }
            })
            .join(', ');
    }
}