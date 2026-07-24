import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import sendInvoiceEmail from '@salesforce/apex/InvoiceEmailService.sendInvoiceEmail';
import isFinanceUiEnabled from '@salesforce/apex/FinancialEngine.isFinanceUiEnabled';

// Fields to retrieve
import ACCOUNT_PERSONEMAIL_FIELD from '@salesforce/schema/Invoice__c.Account__r.PersonEmail';
import ACCOUNT_COMPANY_EMAIL_FIELD from '@salesforce/schema/Invoice__c.Account__r.Company_Email__c';

export default class InvoiceEmailSender extends LightningElement {
    @api recordId;
    customerEmail;
    @track isLoading = false;
    @track showConfirmDialog = false;
    @track showSuccess = false;

    // Self-hide when the Financial Engine master switch is off (default true to avoid a flash).
    engineEnabled = true;
    @wire(isFinanceUiEnabled)
    wiredEngineFlag({ data }) {
        if (data !== undefined) this.engineEnabled = data;
    }

    // Wire the record to get the account email
    @wire(getRecord, { recordId: '$recordId', fields: [ACCOUNT_PERSONEMAIL_FIELD, ACCOUNT_COMPANY_EMAIL_FIELD] })
    wiredInvoice({ error, data }) {
        if (data) {
            const acc = data.fields.Account__r.value;
            if (acc) {
                const pe = acc.fields.PersonEmail?.value;
                const ce = acc.fields.Company_Email__c?.value;
                const personEmail = pe && String(pe).trim();
                const companyEmail = ce && String(ce).trim();
                this.customerEmail = personEmail || companyEmail || null;
            } else {
                this.customerEmail = null;
            }
        } else if (error) {
            console.error('Error loading invoice data', error);
            this.showToast('Error', 'Unable to load invoice information', 'error');
        }
    }

    // Show confirmation dialog
    handleSendInvoice() {
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

    // Send the invoice email
    async sendEmail() {
        if (!this.recordId) return;
        
        this.isLoading = true;
        this.showSuccess = false;
        
        try {
            const result = await sendInvoiceEmail({ invoiceId: this.recordId });
            
            if (result.startsWith('Success')) {
                this.showSuccess = true;
                this.showToast('Success', 'Invoice email sent successfully', 'success');
                
                // Hide success message after 5 seconds
                setTimeout(() => {
                    this.showSuccess = false;
                }, 5000);
            } else {
                this.showToast('Error', result, 'error');
            }
        } catch (error) {
            console.error('Error sending invoice email', error);
            this.showToast('Error', 'Failed to send invoice email: ' + this.reduceErrors(error), 'error');
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