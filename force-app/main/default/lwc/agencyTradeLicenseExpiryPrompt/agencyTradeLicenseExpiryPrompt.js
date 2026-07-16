import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAccountTradeLicenseData from '@salesforce/apex/AccountTradeLicenseExpiryController.getAccountTradeLicenseData';
import sendExpiryNotificationEmail from '@salesforce/apex/AgencyTradeLicenseExpiryEmailController.sendExpiryNotificationEmail';

export default class AgencyTradeLicenseExpiryPrompt extends LightningElement {
    @api recordId; // Account ID passed from the record page
    @track accountData;
    @track isLoading = true;
    @track error;
    @track showNotificationButton = false;
    @track messageColor = '';
    @track displayMessage = '';
    @track notificationCount = 0;

    @wire(getAccountTradeLicenseData, { accountId: '$recordId' })
    wiredAccountData({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.accountData = data;
            this.notificationCount = data.notificationCount || 0;
            this.processExpiryData();
        } else if (error) {
            this.error = error;
            console.error('Error loading account data:', error);
        }
    }

    processExpiryData() {
        if (!this.accountData || !this.accountData.tradeLicenseExpiryDate) {
            this.displayMessage = 'No trade license expiry date found for this agency.';
            this.messageColor = 'slds-text-color_weak';
            return;
        }

        const today = new Date();
        const expiryDate = new Date(this.accountData.tradeLicenseExpiryDate);
        
        // Reset time to compare only dates
        today.setHours(0, 0, 0, 0);
        expiryDate.setHours(0, 0, 0, 0);
        
        const timeDiff = expiryDate.getTime() - today.getTime();
        const daysDiff = Math.ceil(timeDiff / (1000 * 3600 * 24));
        
        if (daysDiff > 0) {
            // Greater than current date - Green
            this.displayMessage = `Trade License for this Agency will expire in ${daysDiff} days on ${this.formatDate(expiryDate)}.`;
            this.messageColor = 'slds-text-color_success';
            this.showNotificationButton = false;
        } else if (daysDiff === 0) {
            // Equal to current date - Orange
            this.displayMessage = 'Trade license for this Agency will expire Today.';
            this.messageColor = 'slds-text-color_warning';
            this.showNotificationButton = true;
        } else {
            // Less than current date - Red
            this.displayMessage = `Trade License for this Agency has been expired on ${this.formatDate(expiryDate)}.`;
            this.messageColor = 'slds-text-color_error';
            this.showNotificationButton = true;
        }
    }

    formatDate(date) {
        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    }

    async handleSendNotification() {
        console.log('=== Button Clicked ===');
        console.log('Record ID:', this.recordId);
        
        if (!this.recordId) {
            console.log('❌ No Record ID available');
            this.showToast('Error', 'Account ID not available', 'error');
            return;
        }

        console.log('✅ Record ID available, calling Apex method...');
        
        try {
            console.log('Calling sendExpiryNotificationEmail with accountId:', this.recordId);
            await sendExpiryNotificationEmail({ accountId: this.recordId });
            console.log('✅ Apex method call successful');
            
            // Increment the notification count locally
            this.notificationCount = (this.notificationCount || 0) + 1;
            
            this.showToast('Success', 'Expiry notification email sent successfully', 'success');
        } catch (error) {
            console.log('❌ Apex method call failed:', error);
            console.log('Error details:', JSON.stringify(error, null, 2));
            this.showToast('Error', error.body?.message || error.message || 'An error occurred while sending notification email', 'error');
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}