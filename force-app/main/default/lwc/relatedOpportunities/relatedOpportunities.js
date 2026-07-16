import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getRelatedOpportunities from '@salesforce/apex/RelatedOpportunitiesController.getRelatedOpportunities';

export default class RelatedOpportunities extends NavigationMixin(LightningElement) {
    @api recordId; // This will hold the Account Id
    opportunities;
    isLoading = true;
    error;

    @wire(getRelatedOpportunities, { accountId: '$recordId' })
    wiredOpportunities({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.opportunities = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.opportunities = undefined;
        }
    }

    navigateToOpportunity(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Opportunity',
                actionName: 'view'
            }
        });
    }

    get hasOpportunities() {
        return this.opportunities && this.opportunities.length > 0;
    }
    
    get opportunitiesCount() {
        return this.opportunities ? this.opportunities.length : 0;
    }
    
    get cardTitle() {
        const count = this.opportunitiesCount;
        return `Related Opportunities (${count})`;
    }
}