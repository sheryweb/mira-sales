import { LightningElement, api, wire } from 'lwc';
import getRequestType from '@salesforce/apex/ApprovalComparisonController.getRequestType';

const TYPE_PAYMENT_PLAN = 'Payment Plan Change';
const TYPE_UNIT_PRICE = 'Unit Price Change';
const TYPE_PROFILE = 'Agency Profile Update';
const TYPE_BANK = 'Bank Detail Update';
const TYPE_DOC = 'Document Re-upload';

export default class ApprovalRequestComparisonViewer extends LightningElement {
    @api recordId;

    requestType;
    loading = true;
    error;

    @wire(getRequestType, { recordId: '$recordId' })
    wiredRequestType({ data, error }) {
        this.loading = false;
        if (error) {
            this.error =
                (error.body && error.body.message) || 'Unable to determine approval request type.';
            this.requestType = null;
        } else {
            this.requestType = data;
            this.error = null;
        }
    }

    get isPaymentPlan() {
        return this.requestType === TYPE_PAYMENT_PLAN;
    }

    get isUnitPrice() {
        return this.requestType === TYPE_UNIT_PRICE;
    }

    get isProfile() {
        return this.requestType === TYPE_PROFILE;
    }

    get isBank() {
        return this.requestType === TYPE_BANK;
    }

    get isDoc() {
        return this.requestType === TYPE_DOC;
    }

    get showComparison() {
        return (
            !this.loading &&
            !this.error &&
            (this.isPaymentPlan || this.isUnitPrice || this.isProfile || this.isBank || this.isDoc)
        );
    }
}