({
    doInit: function(component, event, helper) {
        var recordId = component.get("v.recordId");
        console.log("Record ID on init: " + recordId);
        if ($A.util.isEmpty(recordId)) {
            console.error("Record ID is not set");
        } else {
            console.log("Record ID is: " + recordId);
        }
    },
    handleRecordIdChange: function(component, event, helper) {
        var recordId = component.get("v.recordId");
        console.log("Record ID on change: " + recordId);
        if ($A.util.isEmpty(recordId)) {
            console.error("Record ID is not set");
        } else {
            console.log("Record ID is: " + recordId);
        }
    },
    handlePreview : function (component, event) {
        var recordIds = event.getParam('recordIds');
        var selectedRecordId = event.getParam('selectedRecordId');
        $A.get('e.lightning:openFiles').fire({
            recordIds: recordIds,
            selectedRecordId : selectedRecordId
        });
    },
})