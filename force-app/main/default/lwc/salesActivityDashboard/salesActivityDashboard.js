import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDashboard from '@salesforce/apex/SalesActivityDashboardController.getDashboard';

export default class SalesActivityDashboard extends LightningElement {
    data;
    errorMessage;
    wiredResult;

    @wire(getDashboard)
    wiredDashboard(result) {
        this.wiredResult = result;
        if (result.data) {
            this.data = result.data;
            this.errorMessage = undefined;
        } else if (result.error) {
            this.errorMessage =
                (result.error.body && result.error.body.message) || 'The dashboard could not be loaded.';
        }
    }

    get isLoading() { return !this.data && !this.errorMessage; }
    get hasError() { return Boolean(this.errorMessage); }

    handleRefresh() {
        this.data = undefined;
        refreshApex(this.wiredResult);
    }

    // ---- KPI cards -------------------------------------------------------------

    get kpiCards() {
        const k = this.data.kpis;
        return [
            { id: 'week', label: 'Activities this week', value: k.weekCount, icon: 'utility:event' },
            { id: 'month', label: 'Activities this month', value: k.monthCount, icon: 'utility:date_input' },
            { id: 'hours', label: 'Hours in the field (month)', value: k.monthHours, icon: 'utility:clock' },
            { id: 'rms', label: 'Active RMs this month', value: k.activeRms, icon: 'utility:people' },
            { id: 'covered', label: 'Agencies covered (90 days)', value: `${k.agenciesCovered} / ${k.agenciesTotal}`, icon: 'utility:company' },
            { id: 'attention', label: 'Agencies needing attention', value: k.agenciesAttention, icon: 'utility:warning', warn: k.agenciesAttention > 0 }
        ].map((c) => ({ ...c, cssClass: c.warn ? 'kpi warn' : 'kpi' }));
    }

    // ---- agency attention list ---------------------------------------------------

    get attentionRows() {
        return (this.data.needsAttention || []).map((a) => ({
            ...a,
            lastDisplay: a.lastActivity || 'Never',
            sinceDisplay: a.daysSince == null ? '—' : `${a.daysSince} days ago`,
            rowClass: a.lastActivity ? 'stale' : 'never'
        }));
    }
    get hasAttention() { return this.attentionRows.length > 0; }
    get attentionSummary() {
        const total = this.data.kpis.agenciesAttention;
        const shown = this.attentionRows.length;
        return shown < total
            ? `Showing the ${shown} most urgent of ${total} agencies`
            : `${total} agencies with no activity in the last 60 days`;
    }

    // ---- per-RM matrix -------------------------------------------------------------

    get rmRows() {
        return (this.data.rmRows || []).map((r) => ({
            ...r,
            rowClass: r.weekCount === 0 ? 'quiet' : '',
            hoursDisplay: r.hours
        }));
    }
    get hasRms() { return this.rmRows.length > 0; }

    // ---- outcomes + unlisted projects -----------------------------------------------

    get outcomeRows() {
        const rows = this.data.outcomes || [];
        const max = rows.reduce((m, r) => Math.max(m, r.count), 0) || 1;
        return rows.map((r) => ({
            ...r,
            barStyle: `width: ${Math.round((r.count / max) * 100)}%`
        }));
    }
    get hasOutcomes() { return this.outcomeRows.length > 0; }

    get otherProjectRows() { return this.data.otherProjects || []; }
    get hasOtherProjects() { return this.otherProjectRows.length > 0; }
}
