import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

const FIELDS = ['Account.Status__c', 'Account.Reason_of_Cancellation__c'];

export default class CancellationReason extends LightningElement {
    @api recordId; // Automatically set when used on a record page
    reason;
    isCancelled = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    accountRecord({ error, data }) {
        if (data) {
            const status = data.fields.Status__c.value;
            this.isCancelled = status === 'Cancelled';
            this.reason = this.isCancelled
                ? data.fields.Reason_of_Cancellation__c.value
                : null;
        } else if (error) {
            console.error('Error fetching Account data', error);
        }
    }
}