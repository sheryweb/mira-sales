import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getReportData from '@salesforce/apex/MonthlySalesReportController.getReportData';
import getReportHtml from '@salesforce/apex/MonthlySalesReportController.getReportHtml';
import generatePdfFromHtml from '@salesforce/apex/MonthlySalesReportController.generatePdfFromHtml';

const MONTH_OPTIONS = [
    { label: 'January', value: '1' },
    { label: 'February', value: '2' },
    { label: 'March', value: '3' },
    { label: 'April', value: '4' },
    { label: 'May', value: '5' },
    { label: 'June', value: '6' },
    { label: 'July', value: '7' },
    { label: 'August', value: '8' },
    { label: 'September', value: '9' },
    { label: 'October', value: '10' },
    { label: 'November', value: '11' },
    { label: 'December', value: '12' }
];

export default class MonthlySalesReport extends LightningElement {
    @track report;
    @track reportHtml = '';
    @track isLoading = false;
    @track isDownloading = false;
    @track errorMessage;

    selectedYear;
    selectedMonth;

    monthOptions = MONTH_OPTIONS;

    connectedCallback() {
        const today = new Date();
        // Default to previous month (typical monthly report cadence)
        const previous = new Date(today.getFullYear(), today.getMonth() - 1, 1);
        this.selectedYear = String(previous.getFullYear());
        this.selectedMonth = String(previous.getMonth() + 1);
        this.loadReport();
    }

    get yearOptions() {
        const currentYear = new Date().getFullYear();
        const years = [];
        for (let y = currentYear; y >= currentYear - 5; y -= 1) {
            years.push({ label: String(y), value: String(y) });
        }
        return years;
    }

    get hasReport() {
        return this.report != null && !this.errorMessage;
    }

    get periodLabel() {
        return this.report?.periodLabel || '';
    }

    get transactions() {
        return this.report?.transactions || [];
    }

    get sharedDeals() {
        return this.report?.sharedDeals || [];
    }

    get salesByProject() {
        return this.report?.salesByProject || [];
    }

    get topTeams() {
        return this.report?.topTeams || [];
    }

    get topRm() {
        return this.report?.topRm;
    }

    get topBroker() {
        return this.report?.topBroker;
    }

    get hasSharedDeals() {
        return this.sharedDeals && this.sharedDeals.length > 0;
    }

    get downloadDisabled() {
        return this.isLoading || this.isDownloading || !this.reportHtml;
    }

    handleYearChange(event) {
        this.selectedYear = event.detail.value;
    }

    handleMonthChange(event) {
        this.selectedMonth = event.detail.value;
    }

    handleRefresh() {
        this.loadReport();
    }

    async loadReport() {
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            const year = parseInt(this.selectedYear, 10);
            const month = parseInt(this.selectedMonth, 10);
            const [data, html] = await Promise.all([
                getReportData({ year, month }),
                getReportHtml({ year, month })
            ]);
            this.report = data;
            this.reportHtml = html || '';
            // Paint server HTML into preview host for pixel-close PDF parity
            // eslint-disable-next-line @lwc/lwc/no-inner-html
            const host = this.template.querySelector('[data-id="htmlPreview"]');
            if (host) {
                host.innerHTML = this.reportHtml;
            }
        } catch (error) {
            this.report = undefined;
            this.reportHtml = '';
            this.errorMessage = this.normalizeError(error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Unable to load report',
                    message: this.errorMessage,
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
            // Re-apply HTML after render cycle (host may not exist while loading)
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const host = this.template.querySelector('[data-id="htmlPreview"]');
                if (host && this.reportHtml) {
                    // eslint-disable-next-line @lwc/lwc/no-inner-html
                    host.innerHTML = this.reportHtml;
                }
            }, 0);
        }
    }

    async handleDownloadPdf() {
        if (!this.reportHtml) {
            return;
        }
        this.isDownloading = true;
        try {
            const base64Pdf = await generatePdfFromHtml({ htmlContent: this.reportHtml });
            this.downloadBase64Pdf(
                base64Pdf,
                `MIRA_Monthly_Sales_Report_${this.selectedYear}_${this.pad(this.selectedMonth)}.pdf`
            );
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'PDF ready',
                    message: 'Monthly Sales Report PDF downloaded.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'PDF generation failed',
                    message: this.normalizeError(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isDownloading = false;
        }
    }

    downloadBase64Pdf(base64Data, fileName) {
        const link = document.createElement('a');
        link.href = `data:application/pdf;base64,${base64Data}`;
        link.download = fileName;
        link.click();
    }

    pad(value) {
        const text = String(value || '');
        return text.length === 1 ? `0${text}` : text;
    }

    normalizeError(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        return error.message || 'Unknown error';
    }

    formatNumber(value) {
        if (value === null || value === undefined) {
            return '0';
        }
        return Number(value).toLocaleString('en-US');
    }
}