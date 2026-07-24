import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInvoicePDFUrl from '@salesforce/apex/InvoicePDFUtil.getInvoicePDFUrl';
import getTaxInvoicePDFUrl from '@salesforce/apex/InvoicePDFUtil.getTaxInvoicePDFUrl';
import isFinanceUiEnabled from '@salesforce/apex/FinancialEngine.isFinanceUiEnabled';

export default class InvoicePDFViewer extends LightningElement {
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
    
    // View the Tax Invoice PDF. This locks in the Tax Invoice Date (first payment date) on the
    // server the first time, so the URL is fetched on click rather than in connectedCallback.
    // A blank tab is opened synchronously (within the click gesture) to avoid popup blocking,
    // then pointed at the tax PDF once the URL comes back.
    handleViewTaxInvoice() {
        const tab = window.open('', '_blank');
        this.isLoading = true;
        getTaxInvoicePDFUrl({ invoiceId: this.recordId })
            .then(url => {
                if (tab) {
                    tab.location.href = url;
                } else {
                    window.open(url, '_blank');
                }
                this.isLoading = false;
            })
            .catch(error => {
                if (tab) {
                    tab.close();
                }
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