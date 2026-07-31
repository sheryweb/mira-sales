({
    refreshVisibility: function(component) {
        var record = component.get('v.unitRecord');
        var status = record ? record.Status__c : null;
        var canPaymentPlan = component.get('v.canRequestPaymentPlanChange') === true;
        var opportunityId = component.get('v.opportunityId');
        var isBooked = status === 'Booked';

        component.set(
            'v.showGenerateSalesOffer',
            status === 'Draft' || status === 'Published' || status === 'Booked'
        );
        component.set('v.showBookThisUnit', status === 'Published');
        component.set('v.showPaymentPlanChange', isBooked && canPaymentPlan);
        component.set('v.showUnitPriceChange', isBooked);
        component.set('v.showShareDeal', isBooked && !!opportunityId);
        component.set(
            'v.showBar',
            status === 'Draft' ||
                status === 'Published' ||
                status === 'Booked'
        );
    },

    loadPaymentPlanAccess: function(component) {
        var action = component.get('c.canUserRequestPaymentPlanChange');
        var self = this;
        action.setCallback(this, function(response) {
            var allowed = response.getState() === 'SUCCESS' && response.getReturnValue() === true;
            component.set('v.canRequestPaymentPlanChange', allowed);
            self.refreshVisibility(component);
        });
        $A.enqueueAction(action);
    },

    loadBookedOpportunity: function(component) {
        var unitId = component.get('v.recordId');
        if (!unitId) {
            component.set('v.opportunityId', null);
            this.refreshVisibility(component);
            return;
        }

        var action = component.get('c.getBookedOpportunityIdForUnit');
        var self = this;
        action.setParams({ unitId: unitId });
        action.setCallback(this, function(response) {
            if (response.getState() === 'SUCCESS') {
                component.set('v.opportunityId', response.getReturnValue());
            } else {
                component.set('v.opportunityId', null);
            }
            self.refreshVisibility(component);
        });
        $A.enqueueAction(action);
    }
})
