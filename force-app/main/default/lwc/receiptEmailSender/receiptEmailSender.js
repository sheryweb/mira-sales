import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendReceiptEmail from '@salesforce/apex/ReceiptEmailService.sendReceiptEmail';

export default class ReceiptEmailSender extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track showSuccess = false;
    @track showConfirmDialog = false;

    // Show confirmation dialog
    handleSendEmail() {
        if (!this.recordId) {
            this.showToast('Error', 'Receipt ID is required', 'error');
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
    
    // Send the email
    sendEmail() {
        this.isLoading = true;
        this.showSuccess = false;
        
        sendReceiptEmail({ receiptId: this.recordId })
            .then(result => {
                this.isLoading = false;
                
                if (result.startsWith('Success')) {
                    this.showSuccess = true;
                    this.showToast('Success', 'Receipt email sent successfully', 'success');
                    
                    // Hide success message after 5 seconds
                    setTimeout(() => {
                        this.showSuccess = false;
                    }, 5000);
                } else {
                    this.showToast('Error', result, 'error');
                }
            })
            .catch(error => {
                this.isLoading = false;
                this.handleError(error);
            });
    }
    
    // Handle errors
    handleError(error) {
        let message = 'Unknown error';
        if (error.body && error.body.message) {
            message = error.body.message;
        } else if (typeof error === 'string') {
            message = error;
        }
        this.showToast('Error', message, 'error');
    }
    
    // Show a toast message
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}