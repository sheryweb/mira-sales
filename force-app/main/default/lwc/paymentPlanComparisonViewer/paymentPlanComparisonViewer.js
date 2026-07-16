import { LightningElement, api, track, wire } from 'lwc';
import getPaymentPlanComparison from '@salesforce/apex/PaymentPlanApprovalController.getPaymentPlanComparison';

export default class PaymentPlanComparisonViewer extends LightningElement {
    @api recordId;

    @track comparison = null;
    @track error = null;
    @track loading = true;
    @track _wired = false;

    @wire(getPaymentPlanComparison, { approvalRequestId: '$recordId' })
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
        return this.comparison !== null && this.comparison !== undefined && !this.comparison.notApplicable;
    }

    get isNotApplicable() {
        return this._wired && !this.loading && this.comparison !== null && this.comparison !== undefined && this.comparison.notApplicable === true;
    }

    get notApplicableReason() {
        if (this.comparison && this.comparison.notApplicableReason) {
            return this.comparison.notApplicableReason;
        }
        return 'This record does not have payment plan comparison data.';
    }

    get showViewer() {
        if (this.loading) {
            return false;
        }
        if (this.isNotApplicable) {
            return false;
        }
        return this.hasData || !!this.error;
    }

    get currentLines() {
        if (!this.comparison || !this.comparison.currentLines) return [];
        return this.comparison.currentLines.map((line, i) => ({
            key: 'curr-' + i,
            milestoneName: line.milestoneName || '',
            installmentDate: line.installmentDate || '',
            changeType: line.changeType || 'unchanged',
            rowClass: this.rowClass(line.changeType),
            badge: this.changeBadge(line.changeType),
            hasBadge: line.changeType !== 'unchanged',
            percentDisplay: line.percent != null ? (line.percent + '%') : '\u2014',
            amountDisplay: this.formatAmountDisplay(line.amount, line.constantAmount),
            dateDisplay: line.installmentDate || '\u2014'
        }));
    }

    get proposedLines() {
        if (!this.comparison || !this.comparison.proposedLines) return [];
        return this.comparison.proposedLines.map((line, i) => ({
            key: 'prop-' + i,
            milestoneName: line.milestoneName || '',
            installmentDate: line.installmentDate || '',
            changeType: line.changeType || 'unchanged',
            rowClass: this.rowClass(line.changeType),
            badge: this.changeBadge(line.changeType),
            hasBadge: line.changeType !== 'unchanged',
            percentDisplay: line.percent != null ? (line.percent + '%') : '\u2014',
            amountDisplay: this.formatAmountDisplay(line.amount, line.constantAmount),
            dateDisplay: line.installmentDate || '\u2014'
        }));
    }

    formatAmountDisplay(amount, constantAmount) {
        const value = amount != null ? amount : constantAmount;
        if (value == null || value === '') {
            return '\u2014';
        }
        return (
            'AED ' +
            Number(value).toLocaleString(undefined, {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            })
        );
    }

    get currentCount() {
        return this.comparison && this.comparison.currentLines ? this.comparison.currentLines.length : 0;
    }

    get proposedCount() {
        return this.comparison && this.comparison.proposedLines ? this.comparison.proposedLines.length : 0;
    }

    get changesSummary() {
        if (!this.comparison) return '';
        var currLines = this.comparison.currentLines || [];
        var propLines = this.comparison.proposedLines || [];
        var added   = propLines.filter(function(l) { return l.changeType === 'added'; }).length;
        var updated = currLines.filter(function(l) { return l.changeType === 'updated'; }).length;
        var deleted = currLines.filter(function(l) { return l.changeType === 'deleted'; }).length;
        var parts = [];
        if (added)   parts.push(added   + ' added');
        if (updated) parts.push(updated + ' updated');
        if (deleted) parts.push(deleted + ' deleted');
        return parts.length ? parts.join(' \u00b7 ') : 'No changes';
    }

    get showChangesOnlyNote() {
        return this.comparison && this.comparison.changesOnly === true;
    }

    get changesOnlyNote() {
        if (!this.comparison || !this.comparison.changesOnly) {
            return '';
        }
        const total = this.comparison.totalInstallmentCount;
        if (total != null && total > 0) {
            return `Showing only changed installments (${this.changesSummary}). This unit has ${total} total installments.`;
        }
        return `Showing only changed installments (${this.changesSummary}).`;
    }

    get unitTitle()    { return this.comparison && this.comparison.unitInfo ? this.comparison.unitInfo.title       : ''; }
    get unitProject()  { return this.comparison && this.comparison.unitInfo ? this.comparison.unitInfo.projectName : ''; }
    get unitBuilding() { return this.comparison && this.comparison.unitInfo ? this.comparison.unitInfo.building    : ''; }
    get unitAccount()  { return this.comparison && this.comparison.unitInfo ? this.comparison.unitInfo.accountName : ''; }

    rowClass(changeType) {
        if (changeType === 'deleted') return 'row-deleted';
        if (changeType === 'updated') return 'row-updated';
        if (changeType === 'added')   return 'row-added';
        return '';
    }

    changeBadge(changeType) {
        if (changeType === 'deleted') return 'Delete';
        if (changeType === 'updated') return 'Update';
        if (changeType === 'added')   return 'New';
        return '';
    }
}