import { LightningElement, api, track, wire } from 'lwc';
import getProfileComparison from '@salesforce/apex/ProfileChangeComparisonController.getProfileComparison';

export default class ProfileChangeComparisonViewer extends LightningElement {
    @api recordId;

    @track comparison = null;
    @track error = null;
    @track loading = true;
    @track _wired = false;

    @wire(getProfileComparison, { recordId: '$recordId' })
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

    // Only render the card when this request actually is a profile update with changes.
    get showViewer() {
        if (this.loading || this.isNotApplicable) {
            return false;
        }
        return this.hasData || !!this.error;
    }

    get changeCount() {
        return this.hasData && this.comparison.changes ? this.comparison.changes.length : 0;
    }
}