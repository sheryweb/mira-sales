import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getReceiptPDFUrl from '@salesforce/apex/ReceiptPDFUtil.getReceiptPDFUrl';
import attachReceiptPDF from '@salesforce/apex/ReceiptPDFUtil.attachReceiptPDF';
import isFinanceUiEnabled from '@salesforce/apex/FinancialEngine.isFinanceUiEnabled';

export default class ReceiptPDFViewer extends LightningElement {
    @api recordId;

    // Self-hide when the Financial Engine master switch is off (defence-in-depth behind
    // Lightning page visibility). Default true to avoid a flash in the normal (on) case.
    engineEnabled = true;
    @wire(isFinanceUiEnabled)
    wiredEngineFlag({ data }) {
        if (data !== undefined) this.engineEnabled = data;
    }
    pdfUrl;
    isLoading = false;
    
    // When the component loads, get the PDF URL
    connectedCallback() {
        if (this.recordId) {
            this.getPDFUrl();
        }
    }
    
    // Get the URL for the PDF
    getPDFUrl() {
        this.isLoading = true;
        getReceiptPDFUrl({ receiptId: this.recordId })
            .then(url => {
                this.pdfUrl = url;
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error);
                this.isLoading = false;
            });
    }
    
    // View the PDF in a new tab
    handleViewPDF() {
        if (this.pdfUrl) {
            window.open(this.pdfUrl, '_blank');
        } else {
            this.showToast('Error', 'PDF URL is not available', 'error');
        }
    }
    
    // Attach the PDF to the record
    handleAttachPDF() {
        this.isLoading = true;
        attachReceiptPDF({ receiptId: this.recordId })
            .then(attachmentId => {
                this.showToast('Success', 'PDF has been attached to the record', 'success');
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error);
                this.isLoading = false;
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