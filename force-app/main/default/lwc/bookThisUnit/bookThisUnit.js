import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchClientAccounts from '@salesforce/apex/BookUnitController.searchClientAccounts';
import searchAgencyAccounts from '@salesforce/apex/BookUnitController.searchAgencyAccounts';
import searchContactsByAccount from '@salesforce/apex/BookUnitController.searchContactsByAccount';
import createBookingOpportunity from '@salesforce/apex/BookUnitController.createBookingOpportunity';

export default class BookThisUnit extends NavigationMixin(LightningElement) {
    @api recordId; // Unit__c record Id from record page

    @track showModal = false;
    @track currentStep = 1;
    @track assistedByAgent = false;
    @track isSubmitting = false;

    // Client lookup state
    @track selectedClient = null;
    @track clientSearchKey = '';
    @track clientRecords = [];
    @track clientSearching = false;
    clientSearchTimeout;

    // Agency lookup state
    @track selectedAgency = null;
    @track agencySearchKey = '';
    @track agencyRecords = [];
    @track agencySearching = false;
    agencySearchTimeout;

    // Agent lookup state
    @track selectedAgent = null;
    @track agentSearchKey = '';
    @track agentRecords = [];
    @track agentSearching = false;
    agentSearchTimeout;

    get showClientResults() {
        return this.clientRecords && this.clientRecords.length > 0;
    }

    get showAgencyResults() {
        return this.agencyRecords && this.agencyRecords.length > 0;
    }

    get showAgentResults() {
        return this.agentRecords && this.agentRecords.length > 0;
    }

    get agentLookupDisabled() {
        return !this.selectedAgency;
    }

    get agentPlaceholder() {
        return this.selectedAgency ? 'Search agents...' : 'Select Agency first';
    }

    get isStep1() {
        return this.currentStep === 1;
    }

    get isStep2() {
        return this.currentStep === 2;
    }

    get isNextEnabled() {
        if (!this.selectedClient) return false;
        if (this.assistedByAgent && (!this.selectedAgency || !this.selectedAgent)) return false;
        return true;
    }

    get isConfirmButtonLabel() {
        return this.currentStep === 2 ? 'Confirm and Book' : 'Next';
    }

    get isNextButtonDisabled() {
        if (this.currentStep === 2) return this.isSubmitting;
        return !this.isNextEnabled;
    }

    get assistedByAgentYesNo() {
        return this.assistedByAgent ? 'Yes' : 'No';
    }

    get clientDisplayName() {
        return this.selectedClient ? this.selectedClient.Name : '';
    }

    get agencyDisplayName() {
        return this.selectedAgency ? this.selectedAgency.Name : '';
    }

    get agentDisplayName() {
        return this.selectedAgent ? this.selectedAgent.Name : '';
    }

    handleOpenModal() {
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
        this.currentStep = 1;
        this.resetForm();
    }

    resetForm() {
        this.selectedClient = null;
        this.clientSearchKey = '';
        this.clientRecords = [];
        this.assistedByAgent = false;
        this.selectedAgency = null;
        this.agencySearchKey = '';
        this.agencyRecords = [];
        this.selectedAgent = null;
        this.agentSearchKey = '';
        this.agentRecords = [];
    }

    // Client lookup handlers
    handleClientSearch(event) {
        this.clientSearchKey = event.target.value;
        clearTimeout(this.clientSearchTimeout);
        this.clientSearchTimeout = setTimeout(() => {
            this.performClientSearch();
        }, 300);
    }

    handleClientFocus() {
        if (!this.selectedClient && !this.clientSearchKey) {
            this.performClientSearch();
        }
    }

    performClientSearch() {
        this.clientSearching = true;
        searchClientAccounts({ searchKey: this.clientSearchKey })
            .then((result) => {
                this.clientRecords = result || [];
            })
            .catch((error) => {
                console.error('Error searching client accounts:', error);
                this.clientRecords = [];
            })
            .finally(() => {
                this.clientSearching = false;
            });
    }

    handleSelectClient(event) {
        const recordId = event.currentTarget.dataset.id;
        const recordName = event.currentTarget.dataset.name;
        this.selectedClient = { Id: recordId, Name: recordName };
        this.clientRecords = [];
        this.clientSearchKey = '';
    }

    handleClearClient() {
        this.selectedClient = null;
        this.clientSearchKey = '';
        this.clientRecords = [];
    }

    // Assisted By Agent checkbox
    handleAssistedByAgentChange(event) {
        this.assistedByAgent = event.target.checked;
        if (!this.assistedByAgent) {
            this.selectedAgency = null;
            this.agencySearchKey = '';
            this.agencyRecords = [];
            this.selectedAgent = null;
            this.agentSearchKey = '';
            this.agentRecords = [];
        }
    }

    // Agency lookup handlers
    handleAgencySearch(event) {
        this.agencySearchKey = event.target.value;
        clearTimeout(this.agencySearchTimeout);
        this.agencySearchTimeout = setTimeout(() => {
            this.performAgencySearch();
        }, 300);
    }

    handleAgencyFocus() {
        if (!this.selectedAgency && !this.agencySearchKey) {
            this.performAgencySearch();
        }
    }

    performAgencySearch() {
        this.agencySearching = true;
        searchAgencyAccounts({ searchKey: this.agencySearchKey })
            .then((result) => {
                this.agencyRecords = result || [];
            })
            .catch((error) => {
                console.error('Error searching agency accounts:', error);
                this.agencyRecords = [];
            })
            .finally(() => {
                this.agencySearching = false;
            });
    }

    handleSelectAgency(event) {
        const recordId = event.currentTarget.dataset.id;
        const recordName = event.currentTarget.dataset.name;
        this.selectedAgency = { Id: recordId, Name: recordName };
        this.agencyRecords = [];
        this.agencySearchKey = '';
        this.selectedAgent = null;
        this.agentSearchKey = '';
        this.agentRecords = [];
    }

    handleClearAgency() {
        this.selectedAgency = null;
        this.agencySearchKey = '';
        this.agencyRecords = [];
        this.selectedAgent = null;
        this.agentSearchKey = '';
        this.agentRecords = [];
    }

    // Agent lookup handlers
    handleAgentSearch(event) {
        if (!this.selectedAgency) return;
        this.agentSearchKey = event.target.value;
        clearTimeout(this.agentSearchTimeout);
        this.agentSearchTimeout = setTimeout(() => {
            this.performAgentSearch();
        }, 300);
    }

    handleAgentFocus() {
        if (this.selectedAgency && !this.agentSearchKey) {
            this.performAgentSearch();
        }
    }

    performAgentSearch() {
        if (!this.selectedAgency) return;
        this.agentSearching = true;
        searchContactsByAccount({
            searchKey: this.agentSearchKey,
            accountId: this.selectedAgency.Id
        })
            .then((result) => {
                this.agentRecords = result || [];
            })
            .catch((error) => {
                console.error('Error searching contacts:', error);
                this.agentRecords = [];
            })
            .finally(() => {
                this.agentSearching = false;
            });
    }

    handleSelectAgent(event) {
        const recordId = event.currentTarget.dataset.id;
        const recordName = event.currentTarget.dataset.name;
        this.selectedAgent = { Id: recordId, Name: recordName };
        this.agentRecords = [];
        this.agentSearchKey = '';
    }

    handleClearAgent() {
        this.selectedAgent = null;
        this.agentSearchKey = '';
        this.agentRecords = [];
    }

    handleNext() {
        if (this.currentStep === 1 && this.isNextEnabled) {
            this.currentStep = 2;
        }
    }

    handleBack() {
        if (this.currentStep === 2) {
            this.currentStep = 1;
        }
    }

    handleConfirmOrNext() {
        if (this.currentStep === 1) {
            this.handleNext();
        } else {
            this.handleConfirmAndBook();
        }
    }

    handleConfirmAndBook() {
        if (!this.recordId || !this.selectedClient) return;
        this.isSubmitting = true;
        createBookingOpportunity({
            accountId: this.selectedClient.Id,
            unitId: this.recordId,
            agencyId: this.assistedByAgent && this.selectedAgency ? this.selectedAgency.Id : null,
            agentId: this.assistedByAgent && this.selectedAgent ? this.selectedAgent.Id : null,
            assistedByAgent: this.assistedByAgent
        })
            .then((opportunityId) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Booking created successfully',
                    variant: 'success'
                }));
                this.handleCloseModal();
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: opportunityId,
                        objectApiName: 'Opportunity',
                        actionName: 'view'
                    }
                });
            })
            .catch((error) => {
                console.error('Error creating booking:', error);
                const message = error.body?.message || error.message || 'Unknown error';
                const toast = new ShowToastEvent({
                    title: 'Error',
                    message,
                    variant: 'error'
                });
                this.dispatchEvent(toast);
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }
}