import { LightningElement } from 'lwc';

/**
 * Registry of every dashboard the hub exposes — the ONLY place to touch when
 * adding a dashboard. One entry = one pill in the nav; the component is
 * loaded on demand and rendered through <lwc:component lwc:is>.
 *
 * import() needs a string literal (on-platform module resolution), so each
 * entry carries its own loader arrow.
 */
const DASHBOARDS = [
    {
        id: 'projectCollections',
        label: 'Project Collections',
        description: 'Multi-currency collection KPIs, charts and project comparison',
        icon: 'utility:moneybag',
        loader: () => import('c/projectCollectionDashboard')
    },
    {
        id: 'executiveManagement',
        label: 'Executive Management',
        description: 'Booking-year executive KPIs: sales vs target, pipeline, teams and agencies',
        icon: 'utility:metrics',
        loader: () => import('c/executiveDashboard')
    },
    {
        id: 'misDashboard',
        label: 'MIS Dashboard',
        description: 'All sales activities: Today / MTD / YTD bookings, reservations, sales, teams and agencies',
        icon: 'utility:activity',
        loader: () => import('c/misDashboard')
    },
    {
        id: 'monthlySalesReport',
        label: 'Monthly Sales Report',
        description: 'Monthly / weekly sales report with PDF download',
        icon: 'utility:summary',
        loader: () => import('c/monthlySalesReport')
    }
];

export default class DashboardHub extends LightningElement {
    selectedId = DASHBOARDS[0].id;
    activeCtor;
    errorMessage;

    connectedCallback() {
        this.loadSelected();
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
