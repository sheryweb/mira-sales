import { LightningElement, api } from "lwc";
import FORM_FACTOR from "@salesforce/client/formFactor";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import generatePdf from "@salesforce/apex/UnitGeneratePdfActionController.generatePdf";
import getDefaultEmail from "@salesforce/apex/SalesOfferEmailController.getDefaultEmail";
import emailOffer from "@salesforce/apex/SalesOfferEmailController.emailOffer";

export default class GenerateSalesOfferPDF extends LightningElement {
  showSpinner = false;
  contentDocumentId = null;
  showEmailBox = false;
  emailAddress = "";
  _recordId;
  @api set recordId(value) {
    this._recordId = value;
  }

  get recordId() {
    return this._recordId;
  }

  // Email is the mobile app's substitute for a real download: the Android app
  // cannot save files to the device, and offers must stay behind login (no
  // public links). Desktop's preview downloads fine, so it stays uncluttered.
  get showEmailAction() {
    return this.contentDocumentId != null && FORM_FACTOR !== "Large";
  }

  generate() {
    if (this.recordId != null) {
      this.showSpinner = true;
      this.contentDocumentId = null;
      this.showEmailBox = false;
      generatePdf({ recordId: this.recordId })
        .then((result) => {
          this.contentDocumentId = result;
          const filepreviewEvent = new CustomEvent("filepreviewaura", {
            detail: {
              recordIds: [result],
              selectedRecordId: result
            },
            bubbles: true,
            composed: true
          });
          this.dispatchEvent(filepreviewEvent);
          this.showSpinner = false;
        })
        .catch((error) => {
          this.showSpinner = false;
          if (error && error.body) {
            const evt = new ShowToastEvent({
              title: error.body.message,
              variant: "error"
            });
            this.dispatchEvent(evt);
          }
        });
    }
  }

  async openEmailBox() {
    if (!this.emailAddress) {
      try {
        this.emailAddress = await getDefaultEmail();
      } catch {
        this.emailAddress = "";
      }
    }
    this.showEmailBox = true;
  }

  handleEmailChange(event) {
    this.emailAddress = event.detail.value;
  }

  closeEmailBox() {
    this.showEmailBox = false;
  }

  // The overlay closes on tap; taps inside the box must not bubble up to it.
  stopClick(event) {
    event.stopPropagation();
  }

  sendEmail() {
    const toAddress = (this.emailAddress || "").trim();
    this.showSpinner = true;
    emailOffer({ contentDocumentId: this.contentDocumentId, toAddress })
      .then(() => {
        this.showSpinner = false;
        this.showEmailBox = false;
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Email sent",
            message: "The sales offer PDF was sent to " + toAddress + ".",
            variant: "success"
          })
        );
      })
      .catch((error) => {
        this.showSpinner = false;
        const message =
          (error && error.body && error.body.message) || "Unknown error";
        this.dispatchEvent(
          new ShowToastEvent({
            title: message,
            variant: "error"
          })
        );
      });
  }
}
