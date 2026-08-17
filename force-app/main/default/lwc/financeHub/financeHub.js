import { LightningElement } from 'lwc';

/**
 * Registry of every Finance Center dashboard — the ONLY place to touch when
 * adding one. One entry = one pill in the nav; the component is loaded on
 * demand and rendered through <lwc:component lwc:is>. Same pattern as
 * c/dashboardHub (Performance Center).
 *
 * import() needs a string literal (on-platform module resolution), so each
 * entry carries its own loader arrow.
 */
const DASHBOARDS = [
    {
        id: 'portfolioPosition',
        label: 'Portfolio Position',
        description: 'Contracted / invoiced / received / due split, project and unit drill-down, collection health',
        icon: 'utility:money',
        loader: () => import('c/financePortfolioDashboard')
    },
    {
        id: 'collectionsAging',
        label: 'Collections & Aging',
        description: 'Aging buckets by project and customer, actionable overdue and defaulted lists, trends',
        icon: 'utility:clock',
        loader: () => import('c/financeCollectionsDashboard')
    },
    {
        id: 'cashflowForecast',
        label: 'Cash Flow & Forecast',
        description: 'Expected receipts vs actuals, frozen-baseline variance, collection scenario, escrow split',
        icon: 'utility:trending',
        loader: () => import('c/financeCashflowDashboard')
    },
    {
        id: 'operations',
        label: 'Invoice & Receipt Ops',
        description: 'Daily volumes, receipt methods, PDC calendar, unallocated queue, SOA log, data quality',
        icon: 'utility:record',
        loader: () => import('c/financeOperationsDashboard')
    }
];

/** Shown while the registry above is still empty (shell shipped ahead of the dashboards). */
const UPCOMING = [];

export default class FinanceHub extends LightningElement {
    selectedId = DASHBOARDS.length ? DASHBOARDS[0].id : undefined;
    activeCtor;
    errorMessage;

    connectedCallback() {
        if (DASHBOARDS.length) {
            this.loadSelected();
        }
    }

    get hasDashboards() {
        return DASHBOARDS.length > 0;
    }

    get upcomingItems() {
        return UPCOMING;
    }

    get navItems() {
        return DASHBOARDS.map((dashboard) => ({
            id: dashboard.id,
            label: dashboard.label,
            description: dashboard.description,
            icon: dashboard.icon,
            selected: dashboard.id === this.selectedId,
            cssClass: dashboard.id === this.selectedId ? 'hub-tab active' : 'hub-tab'
        }));
    }

    get isLoading() {
        return !this.activeCtor && !this.errorMessage;
    }

    get hasError() {
        return Boolean(this.errorMessage);
    }

    handleSelect(event) {
        const id = event.currentTarget.dataset.id;
        if (id === this.selectedId && this.activeCtor) {
            return;
        }
        this.selectedId = id;
        this.loadSelected();
    }

    loadSelected() {
        const entry = DASHBOARDS.find((dashboard) => dashboard.id === this.selectedId);
        this.activeCtor = undefined;
        this.errorMessage = undefined;
        const requestedId = this.selectedId;
        entry
            .loader()
            .then((module) => {
                // ignore stale loads if the user switched again mid-flight
                if (this.selectedId === requestedId) {
                    this.activeCtor = module.default;
                }
            })
            .catch(() => {
                if (this.selectedId === requestedId) {
                    this.errorMessage = `Failed to load "${entry.label}". Refresh the page and try again.`;
                }
            });
    }
}
