({
    doInit: function(component, event, helper) {
        helper.loadPaymentPlanAccess(component);
        helper.loadBookedOpportunity(component);
    },

    onRecordUpdated: function(component, event, helper) {
        helper.refreshVisibility(component);
        helper.loadBookedOpportunity(component);
    }
})
