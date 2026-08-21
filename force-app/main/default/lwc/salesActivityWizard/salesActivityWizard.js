import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getInitData from "@salesforce/apex/SalesActivityWizardController.getInitData";
import searchAgencies from "@salesforce/apex/SalesActivityWizardController.searchAgencies";
import searchClients from "@salesforce/apex/SalesActivityWizardController.searchClients";
import saveActivity from "@salesforce/apex/SalesActivityWizardController.saveActivity";

const STEP_ACTIVITY = 1;
const STEP_DETAILS = 2;
const STEP_WHEN = 3;
const STEP_DONE = 4;

const SEARCH_DEBOUNCE_MS = 300;
const DESCRIPTION_MAX = 255;

/** Card copy per known activity; unknown picklist values fall back to a generic card. */
const ACTIVITY_META = {
  "Client Meeting": {
    icon: "utility:people",
    desc: "You met a client — indoor, outdoor or online — introduced via an agency."
  },
  "Agency Briefing": {
    icon: "utility:announcement",
    desc: "You briefed an agency’s agents on projects, inventory or offers."
  }
};

const DURATIONS = [
  { label: "30 min", value: 30 },
  { label: "45 min", value: 45 },
  { label: "1 h", value: 60 },
  { label: "1.5 h", value: 90 },
  { label: "2 h", value: 120 },
  { label: "3 h", value: 180 },
  { label: "Custom", value: "custom" }
];

export default class SalesActivityWizard extends NavigationMixin(
  LightningElement
) {
  step = STEP_ACTIVITY;
  initLoaded = false;

  activities = [];
  types = [];
  rmNames = [];
  outcomes = [];
  projectNames = [];
  otherProjectValue = "";
  weekCount = 0;
  weekInbound = 0;
  weekOutbound = 0;
  inboundTarget = 12;
  outboundTarget = 4;
  userName = "";

  activity = null;
  activityType = null;

  agencyTerm = "";
  agencyResults = [];
  selectedAgency = null;
  clientTerm = "";
  clientResults = [];
  selectedClient = null;

  numberOfAgents = null;
  description = "";
  outcome = null;
  selectedProjects = [];
  otherProject = "";

  rmSearch = "";
  selectedRms = [];

  activityDate = "";
  startTime = "10:00";
  duration = 60;
  customEndTime = "";

  followUpEnabled = false;
  followUpDate = "";
  followUpNote = "";
  savedFollowUp = null;

  recordId = null;
  recordName = "";
  proofFiles = [];

  isBusy = false;
  busyText = "";
  searchSeq = 0;

  connectedCallback() {
    this.activityDate = this.todayIso();
    this.runBusy("Loading…", async () => {
      const d = await getInitData();
      this.activities = d.activities || [];
      this.types = d.types || [];
      this.rmNames = d.rmNames || [];
      this.outcomes = d.outcomes || [];
      this.projectNames = d.projectNames || [];
      this.otherProjectValue =
        d.otherProjectValue || "Other / Upcoming Project";
      this.weekCount = d.weekCount || 0;
      this.weekInbound = d.weekInbound || 0;
      this.weekOutbound = d.weekOutbound || 0;
      this.inboundTarget = d.inboundTarget || 12;
      this.outboundTarget = d.outboundTarget || 4;
      this.userName = d.userName || "";
      this.activityType =
        d.defaultType || (this.types.length ? this.types[0] : null);
      this.initLoaded = true;
    });
  }

  todayIso() {
    const now = new Date();
    const pad = (n) => String(n).padStart(2, "0");
    return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
  }

  // ---- steps ----------------------------------------------------------------

  get isStep1() {
    return this.step === STEP_ACTIVITY;
  }
  get isStep2() {
    return this.step === STEP_DETAILS;
  }
  get isStep3() {
    return this.step === STEP_WHEN;
  }
  get isStep4() {
    return this.step === STEP_DONE;
  }
  get step1Class() {
    return this.stepClass(STEP_ACTIVITY);
  }
  get step2Class() {
    return this.stepClass(STEP_DETAILS);
  }
  get step3Class() {
    return this.stepClass(STEP_WHEN);
  }
  get step4Class() {
    return this.stepClass(STEP_DONE);
  }
  stepClass(n) {
    if (this.step === n) return "step current";
    return this.step > n ? "step done" : "step";
  }

  get weekChipText() {
    return `This week: ${this.weekInbound}/${this.inboundTarget} in · ${this.weekOutbound}/${this.outboundTarget} out`;
  }

  // ---- step 1 : activity ------------------------------------------------------

  get activityCards() {
    return this.activities.map((name) => {
      const meta = ACTIVITY_META[name] || { icon: "utility:event", desc: "" };
      return {
        name,
        icon: meta.icon,
        desc: meta.desc,
        cssClass:
          this.activity === name ? "action-card selected" : "action-card"
      };
    });
  }

  handleActivityPick(event) {
    this.activity = event.currentTarget.dataset.name;
    this.step = STEP_DETAILS;
  }

  get isBriefing() {
    return this.activity === "Agency Briefing";
  }

  // ---- step 2 : details -------------------------------------------------------

  get typeChips() {
    return this.types.map((t) => ({
      value: t,
      cssClass: this.activityType === t ? "chip selected" : "chip"
    }));
  }

  handleTypePick(event) {
    this.activityType = event.currentTarget.dataset.value;
  }

  get detailsTitle() {
    return this.activity || "Details";
  }

  // agency / client type-ahead --------------------------------------------------

  handleAgencyInput(event) {
    this.agencyTerm = event.target.value;
    this.debouncedSearch("agency", this.agencyTerm);
  }

  handleClientInput(event) {
    this.clientTerm = event.target.value;
    this.debouncedSearch("client", this.clientTerm);
  }

  debouncedSearch(kind, term) {
    const seq = ++this.searchSeq;
    if (this.searchTimer) clearTimeout(this.searchTimer);
    if (!term || term.trim().length < 2) {
      if (kind === "agency") this.agencyResults = [];
      else this.clientResults = [];
      return;
    }
    // eslint-disable-next-line @lwc/lwc/no-async-operation -- debounce; the seq guard discards stale results
    this.searchTimer = setTimeout(async () => {
      try {
        const results =
          kind === "agency"
            ? await searchAgencies({ term })
            : await searchClients({ term });
        if (seq !== this.searchSeq) return; // a newer keystroke superseded this one
        if (kind === "agency") this.agencyResults = results;
        else this.clientResults = results;
      } catch (e) {
        this.toast("Search failed", this.errorMessage(e), "error");
      }
    }, SEARCH_DEBOUNCE_MS);
  }

  get showAgencyResults() {
    return !this.selectedAgency && this.agencyResults.length > 0;
  }
  get showClientResults() {
    return !this.selectedClient && this.clientResults.length > 0;
  }

  handleAgencyPick(event) {
    const { id, name } = event.currentTarget.dataset;
    this.selectedAgency = { id, name };
    this.agencyResults = [];
    this.agencyTerm = "";
  }

  handleClientPick(event) {
    const { id, name } = event.currentTarget.dataset;
    this.selectedClient = { id, name };
    this.clientResults = [];
    this.clientTerm = "";
  }

  handleAgencyClear() {
    this.selectedAgency = null;
  }
  handleClientClear() {
    this.selectedClient = null;
  }

  // other detail fields ----------------------------------------------------------

  handleAgentsChange(event) {
    const v = event.target.value;
    this.numberOfAgents = v === "" || v === null ? null : parseInt(v, 10);
  }

  get agentsLabel() {
    return this.isBriefing
      ? "Number of agents briefed"
      : "Number of agents present (optional)";
  }

  handleDescriptionChange(event) {
    this.description = event.target.value || "";
  }

  get descriptionMax() {
    return DESCRIPTION_MAX;
  }
  get descriptionCounter() {
    return `${this.description.length}/${DESCRIPTION_MAX}`;
  }
  get descriptionPlaceholder() {
    return this.isBriefing
      ? "What was presented? Projects covered, agent questions, agreed follow-ups…"
      : "What was discussed? Client interest, units shown, objections, next step…";
  }

  // projects discussed + outcome chips ----------------------------------------------

  get projectChips() {
    return this.projectNames.map((name) => ({
      name,
      cssClass: this.selectedProjects.includes(name) ? "chip selected" : "chip"
    }));
  }

  handleProjectToggle(event) {
    const name = event.currentTarget.dataset.name;
    this.selectedProjects = this.selectedProjects.includes(name)
      ? this.selectedProjects.filter((p) => p !== name)
      : [...this.selectedProjects, name];
  }

  get isOtherProjectPicked() {
    return this.selectedProjects.includes(this.otherProjectValue);
  }

  handleOtherProjectChange(event) {
    this.otherProject = event.target.value || "";
  }

  get outcomeChips() {
    return this.outcomes.map((name) => ({
      name,
      cssClass: this.outcome === name ? "chip selected" : "chip"
    }));
  }

  handleOutcomePick(event) {
    this.outcome = event.currentTarget.dataset.name;
  }

  // RMs attended type-ahead --------------------------------------------------------

  handleRmSearch(event) {
    this.rmSearch = event.target.value || "";
  }

  get rmOptions() {
    const term = this.rmSearch.trim().toLowerCase();
    if (!term) return [];
    return this.rmNames
      .filter(
        (n) => n.toLowerCase().includes(term) && !this.selectedRms.includes(n)
      )
      .slice(0, 8)
      .map((n) => ({ name: n }));
  }

  get showRmOptions() {
    return this.rmOptions.length > 0;
  }

  handleRmPick(event) {
    this.selectedRms = [...this.selectedRms, event.currentTarget.dataset.name];
    this.rmSearch = "";
  }

  handleRmRemove(event) {
    const name = event.currentTarget.dataset.name;
    this.selectedRms = this.selectedRms.filter((n) => n !== name);
  }

  get rmChips() {
    return this.selectedRms.map((name) => ({ name }));
  }
  get hasRmChips() {
    return this.selectedRms.length > 0;
  }

  // details validation ---------------------------------------------------------------

  get detailsInvalid() {
    return this.detailsHint !== "";
  }

  get detailsHint() {
    if (!this.selectedAgency) return "Select the agency to continue.";
    if (this.isBriefing && (!this.numberOfAgents || this.numberOfAgents < 1)) {
      return "Enter how many agents attended.";
    }
    if (this.isOtherProjectPicked && !this.otherProject.trim()) {
      return "Name the project that is not in the list.";
    }
    if (!this.outcome) return "Pick an outcome — how did it go?";
    return "";
  }

  handleBackToActivity() {
    this.step = STEP_ACTIVITY;
  }
  handleToWhen() {
    if (this.detailsInvalid) return;
    this.step = STEP_WHEN;
  }

  // ---- step 3 : when ------------------------------------------------------------

  handleDateChange(event) {
    this.activityDate = event.target.value;
  }
  handleStartTimeChange(event) {
    this.startTime = event.target.value;
  }
  handleCustomEndChange(event) {
    this.customEndTime = event.target.value;
  }

  get durationChips() {
    return DURATIONS.map((d) => ({
      ...d,
      cssClass: this.duration === d.value ? "chip selected" : "chip"
    }));
  }

  handleDurationPick(event) {
    const raw = event.currentTarget.dataset.value;
    this.duration = raw === "custom" ? "custom" : parseInt(raw, 10);
  }

  get isCustomDuration() {
    return this.duration === "custom";
  }

  get startDate() {
    if (!this.activityDate || !this.startTime) return null;
    const d = new Date(`${this.activityDate}T${this.startTime}`);
    return isNaN(d.getTime()) ? null : d;
  }

  get endDate() {
    const start = this.startDate;
    if (!start) return null;
    if (this.isCustomDuration) {
      if (!this.customEndTime) return null;
      const end = new Date(`${this.activityDate}T${this.customEndTime}`);
      return isNaN(end.getTime()) ? null : end;
    }
    return new Date(start.getTime() + this.duration * 60000);
  }

  handleFollowUpToggle(event) {
    this.followUpEnabled = event.target.checked;
    if (this.followUpEnabled && !this.followUpDate) {
      const d = new Date();
      d.setDate(d.getDate() + 3);
      const pad = (n) => String(n).padStart(2, "0");
      this.followUpDate = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
    }
  }

  handleFollowUpDateChange(event) {
    this.followUpDate = event.target.value;
  }
  handleFollowUpNoteChange(event) {
    this.followUpNote = event.target.value || "";
  }

  get followUpInPast() {
    return (
      this.followUpEnabled &&
      this.followUpDate &&
      this.followUpDate < this.todayIso()
    );
  }

  get whenInvalid() {
    return this.whenHint !== "";
  }

  get whenHint() {
    if (!this.startDate) return "Set the date and start time.";
    if (!this.endDate) return "Set the end time.";
    if (this.endDate <= this.startDate)
      return "The end time must be after the start time.";
    if (this.followUpEnabled && !this.followUpDate)
      return "Pick the follow-up date.";
    if (this.followUpInPast) return "The follow-up date cannot be in the past.";
    return "";
  }

  get summaryText() {
    const start = this.startDate;
    const end = this.endDate;
    if (!start || !end || end <= start) return "";
    const day = start.toLocaleDateString("en-GB", {
      weekday: "short",
      day: "numeric",
      month: "short"
    });
    const t = (d) =>
      d.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
    const mins = Math.round((end - start) / 60000);
    const dur =
      mins >= 60
        ? `${Math.floor(mins / 60)}h${mins % 60 ? " " + (mins % 60) + "m" : ""}`
        : `${mins}m`;
    const who = this.selectedAgency ? this.selectedAgency.name : "";
    return `${this.activity} · ${this.activityType} · ${who} · ${day}, ${t(start)}–${t(end)} (${dur})`;
  }

  handleBackToDetails() {
    this.step = STEP_DETAILS;
  }

  // ---- save ---------------------------------------------------------------------

  handleSave() {
    if (this.whenInvalid) return;
    const input = {
      activity: this.activity,
      activityType: this.activityType,
      agencyId: this.selectedAgency ? this.selectedAgency.id : null,
      clientId: this.selectedClient ? this.selectedClient.id : null,
      description: this.description,
      startDateTime: this.startDate.toISOString(),
      endDateTime: this.endDate.toISOString(),
      numberOfAgents: this.numberOfAgents,
      rmsAttended: this.selectedRms,
      outcome: this.outcome,
      projectsDiscussed: this.selectedProjects,
      otherProject: this.otherProject,
      followUpDate: this.followUpEnabled ? this.followUpDate : null,
      followUpNote: this.followUpEnabled ? this.followUpNote : null
    };
    this.runBusy("Saving your activity…", async () => {
      const r = await saveActivity({ input });
      this.recordId = r.recordId;
      this.recordName = r.recordName;
      this.weekCount = r.weekCount;
      this.weekInbound = r.weekInbound || 0;
      this.weekOutbound = r.weekOutbound || 0;
      this.inboundTarget = r.inboundTarget || this.inboundTarget;
      this.outboundTarget = r.outboundTarget || this.outboundTarget;
      this.savedFollowUp = r.followUpDate || null;
      this.step = STEP_DONE;
    });
  }

  get doneTitle() {
    return `Activity ${this.recordName} saved`;
  }
  get targetsMet() {
    return (
      this.weekInbound >= this.inboundTarget &&
      this.weekOutbound >= this.outboundTarget
    );
  }
  get doneMessage() {
    const n = this.weekCount;
    const praise = this.targetsMet
      ? "Weekly target met — brilliant!"
      : n >= 10
        ? "Great momentum!"
        : n >= 5
          ? "Nice pace!"
          : "";
    const followUp = this.savedFollowUp
      ? ` A follow-up task is set for ${this.savedFollowUp}.`
      : "";
    return `That's ${n} activit${n === 1 ? "y" : "ies"} logged this week.${followUp} ${praise}`.trim();
  }
  get targetBars() {
    const bar = (id, label, count, target) => ({
      id,
      count,
      target,
      label: `${label} · ${count} of ${target}`,
      barClass: count >= target ? "target-fill met" : "target-fill",
      barStyle: `width: ${Math.min(Math.round((count / (target || 1)) * 100), 100)}%`
    });
    return [
      bar("inbound", "Inbound", this.weekInbound, this.inboundTarget),
      bar("outbound", "Outbound", this.weekOutbound, this.outboundTarget)
    ];
  }

  get proofFormats() {
    return [".jpg", ".jpeg", ".png", ".heic", ".webp", ".pdf"];
  }
  get hasProofFiles() {
    return this.proofFiles.length > 0;
  }

  handleProofUploaded(event) {
    const names = (event.detail.files || []).map((f) => f.name);
    this.proofFiles = [...this.proofFiles, ...names];
    this.toast(
      "Photos attached",
      `${names.length} file${names.length === 1 ? "" : "s"} saved to ${this.recordName}.`,
      "success"
    );
  }

  handleOpenRecord() {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: { recordId: this.recordId, actionName: "view" }
    });
  }

  handleLogAnother() {
    this.activity = null;
    this.selectedAgency = null;
    this.selectedClient = null;
    this.agencyTerm = "";
    this.clientTerm = "";
    this.agencyResults = [];
    this.clientResults = [];
    this.numberOfAgents = null;
    this.description = "";
    this.outcome = null;
    this.selectedProjects = [];
    this.otherProject = "";
    this.selectedRms = [];
    this.rmSearch = "";
    this.activityDate = this.todayIso();
    this.startTime = "10:00";
    this.duration = 60;
    this.customEndTime = "";
    this.followUpEnabled = false;
    this.followUpDate = "";
    this.followUpNote = "";
    this.savedFollowUp = null;
    this.recordId = null;
    this.recordName = "";
    this.proofFiles = [];
    this.step = STEP_ACTIVITY;
  }

  // ---- plumbing -------------------------------------------------------------------

  async runBusy(text, work) {
    this.isBusy = true;
    this.busyText = text;
    try {
      await work();
    } catch (e) {
      this.toast("Something went wrong", this.errorMessage(e), "error");
    } finally {
      this.isBusy = false;
    }
  }

  errorMessage(e) {
    return (
      (e && e.body && e.body.message) || (e && e.message) || "Unknown error"
    );
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
