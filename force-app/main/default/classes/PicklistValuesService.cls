@RestResource(urlMapping='/picklistValues/*')
global without sharing class PicklistValuesService {

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        List<Map<String, Object>> responseList = new List<Map<String, Object>>();

        List<Map<String,String>> projectStatusPicklistValues = getPicklistValues('Project__c', 'Project_status__c');
        List<Map<String,String>> districtPicklistValues = getPicklistValues('Project__c', 'District__c');
        List<Map<String,String>> realEstateTypePicklistValues = getPicklistValues('Unit__c', 'Type__c');
        List<Map<String,String>> countriesPicklistValues = getPicklistValues('Project__c', 'Country__c');
        
        responseList.add(new Map<String, Object>{'projectStatus'=>projectStatusPicklistValues});
        responseList.add(new Map<String, Object>{'realEstateType'=>realEstateTypePicklistValues});
        responseList.add(new Map<String, Object>{'district'=>districtPicklistValues});
        responseList.add(new Map<String, Object>{'country'=>countriesPicklistValues});
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(responseList));
    }

    private static List<Map<String,String>> getPicklistValues(String objectName, String fieldName){
        List<Map<String,String>> picklistValues = new List<Map<String,String>>();
        Schema.SObjectType objSobjectType = Schema.getGlobalDescribe().get(objectName) ;
        Schema.DescribeSObjectResult objDescribeSobject = objSobjectType.getDescribe() ;
        Map<String,Schema.SObjectField> fields = objDescribeSobject.fields.getMap() ;
        Schema.DescribeFieldResult fieldResult = fields.get(fieldName).getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry pickListVal : ple){
            picklistValues.add(new Map<String, String>{'value'=>pickListVal.getValue(), 'label'=>pickListVal.getLabel()});
        }
        return picklistValues;
    }
}