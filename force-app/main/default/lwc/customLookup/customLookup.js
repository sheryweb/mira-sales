import { LightningElement, api, wire, track } from 'lwc';
import findRecords from '@salesforce/apex/CustomLookupController.findRecords';

export default class CustomLookup extends LightningElement {
    @api objectApiName = 'Opportunity';
    @api searchField = 'Name';
    @api labelName = 'Select Record';
    @api required = false;
    @api placeholder = 'Search...';
    @api iconName = 'standard:opportunity';
    @api filterField;
    @api filterValue;

    @track selectedRecord;
    @track records;
    @track isSearching = false;
    @track searchKey = '';
    @track hasError = false;
    @track errorMessage = '';

    get showResults() {
        return this.records && this.records.length > 0;
    }

    get selectedValue() {
        return this.selectedRecord ? this.selectedRecord.Name : '';
    }

    get containerClass() {
        return `slds-combobox_container ${this.hasError ? 'has-error' : ''}`;
    }

    get inputClass() {
        const baseClass = 'slds-input slds-combobox__input';
        return this.selectedRecord 
            ? `${baseClass} slds-combobox__input-value` 
            : baseClass;
    }

    handleSearch(event) {
        const searchKey = event.target.value;
        this.searchKey = searchKey;
        
        if (searchKey.length >= 2) {
            this.isSearching = true;
            findRecords({
                searchKey: searchKey,
                objectName: this.objectApiName,
                searchField: this.searchField,
                filterField: this.filterField || null,
                filterValue: this.filterValue || null
            })
            .then(result => {
                this.records = result;
                this.hasError = false;
                this.errorMessage = '';
            })
            .catch(error => {
                this.hasError = true;
                this.errorMessage = error.body?.message || 'Error searching records';
                console.error('Error searching records:', error);
            })
            .finally(() => {
                this.isSearching = false;
            });
        } else {
            this.records = [];
        }
    }

    handleSelect(event) {
        const recordId = event.currentTarget.dataset.id;
        const recordName = event.currentTarget.dataset.name;
        
        this.selectedRecord = {
            Id: recordId,
            Name: recordName
        };
        
        this.records = [];
        
        // Notify parent component
        this.dispatchEvent(new CustomEvent('recordselected', {
            detail: {
                value: recordId,
                recordId: recordId,
                recordName: recordName
            }
        }));
    }

    handleClear() {
        this.selectedRecord = null;
        this.records = [];
        this.searchKey = '';
        
        // Notify parent component
        this.dispatchEvent(new CustomEvent('recordselected', {
            detail: {
                value: null,
                recordId: null,
                recordName: null
            }
        }));
    }

    @api
    setSelectedRecord(recordId, recordName) {
        this.selectedRecord = {
            Id: recordId,
            Name: recordName
        };
    }

    @api
    clearSelection() {
        this.handleClear();
    }
}