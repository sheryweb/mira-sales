import { LightningElement } from 'lwc';
import getDashboard from '@salesforce/apex/SalesActivityDashboardController.getDashboard';

export default class SalesActivityDashboard extends LightningElement {
    data;
    errorMessage;
    isRefreshing = false;
    lastUpdated = '';

    connectedCallback() {
        this.load();
    }

    async load() {
        this.isRefreshing = true;
        this.errorMessage = undefined;
        try {
            // fresh stamp per call = cache miss every time; refresh always hits the server
            this.data = await getDashboard({ stamp: String(Date.now()) });
            this.lastUpdated = new Date().toLocaleTimeString('en-GB', {
                hour: '2-digit', minute: '2-digit'
            });
        } catch (e) {
            this.errorMessage =
                (e && e.body && e.body.message) || 'The dashboard could not be loaded.';
        } finally {
            this.isRefreshing = false;
        }
    }

    get isLoading() { return this.isRefreshing && !this.data; }
    get hasError() { return Boolean(this.errorMessage); }
    get updatedText() {
        return this.isRefreshing ? 'Refreshing…' : (this.lastUpdated ? `Updated ${this.lastUpdated}` : '');
    }

    handleRefresh() {
        if (this.isRefreshing) return;
        this.load(); // keeps the current numbers on screen while fresh ones arrive
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

    // ---- weekly target leaderboard ---------------------------------------------------

    get leaderboardRows() {
        const inTgt = this.data.inboundTarget || 1;
        const outTgt = this.data.outboundTarget || 1;
        return (this.data.rmRows || [])
            .map((r) => {
                const inPct = Math.min(r.weekInbound / inTgt, 1);
                const outPct = Math.min(r.weekOutbound / outTgt, 1);
                const met = r.weekInbound >= inTgt && r.weekOutbound >= outTgt;
                return {
                    name: r.name,
                    attainment: (inPct + outPct) / 2,
                    inboundDisplay: `${r.weekInbound} / ${inTgt}`,
                    outboundDisplay: `${r.weekOutbound} / ${outTgt}`,
                    inboundBarStyle: `width: ${Math.round(inPct * 100)}%`,
                    outboundBarStyle: `width: ${Math.round(outPct * 100)}%`,
                    inboundBarClass: r.weekInbound >= inTgt ? 'bar-fill met' : 'bar-fill',
                    outboundBarClass: r.weekOutbound >= outTgt ? 'bar-fill met' : 'bar-fill',
                    badgeLabel: met ? 'Target met' : `${Math.round(((inPct + outPct) / 2) * 100)}%`,
                    badgeClass: met ? 'badge met' : 'badge'
                };
            })
            .sort((a, b) => b.attainment - a.attainment || a.name.localeCompare(b.name))
            .map((r, i) => ({ ...r, rank: i + 1 }));
    }
    get hasLeaderboard() { return this.leaderboardRows.length > 0; }
    get targetSummary() {
        return `Every RM's week vs the target of ${this.data.inboundTarget} inbound + ${this.data.outboundTarget} outbound (online counts as inbound)`;
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
