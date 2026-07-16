import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInvoicePDFUrl from '@salesforce/apex/InvoicePDFUtil.getInvoicePDFUrl';
import attachInvoicePDF from '@salesforce/apex/InvoicePDFUtil.attachInvoicePDF';

export default class InvoicePDFViewer extends LightningElement {
    @api recordId;
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
        getInvoicePDFUrl({ invoiceId: this.recordId })
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
        attachInvoicePDF({ invoiceId: this.recordId })
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