import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

// Define the fields you want to retrieve, including Status__c
const FIELDS = ['Account.Status__c']; // Replace 'Account.Status__c' with the API name of the field

export default class CustomPath extends LightningElement {
    @api recordId; // Automatically populated with the record ID on record pages
    currentStatus;

    // Wire to retrieve the record data and the specific field value (Status__c)
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            // Extract the Status field value from the retrieved record data
            this.currentStatus = data.fields.Status__c.value;
        } else if (error) {
            console.error('Error retrieving record data:', error);
        }
    }

    // Define the full list of possible stages
    allStages = [
        'Incomplete Registration',
        'In Process',
        'Agreement Issued',
        'Half Executed',
        'Completed',
        'Cancelled'  // Adding the Cancelled status here
    ];

    // Get the stages based on the current status
    get pathStages() {
        if (this.currentStatus === 'Cancelled') {
            // If the current status is 'Cancelled', show 'Cancelled' and remove 'Completed'
            return this.allStages.filter(stage => stage !== 'Completed' && stage !== 'Half Executed');
        } else {
            // Otherwise, show 'Completed' and exclude 'Cancelled'
            return this.allStages.filter(stage => stage !== 'Cancelled');
        }
    }

    // Dynamically set the class based on the current status
    getStageClass(stage) {
        const currentIndex = this.pathStages.indexOf(this.currentStatus);
        const stageIndex = this.pathStages.indexOf(stage);

        // If the current status is "Cancelled", make all previous statuses disabled
        if (this.currentStatus === 'Cancelled') {
            if (stage === 'Cancelled') {
                return 'path-step status-cancelled';  // Red background for Cancelled
            } else {
                return 'path-step status-disabled';  // Gray for all other statuses
            }
        } else if (stageIndex < currentIndex) {
            return 'path-step status-previous'; // Green for previous statuses if status is not Cancelled
        } else if (stageIndex === currentIndex) {
            return 'path-step status-current'; // Blue for the current status
        } else {
            return 'path-step status-disabled';  // Gray for future statuses
        }
    }

    // Return computed stages to be used in the template
    get computedStages() {
        return this.pathStages.map(stage => ({
            stage,
            class: this.getStageClass(stage),
        }));
    }
}