import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDashboardData from '@salesforce/apex/ExecutiveDashboardController.getDashboardData';

const CURRENCY = 'AED';

/** Standard dashboard indicator colors (low / mid / high bands). */
const BAND_CLASSES = ['band-low', 'band-mid', 'band-high'];

export default class ExecutiveDashboard extends LightningElement {
    selectedYear = ''; // blank on first load; the server resolves the default
    dashboard;
    errorMessage;
    isLoading = true;
    lastUpdatedLabel = '';

    wiredResult;

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

    get yearOptions() {
        return (this.dashboard?.yearOptions || []).map((year) => ({ label: year, value: year }));
    }

    get subtitle() {
        const year = this.dashboard?.selectedYear || this.selectedYear;
        return year
            ? `Deals booked in ${year} (whatever their current stage) — values in AED`
            : 'Booking-year cohort — values in AED';
    }

    /** YTD Sales vs Target tile: sold value against the 1B gauge scale. */
    get gaugeTile() {
        const data = this.dashboard;
        const value = data ? data.soldValue : null;
        const max = data?.gaugeMax || 0;
        const pct = data && max > 0 ? Math.min(100, Math.round((data.soldValue / max) * 100)) : 0;
        return {
            compact: value === null ? '—' : this.formatCompact(value),
            full: value === null ? '' : this.formatFull(value),
            target: data ? `${pct}% of ${this.formatCompact(max)} target` : '',
            cardClass: `tile ${data ? this.bandClass(data.soldValue, data.gaugeBreakpoint1, data.gaugeBreakpoint2) : 'band-low'}`
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
