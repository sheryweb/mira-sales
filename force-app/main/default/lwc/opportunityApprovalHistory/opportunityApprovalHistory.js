import { LightningElement, api, wire, track } from 'lwc';
import getApprovalHistory from '@salesforce/apex/OpportunityApprovalHistoryController.getApprovalHistory';

const STATUS_THEME = {
    Approved: 'slds-theme_success',
    Applied: 'slds-theme_success',
    Rejected: 'slds-theme_error',
    Pending: 'slds-theme_warning',
    Draft: 'slds-theme_shade'
};

const STEP_META = {
    Started: { label: 'Submitted', icon: 'utility:send', variant: '' },
    Approved: { label: 'Approved', icon: 'utility:success', variant: 'slds-text-color_success' },
    Rejected: { label: 'Rejected', icon: 'utility:close', variant: 'slds-text-color_error' },
    Pending: { label: 'Awaiting approval', icon: 'utility:clock', variant: '' },
    Reassigned: { label: 'Reassigned', icon: 'utility:share', variant: '' },
    Removed: { label: 'Recalled', icon: 'utility:undo', variant: '' },
    NoResponse: { label: 'No response', icon: 'utility:warning', variant: '' }
};

export default class OpportunityApprovalHistory extends LightningElement {
    @api recordId;
    @track requests = [];
    error;
    isLoading = true;
    _wiredResult;

    @wire(getApprovalHistory, { opportunityId: '$recordId' })
    wiredHistory(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.requests = data.map((req, index) => this.decorate(req, index));
            this.error = undefined;
        } else if (error) {
            this.error = this.reduceError(error);
            this.requests = [];
        }
        this.isLoading = false;
    }

    decorate(req, index) {
        const key = req.id || `req-${index}`;
        return {
            ...req,
            key,
            badgeClass: `slds-badge ${STATUS_THEME[req.status] || 'slds-theme_shade'}`,
            expanded: false,
            buttonLabel: 'Show timeline',
            buttonIcon: 'utility:chevronright',
            hasSteps: Array.isArray(req.steps) && req.steps.length > 0,
            steps: (req.steps || []).map((step, j) => {
                const meta = STEP_META[step.action] || { label: step.action, icon: 'utility:record', variant: '' };
                return {
                    key: `${key}-${j}`,
                    label: meta.label,
                    icon: meta.icon,
                    variant: meta.variant,
                    actorName: step.actorName,
                    actionDate: step.actionDate,
                    comments: step.comments,
                    hasComment: !!step.comments
                };
            })
        };
    }

    toggle(event) {
        const key = event.currentTarget.dataset.key;
        this.requests = this.requests.map((req) => {
            if (req.key !== key) {
                return req;
            }
            const expanded = !req.expanded;
            return {
                ...req,
                expanded,
                buttonLabel: expanded ? 'Hide timeline' : 'Show timeline',
                buttonIcon: expanded ? 'utility:chevrondown' : 'utility:chevronright'
            };
        });
    }

    get hasRequests() {
        return this.requests && this.requests.length > 0;
    }

    get showEmpty() {
        return !this.isLoading && !this.error && !this.hasRequests;
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
    }
}