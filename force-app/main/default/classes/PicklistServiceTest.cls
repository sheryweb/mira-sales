@isTest
private class PicklistServiceTest {

    @isTest
    static void testGetPicklistValueLabel() {
        Account acc = new Account(Name='Test Account');
        insert acc;

        Schema.DescribeFieldResult fieldDescribe = Schema.SObjectType.Account.fields.Industry;
        List<Schema.PicklistEntry> picklistValues = fieldDescribe.getPicklistValues();

        String picklistValueApiName = picklistValues[0].getValue();
        String objectApiName = 'Account';
        String fieldApiName = 'Industry';

        PicklistService.PicklistValueLabelRequest request = new PicklistService.PicklistValueLabelRequest();
        request.objectApiName = objectApiName;
        request.fieldApiName = fieldApiName;
        request.picklistValueApiName = picklistValueApiName;

        List<PicklistService.PicklistValueLabelRequest> requests = new List<PicklistService.PicklistValueLabelRequest>{request};
        List<PicklistService.PicklistValueLabelResult> results = PicklistService.getPicklistValueLabel(requests);

        System.assertEquals(1, results.size());
        System.assertEquals(picklistValues[0].getLabel(), results[0].picklistValueLabel);
    }
}