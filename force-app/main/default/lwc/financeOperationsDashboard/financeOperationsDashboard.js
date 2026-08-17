import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import CHART_JS from '@salesforce/resourceUrl/ChartJS';
import getDashboardData from '@salesforce/apex/FinanceOperationsDashboardController.getDashboardData';
import setChequeStatus from '@salesforce/apex/FinanceOperationsDashboardController.setChequeStatus';
import startBulkSoa from '@salesforce/apex/FinanceOperationsDashboardController.startBulkSoa';

/**
 * Invoice & Receipt Operations — Finance Center Tab 4.
 * Daily volumes, receipt method split, the PDC maturity calendar with cheque lifecycle
 * actions, the unallocated work queue, cancellations, the SOA audit log with the bulk
 * generate-and-email action, and the data-quality exceptions panel (the trust anchor —
 * finance believes the dashboard when this panel is visibly at zero).
 */

const MODE_COLORS = {
    'Bank Transfer': '#2a78d6',
    Cheque: '#eda100',
    Cash: '#1baf7a',
    Card: '#4a3aa7',
    'POS Machine': '#e87b34',
    'Online Payment': '#e87ba4',
    Adjustment: '#898781',
    Unspecified: '#c3c2b7'
};
const CHEQUE_CHIP = {
    Received: 'chip chip-blue',
    Deposited: 'chip chip-amber',
    Cleared: 'chip chip-green',
    Bounced: 'chip chip-red',
    Replaced: 'chip'
};
const INK = { secondary: '#52514e', muted: '#898781', grid: '#e1e0d9' };
const CHART_FONT = 'system-ui, -apple-system, "Segoe UI", sans-serif';

export default class FinanceOperationsDashboard extends LightningElement {
    dashboard;
    errorMessage;
    isLoading = true;
    updatedLabel = '';
    isActionBusy = false;
    showBulkModal = false;

    wiredDashboardResult;
    chartJsRequested = false;
    chartJsReady = false;
    charts = {};
    renderedData;

    @wire(getDashboardData)
    wiredDashboard(result) {
        this.wiredDashboardResult = result;
        const { data, error } = result;
        if (data) {
            this.dashboard = data;
            this.errorMessage = undefined;
            this.isLoading = false;
            this.stampUpdated();
        } else if (error) {
            this.errorMessage = this.reduceError(error);
            this.isLoading = false;
        }
    }

    renderedCallback() {
        if (!this.chartJsRequested) {
            this.chartJsRequested = true;
            loadScript(this, CHART_JS)
                .then(() => {
                    this.chartJsReady = true;
                    this.renderCharts();
                })
                .catch(() => {
                    this.errorMessage = 'Failed to load the charting library. Refresh the page and try again.';
                });
        }
        this.renderCharts();
    }

    disconnectedCallback() {
        Object.values(this.charts).forEach((c) => c.destroy());
        this.charts = {};
    }

    // -------------------------------------------------------------- header --

    get currencyDescription() {
        const stamp = this.dashboard && this.dashboard.ratesAsOf
            ? ` · rates as of ${new Intl.DateTimeFormat('en', { day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' }).format(new Date(this.dashboard.ratesAsOf))}`
            : '';
        return `Totals in AED at daily market rates · queue and calendar rows in project currency${stamp}`;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredDashboardResult)
            .then(() => this.stampUpdated())
            .finally(() => {
                this.isLoading = false;
            });
    }

    stampUpdated() {
        this.updatedLabel = `Updated ${new Intl.DateTimeFormat('en', { hour: 'numeric', minute: '2-digit' }).format(new Date())}`;
    }

    get hasError() {
        return Boolean(this.errorMessage);
    }

    // -------------------------------------------------------------- volume --

    get volumeCards() {
        if (!this.dashboard) return [];
        return this.dashboard.volume.map((v) => ({
            ...v,
            fInvoiced: `AED ${compact(v.invoicedAed)}`,
            fCollected: `AED ${compact(v.collectedAed)}`
        }));
    }

    // ----------------------------------------------------- PDC + cheques --

    get pdcUpcoming() {
        return this.decorateCheques(this.dashboard ? this.dashboard.pdcUpcoming : []);
    }

    get bouncedList() {
        return this.decorateCheques(this.dashboard ? this.dashboard.bounced : []);
    }

    get hasPdcUpcoming() {
        return this.pdcUpcoming.length > 0;
    }

    get hasBounced() {
        return this.bouncedList.length > 0;
    }

    decorateCheques(rows) {
        return rows.map((row) => ({
            ...row,
            fAmount: money(row.amount, row.currencyCode),
            dateLabel: dateLabel(row.chequeDate),
            statusClass: CHEQUE_CHIP[row.status] || 'chip',
            actionsDisabled: this.isActionBusy
        }));
    }

    handleChequeStatus(event) {
        const lineId = event.currentTarget.dataset.id;
        const status = event.detail.value;
        this.isActionBusy = true;
        setChequeStatus({ lineId, status })
            .then(() => {
                this.toast('Cheque updated', `Marked "${status}"`, 'success');
                return refreshApex(this.wiredDashboardResult);
            })
            .catch((error) => this.toast('Could not update the cheque', this.reduceError(error), 'error'))
            .finally(() => {
                this.isActionBusy = false;
            });
    }

    // -------------------------------------------------------- unallocated --

    get unallocatedRows() {
        if (!this.dashboard) return [];
        return this.dashboard.unallocated.map((row) => ({
            ...row,
            fReceived: money(row.received, row.currencyCode),
            fUnapplied: money(row.unapplied, row.currencyCode),
            dateLabel: dateLabel(row.paymentDate),
            link: '/' + row.receiptId
        }));
    }

    get hasUnallocated() {
        return this.unallocatedRows.length > 0;
    }

    // ------------------------------------------------------- cancellations --

    get cancelTiles() {
        const d = this.dashboard;
        if (!d) return [];
        return [
            { key: 'inv', label: 'Cancelled Invoices', hero: `${d.cancelledInvoices}`, scope: 'last 90 days', theme: 'tile theme-red' },
            { key: 'rec', label: 'Cancelled Receipts', hero: `${d.cancelledReceipts}`, scope: 'last 90 days', theme: 'tile theme-red' },
            { key: 'appr', label: 'Pending Approvals', hero: `${d.pendingApprovals}`, scope: 'approval requests', theme: 'tile theme-amber' }
        ];
    }

    get cancellationRows() {
        if (!this.dashboard) return [];
        return this.dashboard.cancellations.map((row) => ({
            ...row,
            fAmount: money(row.amount, row.currencyCode),
            whenLabel: dateTimeLabel(row.cancelledOn),
            reasonLabel: row.reason || '—'
        }));
    }

    get hasCancellations() {
        return this.cancellationRows.length > 0;
    }

    // ---------------------------------------------------------------- SOA --

    get soaLogRows() {
        if (!this.dashboard) return [];
        return this.dashboard.soaLog.map((row) => ({
            ...row,
            whenLabel: dateTimeLabel(row.sentOn),
            resultClass: row.isSuccess ? 'chip chip-green' : 'chip chip-red',
            resultShort: row.isSuccess ? 'Sent' : 'Failed'
        }));
    }

    get hasSoaLog() {
        return this.soaLogRows.length > 0;
    }

    get bulkTargetCount() {
        return this.dashboard ? this.dashboard.soaTargets.length : 0;
    }

    get bulkDisabled() {
        return this.isActionBusy || this.bulkTargetCount === 0;
    }

    get bulkButtonLabel() {
        return `Email SOA to all overdue (${this.bulkTargetCount})`;
    }

    get bulkTargetPreview() {
        if (!this.dashboard) return [];
        return this.dashboard.soaTargets.slice(0, 10).map((t) => ({
            ...t,
            label: `${t.accountName || 'Unknown customer'} — ${t.unitName}`
        }));
    }

    get bulkPreviewNote() {
        const extra = this.bulkTargetCount - Math.min(10, this.bulkTargetCount);
        return extra > 0 ? `…and ${extra} more` : '';
    }

    openBulkModal() {
        this.showBulkModal = true;
    }

    closeBulkModal() {
        this.showBulkModal = false;
    }

    confirmBulkSoa() {
        this.isActionBusy = true;
        const oppIds = this.dashboard.soaTargets.map((t) => t.opportunityId);
        startBulkSoa({ opportunityIds: oppIds })
            .then((queued) => {
                this.toast('Bulk SOA queued', `${queued} statements are being generated and emailed one by one — watch the log below.`, 'success');
                this.closeBulkModal();
            })
            .catch((error) => this.toast('Could not start the bulk run', this.reduceError(error), 'error'))
            .finally(() => {
                this.isActionBusy = false;
            });
    }

    // ------------------------------------------------------------------ DQ --

    get dqChecks() {
        if (!this.dashboard) return [];
        return this.dashboard.dqChecks.map((check) => ({
            ...check,
            countClass: check.count === 0 ? 'dq-count dq-zero' : 'dq-count dq-hit',
            hasExamples: check.examples.length > 0,
            exampleText: check.examples.join(' · ')
        }));
    }

    get reconLabel() {
        const d = this.dashboard;
        if (!d) return '';
        return `Engine reconciliation (stored vs derived): ${d.reconDiffCount} differences across ${d.reconUnitsScanned} recently-touched units`;
    }

    get reconClass() {
        return this.dashboard && this.dashboard.reconDiffCount === 0 ? 'dq-count dq-zero' : 'dq-count dq-hit';
    }

    get reconCount() {
        return this.dashboard ? this.dashboard.reconDiffCount : 0;
    }

    // --------------------------------------------------------------- charts --

    renderCharts() {
        if (!this.chartJsReady || !this.dashboard) return;
        if (!this.template.querySelector('canvas.method-canvas')) return; // template not up yet
        if (this.renderedData === this.dashboard) return;
        this.renderedData = this.dashboard;
        this.renderMethodSplit();
        this.renderPdcWeeks();
    }

    renderMethodSplit() {
        const canvas = this.template.querySelector('canvas.method-canvas');
        const slices = this.dashboard.methodSplit;
        this.destroyChart('method');
        this.charts.method = new window.Chart(canvas, {
            type: 'doughnut',
            data: {
                labels: slices.map((s) => s.mode),
                datasets: [{
                    data: slices.map((s) => s.amountAed),
                    backgroundColor: slices.map((s) => MODE_COLORS[s.mode] || '#c3c2b7'),
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '60%',
                plugins: {
                    legend: { position: 'bottom', labels: { color: INK.secondary, font: { family: CHART_FONT }, boxWidth: 12 } },
                    tooltip: { callbacks: { label: (ctx) => `${ctx.label}: AED ${compact(ctx.raw)}` } }
                }
            }
        });
    }

    renderPdcWeeks() {
        const canvas = this.template.querySelector('canvas.pdc-canvas');
        if (!canvas) return;
        const weeks = this.dashboard.pdcWeeks;
        this.destroyChart('pdc');
        this.charts.pdc = new window.Chart(canvas, {
            type: 'bar',
            data: {
                labels: weeks.map((w) => w.label),
                datasets: [{
                    data: weeks.map((w) => w.amountAed),
                    backgroundColor: '#eda100',
                    borderRadius: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: {
                            label: (ctx) => `${weeks[ctx.dataIndex].cheques} cheque(s) · AED ${compact(ctx.raw)}`
                        }
                    }
                },
                scales: {
                    x: { grid: { display: false }, ticks: { color: INK.muted, font: { family: CHART_FONT }, maxRotation: 45 } },
                    y: { grid: { color: INK.grid }, ticks: { color: INK.muted, font: { family: CHART_FONT }, callback: (v) => compact(v) } }
                }
            }
        });
    }

    destroyChart(key) {
        if (this.charts[key]) {
            this.charts[key].destroy();
            delete this.charts[key];
        }
    }

    // -------------------------------------------------------------- helpers --

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (error && error.body) {
            if (Array.isArray(error.body)) return error.body.map((e) => e.message).join(', ');
            if (error.body.message) return error.body.message;
        }
        return (error && error.message) || 'Unknown error';
    }
}

// ---------------------------------------------------------- module helpers --

function compact(value) {
    return new Intl.NumberFormat('en', { notation: 'compact', maximumFractionDigits: 1 }).format(value || 0);
}

function money(value, ccy) {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: ccy || 'AED', maximumFractionDigits: 0 }).format(value || 0);
}

function dateLabel(value) {
    return value ? new Intl.DateTimeFormat('en', { day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(value)) : '—';
}

function dateTimeLabel(value) {
    return value
        ? new Intl.DateTimeFormat('en', { day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' }).format(new Date(value))
        : '—';
}
