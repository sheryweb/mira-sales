import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { getRecord } from 'lightning/uiRecordApi';
import getShareDealInfo from '@salesforce/apex/ShareDealApprovalController.getShareDealInfo';

export default class ShareDealBanner extends LightningElement {
    @api recordId;

    @track shareDeal = false;
    @track sharedRmName;
    @track ownerName;
    @track shareDealStatus;
    @track loaded = false;

    _wiredOpp;

    // Refresh banner when Opportunity record changes (e.g. after approval apply).
    @wire(getRecord, { recordId: '$recordId', fields: ['Opportunity.Id'] })
    wiredOpp(value) {
        this._wiredOpp = value;
        if (value.data || value.error) {
            this.loadFromApex();
        }
    }

    connectedCallback() {
        this.loadFromApex();
    }

    async loadFromApex() {
        if (!this.recordId) {
            return;
        }
        try {
            const info = await getShareDealInfo({ opportunityId: this.recordId });
            if (!info) {
                this.loaded = true;
                return;
            }
            this.shareDeal = info.shareDeal === true;
            this.sharedRmName = info.sharedRmName;
            this.ownerName = info.ownerName;
            this.shareDealStatus = info.shareDealStatus;
        } catch (e) {
            // Keep prior state if Apex fails.
        } finally {
            this.loaded = true;
        }
    }

    @api
    async refresh() {
        if (this._wiredOpp) {
            await refreshApex(this._wiredOpp);
        }
        await this.loadFromApex();
    }

    get showBanner() {
        return this.loaded && (this.shareDeal || this.shareDealStatus === 'Pending');
    }

    get isApprovedShare() {
        return this.shareDeal === true;
    }

    get isPending() {
        return !this.isApprovedShare && this.shareDealStatus === 'Pending';
    }

    get bannerClass() {
        if (this.isPending) {
            return 'share-banner share-banner_pending';
        }
        return 'share-banner share-banner_approved';
    }

    get titleText() {
        if (this.isPending) {
            return 'Share Deal — Pending Approval';
        }
        return 'Share Deal';
    }

    get detailText() {
        const owner = this.ownerName || 'Owner';
        const shared = this.sharedRmName || 'Shared RM';
        if (this.isPending) {
            return 'Awaiting Manager and CSO approval for 50/50 credit.';
        }
        return `${owner} + ${shared} · 50/50 credit`;
    }

    get iconName() {
        return this.isPending ? 'utility:clock' : 'utility:groups';
    }
}
