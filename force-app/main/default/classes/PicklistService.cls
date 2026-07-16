public with sharing class PicklistService {

    @InvocableMethod(label='Get Picklist Value Label')
    public static List<PicklistValueLabelResult> getPicklistValueLabel(List<PicklistValueLabelRequest> requests) {
        List<PicklistValueLabelResult> results = new List<PicklistValueLabelResult>();

        for (PicklistValueLabelRequest request : requests) {
            Schema.SObjectType describe = Schema.getGlobalDescribe().get(request.objectApiName);
            Schema.DescribeFieldResult fieldDescribe = describe.getDescribe().fields.getMap().get(request.fieldApiName).getDescribe();
            List<Schema.PicklistEntry> ple = fieldDescribe.getPicklistValues();
            for( Schema.PicklistEntry pickListVal : ple){
                if(pickListVal.getValue() == request.picklistValueApiName){

                    PicklistValueLabelResult result = new PicklistValueLabelResult();
                    result.picklistValueLabel = pickListVal.getLabel();
                    results.add(result);
                }
            }
        }

        return results;
    }

    public class PicklistValueLabelRequest {
        @InvocableVariable(required=true)
        public String objectApiName;

        @InvocableVariable(required=true)
        public String fieldApiName;

        @InvocableVariable(required=true)
        public String picklistValueApiName;
    }

    public class PicklistValueLabelResult {
        @InvocableVariable
        public String picklistValueLabel;
    }
}