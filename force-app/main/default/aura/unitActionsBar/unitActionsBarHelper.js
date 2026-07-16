({
    refreshVisibility: function(component) {
        var record = component.get('v.unitRecord');
        var status = record ? record.Status__c : null;

        component.set(
            'v.showGenerateSalesOffer',
            status === 'Draft' || status === 'Published' || status === 'Booked'
        );
        component.set('v.showBookThisUnit', status === 'Published');
    }
})