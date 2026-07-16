import { LightningElement, api, track, wire } from 'lwc';
import getBankComparison from '@salesforce/apex/BankChangeComparisonController.getBankComparison';

export default class BankChangeComparisonViewer extends LightningElement {
    @api recordId;

    @track comparison = null;
    @track error = null;
    @track loading = true;
    @track _wired = false;

    @wire(getBankComparison, { recordId: '$recordId' })
    wiredComparison({ data, error }) {
        this._wired = true;
        this.loading = false;
        if (error) {
            this.error = (error && error.body && error.body.message) || 'Failed to load comparison data.';
            this.comparison = null;
        } else {
            this.comparison = data || null;
            this.error = null;
        }
    }

    get hasData() {
        return this.comparison && !this.comparison.notApplicable;
    }

    get isNotApplicable() {
        return this._wired && !this.loading && this.comparison && this.comparison.notApplicable === true;
    }

    get showViewer() {
        if (this.loading || this.isNotApplicable) {
            return false;
        }
        return this.hasData || !!this.error;
    }

    get bankCount() {
        return this.hasData && this.comparison.banks ? this.comparison.banks.length : 0;
    }
}