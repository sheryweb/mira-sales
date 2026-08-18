import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInitData from '@salesforce/apex/UnitStatusWizardController.getInitData';
import getUnits from '@salesforce/apex/UnitStatusWizardController.getUnits';
import updateStatuses from '@salesforce/apex/UnitStatusWizardController.updateStatuses';

const STEP_ACTION = 1;
const STEP_PROJECT = 2;
const STEP_UNITS = 3;
const STEP_DONE = 4;

const COPY = {
    neutral: {
        heroTitle: 'Release / Block Multiple Units',
        heroSubtitle: 'Choose an operation, pick a project, and update its units in one go.'
    },
    block: {
        heroTitle: 'Block Multiple Units',
        heroSubtitle: 'Take available units off the market in one go.',
        action: 'Block',
        emptyMessage: 'No available units to block in this project.',
        confirmTitle: 'Block these units?',
        confirmQuestion: 'Are you sure you want to block the selected units at once?',
        doneTitle: 'Units blocked',
        doneMessage: 'have been blocked successfully and are no longer available for booking.',
        busy: 'Blocking units…'
    },
    release: {
        heroTitle: 'Release Multiple Units',
        heroSubtitle: 'Put blocked units back on the market in one go.',
        action: 'Release',
        emptyMessage: 'No blocked units to release in this project.',
        confirmTitle: 'Release these units?',
        confirmQuestion: 'Are you sure you want to release the selected units at once?',
        doneTitle: 'Units released',
        doneMessage: 'have been released successfully and are now available for booking.',
        busy: 'Releasing units…'
    }
};

export default class UnitStatusWizard extends LightningElement {
    /** Optional preset: 'block' | 'release'. When set (via flexipage property or the
     *  c__mode URL param) the operation step is skipped and the mode is locked. */
    @api defaultMode;

    mode = null;
    modeLocked = false;
    step = STEP_ACTION;
    accessDenied = false;
    initLoaded = false;

    projects = [];
    selectedProjectId = null;

    units = [];
    unitsLoaded = false;
    selectedIds = new Set();

    updatedCount = 0;
    showConfirm = false;

    isBusy = false;
    busyText = '';

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        const urlMode = pageRef && pageRef.state && pageRef.state.c__mode;
        const preset = (urlMode === 'block' || urlMode === 'release') ? urlMode
            : ((this.defaultMode === 'block' || this.defaultMode === 'release') ? this.defaultMode : null);
        if (preset && !this.mode && this.step === STEP_ACTION) {
            this.mode = preset;
            this.modeLocked = true;
            this.step = STEP_PROJECT;
        }
    }

    connectedCallback() {
        this.runBusy('Loading…', async () => {
            const d = await getInitData();
            this.accessDenied = d.accessDenied;
            this.projects = d.projects || [];
            this.initLoaded = true;
        });
    }

    // ---- copy / derived view state -------------------------------------------

    get copy() { return COPY[this.mode] || COPY.block; }
    get heroCopy() { return this.mode ? COPY[this.mode] : COPY.neutral; }
    get wizardClass() {
        if (!this.mode) return 'wizard mode-neutral';
        return this.mode === 'release' ? 'wizard mode-release' : 'wizard mode-block';
    }
    get heroTitle() { return this.heroCopy.heroTitle; }
    get heroSubtitle() { return this.heroCopy.heroSubtitle; }
    get emptyMessage() { return this.copy.emptyMessage; }
    get confirmTitle() { return this.copy.confirmTitle; }
    get doneTitle() { return this.copy.doneTitle; }
    get againLabel() { return 'Run another operation'; }
    get busyActionText() { return this.copy.busy; }

    get showBody() { return this.initLoaded && !this.accessDenied; }
    get isStepAction() { return this.step === STEP_ACTION; }
    get isStep1() { return this.step === STEP_PROJECT; }
    get isStep2() { return this.step === STEP_UNITS; }
    get isStep3() { return this.step === STEP_DONE; }
    get stepActionClass() { return this.stepClass(STEP_ACTION); }
    get step1Class() { return this.stepClass(STEP_PROJECT); }
    get step2Class() { return this.stepClass(STEP_UNITS); }
    get step3Class() { return this.stepClass(STEP_DONE); }
    stepClass(n) {
        if (this.step === n) return 'step current';
        return this.step > n ? 'step done' : 'step';
    }

    get blockCardClass() { return this.mode === 'block' ? 'action-card selected' : 'action-card'; }
    get releaseCardClass() { return this.mode === 'release' ? 'action-card selected' : 'action-card'; }

    get projectOptions() {
        return this.projects;
    }
    get showProjectBack() { return !this.modeLocked; }
    get selectedProjectName() {
        const p = this.projects.find((x) => x.id === this.selectedProjectId);
        return p ? p.name : '';
    }

    get isMultiTower() {
        const towers = new Set(this.units.map((u) => u.tower).filter(Boolean));
        return towers.size > 1;
    }

    get unitCards() {
        const multiTower = this.isMultiTower;
        return this.units.map((u) => {
            const selected = this.selectedIds.has(u.id);
            const blocked = u.status === 'Blocked';
            const br = u.bedrooms == null ? null
                : (Number(u.bedrooms) === 0 ? 'Studio' : `${Number(u.bedrooms)}BR`);
            return {
                ...u,
                selected,
                cssClass: selected ? 'unit-card selected' : 'unit-card',
                title: multiTower && u.tower ? `${u.tower}-${u.title}` : u.title,
                statusClass: blocked ? 'status-chip blocked' : 'status-chip available',
                codeDisplay: u.propertyCode || '—',
                typeDisplay: u.unitType || '—',
                bedroomsDisplay: br || '—'
            };
        });
    }

    get hasUnits() { return this.unitsLoaded && this.units.length > 0; }
    get totalCount() { return this.units.length; }
    get selectedCount() { return this.selectedIds.size; }
    get selectAllDisabled() { return !this.hasUnits || this.selectedIds.size === this.units.length; }
    get clearDisabled() { return this.selectedIds.size === 0; }
    get actionDisabled() { return this.selectedIds.size === 0; }
    get actionLabel() {
        const n = this.selectedIds.size;
        return n === 0 ? `${this.copy.action} Units`
            : `${this.copy.action} ${n} Unit${n === 1 ? '' : 's'}`;
    }
    get confirmMessage() {
        return `${this.copy.confirmQuestion} ${this.selectedIds.size} unit${this.selectedIds.size === 1 ? '' : 's'} of ${this.selectedProjectName} will be affected.`;
    }
    get confirmButtonLabel() { return `Yes, ${this.copy.action.toLowerCase()} them`; }
    get doneMessage() {
        return `${this.updatedCount} unit${this.updatedCount === 1 ? '' : 's'} of ${this.selectedProjectName} ${this.copy.doneMessage}`;
    }

    // ---- handlers -----------------------------------------------------------

    handleActionPick(event) {
        this.mode = event.currentTarget.dataset.mode;
        this.selectedProjectId = null;
        this.step = STEP_PROJECT;
    }

    handleProjectPick(event) {
        this.selectedProjectId = event.currentTarget.dataset.id;
        this.handleToUnits(); // click = choose and go, same as the operation cards
    }

    handleBackToAction() {
        if (this.modeLocked) return;
        this.mode = null; // back on the chooser, no operation is picked — neutral title/theme
        this.selectedProjectId = null;
        this.step = STEP_ACTION;
    }

    handleToUnits() {
        this.selectedIds = new Set();
        this.unitsLoaded = false;
        this.units = [];
        this.step = STEP_UNITS;
        this.runBusy('Loading units…', async () => {
            this.units = await getUnits({ projectId: this.selectedProjectId, mode: this.mode });
            this.unitsLoaded = true;
        });
    }

    handleBackToProjects() {
        this.step = STEP_PROJECT;
    }

    handleUnitToggle(event) {
        const id = event.currentTarget.dataset.id;
        const next = new Set(this.selectedIds);
        if (next.has(id)) next.delete(id); else next.add(id);
        this.selectedIds = next;
    }

    handleSelectAll() {
        this.selectedIds = new Set(this.units.map((u) => u.id));
    }

    handleClearSelection() {
        this.selectedIds = new Set();
    }

    handleOpenConfirm() {
        if (this.selectedIds.size === 0) {
            this.toast('Nothing selected', 'Please select at least 1 unit in order to proceed.', 'warning');
            return;
        }
        this.showConfirm = true;
    }

    handleCancelConfirm() {
        this.showConfirm = false;
    }

    handleConfirmAction() {
        this.showConfirm = false;
        const unitIds = [...this.selectedIds];
        this.runBusy(this.busyActionText, async () => {
            this.updatedCount = await updateStatuses({ unitIds, mode: this.mode });
            this.step = STEP_DONE;
        });
    }

    handleStartOver() {
        this.selectedIds = new Set();
        this.units = [];
        this.unitsLoaded = false;
        this.updatedCount = 0;
        this.selectedProjectId = null;
        if (this.modeLocked) {
            this.step = STEP_PROJECT;
        } else {
            this.mode = null;
            this.step = STEP_ACTION;
        }
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
