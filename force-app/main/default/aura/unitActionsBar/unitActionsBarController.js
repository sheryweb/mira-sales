({
    doInit: function(component, event, helper) {
        helper.refreshVisibility(component);
    },

    onRecordUpdated: function(component, event, helper) {
        helper.refreshVisibility(component);
    }
})