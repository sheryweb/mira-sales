({
    doInit: function(component, event, helper) {
        helper.loadPaymentPlanAccess(component);
    },

    onRecordUpdated: function(component, event, helper) {
        helper.refreshVisibility(component);
    }
})