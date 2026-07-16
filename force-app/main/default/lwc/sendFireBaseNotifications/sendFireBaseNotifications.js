import { LightningElement, api, wire } from 'lwc';

import sendNotifications from '@salesforce/apex/FireBaseController.sendNotifications';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {CurrentPageReference} from 'lightning/navigation';
export default class SendFireBaseNotifications extends LightningElement {
    notificationSent = false;
    _recordId;

    @api set recordId(value) {
        this._recordId = value;
    }

    get recordId() {
        return this._recordId;
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.recordId;
            console.log(this.recordId);
            if(this.recordId != null){

            sendNotifications({notificationId : this.recordId})
            .then(result => {
                this.notificationSent = true;
            })
            .catch(error => {
                if(error && error.body){
                    const evt = new ShowToastEvent({
                        title: error.body.message,
                        variant: 'error',
                    });
                    this.dispatchEvent(evt);
                }
            });
            }
        }
    }
}