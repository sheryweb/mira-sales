import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { loadScript } from 'lightning/platformResourceLoader';
import CHART_JS from '@salesforce/resourceUrl/ChartJS';
import getDashboardData from '@salesforce/apex/ExecutiveDashboardController.getDashboardData';

const CURRENCY = 'AED';

/** Standard dashboard indicator colors (low / mid / high bands). */
const BAND_CLASSES = ['band-low', 'band-mid', 'band-high'];
const GAUGE_COLORS = ['#f9b92f', '#26a4f2', '#49b800'];

/** Series + chrome (dataviz reference palette, light surface). */
const SERIES_BLUE = '#2a78d6';
const PROJECT_PALETTE = ['#2a78d6', '#eb6834', '#1baf7a', '#eda100', '#e87ba4', '#008300', '#4a3aa7', '#e34948'];
const OTHER_COLOR = '#898781';
const INK = { primary: '#0b0b0b', secondary: '#52514e', muted: '#898781', grid: '#e1e0d9', baseline: '#c3c2b7', surface: '#ffffff' };
const CHART_FONT = 'system-ui, -apple-system, "Segoe UI", sans-serif';

export default class ExecutiveDashboard extends LightningElement {
    selectedYear = ''; // blank on first load; the server resolves the default
    dashboard;
    errorMessage;
    isLoading = true;
    lastUpdatedLabel = '';

    wiredResult;

    chartJsRequested = false;
    chartJsReady = false;
    charts = {};
    renderedData;

    @wire(getDashboardData, { targetYear: '$selectedYear' })
    wiredDashboard(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.dashboard = data;
            if (!this.selectedYear) {
                this.selectedYear = data.selectedYear; // lock in the resolved default
            }
            this.errorMessage = undefined;
            this.isLoading = false;
            this.lastUpdatedLabel = `Updated ${new Intl.DateTimeFormat('en-GB', {
                hour: 'numeric',
                minute: '2-digit',
                hour12: true
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

    handleYearChange(event) {
        this.isLoading = true;
        this.selectedYear = event.detail.value;
    }

    handleRefresh() {
        if (!this.wiredResult) {
            return;
        }
        this.isLoading = true;
        refreshApex(this.wiredResult).finally(() => {
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
        this.buildGauge();
        this.buildMonthlyChart();
        this.buildQuarterlyChart();
        this.buildProjectDonut();
    }

    destroyCharts() {
        Object.values(this.charts).forEach((chart) => chart.destroy());
        this.charts = {};
    }

    buildGauge() {
        const canvas = this.template.querySelector('canvas.gauge-canvas');
        if (!canvas) {
            return;
        }
        const data = this.dashboard;
        const max = Number(data.gaugeMax) || 1;
        const bp1 = Number(data.gaugeBreakpoint1);
        const bp2 = Number(data.gaugeBreakpoint2);
        const value = Math.max(0, Math.min(Number(data.soldValue), max));
        const formatCompact = (v) => this.formatCompact(v);
        const GAUGE_TICKS = 5; // 0, 200M, 400M, 600M, 800M, 1B on the 1B scale
        const needle = {
            id: 'gaugeNeedle',
            afterDatasetsDraw(chart) {
                const arc = chart.getDatasetMeta(0).data[0];
                if (!arc) {
                    return;
                }
                const props = arc.getProps(['x', 'y', 'outerRadius', 'innerRadius'], true);
                const midRadius = (props.outerRadius + props.innerRadius) / 2;
                const ctx = chart.ctx;
                ctx.save();
                ctx.translate(props.x, props.y);

                // scale ticks + range labels around the outside of the arc
                ctx.font = `10px ${CHART_FONT}`;
                for (let i = 0; i <= GAUGE_TICKS; i++) {
                    const t = i / GAUGE_TICKS;
                    const tickAngle = Math.PI * (1 + t);
                    const cos = Math.cos(tickAngle);
                    const sin = Math.sin(tickAngle);
                    ctx.strokeStyle = INK.baseline;
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(cos * props.outerRadius, sin * props.outerRadius);
                    ctx.lineTo(cos * (props.outerRadius + 4), sin * (props.outerRadius + 4));
                    ctx.stroke();
                    ctx.fillStyle = INK.muted;
                    ctx.textAlign = cos < -0.25 ? 'right' : cos > 0.25 ? 'left' : 'center';
                    ctx.textBaseline = Math.abs(cos) > 0.9 ? 'middle' : 'bottom';
                    ctx.fillText(
                        formatCompact((max * i) / GAUGE_TICKS),
                        cos * (props.outerRadius + 7),
                        sin * (props.outerRadius + 7)
                    );
                }

                // needle + hub, drawn after the labels so it always reads on top
                const angle = Math.PI * (1 + value / max);
                ctx.rotate(angle);
                ctx.beginPath();
                ctx.moveTo(0, -3);
                ctx.lineTo(midRadius - 4, 0);
                ctx.lineTo(0, 3);
                ctx.closePath();
                ctx.fillStyle = INK.primary;
                ctx.fill();
                ctx.rotate(-angle);
                ctx.beginPath();
                ctx.arc(0, 0, 5.5, 0, 2 * Math.PI);
                ctx.fill();
                ctx.restore();
            }
        };
        this.charts.gauge = new window.Chart(canvas.getContext('2d'), {
            type: 'doughnut',
            plugins: [needle],
            data: {
                labels: ['Low', 'Mid', 'High'],
                datasets: [
                    {
                        data: [bp1, bp2 - bp1, max - bp2],
                        backgroundColor: GAUGE_COLORS,
                        borderWidth: 0,
                        spacing: 3,
                        borderRadius: 12
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                rotation: -90,
                circumference: 180,
                cutout: '84%',
                layout: { padding: { top: 16, left: 40, right: 40, bottom: 4 } },
                plugins: {
                    legend: { display: false },
                    tooltip: { enabled: false }
                }
            }
        });
    }

    buildMonthlyChart() {
        const canvas = this.template.querySelector('canvas.monthly-canvas');
        if (!canvas) {
            return;
        }
        const rows = this.dashboard.monthlySold || [];
        const formatFull = (v) => this.formatFull(v);
        this.charts.monthly = new window.Chart(canvas.getContext('2d'), {
            type: 'bar',
            data: {
                labels: rows.map((r) => this.shortPeriod(r.name)),
                datasets: [
                    {
                        label: 'Sold value',
                        data: rows.map((r) => r.value),
                        backgroundColor: SERIES_BLUE,
                        borderRadius: 4,
                        borderSkipped: 'start',
                        maxBarThickness: 36
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: { grid: { display: false }, border: { color: INK.baseline }, ticks: { color: INK.muted } },
                    y: {
                        beginAtZero: true,
                        grid: { color: INK.grid },
                        border: { display: false },
                        ticks: { color: INK.muted, callback: (v) => this.formatCompact(v) }
                    }
                },
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: {
                            title: (items) => rows[items[0].dataIndex].name,
                            label: (ctx) => ` ${formatFull(ctx.parsed.y)} · ${rows[ctx.dataIndex].units} unit(s)`
                        }
                    }
                }
            }
        });
    }

    buildQuarterlyChart() {
        const canvas = this.template.querySelector('canvas.quarterly-canvas');
        if (!canvas) {
            return;
        }
        const rows = this.dashboard.quarterlySold || [];
        const formatFull = (v) => this.formatFull(v);
        const formatGrouped = (v) =>
            new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(v);
        const insideLabels = {
            id: 'hBarLabels',
            afterDatasetsDraw(chart) {
                const ctx = chart.ctx;
                const meta = chart.getDatasetMeta(0);
                meta.data.forEach((bar, index) => {
                    const raw = rows[index]?.value;
                    if (!raw) {
                        return;
                    }
                    const text = formatGrouped(raw);
                    ctx.save();
                    ctx.font = `600 11px ${CHART_FONT}`;
                    ctx.textBaseline = 'middle';
                    const width = ctx.measureText(text).width;
                    const barWidth = Math.abs(bar.x - bar.base);
                    if (barWidth > width + 16) {
                        ctx.textAlign = 'right';
                        ctx.fillStyle = INK.surface;
                        ctx.fillText(text, bar.x - 8, bar.y);
                    } else {
                        ctx.textAlign = 'left';
                        ctx.fillStyle = INK.secondary;
                        ctx.fillText(text, bar.x + 8, bar.y);
                    }
                    ctx.restore();
                });
            }
        };
        this.charts.quarterly = new window.Chart(canvas.getContext('2d'), {
            type: 'bar',
            plugins: [insideLabels],
            data: {
                labels: rows.map((r) => r.name),
                datasets: [
                    {
                        label: 'Sold value',
                        data: rows.map((r) => r.value),
                        backgroundColor: SERIES_BLUE,
                        borderRadius: 4,
                        borderSkipped: 'start',
                        maxBarThickness: 30
                    }
                ]
            },
            options: {
                indexAxis: 'y',
                responsive: true,
                maintainAspectRatio: false,
                layout: { padding: { right: 8 } },
                scales: {
                    x: {
                        beginAtZero: true,
                        grid: { color: INK.grid },
                        border: { display: false },
                        ticks: { color: INK.muted, callback: (v) => this.formatCompact(v) }
                    },
                    y: { grid: { display: false }, border: { color: INK.baseline }, ticks: { color: INK.muted } }
                },
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: {
                            label: (ctx) => ` ${formatFull(ctx.parsed.x)} · ${rows[ctx.dataIndex].units} unit(s)`
                        }
                    }
                }
            }
        });
    }

    buildProjectDonut() {
        const canvas = this.template.querySelector('canvas.project-canvas');
        if (!canvas) {
            return;
        }
        const segments = this.projectSegments();
        const formatFull = (v) => this.formatFull(v);
        this.charts.project = new window.Chart(canvas.getContext('2d'), {
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
                cutout: '66%',
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            usePointStyle: true,
                            pointStyle: 'circle',
                            boxHeight: 7,
                            color: INK.secondary,
                            font: { size: 11 }
                        }
                    },
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

    /** Donut segments: hue by value rank, ninth-plus projects fold into Other. */
    projectSegments() {
        const rows = this.dashboard?.projectSold || [];
        const segments = [];
        let otherTotal = 0;
        rows.forEach((row, index) => {
            if (!row.value || row.value <= 0) {
                return;
            }
            if (index < PROJECT_PALETTE.length) {
                segments.push({ label: row.name, value: row.value, color: PROJECT_PALETTE[index] });
            } else {
                otherTotal += row.value;
            }
        });
        if (otherTotal > 0) {
            segments.push({ label: 'Other', value: otherTotal, color: OTHER_COLOR });
        }
        return segments;
    }

    /** "February 2026" → "Feb 26" for compact x-axis labels. */
    shortPeriod(label) {
        const parts = (label || '').split(' ');
        return parts.length === 2 ? `${parts[0].slice(0, 3)} ${parts[1].slice(2)}` : label;
    }

    /* ---------- template getters ---------- */

    get yearOptions() {
        return (this.dashboard?.yearOptions || []).map((year) => ({ label: year, value: year }));
    }

    get subtitle() {
        const year = this.dashboard?.selectedYear || this.selectedYear;
        return year
            ? `Deals booked in ${year} (whatever their current stage) — values in AED`
            : 'Booking-year cohort — values in AED';
    }

    /** YTD Sales vs Target: sold value against the 1B gauge scale. */
    get gaugeTile() {
        const data = this.dashboard;
        const value = data ? data.soldValue : null;
        const max = data?.gaugeMax || 0;
        const pct = data && max > 0 ? Math.min(100, Math.round((data.soldValue / max) * 100)) : 0;
        return {
            compact: value === null ? '—' : this.formatCompact(value),
            full: value === null ? '' : this.formatFull(value),
            target: data ? `${pct}% of ${this.formatCompact(max)} target` : ''
        };
    }

    get unitsTile() {
        const data = this.dashboard;
        const value = data ? data.totalUnits : null;
        return {
            display: value === null ? '—' : String(value),
            cardClass: `tile ${data ? this.bandClass(data.totalUnits, data.unitsBreakpoint1, data.unitsBreakpoint2) : 'band-low'}`
        };
    }

    get valueTile() {
        const data = this.dashboard;
        const value = data ? data.totalValue : null;
        return {
            compact: value === null ? '—' : this.formatCompact(value),
            full: value === null ? '' : this.formatFull(value),
            cardClass: `tile ${data ? this.bandClass(data.totalValue, data.gaugeBreakpoint1, data.gaugeBreakpoint2) : 'band-low'}`
        };
    }

    get donutCenter() {
        return this.dashboard ? this.formatCompact(this.dashboard.soldValue) : '—';
    }

    get hasNoMonthly() {
        return !(this.dashboard?.monthlySold || []).length;
    }

    get hasNoQuarterly() {
        return !(this.dashboard?.quarterlySold || []).length;
    }

    get hasNoProjects() {
        return !this.projectSegments().length;
    }

    get hasError() {
        return Boolean(this.errorMessage);
    }

    /** Standard dashboard banding: below bp1 = low, below bp2 = mid, else high. */
    bandClass(value, breakpoint1, breakpoint2) {
        if (value >= breakpoint2) {
            return BAND_CLASSES[2];
        }
        return value >= breakpoint1 ? BAND_CLASSES[1] : BAND_CLASSES[0];
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
