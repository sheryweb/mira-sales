@isTest
private class AgencyProfileApprovalServiceTest {

    private static Approval_Request__c makeRequest(Id acctId, String jsonStr) {
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Agency Profile Update',
            Related_Object_Type__c = 'Account',
            Related_Record_Id__c = acctId,
            Field_To_Update__c = 'Company Profile (multiple)',
            Current_Value__c = 'See Profile Changes',
            Requested_Value__c = 'See Profile Changes',
            Justification__c = 'Company profile update from Broker Portal',
            Profile_Changes_JSON__c = jsonStr,
            Status__c = 'Pending'
        );
        insert req;
        return req;
    }

    @isTest
    static void applies_whitelisted_and_ignores_others() {
        Account acc = new Account(Name = 'Apply Agency', Skip_Trigger__c = true,
            Phone = '111', Company_Email__c = 'old@abc.ae', Trade_License_Number__c = 'TL-OLD');
        insert acc;

        String json =
            '[{"field":"Phone","newValue":"+971 4 555 9999"},' +
            ' {"field":"Signatory_Name__c","newValue":"Jane S"},' +
            ' {"field":"Trade_License_Number__c","newValue":"TL-HACK"},' +   // no longer editable -> ignored
            ' {"field":"AnnualRevenue","newValue":"99999"}]';               // never editable -> ignored
        Approval_Request__c req = makeRequest(acc.Id, json);

        Test.startTest();
        AgencyProfileApprovalService.applyApprovedChanges(new Set<Id>{ req.Id });
        Test.stopTest();

        Account a = [SELECT Phone, Signatory_Name__c, Trade_License_Number__c, AnnualRevenue FROM Account WHERE Id = :acc.Id];
        System.assertEquals('+971 4 555 9999', a.Phone, 'whitelisted field applied');
        System.assertEquals('Jane S', a.Signatory_Name__c, 'whitelisted field applied');
        System.assertEquals('TL-OLD', a.Trade_License_Number__c, 'non-editable field must be ignored');
        System.assertEquals(null, a.AnnualRevenue, 'non-whitelisted field ignored');
        System.assertEquals('Applied', [SELECT Status__c FROM Approval_Request__c WHERE Id = :req.Id].Status__c);
    }

    @isTest
    static void company_email_change_syncs_broker_user() {
        Account acc = new Account(Name = 'Sync Agency', Skip_Trigger__c = true, Company_Email__c = 'old@abc.ae');
        insert acc;
        Broker_User__c bu = new Broker_User__c(Account__c = acc.Id, Email__c = 'old@abc.ae', Active__c = true);
        insert bu;

        Approval_Request__c req = makeRequest(acc.Id, '[{"field":"Company_Email__c","newValue":"new@abc.ae"}]');

        Test.startTest();
        AgencyProfileApprovalService.applyApprovedChanges(new Set<Id>{ req.Id });
        Test.stopTest();

        System.assertEquals('new@abc.ae', [SELECT Company_Email__c FROM Account WHERE Id = :acc.Id].Company_Email__c, 'account email updated');
        System.assertEquals('new@abc.ae', [SELECT Email__c FROM Broker_User__c WHERE Id = :bu.Id].Email__c, 'broker login email synced');
    }

    @isTest
    static void invocable_entry_point_runs() {
        Account acc = new Account(Name = 'Apply Agency 2', Skip_Trigger__c = true, Phone = '222');
        insert acc;
        Approval_Request__c req = makeRequest(acc.Id, '[{"field":"Phone","newValue":"333"}]');

        Test.startTest();
        AgencyProfileApprovalService.applyApproved(new List<Id>{ req.Id });
        Test.stopTest();

        System.assertEquals('333', [SELECT Phone FROM Account WHERE Id = :acc.Id].Phone);
    }

    @isTest
    static void ignores_blank_input() {
        AgencyProfileApprovalService.applyApprovedChanges(new Set<Id>());
        AgencyProfileApprovalService.applyApprovedChanges(null);
        System.assert(true);
    }
}