import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import getFormDefaults from "@salesforce/apex/NGeniusPaymentLinkController.getFormDefaults";
import createPaymentLink from "@salesforce/apex/NGeniusPaymentLinkController.createPaymentLink";
import getRecentLinks from "@salesforce/apex/NGeniusPaymentLinkController.getRecentLinks";

const RECENT_COLUMNS = [
  { label: "Link", fieldName: "Name", initialWidth: 110 },
  { label: "Recipient", fieldName: "Recipient_Name__c" },
  { label: "Email", fieldName: "Recipient_Email__c" },
  {
    label: "Amount",
    fieldName: "Amount__c",
    type: "number",
    typeAttributes: { minimumFractionDigits: 2 },
    cellAttributes: { alignment: "right" }
  },
  { label: "Currency", fieldName: "Currency_Code__c", initialWidth: 100 },
  { label: "Status", fieldName: "Status__c", initialWidth: 110 },
  {
    label: "Expires",
    fieldName: "Expiry_Date__c",
    type: "date-local",
    initialWidth: 120
  },
  {
    type: "action",
    typeAttributes: {
      rowActions: [
        { label: "Copy payment link", name: "copy" },
        { label: "Open record", name: "open" }
      ]
    }
  }
];

export default class NGeniusPaymentLink extends NavigationMixin(
  LightningElement
) {
  defaults;
  defaultsError;
  recentLinks = [];
  recentColumns = RECENT_COLUMNS;
  wiredLinksResult;

  form = {};
  isWorking = false;
  result;
  errorText;

  @wire(getFormDefaults)
  wiredDefaults({ error, data }) {
    if (data) {
      this.defaults = data;
      this.form = {
        countryCode: data.defaultCountryCode,
        currencyCode: data.defaultCurrency,
        expiryDate: data.defaultExpiryDate
      };
    } else if (error) {
      this.defaultsError = this.extractError(error);
    }
  }

  @wire(getRecentLinks, { recordLimit: 10 })
  wiredLinks(value) {
    this.wiredLinksResult = value;
    if (value.data) {
      this.recentLinks = value.data;
    }
  }

  // ---- state ------------------------------------------------------------------

  get isLoadingDefaults() {
    return !this.defaults && !this.defaultsError;
  }
  get showNotConfigured() {
    return Boolean(
      this.defaultsError || (this.defaults && !this.defaults.configured)
    );
  }
  get configErrorText() {
    return (
      this.defaultsError ||
      (this.defaults && this.defaults.configError) ||
      "N-Genius configuration could not be loaded."
    );
  }
  get showNoPermission() {
    return Boolean(
      this.defaults && this.defaults.configured && !this.defaults.canGenerate
    );
  }
  get showForm() {
    return Boolean(
      this.defaults &&
      this.defaults.configured &&
      this.defaults.canGenerate &&
      !this.result
    );
  }
  get showSuccess() {
    return Boolean(this.result);
  }
  get showSandboxBadge() {
    return Boolean(
      this.defaults && this.defaults.environmentName !== "Production"
    );
  }
  get sandboxBadgeLabel() {
    return `${(this.defaults && this.defaults.environmentName) || "Sandbox"} — test links only`;
  }
  get hasRecent() {
    return this.recentLinks.length > 0;
  }
  get currencyOptions() {
    return (this.defaults && this.defaults.currencyOptions) || [];
  }
  get todayIso() {
    const now = new Date();
    const pad = (n) => String(n).padStart(2, "0");
    return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
  }
  get smsResultText() {
    return this.result && this.result.smsSent
      ? "An SMS with the link was also sent."
      : "No mobile was supplied, so no SMS was sent.";
  }

  // ---- form -------------------------------------------------------------------

  handleField(event) {
    this.form = {
      ...this.form,
      [event.target.dataset.field]: event.target.value
    };
  }

  async generate() {
    this.errorText = undefined;
    const inputs = [
      ...this.template.querySelectorAll(
        "lightning-input, lightning-combobox, lightning-textarea"
      )
    ];
    const allValid = inputs.reduce((ok, el) => el.reportValidity() && ok, true);
    if (!allValid) {
      return;
    }

    this.isWorking = true;
    try {
      // Keys must match NGeniusPaymentLinkController.LinkRequest exactly.
      const request = {
        firstName: this.form.firstName,
        lastName: this.form.lastName,
        email: this.form.email,
        countryCode: this.form.countryCode,
        mobile: this.form.mobile,
        amount: this.form.amount,
        currencyCode: this.form.currencyCode,
        expiryDate: this.form.expiryDate,
        description: this.form.description,
        referenceNote: this.form.referenceNote,
        message: this.form.message
      };
      const outcome = await createPaymentLink({ request });
      if (!outcome.success) {
        // Gateway-side failure: the controller returns (not throws) so the Error
        // audit record survives the transaction. Render it like any other error.
        this.showError(outcome.errorMessage);
        return;
      }
      this.result = outcome;
      this.toast(
        "Payment link sent",
        `N-Genius emailed the link to ${this.result.recipientEmail}.`,
        "success"
      );
      refreshApex(this.wiredLinksResult);
    } catch (e) {
      this.showError(this.extractError(e));
    } finally {
      this.isWorking = false;
    }
  }

  showError(message) {
    this.errorText = message;
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Payment link failed",
        message,
        variant: "error",
        mode: "sticky"
      })
    );
  }

  createAnother() {
    this.result = undefined;
    this.errorText = undefined;
    this.form = {
      countryCode: this.defaults.defaultCountryCode,
      currencyCode: this.defaults.defaultCurrency,
      expiryDate: this.defaults.defaultExpiryDate
    };
  }

  // ---- success actions -----------------------------------------------------------

  copyResultLink() {
    this.copyToClipboard(this.result.paymentUrl);
  }

  openAuditRecord() {
    if (!this.result || !this.result.recordId) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: { recordId: this.result.recordId, actionName: "view" }
    });
  }

  // ---- recent links ---------------------------------------------------------------

  handleRowAction(event) {
    const action = event.detail.action.name;
    const row = event.detail.row;
    if (action === "copy") {
      this.copyToClipboard(row.Payment_URL__c);
    } else if (action === "open") {
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: { recordId: row.Id, actionName: "view" }
      });
    }
  }

  refreshRecent() {
    if (this.wiredLinksResult) {
      refreshApex(this.wiredLinksResult);
    }
  }

  // ---- helpers -----------------------------------------------------------------------

  async copyToClipboard(text) {
    if (!text) {
      this.toast(
        "Nothing to copy",
        "This row has no payment link stored.",
        "warning"
      );
      return;
    }
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(text);
      } else {
        this.execCommandCopy(text);
      }
      this.toast("Copied", "Payment link copied to the clipboard.", "success");
    } catch {
      // Some contexts block the async clipboard API — fall back before giving up.
      try {
        this.execCommandCopy(text);
        this.toast(
          "Copied",
          "Payment link copied to the clipboard.",
          "success"
        );
      } catch {
        this.toast(
          "Copy failed",
          "Select the link text and copy it manually.",
          "warning"
        );
      }
    }
  }

  execCommandCopy(text) {
    const area = document.createElement("textarea");
    area.value = text;
    document.body.appendChild(area);
    area.select();
    document.execCommand("copy");
    document.body.removeChild(area);
  }

  /** Apex errors arrive in several shapes — normalise them all to one string. */
  extractError(error) {
    if (!error) {
      return "Unknown error.";
    }
    if (Array.isArray(error.body)) {
      return error.body.map((e) => e.message).join(" ");
    }
    if (
      error.body &&
      Array.isArray(error.body.pageErrors) &&
      error.body.pageErrors.length
    ) {
      return error.body.pageErrors.map((e) => e.message).join(" ");
    }
    if (error.body && error.body.message) {
      return error.body.message;
    }
    if (error.message) {
      return error.message;
    }
    return "Unknown error.";
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
