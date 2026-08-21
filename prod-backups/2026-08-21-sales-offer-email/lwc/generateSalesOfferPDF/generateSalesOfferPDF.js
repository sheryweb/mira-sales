import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import generatePdf from "@salesforce/apex/UnitGeneratePdfActionController.generatePdf";

export default class GenerateSalesOfferPDF extends LightningElement {
  showSpinner = false;
  _recordId;
  @api set recordId(value) {
    this._recordId = value;
  }

  get recordId() {
    return this._recordId;
  }

  generate() {
    if (this.recordId != null) {
      this.showSpinner = true;
      generatePdf({ recordId: this.recordId })
        .then((result) => {
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
}
