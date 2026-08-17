import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import CHART_JS from '@salesforce/resourceUrl/ChartJS';
import getDashboardData from '@salesforce/apex/FinanceCollectionsDashboardController.getDashboardData';
import createFollowUpTask from '@salesforce/apex/FinanceCollectionsDashboardController.createFollowUpTask';
import setCollectionFlag from '@salesforce/apex/FinanceCollectionsDashboardController.setCollectionFlag';
import sendSOAEmail from '@salesforce/apex/SOAEmailService.sendSOAEmail';

/**
 * Collections & Aging — Finance Center Tab 2. The actionable one: the overdue and defaulted
 * lists carry inline actions (follow-up task, SOA email via the existing SOAEmailService,
 * legal/termination flag). Aging buckets come from Aging_Bucket__mdt — never hardcoded here.
 * Cross-project charts and the customer matrix are AED; the action lists show each unit's
 * own project currency.
 */

const BUCKET_COLORS = ['#9db8d9', '#f2c14e', '#eda100', '#e87b34', '#e34948', '#8f1f1f'];
const HEALTH_CHIP = {
    'Fully Paid': 'chip chip-green',
    'On Track': 'chip chip-blue',
    Overdue: 'chip chip-amber',
    Defaulted: 'chip chip-red'
};
const INK = { secondary: '#52514e', muted: '#898781', grid: '#e1e0d9' };
const CHART_FONT = 'system-ui, -apple-system, "Segoe UI", sans-serif';

export default class FinanceCollectionsDashboard extends LightningElement {
    dashboard;
    errorMessage;
    isLoading = true;
    updatedLabel = '';

    // action modal state
    modal; // { type: 'task'|'soa', row }
    taskNote = '';
    isActionBusy = false;

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
        return `Charts and customer matrix in AED at daily market rates · action lists in each project's own currency${stamp}`;
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
            { key: 'overdue', label: 'Total Overdue', theme: 'tile theme-red', hero: `AED ${compact(d.totalOverdueAed)}`, scope: 'open invoices past due' },
            { key: 'open', label: 'Total Open Invoices', theme: 'tile theme-blue', hero: `AED ${compact(d.totalOpenAed)}`, scope: 'incl. not yet due' },
            { key: 'customers', label: 'Overdue Customers', theme: 'tile theme-amber', hero: `${d.overdueCustomers}`, scope: 'with past-due invoices' },
            { key: 'defaulted', label: 'Defaulted Units', theme: 'tile theme-red', hero: `${d.defaultedUnits}`, scope: '90+ days & >2 missed' },
            { key: 'flagged', label: 'Flagged Units', theme: 'tile', hero: `${d.flaggedUnits}`, scope: 'legal / termination notice' }
        ];
    }

    // ------------------------------------------------------ customer matrix --

    get matrixHeaders() {
        return this.dashboard ? this.dashboard.bucketLabels : [];
    }

    get customerRows() {
        if (!this.dashboard) return [];
        return this.dashboard.customers.map((c) => ({
            ...c,
            cells: c.bucketsAed.map((v, i) => ({ key: `${c.accountId}-${i}`, label: v > 0 ? compact(v) : '—', cssClass: v > 0 ? 'num cell-filled' : 'num cell-zero' })),
            fTotal: compact(c.totalAed),
            oldestLabel: c.oldestDays > 0 ? `${c.oldestDays}d` : '—'
        }));
    }

    get customersNote() {
        const n = this.dashboard ? this.dashboard.customersNotShown : 0;
        return n > 0 ? `+ ${n} more customers not shown — use the AR aging report for the full list` : '';
    }

    get hasCustomers() {
        return this.dashboard && this.dashboard.customers.length > 0;
    }

    // -------------------------------------------------------- action lists --

    get overdueRows() {
        return this.decorateRows(this.dashboard ? this.dashboard.overdueRows : []);
    }

    get defaultedRows() {
        return this.decorateRows(this.dashboard ? this.dashboard.defaultedRows : []);
    }

    get hasOverdueRows() {
        return this.overdueRows.length > 0;
    }

    get hasDefaultedRows() {
        return this.defaultedRows.length > 0;
    }

    decorateRows(rows) {
        return rows.map((r) => ({
            ...r,
            customerLabel: r.accountName || '—',
            fDue: money(r.due, r.currencyCode),
            daysLabel: r.overdueDays > 0 ? `${r.overdueDays}d` : '—',
            healthClass: HEALTH_CHIP[r.health] || 'chip',
            flagLabel: r.flag ? `${r.flag} · ${r.flagDate || ''}` : '',
            emailDisabled: !r.opportunityId || this.isActionBusy,
            actionsDisabled: this.isActionBusy
        }));
    }

    // ---- follow-up task ----

    openTaskModal(event) {
        this.modal = { type: 'task', row: this.findRow(event.currentTarget.dataset.id) };
        this.taskNote = '';
    }

    handleNoteChange(event) {
        this.taskNote = event.target.value;
    }

    saveTask() {
        const row = this.modal.row;
        this.isActionBusy = true;
        createFollowUpTask({ accountId: row.accountId, unitName: row.unitName, note: this.taskNote })
            .then(() => {
                this.toast('Follow-up logged', `Task created for ${row.customerLabel || row.unitName}`, 'success');
                this.closeModal();
            })
            .catch((error) => this.toast('Could not create the task', this.reduceError(error), 'error'))
            .finally(() => {
                this.isActionBusy = false;
            });
    }

    // ---- SOA email ----

    openSoaModal(event) {
        this.modal = { type: 'soa', row: this.findRow(event.currentTarget.dataset.id) };
    }

    sendSoa() {
        const row = this.modal.row;
        this.isActionBusy = true;
        sendSOAEmail({ opportunityId: row.opportunityId })
            .then((result) => {
                const ok = result && result.startsWith('Success');
                this.toast(ok ? 'SOA email sent' : 'SOA email failed', result, ok ? 'success' : 'error');
                if (ok) this.closeModal();
            })
            .catch((error) => this.toast('SOA email failed', this.reduceError(error), 'error'))
            .finally(() => {
                this.isActionBusy = false;
            });
    }

    // ---- collection flag ----

    handleFlagSelect(event) {
        const unitId = event.currentTarget.dataset.id;
        const value = event.detail.value;
        const flag = value === 'CLEAR' ? '' : value;
        this.isActionBusy = true;
        setCollectionFlag({ unitId, flag })
            .then(() => {
                this.toast('Flag updated', flag ? `Marked "${flag}"` : 'Flag cleared', 'success');
                return refreshApex(this.wiredDashboardResult);
            })
            .catch((error) => this.toast('Could not update the flag', this.reduceError(error), 'error'))
            .finally(() => {
                this.isActionBusy = false;
            });
    }

    // ---- modal plumbing ----

    findRow(unitId) {
        const all = [...(this.dashboard.overdueRows || []), ...(this.dashboard.defaultedRows || [])];
        const r = all.find((row) => row.unitId === unitId);
        return { ...r, customerLabel: r.accountName || r.unitName, fDue: money(r.due, r.currencyCode) };
    }

    closeModal() {
        this.modal = undefined;
        this.taskNote = '';
    }

    get isTaskModal() {
        return this.modal && this.modal.type === 'task';
    }

    get isSoaModal() {
        return this.modal && this.modal.type === 'soa';
    }

    get modalRow() {
        return this.modal ? this.modal.row : {};
    }

    // --------------------------------------------------------------- charts --

    renderCharts() {
        if (!this.chartJsReady || !this.dashboard) return;
        if (!this.template.querySelector('canvas.aging-canvas')) return; // template not up yet
        if (this.renderedData === this.dashboard) return;
        this.renderedData = this.dashboard;
        this.renderAgingByProject();
        this.renderAgingTrend();
        this.renderDsoTrend();
    }

    renderAgingByProject() {
        const canvas = this.template.querySelector('canvas.aging-canvas');
        const d = this.dashboard;
        this.destroyChart('aging');
        this.charts.aging = new window.Chart(canvas, {
            type: 'bar',
            data: {
                labels: d.projectAging.map((p) => p.name),
                datasets: d.bucketLabels.map((label, i) => ({
                    label,
                    data: d.projectAging.map((p) => p.bucketsAed[i]),
                    backgroundColor: BUCKET_COLORS[i % BUCKET_COLORS.length],
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
                    x: { stacked: true, grid: { display: false }, ticks: { color: INK.secondary, font: { family: CHART_FONT } } },
                    y: { stacked: true, grid: { color: INK.grid }, ticks: { color: INK.muted, font: { family: CHART_FONT }, callback: (v) => compact(v) } }
                }
            }
        });
    }

    renderAgingTrend() {
        const canvas = this.template.querySelector('canvas.trend-canvas');
        if (!canvas) return;
        const d = this.dashboard;
        this.destroyChart('trend');
        this.charts.trend = new window.Chart(canvas, {
            type: 'line',
            data: {
                labels: d.trend.map((t) => t.snapshotDate),
                datasets: d.bucketLabels.slice(0, 6).map((label, i) => ({
                    label,
                    data: d.trend.map((t) => t.agingAed[i]),
                    borderColor: BUCKET_COLORS[i % BUCKET_COLORS.length],
                    backgroundColor: BUCKET_COLORS[i % BUCKET_COLORS.length] + '55',
                    fill: true,
                    pointRadius: 2,
                    tension: 0.25
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
                    x: { grid: { display: false }, ticks: { color: INK.muted, font: { family: CHART_FONT } } },
                    y: { stacked: true, grid: { color: INK.grid }, ticks: { color: INK.muted, font: { family: CHART_FONT }, callback: (v) => compact(v) } }
                }
            }
        });
    }

    renderDsoTrend() {
        const canvas = this.template.querySelector('canvas.dso-canvas');
        if (!canvas) return;
        const d = this.dashboard;
        this.destroyChart('dso');
        this.charts.dso = new window.Chart(canvas, {
            type: 'line',
            data: {
                labels: d.trend.map((t) => t.snapshotDate),
                datasets: [
                    {
                        label: 'DSO (days)',
                        data: d.trend.map((t) => t.dso),
                        borderColor: '#4a3aa7',
                        backgroundColor: '#4a3aa7',
                        yAxisID: 'y',
                        pointRadius: 2,
                        tension: 0.25
                    },
                    {
                        label: 'Collection Efficiency (%)',
                        data: d.trend.map((t) => t.efficiencyPct),
                        borderColor: '#1baf7a',
                        backgroundColor: '#1baf7a',
                        yAxisID: 'y1',
                        pointRadius: 2,
                        tension: 0.25
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { position: 'bottom', labels: { color: INK.secondary, font: { family: CHART_FONT }, boxWidth: 12 } } },
                scales: {
                    x: { grid: { display: false }, ticks: { color: INK.muted, font: { family: CHART_FONT } } },
                    y: { position: 'left', grid: { color: INK.grid }, title: { display: true, text: 'days', color: INK.muted }, ticks: { color: INK.muted, font: { family: CHART_FONT } } },
                    y1: { position: 'right', min: 0, max: 100, grid: { drawOnChartArea: false }, title: { display: true, text: '%', color: INK.muted }, ticks: { color: INK.muted, font: { family: CHART_FONT } } }
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
