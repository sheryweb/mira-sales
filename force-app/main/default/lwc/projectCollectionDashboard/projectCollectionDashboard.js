import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { loadScript } from 'lightning/platformResourceLoader';
import CHART_JS from '@salesforce/resourceUrl/ChartJS';
import getDashboardData from '@salesforce/apex/ProjectCollectionDashboardController.getDashboardData';

/** All figures are AED; non-AED received amounts are converted server-side. */
const CURRENCY = 'AED';

/**
 * Tile metadata: metric key on DashboardData + display label + scope + color
 * theme. Tiles are themed by scope row: all-stage cards blue, Sold cards violet.
 */
const TILE_DEFS = [
    { key: 'totalValue', label: 'Project Total Value', scope: 'All stages', theme: 'all' },
    { key: 'totalReceived', label: 'Projects Received Value', scope: 'All stages', theme: 'all' },
    { key: 'totalRemaining', label: 'Projects Remaining Value', scope: 'All stages', theme: 'all' },
    { key: 'soldValue', label: 'Projects Sold Value', scope: 'Reserved / Sold', theme: 'sold' },
    { key: 'soldReceived', label: 'Projects Sold Received Value', scope: 'Reserved / Sold', theme: 'sold' },
    { key: 'soldRemaining', label: 'Projects Sold Remaining Value', scope: 'Reserved / Sold', theme: 'sold' }
];

/** Donut metadata: ProjectRow metric powering each donut (Booked/Reserved/Sold deal scope). */
const DONUT_DEFS = [
    { metric: 'brsValue', title: 'Deal Value by Project', centerLabel: 'Total value' },
    { metric: 'brsReceived', title: 'Received by Project', centerLabel: 'Received' },
    { metric: 'brsRemaining', title: 'Remaining by Project', centerLabel: 'Remaining' }
];

/**
 * Categorical palette (dataviz reference instance, light mode, fixed slot order).
 * A project keeps the same hue across all three donuts; projects beyond the
 * eighth fold into a muted "Other" — hues are never cycled.
 */
const PROJECT_PALETTE = ['#2a78d6', '#eb6834', '#1baf7a', '#eda100', '#e87ba4', '#008300', '#4a3aa7', '#e34948'];
const OTHER_COLOR = '#898781';
const OTHER_LABEL = 'Other';

/**
 * Bar series hues — same roles as the KPI tile themes. Remaining uses the dark
 * violet step (#4a3aa7, the remaining tile's hero ink) rather than the tile's
 * #7a6ad8 accent: the lighter violet sits ΔE 1.7 (protan) from the blue, so
 * the two series would be indistinguishable for colorblind readers.
 */
const SERIES_COLORS = { value: '#2a78d6', received: '#1baf7a', remaining: '#4a3aa7' };

/** Chart chrome ink (dataviz tokens, light surface). */
const INK = { secondary: '#52514e', muted: '#898781', grid: '#e1e0d9', baseline: '#c3c2b7', surface: '#ffffff' };

export default class ProjectCollectionDashboard extends LightningElement {
    dashboard;
    errorMessage;
    isLoading = true;
    lastUpdatedLabel = '';

    wiredDashboardResult;

    chartJsRequested = false;
    chartJsReady = false;
    charts = {}; // live Chart instances keyed by donut metric / 'bar'
    renderedData; // DashboardData reference the charts were last built from

    @wire(getDashboardData)
    wiredDashboard(result) {
        this.wiredDashboardResult = result;
        const { data, error } = result;
        if (data) {
            this.dashboard = data;
            this.errorMessage = undefined;
            this.isLoading = false;
            this.lastUpdatedLabel = `Updated ${new Intl.DateTimeFormat('en-GB', {
                hour: '2-digit',
                minute: '2-digit'
            }).format(new Date())}`;
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
                .catch((error) => {
                    this.errorMessage = this.reduceError(error);
                });
        }
        this.renderCharts();
    }

    disconnectedCallback() {
        this.destroyCharts();
    }

    handleRefresh() {
        if (!this.wiredDashboardResult) {
            return;
        }
        this.isLoading = true;
        refreshApex(this.wiredDashboardResult).finally(() => {
            this.isLoading = false;
        });
    }

    /* ---------- charts ---------- */

    renderCharts() {
        if (!this.chartJsReady || !this.dashboard || this.renderedData === this.dashboard) {
            return;
        }
        this.renderedData = this.dashboard;
        this.destroyCharts();
        DONUT_DEFS.forEach((def) => this.buildDonut(def.metric));
        this.buildBarChart();
    }

    destroyCharts() {
        Object.values(this.charts).forEach((chart) => chart.destroy());
        this.charts = {};
    }

    buildDonut(metric) {
        const canvas = this.template.querySelector(`canvas[data-metric="${metric}"]`);
        if (!canvas) {
            return;
        }
        const segments = this.donutSegments(metric);
        const formatFull = (value) => this.formatFull(value);
        this.charts[metric] = new window.Chart(canvas.getContext('2d'), {
            type: 'doughnut',
            data: {
                labels: segments.map((s) => s.label),
                datasets: [
                    {
                        data: segments.map((s) => s.value),
                        backgroundColor: segments.map((s) => s.color),
                        borderColor: INK.surface,
                        borderWidth: 2,
                        hoverOffset: 4
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '68%',
                plugins: {
                    legend: { display: false }, // shared HTML legend strip below the row
                    tooltip: {
                        callbacks: {
                            label(ctx) {
                                const total = ctx.dataset.data.reduce((sum, v) => sum + v, 0);
                                const pct = total > 0 ? Math.round((ctx.parsed / total) * 100) : 0;
                                return ` ${formatFull(ctx.parsed)} (${pct}%)`;
                            }
                        }
                    }
                }
            }
        });
    }

    buildBarChart() {
        const canvas = this.template.querySelector('canvas.bar-canvas');
        if (!canvas) {
            return;
        }
        const projects = this.dashboard.projects || [];
        const formatFull = (value) => this.formatFull(value);
        const formatCompact = (value) => this.formatCompact(value);
        const barDataset = (label, key, color) => ({
            label,
            data: projects.map((p) => p[key]),
            backgroundColor: color,
            borderRadius: 4,
            borderSkipped: 'start',
            maxBarThickness: 52
        });
        // Chart.js core has no data labels (and the org's ChartJSDataLabels
        // resource is a stub) — draw the per-bar values vertically ourselves.
        const verticalBarLabels = {
            id: 'verticalBarLabels',
            afterDatasetsDraw(chart) {
                const ctx = chart.ctx;
                chart.data.datasets.forEach((dataset, datasetIndex) => {
                    const meta = chart.getDatasetMeta(datasetIndex);
                    if (meta.hidden) {
                        return;
                    }
                    meta.data.forEach((bar, index) => {
                        const raw = dataset.data[index];
                        if (!raw) {
                            return;
                        }
                        const text = formatCompact(raw);
                        ctx.save();
                        ctx.font = '600 11px system-ui, -apple-system, "Segoe UI", sans-serif';
                        const textWidth = ctx.measureText(text).width;
                        const barEnd = Math.min(bar.y, bar.base);
                        const barHeight = Math.abs(bar.base - bar.y);
                        ctx.translate(bar.x, 0);
                        ctx.rotate(-Math.PI / 2);
                        ctx.textBaseline = 'middle';
                        if (barHeight > textWidth + 14) {
                            // inside the bar, hanging down from its top
                            ctx.textAlign = 'right';
                            ctx.fillStyle = '#ffffff';
                            ctx.fillText(text, -(barEnd + 7), 0);
                        } else {
                            // bar too short — stand the label above it in ink
                            ctx.textAlign = 'left';
                            ctx.fillStyle = INK.secondary;
                            ctx.fillText(text, -(barEnd - 5), 0);
                        }
                        ctx.restore();
                    });
                });
            }
        };
        this.charts.bar = new window.Chart(canvas.getContext('2d'), {
            type: 'bar',
            plugins: [verticalBarLabels],
            data: {
                labels: projects.map((p) => p.projectName),
                datasets: [
                    barDataset('Total Value', 'totalValue', SERIES_COLORS.value),
                    barDataset('Received', 'totalReceived', SERIES_COLORS.received),
                    barDataset('Remaining', 'totalRemaining', SERIES_COLORS.remaining)
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                layout: { padding: { top: 34 } },
                datasets: { bar: { categoryPercentage: 0.82, barPercentage: 0.92 } },
                scales: {
                    x: {
                        grid: { display: false },
                        border: { color: INK.baseline },
                        ticks: { color: INK.muted }
                    },
                    y: {
                        beginAtZero: true,
                        grid: { color: INK.grid },
                        border: { display: false },
                        ticks: { color: INK.muted, callback: (value) => formatCompact(value) }
                    }
                },
                plugins: {
                    legend: {
                        position: 'top',
                        align: 'end',
                        labels: { usePointStyle: true, pointStyle: 'circle', boxHeight: 7, color: INK.secondary }
                    },
                    tooltip: {
                        callbacks: {
                            label(ctx) {
                                return ` ${ctx.dataset.label}: ${formatFull(ctx.parsed.y)}`;
                            }
                        }
                    }
                }
            }
        });
    }

    /**
     * Donut segments for one ProjectRow metric: hue fixed by project position
     * (stable across all three donuts), zero/negative slices dropped, projects
     * beyond the palette folded into a single "Other" slice.
     */
    donutSegments(metric) {
        const projects = this.dashboard?.projects || [];
        const segments = [];
        let otherTotal = 0;
        projects.forEach((project, index) => {
            const value = project[metric] || 0;
            if (value <= 0) {
                return;
            }
            if (index < PROJECT_PALETTE.length) {
                segments.push({ label: project.projectName, value, color: PROJECT_PALETTE[index] });
            } else {
                otherTotal += value;
            }
        });
        if (otherTotal > 0) {
            segments.push({ label: OTHER_LABEL, value: otherTotal, color: OTHER_COLOR });
        }
        return segments;
    }

    /* ---------- template getters ---------- */

    get tiles() {
        const data = this.dashboard;
        return TILE_DEFS.map((def) => {
            const value = data ? data[def.key] : null;
            return {
                key: def.key,
                label: def.label,
                scope: def.scope,
                cardClass: `tile theme-${def.theme}`,
                compact: value === null ? '—' : this.formatCompact(value),
                full: value === null ? '' : this.formatFull(value)
            };
        });
    }

    get donutCards() {
        const projects = this.dashboard?.projects || [];
        const valueTotal = projects.reduce((sum, p) => sum + (p.brsValue || 0), 0);
        return DONUT_DEFS.map((def) => {
            const total = projects.reduce((sum, p) => sum + (p[def.metric] || 0), 0);
            const hasSlices = projects.some((p) => (p[def.metric] || 0) > 0);
            return {
                metric: def.metric,
                title: def.title,
                centerLabel: def.centerLabel,
                centerCompact: this.formatCompact(total),
                centerFull: this.formatFull(total),
                // share of the total deal value: Value reads 100%, Received and
                // Remaining read as their percentage of that value
                centerPct: valueTotal > 0 ? `${Math.round((total / valueTotal) * 100)}% of value` : '',
                isEmpty: !hasSlices
            };
        });
    }

    get projectLegend() {
        const projects = this.dashboard?.projects || [];
        const items = projects.map((project, index) => ({
            name: project.projectName,
            swatch: `background:${index < PROJECT_PALETTE.length ? PROJECT_PALETTE[index] : OTHER_COLOR}`
        }));
        if (projects.length > PROJECT_PALETTE.length) {
            return items
                .slice(0, PROJECT_PALETTE.length)
                .concat([{ name: OTHER_LABEL, swatch: `background:${OTHER_COLOR}` }]);
        }
        return items;
    }

    get tableRows() {
        const projects = this.dashboard?.projects || [];
        return projects.map((project, index) => {
            const pct = project.totalValue > 0 ? Math.round((project.totalReceived / project.totalValue) * 100) : 0;
            return {
                projectId: project.projectId,
                name: project.projectName,
                swatch: `background:${index < PROJECT_PALETTE.length ? PROJECT_PALETTE[index] : OTHER_COLOR}`,
                totalValue: this.formatFull(project.totalValue),
                totalReceived: this.formatFull(project.totalReceived),
                totalRemaining: this.formatFull(project.totalRemaining),
                pct: `${pct}%`,
                barStyle: `width:${Math.max(0, Math.min(100, pct))}%`
            };
        });
    }

    get tableTotals() {
        const data = this.dashboard;
        const pct = data && data.totalValue > 0 ? Math.round((data.totalReceived / data.totalValue) * 100) : 0;
        return {
            totalValue: this.formatFull(data?.totalValue),
            totalReceived: this.formatFull(data?.totalReceived),
            totalRemaining: this.formatFull(data?.totalRemaining),
            pct: `${pct}%`,
            barStyle: `width:${Math.max(0, Math.min(100, pct))}%`
        };
    }

    get hasProjects() {
        return (this.dashboard?.projects || []).length > 0;
    }

    get hasNoProjects() {
        return !this.hasProjects;
    }

    get currencyDescription() {
        const base = 'All projects — values in AED (non-AED amounts converted at daily market rates)';
        const asOf = this.dashboard?.ratesAsOf;
        if (!asOf) {
            return base;
        }
        const stamp = new Date(asOf);
        if (isNaN(stamp.getTime())) {
            return base;
        }
        const formatted = new Intl.DateTimeFormat('en-GB', {
            day: 'numeric',
            month: 'short',
            hour: '2-digit',
            minute: '2-digit'
        }).format(stamp);
        return `${base} · rates as of ${formatted}`;
    }

    get hasError() {
        return Boolean(this.errorMessage);
    }

    formatCompact(value) {
        return new Intl.NumberFormat('en', {
            notation: 'compact',
            maximumFractionDigits: 1
        }).format(value || 0);
    }

    formatFull(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: CURRENCY,
            maximumFractionDigits: 0
        }).format(value || 0);
    }

    reduceError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return error?.message || 'Unknown error while loading the dashboard.';
    }
}
