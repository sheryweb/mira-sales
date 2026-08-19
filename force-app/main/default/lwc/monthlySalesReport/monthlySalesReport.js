import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getReportData from '@salesforce/apex/MonthlySalesReportController.getReportData';
import getReportHtml from '@salesforce/apex/MonthlySalesReportController.getReportHtml';
import getRmOptions from '@salesforce/apex/MonthlySalesReportController.getRmOptions';

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

const REPORT_TYPE_OPTIONS = [
    { label: 'Monthly', value: 'Monthly' },
    { label: 'Weekly', value: 'Weekly' },
    { label: 'Date Range', value: 'Date Range' }
];

const ALL_RMS_OPTION = { label: 'All RMs', value: '' };

export default class MonthlySalesReport extends LightningElement {
    @track report;
    @track reportHtml = '';
    @track isLoading = false;
    @track isDownloading = false;
    @track errorMessage;
    @track rmOptions = [ALL_RMS_OPTION];

    selectedReportType = 'Monthly';
    selectedYear;
    selectedMonth;
    selectedWeekDate;
    selectedRangeStart;
    selectedRangeEnd;
    selectedOwnerId = '';

    reportTypeOptions = REPORT_TYPE_OPTIONS;
    monthOptions = MONTH_OPTIONS;

    connectedCallback() {
        const today = new Date();
        const previous = new Date(today.getFullYear(), today.getMonth() - 1, 1);
        const previousEnd = new Date(today.getFullYear(), today.getMonth(), 0);
        this.selectedYear = String(previous.getFullYear());
        this.selectedMonth = String(previous.getMonth() + 1);
        this.selectedWeekDate = this.toIsoDate(this.mondayOf(today));
        this.selectedRangeStart = this.toIsoDate(previous);
        this.selectedRangeEnd = this.toIsoDate(previousEnd);
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

    get isMonthly() {
        return this.selectedReportType === 'Monthly';
    }

    get isWeekly() {
        return this.selectedReportType === 'Weekly';
    }

    get isDateRange() {
        return this.selectedReportType === 'Date Range';
    }

    get hasReport() {
        return this.report != null && !this.errorMessage;
    }

    get periodLabel() {
        return this.report?.periodLabel || '';
    }

    get cardTitle() {
        if (this.isWeekly) {
            return 'MIRA Weekly Sales Report';
        }
        if (this.isDateRange) {
            return 'MIRA Date Range Sales Report';
        }
        return 'MIRA Monthly Sales Report';
    }

    get downloadButtonLabel() {
        if (this.isWeekly) {
            return 'Print / Save Weekly Sales Report PDF';
        }
        if (this.isDateRange) {
            return 'Print / Save Date Range Sales Report PDF';
        }
        return 'Print / Save Monthly Sales Report PDF';
    }

    get topTeamHeading() {
        if (this.isWeekly) {
            return 'Top Team of the Week';
        }
        if (this.isDateRange) {
            return 'Top Team of the Period';
        }
        return 'Top Team of the Month';
    }

    get topRmHeading() {
        if (this.isWeekly) {
            return 'Top RM of the Week';
        }
        if (this.isDateRange) {
            return 'Top RM of the Period';
        }
        return 'Top RM of the Month';
    }

    get topBrokerHeading() {
        if (this.isWeekly) {
            return 'Top Broker of the Week';
        }
        if (this.isDateRange) {
            return 'Top Broker of the Period';
        }
        return 'Top Broker of the Month';
    }

    get transactions() {
        return (this.report?.transactions || []).map((txn) => ({
            ...txn,
            unitPriceDisplay: this.formatAmount(txn.unitPrice),
            stagePillClass: this.stagePillClass(txn.stageName)
        }));
    }

    stagePillClass(stageName) {
        const stage = (stageName || '').toUpperCase();
        if (stage === 'BOOKED') {
            return 'stage-pill stage-pill-booked';
        }
        if (stage === 'SOLD') {
            return 'stage-pill stage-pill-sold';
        }
        if (stage === 'RESERVED') {
            return 'stage-pill stage-pill-reserved';
        }
        return 'stage-pill';
    }

    get sharedDeals() {
        return (this.report?.sharedDeals || []).map((deal) => ({
            ...deal,
            dealValueDisplay: this.formatAmount(deal.dealValue),
            ownerCredits: (deal.ownerCredits || []).map((c) => ({
                ...c,
                creditAmountDisplay: this.formatAmount(c.creditAmount),
                unitCreditDisplay: this.formatAmount(c.unitCredit)
            })),
            managerCredits: (deal.managerCredits || []).map((c) => ({
                ...c,
                creditAmountDisplay: this.formatAmount(c.creditAmount),
                unitCreditDisplay: this.formatAmount(c.unitCredit)
            }))
        }));
    }

    get salesByProject() {
        return (this.report?.salesByProject || []).map((row) => ({
            ...row,
            unitsDisplay: this.formatAmount(row.units),
            totalValueDisplay: this.formatAmount(row.totalValue),
            shareDisplay: this.formatAmount(row.shareOfSalesPercent)
        }));
    }

    get topTeams() {
        return (this.report?.topTeams || []).map((team) => ({
            ...team,
            unitsDisplay: this.formatAmount(team.units),
            totalValueDisplay: this.formatAmount(team.totalValue)
        }));
    }

    get hasTopTeams() {
        return this.topTeams.length > 0;
    }

    get topRm() {
        const rm = this.report?.topRm;
        if (!rm) {
            return null;
        }
        return {
            ...rm,
            unitsDisplay: this.formatAmount(rm.units),
            totalValueDisplay: this.formatAmount(rm.totalValue)
        };
    }

    get topBroker() {
        const broker = this.report?.topBroker;
        if (!broker) {
            return null;
        }
        return {
            ...broker,
            unitsDisplay: this.formatAmount(broker.units),
            totalValueDisplay: this.formatAmount(broker.totalValue)
        };
    }

    get totalSalesValueDisplay() {
        return this.formatAmount(this.report?.totalSalesValue);
    }

    get unitsBookedDisplay() {
        return this.formatAmount(this.report?.unitsBooked);
    }

    get bookedCountDisplay() {
        return this.formatAmount(this.report?.bookedCount);
    }

    get soldCountDisplay() {
        return this.formatAmount(this.report?.soldCount);
    }

    get reservedCountDisplay() {
        return this.formatAmount(this.report?.reservedCount);
    }

    get hasSharedDeals() {
        return this.sharedDeals && this.sharedDeals.length > 0;
    }

    get downloadDisabled() {
        return this.isLoading || this.isDownloading || !this.reportHtml;
    }

    handleReportTypeChange(event) {
        this.selectedReportType = event.detail.value;
    }

    handleYearChange(event) {
        this.selectedYear = event.detail.value;
    }

    handleMonthChange(event) {
        this.selectedMonth = event.detail.value;
    }

    handleWeekDateChange(event) {
        const raw = event.detail.value;
        if (!raw) {
            this.selectedWeekDate = raw;
            return;
        }
        // Snap to Monday of the selected week for consistency with Apex
        const parts = raw.split('-').map((v) => parseInt(v, 10));
        const d = new Date(parts[0], parts[1] - 1, parts[2]);
        this.selectedWeekDate = this.toIsoDate(this.mondayOf(d));
    }

    handleRangeStartChange(event) {
        this.selectedRangeStart = event.detail.value;
    }

    handleRangeEndChange(event) {
        this.selectedRangeEnd = event.detail.value;
    }

    handleOwnerChange(event) {
        this.selectedOwnerId = event.detail.value || '';
    }

    handleRefresh() {
        this.loadReport();
    }

    reportParams() {
        const ownerId = this.selectedOwnerId || null;
        if (this.isWeekly) {
            return {
                reportType: 'Weekly',
                year: null,
                month: null,
                weekStartIso: this.selectedWeekDate,
                startDateIso: null,
                endDateIso: null,
                ownerId
            };
        }
        if (this.isDateRange) {
            return {
                reportType: 'Date Range',
                year: null,
                month: null,
                weekStartIso: null,
                startDateIso: this.selectedRangeStart,
                endDateIso: this.selectedRangeEnd,
                ownerId
            };
        }
        return {
            reportType: 'Monthly',
            year: parseInt(this.selectedYear, 10),
            month: parseInt(this.selectedMonth, 10),
            weekStartIso: null,
            startDateIso: null,
            endDateIso: null,
            ownerId
        };
    }

    rmOptionParams() {
        const params = this.reportParams();
        return {
            reportType: params.reportType,
            year: params.year,
            month: params.month,
            weekStartIso: params.weekStartIso,
            startDateIso: params.startDateIso,
            endDateIso: params.endDateIso
        };
    }

    async loadReport() {
        if (this.isDateRange) {
            if (!this.selectedRangeStart || !this.selectedRangeEnd) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Date range required',
                        message: 'Select both From and To dates.',
                        variant: 'warning'
                    })
                );
                return;
            }
            if (this.selectedRangeEnd < this.selectedRangeStart) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Invalid date range',
                        message: 'To date must be on or after From date.',
                        variant: 'warning'
                    })
                );
                return;
            }
        }

        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            const params = this.reportParams();
            const [data, html, rms] = await Promise.all([
                getReportData(params),
                getReportHtml(params),
                getRmOptions(this.rmOptionParams())
            ]);
            this.report = data;
            this.reportHtml = html || '';
            this.rmOptions = [ALL_RMS_OPTION, ...(rms || [])];
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
        }
    }

    handleConfirmDownloadPdf() {
        if (!this.reportHtml) {
            return;
        }
        this.isDownloading = true;
        try {
            const params = this.reportParams();
            const qs = new URLSearchParams();
            qs.set('reportType', params.reportType || 'Monthly');
            if (this.isWeekly) {
                qs.set('weekStartIso', params.weekStartIso || this.selectedWeekDate);
            } else if (this.isDateRange) {
                qs.set('startDate', params.startDateIso || this.selectedRangeStart);
                qs.set('endDate', params.endDateIso || this.selectedRangeEnd);
            } else {
                qs.set('year', String(params.year));
                qs.set('month', String(params.month));
            }
            if (params.ownerId) {
                qs.set('ownerId', params.ownerId);
            }
            // Browser HTML page (no renderAs=pdf) → print dialog → Save as PDF (CSS3 works).
            const url = `/apex/MonthlySalesReportPrint?${qs.toString()}`;
            window.open(url, '_blank');

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Print dialog opening',
                    message: 'In the print dialog, choose Save as PDF. Enable background graphics for the dark theme.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Unable to open print page',
                    message: this.normalizeError(error),
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        } finally {
            this.isDownloading = false;
        }
    }

    mondayOf(dateObj) {
        const d = new Date(dateObj.getFullYear(), dateObj.getMonth(), dateObj.getDate());
        const day = d.getDay(); // 0=Sun..6=Sat
        const diff = day === 0 ? -6 : 1 - day;
        d.setDate(d.getDate() + diff);
        return d;
    }

    toIsoDate(dateObj) {
        const y = dateObj.getFullYear();
        const m = this.pad(dateObj.getMonth() + 1);
        const d = this.pad(dateObj.getDate());
        return `${y}-${m}-${d}`;
    }

    pad(value) {
        const text = String(value || '');
        return text.length === 1 ? `0${text}` : text;
    }

    formatAmount(value) {
        if (value === null || value === undefined || value === '') {
            return '0';
        }
        const num = Number(value);
        if (Number.isNaN(num)) {
            return String(value);
        }
        return num.toLocaleString('en-US');
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
}
