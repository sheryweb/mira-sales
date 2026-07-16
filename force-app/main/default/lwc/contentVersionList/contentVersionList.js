import { LightningElement, api, wire, track } from 'lwc';
import getContentVersions from '@salesforce/apex/ContentVersionController.getContentVersions';

const columns = [
    {
        label: 'Title',
        fieldName: 'contentUrl',
        type: 'url',
        typeAttributes: {
            label: {
                fieldName: 'Title'
            },
            target: '_blank'
        }
    },
    { label: 'Description', fieldName: 'Description' },
    { label: 'File Type', fieldName: 'FileType' },
    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date' }
];

export default class ContentVersionList extends LightningElement {
    @api recordId;
    @track contentVersions;
    columns = columns;

    @wire(getContentVersions, { accountId: '$recordId' })
    wiredContentVersions({ error, data }) {
        if (data) {
            console.log('Content Versions:', data);
            this.contentVersions = data.map(record => {
                return {
                    ...record,
                    contentUrl: `/lightning/r/ContentDocument/${record.ContentDocumentId}/view`
                };
            });
        } else if (error) {
            console.error('Error fetching content versions:', error);
            this.contentVersions = undefined;
        }
    }
}