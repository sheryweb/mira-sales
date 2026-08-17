import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { loadScript } from 'lightning/platformResourceLoader';
import CHART_JS from '@salesforce/resourceUrl/ChartJS';
import getDashboardData from '@salesforce/apex/FinancePortfolioDashboardController.getDashboardData';
import getUnitRows from '@salesforce/apex/FinancePortfolioDashboardController.getUnitRows';

/**
 * Portfolio Position — Finance Center Tab 1.
 * Per-project rows, unit rows and the heatmap are in each project's OWN currency;
 * only the KPI tiles and cross-project charts are AED (converted server-side at read time).
 */

const HEALTH_META = [
    { key: 'unitsFullyPaid', label: 'Fully Paid', color: '#1baf7a', cellClass: 'cell-fully' },
    { key: 'unitsOnTrack', label: 'On Track', color: '#2a78d6', cellClass: 'cell-track' },
    { key: 'unitsOverdue', label: 'Overdue', color: '#eda100', cellClass: 'cell-overdue' },
    { key: 'unitsDefaulted', label: 'Defaulted', color: '#e34948', cellClass: 'cell-defaulted' }
];
const HEALTH_CELL_CLASS = {
    'Fully Paid': 'cell-fully',
    'On Track': 'cell-track',
    Overdue: 'cell-overdue',
    Defaulted: 'cell-defaulted'
};
const WATERFALL_COLORS = ['#2a78d6', '#7fa8d9', '#1baf7a', '#eda100', '#c3c2b7'];
const INK = { primary: '#0b0b0b', secondary: '#52514e', muted: '#898781', grid: '#e1e0d9' };
const CHART_FONT = 'system-ui, -apple-system, "Segoe UI", sans-serif';

export default class FinancePortfolioDashboard extends LightningElement {
    dashboard;
    errorMessage;
    isLoading = true;
    updatedLabel = '';
    waterfallScope = 'portfolio';
    isExporting = false;
    @track expandedByProject = {};

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
            this.renderCharts();
        } else if (error) {
            this.errorMessage = this.reduceError(error);
            this.isLoading = false;
        }
    }

    // ------------------------------------------------------------ lifecycle --

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
        this.destroyCharts();
    }

    // -------------------------------------------------------------- header --

    get currencyDescription() {
        const stamp = this.dashboard && this.dashboard.ratesAsOf
            ? ` · rates as of ${new Intl.DateTimeFormat('en', {
                  day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit'
              }).format(new Date(this.dashboard.ratesAsOf))}`
            : '';
        return `Project figures in each project's own currency · portfolio tiles in AED at daily market rates${stamp}`;
    }

    handleRefresh() {
        this.isLoading = true;
        this.expandedByProject = {}; // expanded unit rows would be stale
        refreshApex(this.wiredDashboardResult)
            .then(() => this.stampUpdated())
            .finally(() => {
                this.isLoading = false;
            });
    }

    stampUpdated() {
        this.updatedLabel = `Updated ${new Intl.DateTimeFormat('en', {
            hour: 'numeric', minute: '2-digit'
        }).format(new Date())}`;
    }

    // --------------------------------------------------------------- tiles --

    get tiles() {
        const d = this.dashboard;
        if (!d) return [];
        return [
            { key: 'contracted', label: 'Total Contracted', theme: 'tile theme-blue', hero: this.compactAed(d.contractedAed), full: this.fullAed(d.contractedAed), scope: `${d.unitsTotal} units` },
            { key: 'invoiced', label: 'Invoiced to Date', theme: 'tile', hero: this.compactAed(d.invoicedAed), full: this.fullAed(d.invoicedAed), scope: 'non-cancelled invoices' },
            { key: 'received', label: 'Received to Date', theme: 'tile theme-green', hero: this.compactAed(d.receivedAed), full: this.fullAed(d.receivedAed), scope: 'reconciled receipts' },
            { key: 'due', label: 'Outstanding — Due', theme: 'tile theme-amber', hero: this.compactAed(d.dueAed), full: this.fullAed(d.dueAed), scope: 'instalments due to date' },
            { key: 'notYetDue', label: 'Outstanding — Not Yet Due', theme: 'tile', hero: this.compactAed(d.notYetDueAed), full: this.fullAed(d.notYetDueAed), scope: 'future instalments' },
            { key: 'overdue', label: 'Overdue Invoices', theme: 'tile theme-red', hero: this.compactAed(d.overdueInvoiceAed), full: this.fullAed(d.overdueInvoiceAed), scope: 'raised & past due date' },
            { key: 'efficiency', label: 'Collection Efficiency', theme: 'tile theme-green', hero: `${d.efficiencyPct}%`, full: 'received ÷ (received + due to date)', scope: 'to date' },
            { key: 'avgDays', label: 'Avg Days to Collect', theme: 'tile', hero: `${d.avgDaysToCollect}d`, full: 'amount-weighted lag from instalment date to payment date', scope: 'engine allocation ledger' },
            { key: 'unallocated', label: 'Unallocated Receipts', theme: 'tile theme-amber', hero: this.compactAed(d.unallocatedAed), full: this.fullAed(d.unallocatedAed), scope: 'not applied to any invoice' }
        ];
    }

    // ------------------------------------------------------ waterfall scope --

    get waterfallOptions() {
        const options = [{ label: 'Portfolio (AED)', value: 'portfolio' }];
        (this.dashboard ? this.dashboard.projects : []).forEach((p) => {
            options.push({ label: `${p.name} (${p.currencyCode})`, value: p.projectId });
        });
        return options;
    }

    handleWaterfallScope(event) {
        this.waterfallScope = event.detail.value;
        this.renderWaterfall();
    }

    // ------------------------------------------------------- project table --

    get hasProjects() {
        return this.dashboard && this.dashboard.projects.length > 0;
    }

    get projectTableRows() {
        if (!this.dashboard) return [];
        return this.dashboard.projects.map((p) => {
            const state = this.expandedByProject[p.projectId] || {};
            return {
                ...p,
                fContracted: this.money(p.contracted, p.currencyCode),
                fInvoiced: this.money(p.invoiced, p.currencyCode),
                fReceived: this.money(p.received, p.currencyCode),
                fRemaining: this.money(p.remaining, p.currencyCode),
                fOverdue: this.money(p.overdueInvoice, p.currencyCode),
                collectedLabel: `${p.collectedPct}%`,
                barStyle: `width:${Math.min(100, Math.max(0, p.collectedPct))}%`,
                expanded: Boolean(state.rows || state.loading || state.error),
                chevron: state.rows || state.loading ? '▾' : '▸',
                unitsLoading: Boolean(state.loading),
                unitsError: state.error,
                loadingKey: `${p.projectId}-loading`,
                errorKey: `${p.projectId}-error`,
                unitRows: (state.rows || []).map((u) => ({
                    ...u,
                    fTotal: this.money(u.total, p.currencyCode),
                    fReceived: this.money(u.received, p.currencyCode),
                    fDue: this.money(u.due, p.currencyCode),
                    fNotYetDue: this.money(u.notYetDue, p.currencyCode),
                    fRemaining: this.money(u.remaining, p.currencyCode),
                    paidLabel: `${u.paidPct}%`,
                    overdueLabel: u.overdueDays > 0 ? `${u.overdueDays}d` : '—',
                    healthClass: `health-chip ${HEALTH_CELL_CLASS[u.health] || 'cell-none'}`,
                    healthLabel: u.health || 'No plan'
                }))
            };
        });
    }

    toggleProject(event) {
        const projectId = event.currentTarget.dataset.id;
        const current = this.expandedByProject[projectId];
        if (current) {
            const next = { ...this.expandedByProject };
            delete next[projectId];
            this.expandedByProject = next;
            return;
        }
        this.expandedByProject = { ...this.expandedByProject, [projectId]: { loading: true } };
        getUnitRows({ projectId })
            .then((rows) => {
                if (this.expandedByProject[projectId]) {
                    this.expandedByProject = { ...this.expandedByProject, [projectId]: { rows } };
                }
            })
            .catch((error) => {
                if (this.expandedByProject[projectId]) {
                    this.expandedByProject = {
                        ...this.expandedByProject,
                        [projectId]: { error: this.reduceError(error) }
                    };
                }
            });
    }

    // ---------------------------------------------------------- CSV export --

    handleExport() {
        if (!this.dashboard || this.isExporting) return;
        this.isExporting = true;
        const projects = this.dashboard.projects;
        Promise.all(projects.map((p) => getUnitRows({ projectId: p.projectId })))
            .then((unitLists) => {
                const lines = [csvRow([
                    'Level', 'Project', 'Unit', 'Status', 'Currency', 'Total', 'Invoiced',
                    'Received', 'Remaining', 'Due', 'Not Yet Due', 'Overdue Invoices',
                    'Unallocated', '% Collected', 'Overdue Days', 'Missed Instalments', 'Health'
                ])];
                projects.forEach((p, i) => {
                    lines.push(csvRow([
                        'PROJECT', p.name, '', '', p.currencyCode, p.contracted, p.invoiced,
                        p.received, p.remaining, p.due, p.notYetDue, p.overdueInvoice,
                        p.unallocated, p.collectedPct, '', '', ''
                    ]));
                    unitLists[i].forEach((u) => {
                        lines.push(csvRow([
                            'UNIT', p.name, u.name, u.status, p.currencyCode, u.total, '',
                            u.received, u.remaining, u.due, u.notYetDue, '', '',
                            u.paidPct, u.overdueDays, u.missedInstalments, u.health || ''
                        ]));
                    });
                });
                const stamp = new Date().toISOString().slice(0, 10);
                downloadCsv(lines.join('\n'), `portfolio-position-${stamp}.csv`);
            })
            .catch((error) => {
                this.errorMessage = this.reduceError(error);
            })
            .finally(() => {
                this.isExporting = false;
            });
    }

    // -------------------------------------------------------------- heatmap --

    get heatmapProjects() {
        if (!this.dashboard) return [];
        const byProject = new Map();
        this.dashboard.heatmap.forEach((cell) => {
            if (!byProject.has(cell.projectId)) {
                byProject.set(cell.projectId, { projectId: cell.projectId, projectName: cell.projectName, towers: new Map() });
            }
            const proj = byProject.get(cell.projectId);
            if (!proj.towers.has(cell.tower)) {
                proj.towers.set(cell.tower, []);
            }
            proj.towers.get(cell.tower).push(cell);
        });
        return Array.from(byProject.values()).map((proj) => ({
            projectId: proj.projectId,
            projectName: proj.projectName,
            towers: Array.from(proj.towers.entries())
                .sort((a, b) => a[0].localeCompare(b[0]))
                .map(([tower, cells]) => ({
                    key: `${proj.projectId}-${tower}`,
                    label: tower === '—' ? 'No tower' : `Tower ${tower.replace(/^Tower /, '')}`,
                    cells: cells
                        .slice()
                        .sort((a, b) => b.floorSort - a.floorSort || a.unitName.localeCompare(b.unitName))
                        .map((cell) => ({
                            unitId: cell.unitId,
                            cssClass: `heat-cell ${HEALTH_CELL_CLASS[cell.health] || 'cell-none'}`,
                            title: heatTitle(cell)
                        }))
                }))
        }));
    }

    // --------------------------------------------------------------- charts --

    renderCharts() {
        if (!this.chartJsReady || !this.dashboard) return;
        if (this.renderedData === this.dashboard) return;
        this.renderedData = this.dashboard;
        this.renderWaterfall();
        this.renderHealthChart();
        this.renderTopOutstanding();
    }

    renderWaterfall() {
        if (!this.chartJsReady || !this.dashboard) return;
        const canvas = this.template.querySelector('canvas.waterfall-canvas');
        if (!canvas) return;
        let contracted, invoiced, received, due, notYetDue, ccy;
        if (this.waterfallScope === 'portfolio') {
            const d = this.dashboard;
            contracted = d.contractedAed; invoiced = d.invoicedAed; received = d.receivedAed;
            due = d.dueAed; notYetDue = d.notYetDueAed; ccy = 'AED';
        } else {
            const p = this.dashboard.projects.find((row) => row.projectId === this.waterfallScope);
            if (!p) return;
            contracted = p.contracted; invoiced = p.invoiced; received = p.received;
            due = p.due; notYetDue = p.notYetDue; ccy = p.currencyCode;
        }
        this.destroyChart('waterfall');
        this.charts.waterfall = new window.Chart(canvas, {
            type: 'bar',
            data: {
                labels: ['Contracted', 'Invoiced', 'Received', 'Due', 'Future Instalments'],
                datasets: [{
                    data: [
                        [0, contracted],
                        [0, invoiced],
                        [0, received],
                        [received, received + due],
                        [received + due, received + due + notYetDue]
                    ],
                    backgroundColor: WATERFALL_COLORS,
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
                            label: (ctx) => {
                                const [from, to] = ctx.raw;
                                return `${compactNumber(to - from)} ${ccy}`;
                            }
                        }
                    }
                },
                scales: {
                    x: { grid: { display: false }, ticks: { color: INK.secondary, font: { family: CHART_FONT } } },
                    y: { grid: { color: INK.grid }, ticks: { color: INK.muted, font: { family: CHART_FONT }, callback: (v) => compactNumber(v) } }
                }
            }
        });
    }

    renderHealthChart() {
        const canvas = this.template.querySelector('canvas.health-canvas');
        if (!canvas) return;
        const projects = this.dashboard.projects;
        this.destroyChart('health');
        this.charts.health = new window.Chart(canvas, {
            type: 'bar',
            data: {
                labels: projects.map((p) => p.name),
                datasets: HEALTH_META.map((meta) => ({
                    label: meta.label,
                    data: projects.map((p) => p[meta.key]),
                    backgroundColor: meta.color,
                    borderRadius: 3
                }))
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { position: 'bottom', labels: { color: INK.secondary, font: { family: CHART_FONT }, boxWidth: 12 } }
                },
                scales: {
                    x: { stacked: true, grid: { display: false }, ticks: { color: INK.secondary, font: { family: CHART_FONT } } },
                    y: { stacked: true, grid: { color: INK.grid }, ticks: { color: INK.muted, precision: 0, font: { family: CHART_FONT } } }
                }
            }
        });
    }

    renderTopOutstanding() {
        const canvas = this.template.querySelector('canvas.top-canvas');
        if (!canvas) return;
        const top = this.dashboard.projects.slice(0, 10); // already sorted by outstanding desc
        this.destroyChart('top');
        this.charts.top = new window.Chart(canvas, {
            type: 'bar',
            data: {
                labels: top.map((p) => p.name),
                datasets: [{
                    data: top.map((p) => p.outstandingAed),
                    backgroundColor: '#4a3aa7',
                    borderRadius: 4
                }]
            },
            options: {
                indexAxis: 'y',
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: { callbacks: { label: (ctx) => `AED ${compactNumber(ctx.raw)}` } }
                },
                scales: {
                    x: { grid: { color: INK.grid }, ticks: { color: INK.muted, font: { family: CHART_FONT }, callback: (v) => compactNumber(v) } },
                    y: { grid: { display: false }, ticks: { color: INK.secondary, font: { family: CHART_FONT } } }
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

    destroyCharts() {
        Object.keys(this.charts).forEach((key) => this.destroyChart(key));
    }

    // -------------------------------------------------------------- helpers --

    get hasError() {
        return Boolean(this.errorMessage);
    }

    money(value, ccy) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency', currency: ccy || 'AED', maximumFractionDigits: 0
        }).format(value || 0);
    }

    compactAed(value) {
        return `AED ${compactNumber(value)}`;
    }

    fullAed(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency', currency: 'AED', maximumFractionDigits: 0
        }).format(value || 0);
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

function compactNumber(value) {
    return new Intl.NumberFormat('en', { notation: 'compact', maximumFractionDigits: 1 }).format(value || 0);
}

function heatTitle(cell) {
    let title = `${cell.unitName} — ${cell.health || 'No plan'}`;
    if (cell.due > 0) title += ` · due ${compactNumber(cell.due)}`;
    if (cell.overdueDays > 0) title += ` · ${cell.overdueDays}d overdue`;
    return title;
}

function csvRow(values) {
    return values
        .map((v) => {
            const s = v === null || v === undefined ? '' : String(v);
            return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
        })
        .join(',');
}

function downloadCsv(content, filename) {
    const blob = new Blob(['﻿' + content], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.click();
    URL.revokeObjectURL(url);
}
