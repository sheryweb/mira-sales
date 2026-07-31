({
    refreshVisibility: function(component) {
        var opp = component.get('v.opportunityRecord');
        var unitId = opp && opp.Unit__c ? opp.Unit__c : null;
        var status = opp && opp.Unit__r ? opp.Unit__r.Status__c : null;
        var stageName = opp ? opp.StageName : null;
        var canPaymentPlan = component.get('v.canRequestPaymentPlanChange') === true;
        var isUnitBooked = status === 'Booked';
        var isOppBooked = stageName === 'Booked';

        component.set('v.unitId', unitId);
        component.set('v.showPaymentPlanChange', unitId && isUnitBooked && canPaymentPlan);
        component.set('v.showUnitPriceChange', unitId && isUnitBooked);
        component.set('v.showShareDeal', isOppBooked);
        component.set('v.showBar', (unitId && isUnitBooked) || isOppBooked);
    },

    loadPaymentPlanAccess: function(component) {
        var action = component.get('c.canUserRequestPaymentPlanChange');
        action.setCallback(this, function(response) {
            var allowed = response.getState() === 'SUCCESS' && response.getReturnValue() === true;
            component.set('v.canRequestPaymentPlanChange', allowed);
            this.refreshVisibility(component);
        });
        $A.enqueueAction(action);
    }
})
