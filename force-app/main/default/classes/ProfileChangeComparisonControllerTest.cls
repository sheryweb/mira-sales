@isTest
private class ProfileChangeComparisonControllerTest {

    private static Approval_Request__c makeRequest(Id acctId, String type, String json) {
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = type,
            Related_Object_Type__c = 'Account',
            Related_Record_Id__c = (acctId == null) ? null : String.valueOf(acctId),
            Field_To_Update__c = 'Company Profile (multiple)',
            Current_Value__c = 'See Profile Changes',
            Requested_Value__c = 'See Profile Changes',
            Justification__c = 'Company profile update from Broker Portal',
            Profile_Changes_JSON__c = json,
            Status__c = 'Pending'
        );
        insert req;
        return req;
    }

    private static String sampleJson() {
        return JSON.serialize(new List<Object>{
            new Map<String, Object>{ 'field' => 'Phone', 'label' => 'Phone', 'oldValue' => '111', 'newValue' => '222' },
            new Map<String, Object>{ 'field' => 'BillingStreet', 'label' => 'Address', 'oldValue' => '', 'newValue' => 'Downtown' }
        });
    }

    @isTest
    static void returns_changed_fields() {
        Account acc = new Account(Name = 'Cmp Agency', Skip_Trigger__c = true);
        insert acc;
        Approval_Request__c req = makeRequest(acc.Id, 'Agency Profile Update', sampleJson());

        Test.startTest();
        ProfileChangeComparisonController.Comparison c =
            ProfileChangeComparisonController.getProfileComparison(req.Id);
        Test.stopTest();

        System.assertEquals(false, c.notApplicable, 'profile request is applicable');
        System.assertEquals(2, c.changes.size(), 'only the changed fields appear');
        System.assertEquals('Cmp Agency', c.agencyName);
        System.assertEquals('Phone', c.changes[0].label);
        System.assertEquals('111', c.changes[0].oldValue);
        System.assertEquals('222', c.changes[0].newValue);
        System.assertEquals('—', c.changes[1].oldValue, 'blank old value shows an em dash');
        System.assertEquals('Downtown', c.changes[1].newValue);
        System.assertNotEquals(null, c.submittedDate);
    }

    @isTest
    static void non_profile_request_is_not_applicable() {
        Approval_Request__c req = makeRequest(null, 'Unit Price Change', sampleJson());
        ProfileChangeComparisonController.Comparison c =
            ProfileChangeComparisonController.getProfileComparison(req.Id);
        System.assertEquals(true, c.notApplicable);
    }

    @isTest
    static void empty_changes_is_not_applicable() {
        Account acc = new Account(Name = 'Empty Agency', Skip_Trigger__c = true);
        insert acc;
        Approval_Request__c req = makeRequest(acc.Id, 'Agency Profile Update', '[]');
        ProfileChangeComparisonController.Comparison c =
            ProfileChangeComparisonController.getProfileComparison(req.Id);
        System.assertEquals(true, c.notApplicable, 'no changes -> nothing to compare');
    }
}