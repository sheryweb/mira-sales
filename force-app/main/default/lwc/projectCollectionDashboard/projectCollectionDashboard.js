import { LightningElement, wire } from 'lwc';
import getAvailableCurrencies from '@salesforce/apex/ProjectCollectionDashboardController.getAvailableCurrencies';
import getDashboardData from '@salesforce/apex/ProjectCollectionDashboardController.getDashboardData';

const DEFAULT_CURRENCY = 'AED';

const CURRENCY_LABELS = {
    AED: 'UAE Dirham',
    CHF: 'Swiss Franc',
    USD: 'US Dollar',
    EUR: 'Euro'
};

/** Tile metadata: metric key on DashboardData + display label + scope + color theme. */
const TILE_DEFS = [
    { key: 'totalValue', label: 'Project Total Value', scope: 'All stages', theme: 'value' },
    { key: 'totalReceived', label: 'Projects Received Value', scope: 'All stages', theme: 'received' },
    { key: 'totalRemaining', label: 'Projects Remaining Value', scope: 'All stages', theme: 'remaining' },
    { key: 'soldValue', label: 'Projects Sold Value', scope: 'Reserved / Sold', theme: 'value' },
    { key: 'soldReceived', label: 'Projects Sold Received Value', scope: 'Reserved / Sold', theme: 'received' },
    { key: 'soldRemaining', label: 'Projects Sold Remaining Value', scope: 'Reserved / Sold', theme: 'remaining' }
];

export default class ProjectCollectionDashboard extends LightningElement {
    selectedCurrency = DEFAULT_CURRENCY;
    currencyOptions = [];
    dashboard;
    errorMessage;
    isLoading = true;

    wiredDashboardResult; // kept for refreshApex (refresh control arrives with the polish step)

    @wire(getAvailableCurrencies)
    wiredCurrencies({ data, error }) {
        if (data) {
            this.currencyOptions = data.map((iso) => ({
                label: CURRENCY_LABELS[iso] ? `${iso} — ${CURRENCY_LABELS[iso]}` : iso,
                value: iso
            }));
            if (data.length && !data.includes(this.selectedCurrency)) {
                this.selectedCurrency = data[0];
            }
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    @wire(getDashboardData, { currencyIso: '$selectedCurrency' })
    wiredDashboard(result) {
        this.wiredDashboardResult = result;
        const { data, error } = result;
        if (data) {
            this.dashboard = data;
            this.errorMessage = undefined;
            this.isLoading = false;
        } else if (error) {
            this.errorMessage = this.reduceError(error);
            this.isLoading = false;
        }
    }

    handleCurrencyChange(event) {
        this.isLoading = true;
        this.selectedCurrency = event.detail.value;
    }

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

    get currencyDescription() {
        const name = CURRENCY_LABELS[this.selectedCurrency];
        return name
            ? `Collections across all ${this.selectedCurrency} (${name}) projects`
            : `Collections across all ${this.selectedCurrency} projects`;
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
            currency: this.selectedCurrency,
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
