import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import CHART_JS from '@salesforce/resourceUrl/ChartJS';
import getDashboardData from '@salesforce/apex/FinanceCashflowDashboardController.getDashboardData';
import updateSlippageReason from '@salesforce/apex/FinanceCashflowDashboardController.updateSlippageReason';

/**
 * Cash Flow & Forecast — Finance Center Tab 3.
 * Forecast bars come from Finance_Forecast_Line__c (frozen month-start baselines for past
 * months, live lines for current/future); the actual line comes from receipts. Portfolio
 * scope and the escrow split are AED; per-project scopes and variance rows stay native.
 */

const INK = { secondary: '#52514e', muted: '#898781', grid: '#e1e0d9' };
const CHART_FONT = 'system-ui, -apple-system, "Segoe UI", sans-serif';
const ESCROW_META = [
    { key: 'escrowAed', label: 'Escrow', color: '#2a78d6' },
    { key: 'operatingAed', label: 'Operating', color: '#1baf7a' },
    { key: 'cashAed', label: 'Cash', color: '#eda100' },
    { key: 'otherAed', label: 'Unclassified', color: '#c3c2b7' }
];

export default class FinanceCashflowDashboard extends LightningElement {
    dashboard;
    errorMessage;
    isLoading = true;
    updatedLabel = '';
    forecastScope = 'portfolio';
    scenarioPct = 25;

    // slippage modal
    modalRow;
    modalReason = '';
    isSaving = false;

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
        return `Portfolio and escrow figures in AED at daily market rates · project scopes and variance in project currency${stamp}`;
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

    // --------------------------------------------------------------- tiles --

    get tiles() {
        const d = this.dashboard;
        if (!d) return [];
        return [
            { key: 'expected', label: 'Expected This Month', theme: 'tile theme-blue', hero: `AED ${compact(d.currentMonthExpectedAed)}`, scope: 'scheduled instalments' },
            { key: 'received', label: 'Received This Month', theme: 'tile theme-green', hero: `AED ${compact(d.currentMonthActualAed)}`, scope: 'reconciled receipts' },
            { key: 'next3', label: 'Scheduled — 3 Months', theme: 'tile', hero: `AED ${compact(d.next3ExpectedAed)}`, scope: 'this + next 2 months' },
            { key: 'backlog', label: 'Overdue Backlog', theme: 'tile theme-amber', hero: `AED ${compact(d.overdueAed)}`, scope: 'collectable on top of schedule' }
        ];
    }

    // ------------------------------------------------------------ scenario --

    handleScenarioChange(event) {
        this.scenarioPct = Number(event.detail.value);
    }

    get scenarioBase() {
        return this.dashboard ? `AED ${compact(this.dashboard.nextMonthExpectedAed)}` : '';
    }

    get scenarioRecovered() {
        if (!this.dashboard) return '';
        return `AED ${compact((this.dashboard.overdueAed * this.scenarioPct) / 100)}`;
    }

    get scenarioTotal() {
        if (!this.dashboard) return '';
        const total = this.dashboard.nextMonthExpectedAed + (this.dashboard.overdueAed * this.scenarioPct) / 100;
        return `AED ${compact(total)}`;
    }

    get scenarioLabel() {
        return `If ${this.scenarioPct}% of the overdue backlog is collected within 30 days`;
    }

    // ------------------------------------------------------ forecast scope --

    get forecastOptions() {
        const options = [{ label: 'Portfolio (AED)', value: 'portfolio' }];
        (this.dashboard ? this.dashboard.projects : []).forEach((p) => {
            options.push({ label: `${p.name} (${p.currencyCode})`, value: p.projectId });
        });
        return options;
    }

    handleForecastScope(event) {
        this.forecastScope = event.detail.value;
        this.renderForecast();
    }

    // ------------------------------------------------------------ variance --

    get varianceRows() {
        if (!this.dashboard) return [];
        return this.dashboard.variance.map((row) => ({
            ...row,
            monthLabel: monthLabel(row.monthStart),
            fExpected: money(row.expected, row.currencyCode),
            fActual: money(row.actual, row.currencyCode),
            fVariance: money(row.varianceAmount, row.currencyCode),
            pctLabel: `${row.variancePct}%`,
            varianceClass: row.varianceAmount < 0 ? 'num variance-neg' : 'num variance-pos',
            reasonLabel: row.slippageReason || '—'
        }));
    }

    get hasVariance() {
        return this.varianceRows.length > 0;
    }

    openReasonModal(event) {
        const lineId = event.currentTarget.dataset.id;
        const row = this.varianceRows.find((r) => r.lineId === lineId);
        this.modalRow = row;
        this.modalReason = row.slippageReason || '';
    }

    handleReasonChange(event) {
        this.modalReason = event.target.value;
    }

    saveReason() {
        this.isSaving = true;
        updateSlippageReason({ lineId: this.modalRow.lineId, reason: this.modalReason })
            .then(() => {
                this.toast('Saved', 'Slippage reason updated', 'success');
                this.closeModal();
                return refreshApex(this.wiredDashboardResult);
            })
            .catch((error) => this.toast('Could not save', this.reduceError(error), 'error'))
            .finally(() => {
                this.isSaving = false;
            });
    }

    closeModal() {
        this.modalRow = undefined;
        this.modalReason = '';
    }

    // --------------------------------------------------------------- charts --

    renderCharts() {
        if (!this.chartJsReady || !this.dashboard) return;
        if (!this.template.querySelector('canvas.forecast-canvas')) return; // template not up yet
        if (this.renderedData === this.dashboard) return;
        this.renderedData = this.dashboard;
        this.renderForecast();
        this.renderEscrow();
    }

    renderForecast() {
        if (!this.chartJsReady || !this.dashboard) return;
        const canvas = this.template.querySelector('canvas.forecast-canvas');
        if (!canvas) return;
        let months, ccy;
        if (this.forecastScope === 'portfolio') {
            months = this.dashboard.portfolio;
            ccy = 'AED';
        } else {
            const p = this.dashboard.projects.find((row) => row.projectId === this.forecastScope);
            if (!p) return;
            months = p.months;
            ccy = p.currencyCode;
        }
        this.destroyChart('forecast');
        this.charts.forecast = new window.Chart(canvas, {
            data: {
                labels: months.map((m) => monthLabel(m.monthStart)),
                datasets: [
                    {
                        type: 'bar',
                        label: 'Forecast',
                        data: months.map((m) => m.expected),
                        backgroundColor: '#7fa8d9',
                        borderRadius: 3,
                        order: 2
                    },
                    {
                        type: 'line',
                        label: 'Actual',
                        data: months.map((m) => (m.hasActual ? m.actual : null)),
                        borderColor: '#1baf7a',
                        backgroundColor: '#1baf7a',
                        pointRadius: 3,
                        tension: 0.25,
                        order: 1
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { position: 'bottom', labels: { color: INK.secondary, font: { family: CHART_FONT }, boxWidth: 12 } },
                    tooltip: { callbacks: { label: (ctx) => `${ctx.dataset.label}: ${compact(ctx.raw)} ${ccy}` } }
                },
                scales: {
                    x: { grid: { display: false }, ticks: { color: INK.muted, font: { family: CHART_FONT }, maxRotation: 60 } },
                    y: { grid: { color: INK.grid }, ticks: { color: INK.muted, font: { family: CHART_FONT }, callback: (v) => compact(v) } }
                }
            }
        });
    }

    renderEscrow() {
        const canvas = this.template.querySelector('canvas.escrow-canvas');
        if (!canvas) return;
        const d = this.dashboard;
        this.destroyChart('escrow');
        this.charts.escrow = new window.Chart(canvas, {
            type: 'bar',
            data: {
                labels: d.escrow.map((m) => m.monthKey),
                datasets: ESCROW_META.map((meta) => ({
                    label: meta.label,
                    data: d.escrow.map((m) => m[meta.key]),
                    backgroundColor: meta.color,
                    borderRadius: 3
                }))
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { position: 'bottom', labels: { color: INK.secondary, font: { family: CHART_FONT }, boxWidth: 12 } },
                    tooltip: { callbacks: { label: (ctx) => `${ctx.dataset.label}: AED ${compact(ctx.raw)}` } }
                },
                scales: {
                    x: { stacked: true, grid: { display: false }, ticks: { color: INK.muted, font: { family: CHART_FONT } } },
                    y: { stacked: true, grid: { color: INK.grid }, ticks: { color: INK.muted, font: { family: CHART_FONT }, callback: (v) => compact(v) } }
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

function monthLabel(dateValue) {
    return new Intl.DateTimeFormat('en', { month: 'short', year: '2-digit' }).format(new Date(dateValue));
}
