import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getUnitPaymentPlanLines from '@salesforce/apex/PaymentPlanApprovalController.getUnitPaymentPlanLines';
import getUnitCashFlowSums from '@salesforce/apex/PaymentPlanApprovalController.getUnitCashFlowSums';
import createUnitCashFlowSum from '@salesforce/apex/PaymentPlanApprovalController.createUnitCashFlowSum';
import getOpenPaymentPlanRequestForUnit from '@salesforce/apex/PaymentPlanApprovalController.getOpenPaymentPlanRequestForUnit';
import getApprovalRequestLines from '@salesforce/apex/PaymentPlanApprovalController.getApprovalRequestLines';
import createDraftRequest from '@salesforce/apex/PaymentPlanApprovalController.createDraftRequest';
import saveApprovalLines from '@salesforce/apex/PaymentPlanApprovalController.saveApprovalLines';
import getPaymentPlanApproverOptions from '@salesforce/apex/PaymentPlanApprovalController.getPaymentPlanApproverOptions';
import submitPaymentPlanApproval from '@salesforce/apex/PaymentPlanApprovalController.submitPaymentPlanApproval';

const FEE_MILESTONES = new Set(['Oqood', 'DLD Fee', 'Registration Fee', 'Purchase Taxes']);

export default class PaymentPlanApprovalEditor extends LightningElement {
    @api recordId;

    @track rows = [];
    @track justification = '';
    @track loading = false;
    @track approvalRequestId;
    @track requestStatus = null;
    @track requestStatusLabel = '';
    @track approvalStageLabel = '';
    @track inApprovalProcess = false;
    @track approvalRequestName = '';
    @track showEditorModal = false;
    @track showMainModal = false;
    @track editingRow;
    @track selectedUnitId;
    @track unitCashFlowSums = [];
    @track newCashFlowSumYear = '';
    @track creatingCashFlowSum = false;
    @track showNewYearForm = false;
    @track approverOptions = [];
    @track selectedApproverId;
    @track totalInstallmentCount = 0;
    @track planTruncated = false;

    originalSnapshot = new Map();

    connectedCallback() {
        if (this.recordId) {
            this.selectedUnitId = this.recordId;
            this.loadPaymentPlan();
        }
    }

    get hasUnit() {
        return !!this.selectedUnitId;
    }

    get modalSubtitle() {
        if (this.approvalRequestName) return this.approvalRequestName;
        return 'New Request';
    }

    async handleOpenModal() {
        await this.loadApproverOptions();
        this.showMainModal = true;
    }

    async loadApproverOptions() {
        try {
            const options = await getPaymentPlanApproverOptions();
            this.approverOptions = (options || []).map((option) => ({
                label: option.name,
                value: option.id
            }));
            if (
                this.selectedApproverId &&
                !this.approverOptions.some((option) => option.value === this.selectedApproverId)
            ) {
                this.selectedApproverId = null;
            }
            if (!this.selectedApproverId && this.approverOptions.length === 1) {
                this.selectedApproverId = this.approverOptions[0].value;
            }
        } catch (error) {
            this.approverOptions = [];
            this.showError(error);
        }
    }

    handleApproverChange(event) {
        this.selectedApproverId = event.detail.value;
    }

    get hasApproverOptions() {
        return this.approverOptions.length > 0;
    }

    get disableSubmit() {
        return this.loading || !this.hasApproverOptions;
    }

    handleCloseModal() {
        this.showMainModal = false;
        this.selectedApproverId = null;
    }

    get isReadOnly() {
        return (
            this.inApprovalProcess ||
            (this.approvalRequestId && this.requestStatus && this.requestStatus !== 'Draft')
        );
    }

    get canSubmit() {
        return this.hasUnit && !this.isReadOnly && this.rows.length > 0;
    }

    get showPlanTruncatedWarning() {
        return this.planTruncated && this.hasUnit;
    }

    get planTruncatedMessage() {
        return `This unit has ${this.totalInstallmentCount} installments. Showing the first ${this.rows.length} by date. Edit installments within the loaded list, or contact an administrator if you need access to installments beyond this limit.`;
    }

    get showStatusBanner() {
        if (!this.approvalRequestId) {
            return false;
        }
        return (
            this.inApprovalProcess ||
            this.requestStatus === 'Pending' ||
            this.requestStatus === 'Approved' ||
            this.requestStatus === 'Rejected'
        );
    }

    get showRequestButton() {
        return (
            !this.approvalRequestId ||
            (this.requestStatus === 'Draft' && !this.inApprovalProcess) ||
            this.requestStatus === 'Rejected'
        );
    }

    get statusBannerClass() {
        const base = 'slds-box request-status-box';
        if (this.requestStatus === 'Approved') {
            return `${base} request-status-box--approved`;
        }
        if (this.requestStatus === 'Rejected') {
            return `${base} request-status-box--rejected`;
        }
        return `${base} request-status-box--pending`;
    }

    get statusBannerIcon() {
        if (this.requestStatus === 'Approved') {
            return 'utility:success';
        }
        if (this.requestStatus === 'Rejected') {
            return 'utility:ban';
        }
        return 'utility:clock';
    }

    get displayStatusLabel() {
        return this.requestStatusLabel || this.requestStatus || 'In Progress';
    }

    get approvalRequestUrl() {
        return this.approvalRequestId ? `/${this.approvalRequestId}` : '#';
    }

    get tableRows() {
        return this.rows
            .filter((row) => !row.isRemoved && !row.isExcludedFee)
            .map((row) => ({
                ...row,
                rowClass: row.hasPayments ? 'slds-text-color_weak' : '',
                actionLabel: this.getActionLabel(row),
                percentDisplay: row.percent != null ? `${row.percent}%` : '',
                disableEdit: row.hasPayments || this.isReadOnly,
                disableDelete: row.hasPayments || this.isReadOnly
            }));
    }

    get totalPercent() {
        const total = this.rows
            .filter((row) => !row.isRemoved && !row.isExcludedFee)
            .reduce((sum, row) => sum + (parseFloat(row.percent) || 0), 0);
        return Math.round(total * 100) / 100;
    }

    get percentIsValid() {
        return this.totalPercent === 100;
    }

    get percentSummaryClass() {
        return this.percentIsValid
            ? 'slds-text-color_success slds-text-body_small slds-m-top_x-small'
            : 'slds-text-color_error slds-text-body_small slds-m-top_x-small';
    }

    get percentSummaryIcon() {
        return this.percentIsValid ? 'utility:success' : 'utility:error';
    }

    get editingRowRequiresCashFlowSum() {
        return this.editingRow?.isNew === true;
    }

    get installmentEditorTitle() {
        return this.editingRow?.isNew ? 'Add Installment' : 'Edit Installment';
    }

    get installmentEditorSubtitle() {
        return this.editingRow?.isNew
            ? 'Define the new installment and link it to a Cash Flow Sum year.'
            : 'Update installment details for this payment plan change.';
    }

    get mainModalClass() {
        const base = 'slds-modal slds-fade-in-open slds-modal_large';
        return this.showEditorModal ? `${base} main-modal-hidden` : base;
    }

    get mainModalBackdropClass() {
        const base = 'slds-backdrop slds-backdrop_open';
        return this.showEditorModal ? `${base} main-modal-hidden` : base;
    }

    handleUnitSelected(event) {
        this.selectedUnitId = event.detail.value;
        this.clearOpenRequestState();
        this.justification = '';
        if (this.selectedUnitId) {
            this.loadPaymentPlan();
        } else {
            this.rows = [];
            this.originalSnapshot = new Map();
        }
    }

    async loadPaymentPlan(silent = false) {
        this.loading = true;
        try {
            const [linesResult, openRequest, cashFlowSums] = await Promise.all([
                getUnitPaymentPlanLines({ unitId: this.selectedUnitId }),
                getOpenPaymentPlanRequestForUnit({ unitId: this.selectedUnitId }),
                getUnitCashFlowSums({ unitId: this.selectedUnitId })
            ]);

            this.unitCashFlowSums = cashFlowSums || [];

            const lines = linesResult?.lines || [];
            this.totalInstallmentCount = linesResult?.totalCount ?? lines.length;
            this.planTruncated = linesResult?.truncated === true;

            this.rows = lines.map((line, index) => this.buildRowFromServer(line, index));
            this.originalSnapshot = new Map(
                this.rows
                    .filter((row) => row.cashFlowId)
                    .map((row) => [row.cashFlowId, this.cloneRow(row)])
            );

            if (openRequest?.approvalRequestId) {
                this.applyOpenRequest(openRequest);
                await this.mergeSavedApprovalLines(openRequest.approvalRequestId);
                if (!silent && (openRequest.inApprovalProcess || openRequest.status === 'Pending')) {
                    this.showToast(
                        'Pending Approval',
                        this.buildStatusToastMessage(openRequest),
                        'warning'
                    );
                } else if (!silent && openRequest.status === 'Approved') {
                    this.showToast(
                        'Approved',
                        `Payment plan request ${openRequest.name || ''} has been approved.`.trim(),
                        'success'
                    );
                } else if (!silent && openRequest.status === 'Rejected') {
                    this.showToast(
                        'Rejected',
                        `Payment plan request ${openRequest.name || ''} was rejected.`.trim(),
                        'error'
                    );
                } else if (!silent && openRequest.status === 'Draft') {
                    this.showToast(
                        'Draft resumed',
                        `Continuing payment plan draft ${openRequest.name || ''}.`.trim(),
                        'info'
                    );
                }
            } else {
                this.clearOpenRequestState();
            }
        } catch (error) {
            this.showError(error);
        } finally {
            this.loading = false;
        }
    }

    async mergeSavedApprovalLines(approvalRequestId) {
        const savedLines = await getApprovalRequestLines({ approvalRequestId });
        if (!savedLines?.length) {
            return;
        }

        const rowsByCashFlowId = new Map(
            this.rows.filter((row) => row.cashFlowId).map((row) => [row.cashFlowId, row])
        );

        for (const line of savedLines) {
            if (line.Action__c === 'Insert') {
                this.rows = [
                    ...this.rows,
                    {
                        clientKey: `draft-${line.Id}`,
                        cashFlowId: null,
                        milestoneName: line.Milestone_Name__c,
                        installmentMilestone: line.Milestone_Name__c,
                        installmentDate: line.Date__c,
                        percent: line.Percent__c,
                        constantAmount: line.Constant__c,
                        cashFlowSumId: line.Cash_Flow_Sum__c,
                        cashFlowSumName: line.Cash_Flow_Sum__r?.Name,
                        isAdditionalPayment: line.Is_Additional_Payment__c,
                        receivedAmount: 0,
                        hasPayments: false,
                        isExcludedFee: FEE_MILESTONES.has(line.Milestone_Name__c),
                        isNew: true,
                        isRemoved: false,
                        isDirty: true
                    }
                ];
                continue;
            }

            const row = rowsByCashFlowId.get(line.Cash_Flow__c);
            if (!row) {
                continue;
            }

            if (line.Action__c === 'Delete') {
                row.isRemoved = true;
                row.isDirty = true;
                continue;
            }

            if (line.Action__c === 'Update') {
                row.milestoneName = line.Milestone_Name__c;
                row.installmentDate = line.Date__c;
                row.percent = line.Percent__c;
                row.constantAmount = line.Constant__c;
                row.cashFlowSumId = line.Cash_Flow_Sum__c;
                row.cashFlowSumName = line.Cash_Flow_Sum__r?.Name;
                row.isAdditionalPayment = line.Is_Additional_Payment__c;
                row.isDirty = true;
            }
        }

        this.rows = [...this.rows];
    }

    buildRowFromServer(line, index) {
        return {
            clientKey: line.cashFlowId || `existing-${index}`,
            cashFlowId: line.cashFlowId,
            milestoneName: line.milestoneName,
            installmentMilestone: line.installmentMilestone,
            installmentDate: line.installmentDate,
            percent: line.percent,
            constantAmount: line.constantAmount,
            cashFlowSumId: line.cashFlowSumId,
            cashFlowSumName: line.cashFlowSumName,
            isAdditionalPayment: line.isAdditionalPayment,
            receivedAmount: line.receivedAmount,
            hasPayments: line.receivedAmount > 0,
            isExcludedFee: line.isExcludedFee || FEE_MILESTONES.has(line.milestoneName),
            isNew: false,
            isRemoved: false,
            isDirty: false
        };
    }

    handleJustificationChange(event) {
        this.justification = event.target.value;
    }

    handleAddRow() {
        this.editingRow = {
            clientKey: `new-${Date.now()}`,
            cashFlowId: null,
            milestoneName: '',
            installmentDate: null,
            percent: null,
            constantAmount: null,
            cashFlowSumId: null,
            cashFlowSumName: '',
            isAdditionalPayment: false,
            isNew: true,
            isRemoved: false
        };
        this.newCashFlowSumYear = '';
        this.showNewYearForm = false;
        this.showEditorModal = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this.syncCashFlowSumLookupSelection(), 0);
    }

    handleEditRow(event) {
        const clientKey = event.currentTarget.dataset.key;
        const row = this.rows.find((item) => item.clientKey === clientKey);
        if (!row) {
            return;
        }
        this.editingRow = { ...row };
        this.newCashFlowSumYear = this.extractYearFromDate(row.installmentDate) || row.cashFlowSumName || '';
        this.showNewYearForm = false;
        this.showEditorModal = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this.syncCashFlowSumLookupSelection(), 0);
    }

    handleDeleteRow(event) {
        const clientKey = event.currentTarget.dataset.key;
        this.rows = this.rows.map((row) => {
            if (row.clientKey !== clientKey) {
                return row;
            }
            if (row.isNew) {
                return { ...row, isRemoved: true };
            }
            return { ...row, isRemoved: true, isDirty: true };
        });
    }

    handleModalFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.editingRow = { ...this.editingRow, [field]: value };

        if (field === 'installmentDate') {
            this.suggestCashFlowSumForDate(value);
        }
    }

    handleShowNewYearForm(event) {
        event.preventDefault();
        this.showNewYearForm = true;
        if (!this.newCashFlowSumYear && this.editingRow?.installmentDate) {
            this.newCashFlowSumYear = this.extractYearFromDate(this.editingRow.installmentDate) || '';
        }
    }

    handleNewCashFlowSumYearChange(event) {
        this.newCashFlowSumYear = event.target.value;
    }

    handleCashFlowSumSelected(event) {
        const { value, recordName } = event.detail;
        this.editingRow = {
            ...this.editingRow,
            cashFlowSumId: value,
            cashFlowSumName: recordName || ''
        };
    }

    async handleCreateCashFlowSum() {
        const year = (this.newCashFlowSumYear || '').trim();
        if (!/^\d{4}$/.test(year)) {
            this.showToast('Validation', 'Enter a four-digit year (for example 2026).', 'error');
            return;
        }

        this.creatingCashFlowSum = true;
        try {
            const cashFlowSumId = await createUnitCashFlowSum({
                unitId: this.selectedUnitId,
                yearName: year
            });
            this.unitCashFlowSums = await getUnitCashFlowSums({ unitId: this.selectedUnitId });
            this.editingRow = {
                ...this.editingRow,
                cashFlowSumId,
                cashFlowSumName: year
            };
            this.syncCashFlowSumLookupSelection();
            this.showNewYearForm = false;
            this.showToast('Success', `Cash Flow Sum ${year} is ready.`, 'success');
        } catch (error) {
            this.showError(error);
        } finally {
            this.creatingCashFlowSum = false;
        }
    }

    suggestCashFlowSumForDate(installmentDate) {
        const year = this.extractYearFromDate(installmentDate);
        if (!year) {
            return;
        }

        this.newCashFlowSumYear = year;
        const match = (this.unitCashFlowSums || []).find((sum) => sum.name === year);
        if (match) {
            this.editingRow = {
                ...this.editingRow,
                cashFlowSumId: match.id,
                cashFlowSumName: match.name
            };
            this.syncCashFlowSumLookupSelection();
        }
    }

    extractYearFromDate(installmentDate) {
        if (!installmentDate || installmentDate.length < 4) {
            return null;
        }
        return installmentDate.substring(0, 4);
    }

    syncCashFlowSumLookupSelection() {
        const lookup = this.template.querySelector('[data-id="cash-flow-sum-lookup"]');
        if (!lookup) {
            return;
        }
        if (this.editingRow?.cashFlowSumId) {
            lookup.setSelectedRecord(this.editingRow.cashFlowSumId, this.editingRow.cashFlowSumName);
        } else {
            lookup.clearSelection();
        }
    }

    handleModalCancel() {
        this.showEditorModal = false;
        this.editingRow = null;
        this.newCashFlowSumYear = '';
        this.showNewYearForm = false;
    }

    handleModalSave() {
        if (!this.editingRow.milestoneName || !this.editingRow.installmentDate) {
            this.showToast('Validation', 'Milestone name and installment date are required.', 'error');
            return;
        }
        if (this.editingRow.isNew && !this.editingRow.cashFlowSumId) {
            this.showToast('Validation', 'Cash Flow Sum (year) is required for new installments.', 'error');
            return;
        }

        const updatedRow = {
            ...this.editingRow,
            isDirty: !this.editingRow.isNew
        };

        const existingIndex = this.rows.findIndex((row) => row.clientKey === updatedRow.clientKey);
        if (existingIndex >= 0) {
            const nextRows = [...this.rows];
            nextRows[existingIndex] = updatedRow;
            this.rows = nextRows;
        } else {
            this.rows = [...this.rows, updatedRow];
        }

        this.showEditorModal = false;
        this.editingRow = null;
        this.newCashFlowSumYear = '';
        this.showNewYearForm = false;
    }

    async handleSaveDraft() {
        if (!this.validateBeforeSubmit()) {
            return;
        }
        this.loading = true;
        try {
            if (!this.approvalRequestId) {
                this.approvalRequestId = await createDraftRequest({
                    unitId: this.selectedUnitId,
                    justification: this.justification
                });
            }
            await saveApprovalLines({
                approvalRequestId: this.approvalRequestId,
                linesJson: JSON.stringify(this.buildLinePayload())
            });
            this.showToast('Success', 'Payment plan changes saved as draft.', 'success');
        } catch (error) {
            this.showError(error);
        } finally {
            this.loading = false;
        }
    }

    async handleSubmitForApproval() {
        if (!this.validateBeforeSubmit()) {
            return;
        }
        this.loading = true;
        try {
            if (!this.approvalRequestId) {
                this.approvalRequestId = await createDraftRequest({
                    unitId: this.selectedUnitId,
                    justification: this.justification
                });
            }
            const submittedId = await submitPaymentPlanApproval({
                unitId: this.selectedUnitId,
                justification: this.justification,
                linesJson: JSON.stringify(this.buildLinePayload()),
                approvalRequestId: this.approvalRequestId,
                approverUserId: this.selectedApproverId
            });

            this.approvalRequestId = submittedId;
            this.showMainModal = false;

            await this.loadPaymentPlan(true);

            this.showToast(
                'Submitted for Approval',
                this.buildStatusToastMessage({
                    name: this.approvalRequestName,
                    statusLabel: this.requestStatusLabel,
                    approvalStageLabel: this.approvalStageLabel
                }),
                'success'
            );
        } catch (error) {
            this.showError(error);
        } finally {
            this.loading = false;
        }
    }

    validateBeforeSubmit() {
        if (!this.selectedUnitId) {
            this.showToast('Validation', 'Select a unit before continuing.', 'error');
            return false;
        }
        if (!this.justification || this.justification.trim().length < 10) {
            this.showToast('Validation', 'Justification must be at least 10 characters.', 'error');
            return false;
        }
        const changes = this.buildLinePayload();
        if (changes.length === 0) {
            this.showToast('Validation', 'Make at least one payment plan change before submitting.', 'error');
            return false;
        }
        if (!this.percentIsValid) {
            this.showToast(
                'Invalid Total Percentage',
                `Installment percentages must add up to exactly 100%. Current total: ${this.totalPercent}%.`,
                'error'
            );
            return false;
        }
        if (!this.selectedApproverId) {
            this.showToast('Validation', 'Select an approver before submitting for approval.', 'error');
            return false;
        }
        if (!this.hasApproverOptions) {
            this.showToast(
                'Validation',
                'No approvers are available. Assign the Sales Director MIRA profile to eligible users.',
                'error'
            );
            return false;
        }
        return true;
    }

    buildLinePayload() {
        const payload = [];
        let sortOrder = 1;

        for (const row of this.rows) {
            if (row.isRemoved && row.cashFlowId) {
                payload.push(this.toLineInput(row, 'Delete', sortOrder++));
                continue;
            }
            if (row.isRemoved) {
                continue;
            }
            if (row.isNew) {
                payload.push(this.toLineInput(row, 'Insert', sortOrder++));
                continue;
            }

            const original = this.originalSnapshot.get(row.cashFlowId);
            if (!original || this.hasRowChanged(original, row)) {
                payload.push(this.toLineInput(row, 'Update', sortOrder++));
            }
        }

        return payload;
    }

    toLineInput(row, action, sortOrder) {
        return {
            clientKey: row.clientKey,
            cashFlowId: row.cashFlowId,
            action,
            milestoneName: row.milestoneName,
            installmentDate: row.installmentDate,
            percent: row.percent,
            constantAmount: row.constantAmount,
            cashFlowSumId: row.cashFlowSumId,
            isAdditionalPayment: row.isAdditionalPayment,
            sortOrder
        };
    }

    hasRowChanged(original, current) {
        return (
            original.milestoneName !== current.milestoneName ||
            original.installmentDate !== current.installmentDate ||
            original.percent !== current.percent ||
            original.constantAmount !== current.constantAmount ||
            original.cashFlowSumId !== current.cashFlowSumId ||
            original.isAdditionalPayment !== current.isAdditionalPayment
        );
    }

    getActionLabel(row) {
        if (row.isRemoved) {
            return 'Delete';
        }
        if (row.isNew) {
            return 'Insert';
        }
        if (row.isDirty) {
            return 'Update';
        }
        return 'Unchanged';
    }

    cloneRow(row) {
        return { ...row };
    }

    resetForm() {
        this.rows = [];
        this.justification = '';
        this.clearOpenRequestState();
        this.originalSnapshot = new Map();
        this.selectedUnitId = this.recordId || null;
        if (this.recordId) {
            this.loadPaymentPlan();
        }
    }

    applyOpenRequest(openRequest) {
        this.approvalRequestId = openRequest.approvalRequestId;
        this.requestStatus = openRequest.status || null;
        this.requestStatusLabel = openRequest.statusLabel || '';
        this.approvalStageLabel = openRequest.approvalStageLabel || '';
        this.inApprovalProcess = openRequest.inApprovalProcess === true;
        this.approvalRequestName = openRequest.name || '';
        this.justification = openRequest.justification || '';
    }

    clearOpenRequestState() {
        this.approvalRequestId = null;
        this.requestStatus = null;
        this.requestStatusLabel = '';
        this.approvalStageLabel = '';
        this.inApprovalProcess = false;
        this.approvalRequestName = '';
    }

    buildStatusToastMessage(openRequest) {
        const requestName = openRequest?.name || this.approvalRequestName || '';
        const statusLabel = openRequest?.statusLabel || this.requestStatusLabel || 'Pending Approval';
        const stageLabel = openRequest?.approvalStageLabel || this.approvalStageLabel;
        const parts = [`Request ${requestName}`.trim(), statusLabel];
        if (stageLabel) {
            parts.push(stageLabel);
        }
        return parts.filter(Boolean).join(' — ');
    }

    showError(error) {
        let message = this.extractErrorMessage(error);

        if (message === 'Script-thrown exception') {
            message =
                'Submit failed on the server. Deploy the latest PaymentPlanApprovalController and PaymentPlanApprovalService, then check Debug Logs for the real error.';
        }

        // eslint-disable-next-line no-console
        console.error('Payment plan approval error', error);
        this.showToast('Error', message, 'error');
    }

    extractErrorMessage(error) {
        if (!error) {
            return 'An unexpected error occurred.';
        }

        const body = error.body;

        if (typeof body === 'string' && body.trim()) {
            return body;
        }

        if (body?.message) {
            return body.message;
        }

        if (Array.isArray(body) && body[0]?.message) {
            return body[0].message;
        }

        if (body?.pageErrors?.length) {
            return body.pageErrors[0].message;
        }

        if (body?.output?.errors?.length) {
            return body.output.errors[0].message;
        }

        if (body?.output?.fieldErrors) {
            const fields = Object.keys(body.output.fieldErrors);
            if (fields.length > 0) {
                return body.output.fieldErrors[fields[0]][0].message;
            }
        }

        if (body?.fieldErrors) {
            const fields = Object.keys(body.fieldErrors);
            if (fields.length > 0) {
                return body.fieldErrors[fields[0]][0].message;
            }
        }

        if (error.message) {
            return error.message;
        }

        return 'An unexpected error occurred.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}