import { LightningElement } from 'lwc';

/**
 * Registry of every Finance Center dashboard — the ONLY place to touch when
 * adding one. One entry = one pill in the nav; the component is loaded on
 * demand and rendered through <lwc:component lwc:is>. Same pattern as
 * c/dashboardHub (Performance Center).
 *
 * import() needs a string literal (on-platform module resolution), so each
 * entry carries its own loader arrow.
 *
 * Build order (see the Finance Center plan):
 *   Phase 2 — Portfolio Position      loader: () => import('c/financePortfolioDashboard')
 *   Phase 3 — Collections & Aging     loader: () => import('c/financeCollectionsDashboard')
 *   Phase 4 — Cash Flow & Forecast    loader: () => import('c/financeCashflowDashboard')
 *   Phase 5 — Invoice & Receipt Ops   loader: () => import('c/financeOperationsDashboard')
 */
const DASHBOARDS = [];

/** Shown while the registry above is still empty (shell shipped ahead of the dashboards). */
const UPCOMING = [
    { id: 'portfolio', label: 'Portfolio Position', detail: 'Contracted / invoiced / received / due split, project & unit drill-down, collection health' },
    { id: 'collections', label: 'Collections & Aging', detail: 'Aging buckets, top overdue customers with follow-up actions, trends' },
    { id: 'cashflow', label: 'Cash Flow & Forecast', detail: 'Expected receipts by month, forecast vs actual variance, scenarios' },
    { id: 'operations', label: 'Invoice & Receipt Operations', detail: 'Daily volumes, PDC calendar, unallocated queue, data-quality exceptions' }
];

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
