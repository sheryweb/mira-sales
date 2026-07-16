import { LightningElement, api, track, wire } from 'lwc';
import getUnitPriceComparison from '@salesforce/apex/UnitPriceApprovalController.getUnitPriceComparison';

export default class UnitPriceComparisonViewer extends LightningElement {
    @api recordId;

    @track comparison = null;
    @track error = null;
    @track loading = true;
    @track _wired = false;

    @wire(getUnitPriceComparison, { approvalRequestId: '$recordId' })
    wiredComparison({ data, error }) {
        this._wired = true;
        this.loading = false;
        if (error) {
            this.error =
                (error && error.body && error.body.message) || 'Failed to load comparison data.';
            this.comparison = null;
        } else {
            this.comparison = data || null;
            this.error = null;
        }
    }

    get hasData() {
        return (
            this.comparison !== null &&
            this.comparison !== undefined &&
            !this.comparison.notApplicable
        );
    }

    get isNotApplicable() {
        return (
            this._wired &&
            !this.loading &&
            this.comparison !== null &&
            this.comparison !== undefined &&
            this.comparison.notApplicable === true
        );
    }

    get notApplicableReason() {
        if (this.comparison && this.comparison.notApplicableReason) {
            return this.comparison.notApplicableReason;
        }
        return 'This record does not have unit price comparison data.';
    }

    get showViewer() {
        if (this.loading) {
            return false;
        }
        if (this.isNotApplicable) {
            return false;
        }
        return this.hasData || !!this.error;
    }

    get unitTitle() {
        return this.comparison && this.comparison.unitInfo ? this.comparison.unitInfo.title : '';
    }

    get unitProject() {
        return this.comparison && this.comparison.unitInfo ? this.comparison.unitInfo.projectName : '';
    }

    get unitBuilding() {
        return this.comparison && this.comparison.unitInfo ? this.comparison.unitInfo.building : '';
    }

    get unitAccount() {
        return this.comparison && this.comparison.unitInfo ? this.comparison.unitInfo.accountName : '';
    }

    get currencyCode() {
        return this.comparison && this.comparison.priceCurrency
            ? this.comparison.priceCurrency
            : 'AED';
    }

    get isForeignCurrency() {
        return this.currencyCode !== 'AED';
    }

    get currentPriceDisplay() {
        return this.formatMoney(this.currencyCode, this.comparison ? this.comparison.currentPrice : null);
    }

    get requestedPriceDisplay() {
        return this.formatMoney(this.currencyCode, this.comparison ? this.comparison.requestedPrice : null);
    }

    get currentCostAedDisplay() {
        return this.formatMoney('AED', this.comparison ? this.comparison.currentCostAED : null);
    }

    get requestedCostAedDisplay() {
        return this.formatMoney('AED', this.comparison ? this.comparison.requestedCostAED : null);
    }

    get discountPercentDisplay() {
        const percent = this.comparison ? this.comparison.discountPercent : null;
        if (percent == null || percent === '') {
            return '—';
        }
        return `${percent}%`;
    }

    get priceDifferenceDisplay() {
        return this.formatSignedMoney(this.currencyCode, this.comparison ? this.comparison.priceDifference : null);
    }

    get costAedDifferenceDisplay() {
        return this.formatSignedMoney('AED', this.comparison ? this.comparison.costAedDifference : null);
    }

    get conversionRateDisplay() {
        if (!this.isForeignCurrency || !this.comparison || !this.comparison.conversionRate) {
            return '';
        }
        return `1 AED = ${this.comparison.conversionRate} ${this.currencyCode} (Currency Management)`;
    }

    get priceDiffClass() {
        return this.diffClass(this.comparison ? this.comparison.priceDifference : null);
    }

    get costAedDiffClass() {
        return this.diffClass(this.comparison ? this.comparison.costAedDifference : null);
    }

    diffClass(value) {
        if (value == null || value === 0) {
            return 'slds-text-color_default';
        }
        return value > 0 ? 'slds-text-color_success' : 'slds-text-color_error';
    }

    formatMoney(currencyCode, value) {
        if (value == null || value === '') {
            return `${currencyCode} —`;
        }
        const num = Number(value);
        if (Number.isNaN(num)) {
            return `${currencyCode} —`;
        }
        return `${currencyCode} ${Math.round(num).toLocaleString(undefined, {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        })}`;
    }

    formatSignedMoney(currencyCode, value) {
        if (value == null || value === '') {
            return `${currencyCode} —`;
        }
        const num = Number(value);
        if (Number.isNaN(num)) {
            return `${currencyCode} —`;
        }
        const prefix = num > 0 ? '+' : '';
        return `${prefix}${currencyCode} ${Math.round(num).toLocaleString(undefined, {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        })}`;
    }
}