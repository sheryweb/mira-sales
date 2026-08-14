import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDashboardData from '@salesforce/apex/MISDashboardController.getDashboardData';

/**
 * MIS Dashboard — Today / MTD / YTD sales activity matrix (20 tables).
 * Faithful rebuild of the standard "MIS Dashoboard"; component titles mirror
 * the original's headers, values are compact AED like the original with the
 * full amount on hover. All aggregation happens server-side in one call.
 */
const COLUMNS = [
    {
        key: 'today',
        label: 'Today',
        tables: [
            { key: 'todayBooked', title: "Today's Booking", scope: 'Booked today', nameHeader: 'Project Name', empty: 'No bookings today' },
            { key: 'todayReserved', title: "Today's Reserved", scope: 'Reserved today', nameHeader: 'Project Name', empty: 'No reservations today' },
            { key: 'todaySold', title: "Today's Sold", scope: 'Sold today', nameHeader: 'Project Name', empty: 'No sold units today' },
            { key: 'todayAgentDirect', title: 'Agent vs Direct - Today', scope: 'Booked today', nameHeader: 'Direct / Agent', empty: 'No bookings today' }
        ]
    },
    {
        key: 'mtd',
        label: 'Month to Date',
        tables: [
            { key: 'mtdBooked', title: 'Booked - MTD', scope: 'Booked this month', nameHeader: 'Project Name', empty: 'No bookings this month' },
            { key: 'mtdReserved', title: 'Reserved - MTD', scope: 'Reserved this month', nameHeader: 'Project Name', empty: 'No reservations this month' },
            { key: 'mtdSold', title: 'Sold - MTD', scope: 'Sold this month', nameHeader: 'Project Name', empty: 'No sold units this month' },
            { key: 'mtdAllStatus', title: 'All Status - MTD', scope: 'Any activity this month', nameHeader: 'Project Name', empty: 'No activity this month' },
            { key: 'mtdTopAgencies', title: 'Top 10 Agents - MTD', scope: 'Agent-assisted', nameHeader: 'Agency', empty: 'No agency deals this month' },
            { key: 'mtdAgentDirect', title: 'Agent vs Direct - MTD', scope: 'Any activity this month', nameHeader: 'Direct / Agent', empty: 'No activity this month' },
            { key: 'mtdManagers', title: 'Managers Performance - MTD', scope: 'Any activity this month', nameHeader: 'Manager', empty: 'No activity this month' },
            { key: 'mtdManagementSale', title: 'Management Sale - MTD', scope: 'Management bucket', nameHeader: 'Manager', empty: 'No management deals this month' }
        ]
    },
    {
        key: 'ytd',
        label: 'Year to Date',
        tables: [
            { key: 'ytdReserved', title: 'YTD Performance - Reserved', scope: 'Reserved this year', nameHeader: 'Project Name', empty: 'No reservations this year' },
            { key: 'ytdSold', title: 'YTD Performance - Sold', scope: 'Sold this year', nameHeader: 'Project Name', empty: 'No sold units this year' },
            { key: 'ytdCombined', title: 'YTD Performance', scope: 'Booked this year', nameHeader: 'Project Name', empty: 'No bookings this year' },
            { key: 'ytdTeam', title: 'Team Performance - YTD', scope: 'Booked this year', nameHeader: 'Relationship Manager', empty: 'No bookings this year' },
            { key: 'ytdTopAgencies', title: 'Top 10 Agents - YTD', scope: 'Agent-assisted · booked this year', nameHeader: 'Agency', empty: 'No agency deals this year' },
            { key: 'ytdAgentDirect', title: 'Agent vs Direct - YTD', scope: 'Booked this year', nameHeader: 'Direct / Agent', empty: 'No bookings this year' },
            { key: 'ytdManagers', title: 'Managers Performance - YTD', scope: 'Booked this year onward', nameHeader: 'Manager', empty: 'No bookings this year' },
            { key: 'ytdManagementSale', title: 'Management Sale - YTD', scope: 'Management bucket', nameHeader: 'Manager', empty: 'No management deals this year' }
        ]
    }
];

export default class MisDashboard extends LightningElement {
    dashboard;
    errorMessage;
    isLoading = true;
    lastUpdatedLabel = '';

    wiredResult;

    @wire(getDashboardData)
    wiredDashboard(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.dashboard = data;
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

    handleRefresh() {
        if (!this.wiredResult) {
            return;
        }
        this.isLoading = true;
        refreshApex(this.wiredResult).finally(() => {
            this.isLoading = false;
        });
    }

    get subtitle() {
        return 'All sales activities — today, month to date and year to date — values in AED';
    }

    /** The whole matrix as view models: columns → table cards → rows. */
    get columns() {
        return COLUMNS.map((column) => ({
            key: column.key,
            label: column.label,
            tables: column.tables.map((table) => this.tableView(table))
        }));
    }

    tableView(config) {
        const source = this.dashboard ? this.dashboard[config.key] || [] : [];
        let totalUnits = 0;
        let totalValue = 0;
        const rows = source.map((row) => {
            totalUnits += row.units || 0;
            totalValue += row.value || 0;
            return {
                key: row.name,
                name: row.name,
                units: row.units,
                value: this.formatCompact(row.value),
                fullValue: this.formatFull(row.value)
            };
        });
        return {
            key: config.key,
            title: config.title,
            scope: config.scope,
            nameHeader: config.nameHeader,
            empty: config.empty,
            rows,
            hasRows: rows.length > 0,
            totalUnits,
            totalValue: this.formatCompact(totalValue),
            totalFull: this.formatFull(totalValue)
        };
    }

    get hasError() {
        return Boolean(this.errorMessage);
    }

    /** "AED 4.99M" like the original dashboard's compact chips. */
    formatCompact(value) {
        return (
            'AED ' +
            new Intl.NumberFormat('en', {
                notation: 'compact',
                maximumFractionDigits: 2
            }).format(value || 0)
        );
    }

    formatFull(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'AED',
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
