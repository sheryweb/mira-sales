import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInitData from '@salesforce/apex/MultiSalesOfferWizardController.getInitData';
import getUnits from '@salesforce/apex/MultiSalesOfferWizardController.getUnits';
import cleanupExistingOffers from '@salesforce/apex/MultiSalesOfferWizardController.cleanupExistingOffers';
import generateOffers from '@salesforce/apex/MultiSalesOfferWizardController.generateOffers';

const STEP_PROJECT = 1;
const STEP_UNITS = 2;
const STEP_RESULT = 3;

export default class MultiSalesOfferWizard extends NavigationMixin(LightningElement) {
    step = STEP_PROJECT;
    accessDenied = false;
    initLoaded = false;

    projectNames = [];
    selectedProject = null;

    currencies = [];
    selectedCurrency = '';
    maxUnits = 15;

    units = [];
    unitsLoaded = false;
    selectedIds = new Set();
    typeFilter = '';

    contentDocumentId = null;
    generatedCount = 0;

    isBusy = false;
    busyText = '';

    connectedCallback() {
        this.runBusy('Loading…', async () => {
            const d = await getInitData();
            this.accessDenied = d.accessDenied;
            this.projectNames = d.projectNames;
            this.selectedProject = d.projectNames[0]; // flow default: first project
            this.currencies = d.currencies || [];
            this.maxUnits = d.maxUnits;
            this.initLoaded = true;
        });
    }

    // ---- derived view state -------------------------------------------------

    get showBody() { return this.initLoaded && !this.accessDenied; }
    get isStep1() { return this.step === STEP_PROJECT; }
    get isStep2() { return this.step === STEP_UNITS; }
    get isStep3() { return this.step === STEP_RESULT; }
    get step1Class() { return this.stepClass(STEP_PROJECT); }
    get step2Class() { return this.stepClass(STEP_UNITS); }
    get step3Class() { return this.stepClass(STEP_RESULT); }
    stepClass(n) {
        if (this.step === n) return 'step current';
        return this.step > n ? 'step done' : 'step';
    }

    get projectOptions() {
        return this.projectNames.map((name) => ({
            name,
            selected: name === this.selectedProject,
            cssClass: name === this.selectedProject ? 'project-card selected' : 'project-card'
        }));
    }

    get nextDisabled() { return !this.selectedProject; }

    get currencyOptions() {
        const opts = this.currencies.map((c) => ({ label: c, value: c }));
        return [{ label: 'None', value: '' }, ...opts];
    }

    /** More than one distinct tower/building among the loaded units? */
    get isMultiTower() {
        const towers = new Set(this.units.map((u) => u.tower).filter(Boolean));
        return towers.size > 1;
    }

    /** 'Studio' for 0 bedrooms, '2BR Duplex' when the type says so — the filter's vocabulary. */
    bedroomTypeLabel(u) {
        if (u.bedrooms == null) return null;
        const br = Number(u.bedrooms) === 0 ? 'Studio' : `${Number(u.bedrooms)}BR`;
        const duplex = (u.unitType || '').toLowerCase().includes('duplex');
        return duplex ? `${br} Duplex` : br;
    }

    /** Unit_Cost__c is 'CCY 1234567.8' text — reformat the number, keep the currency. */
    formatUnitCost(raw) {
        if (!raw) return '—';
        const m = /^([A-Za-z]{3})\s+(-?[\d.]+)$/.exec(raw.trim());
        if (!m) return raw;
        const amount = Number(m[2]);
        if (!amount) return '—';
        return `${m[1].toUpperCase()} ${amount.toLocaleString('en-US', { maximumFractionDigits: 0 })}`;
    }

    get typeFilterOptions() {
        const labels = new Set();
        this.units.forEach((u) => {
            const label = this.bedroomTypeLabel(u);
            if (label) labels.add(label);
        });
        const sorted = [...labels].sort((a, b) => {
            const rank = (l) => (l.startsWith('Studio') ? -1 : parseInt(l, 10));
            return rank(a) - rank(b) || a.localeCompare(b);
        });
        return [{ label: 'All types', value: '' }, ...sorted.map((l) => ({ label: l, value: l }))];
    }

    get unitCards() {
        const atCap = this.selectedIds.size >= this.maxUnits;
        const multiTower = this.isMultiTower;
        return this.units
            .filter((u) => !this.typeFilter || this.bedroomTypeLabel(u) === this.typeFilter)
            .map((u) => {
                const selected = this.selectedIds.has(u.id);
                const blocked = u.status === 'Blocked';
                let cssClass = 'unit-card';
                if (selected) cssClass += ' selected';
                else if (atCap) cssClass += ' capped';
                const bedroomLabel = this.bedroomTypeLabel(u);
                return {
                    ...u,
                    selected,
                    cssClass,
                    title: multiTower && u.tower ? `${u.tower}-${u.title}` : u.title,
                    statusClass: blocked ? 'status-chip blocked' : 'status-chip available',
                    costDisplay: this.formatUnitCost(u.unitCost),
                    typeDisplay: u.unitType || '—',
                    bedroomsDisplay: bedroomLabel || '—',
                    areaDisplay: u.totalArea == null ? '—'
                        : Number(u.totalArea).toLocaleString('en-US', { maximumFractionDigits: 0 }) + ' sqft'
                };
            });
    }

    get hasUnits() { return this.unitsLoaded && this.units.length > 0; }
    get selectedCount() { return this.selectedIds.size; }
    get counterClass() {
        return this.selectedIds.size >= this.maxUnits ? 'count-chip full' : 'count-chip';
    }
    get generateDisabled() { return this.selectedIds.size === 0; }
    get generateLabel() {
        const n = this.selectedIds.size;
        return n === 0 ? 'Generate PDF' : `Generate PDF (${n} unit${n === 1 ? '' : 's'})`;
    }
    get resultSummary() {
        const n = this.generatedCount;
        return `One combined PDF covering ${n} unit${n === 1 ? '' : 's'} of ${this.selectedProject}.`;
    }

    // ---- handlers -----------------------------------------------------------

    handleProjectPick(event) {
        this.selectedProject = event.currentTarget.dataset.name;
    }

    handleToUnits() {
        this.selectedIds = new Set();
        this.selectedCurrency = '';
        this.typeFilter = '';
        this.unitsLoaded = false;
        this.units = [];
        this.step = STEP_UNITS;
        this.runBusy('Loading units…', async () => {
            this.units = await getUnits({ projectName: this.selectedProject });
            this.unitsLoaded = true;
        });
    }

    handleBackToProjects() {
        this.step = STEP_PROJECT;
    }

    handleUnitToggle(event) {
        const id = event.currentTarget.dataset.id;
        const next = new Set(this.selectedIds);
        if (next.has(id)) {
            next.delete(id);
        } else if (next.size >= this.maxUnits) {
            this.toast('Selection limit', `A maximum of ${this.maxUnits} units can be selected in one go.`, 'warning');
            return;
        } else {
            next.add(id);
        }
        this.selectedIds = next;
    }

    handleCurrencyChange(event) {
        this.selectedCurrency = event.detail.value;
    }

    handleTypeFilterChange(event) {
        this.typeFilter = event.detail.value;
    }

    handleGenerate() {
        if (this.selectedIds.size === 0) {
            this.toast('Nothing selected', 'Please select at least 1 unit in order to proceed.', 'warning');
            return;
        }
        const unitIds = [...this.selectedIds];
        this.runBusy('Generating your sales offer PDF…', async () => {
            // Two calls on purpose: the PDF render is a callout and cannot share a
            // transaction with the deletion of the previous offer files.
            await cleanupExistingOffers({ unitIds });
            this.contentDocumentId = await generateOffers({
                unitIds,
                selectedCurrency: this.selectedCurrency,
                projectName: this.selectedProject
            });
            this.generatedCount = unitIds.length;
            this.step = STEP_RESULT;
        });
    }

    handlePreview() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: this.contentDocumentId }
        });
    }

    handleDownload() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/sfc/servlet.shepherd/document/download/${this.contentDocumentId}`
            }
        });
    }

    handleStartOver() {
        this.step = STEP_PROJECT;
        this.selectedIds = new Set();
        this.selectedCurrency = '';
        this.contentDocumentId = null;
        this.units = [];
        this.unitsLoaded = false;
    }

    // ---- plumbing -----------------------------------------------------------

    async runBusy(text, work) {
        this.isBusy = true;
        this.busyText = text;
        try {
            await work();
        } catch (e) {
            this.toast('Something went wrong', this.errorMessage(e), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    errorMessage(e) {
        return (e && e.body && e.body.message) || (e && e.message) || 'Unknown error';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
