import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getDocComparison from '@salesforce/apex/DocumentChangeComparisonController.getDocComparison';

export default class DocumentChangeComparisonViewer extends NavigationMixin(LightningElement) {
    @api recordId;

    @track comparison = null;
    @track error = null;
    @track loading = true;
    @track _wired = false;

    @wire(getDocComparison, { recordId: '$recordId' })
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

    get docCount() {
        return this.hasData && this.comparison.docs ? this.comparison.docs.length : 0;
    }

    openFile(event) {
        const docId = event.currentTarget.dataset.id;
        if (!docId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: docId }
        });
    }
}