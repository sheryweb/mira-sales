@isTest
private class BrokerBankApprovalServiceTest {

    private static Account makeAgency() {
        Account a = new Account(Name = 'Apply Agency ' + String.valueOf(Crypto.getRandomLong()), Skip_Trigger__c = true);
        insert a;
        return a;
    }

    private static Approval_Request__c makeRequest(Id acctId, String json) {
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Bank Detail Update', Related_Object_Type__c = 'Account',
            Related_Record_Id__c = String.valueOf(acctId), Field_To_Update__c = 'Bank Details (multiple)',
            Current_Value__c = 'See Bank Changes', Requested_Value__c = 'See Bank Changes',
            Justification__c = 'test', Profile_Changes_JSON__c = json, Status__c = 'Approved');
        insert req;
        return req;
    }

    @isTest
    static void updates_existing_and_inserts_new_bank() {
        Account acc = makeAgency();
        Bank__c existing = new Bank__c(Account__c = acc.Id, Name = 'Old Bank', IBAN__c = 'AE000');
        insert existing;

        String json = JSON.serialize(new List<Object>{
            new Map<String, Object>{ 'recordId' => existing.Id, 'fields' => new Map<String, Object>{
                'Name' => 'Old Bank', 'IBAN__c' => 'AE123NEW' } },
            new Map<String, Object>{ 'recordId' => '', 'fields' => new Map<String, Object>{
                'Name' => 'New Bank', 'Swift_Code__c' => 'NEWAEAD' } }
        });
        Approval_Request__c req = makeRequest(acc.Id, json);

        Test.startTest();
        BrokerBankApprovalService.applyApprovedChanges(new Set<Id>{ req.Id });
        Test.stopTest();

        Bank__c updated = [SELECT IBAN__c FROM Bank__c WHERE Id = :existing.Id];
        System.assertEquals('AE123NEW', updated.IBAN__c, 'existing bank IBAN updated');
        System.assertEquals(2, [SELECT COUNT() FROM Bank__c WHERE Account__c = :acc.Id], 'new bank inserted');
        System.assertEquals('Applied', [SELECT Status__c FROM Approval_Request__c WHERE Id = :req.Id].Status__c);
    }

    @isTest
    static void ignores_bank_belonging_to_another_account() {
        Account mine = makeAgency();
        Account other = makeAgency();
        Bank__c othersBank = new Bank__c(Account__c = other.Id, Name = 'Other Bank', IBAN__c = 'AEOTHER');
        insert othersBank;

        // Tampered payload: try to update another account's bank via my request.
        String json = JSON.serialize(new List<Object>{
            new Map<String, Object>{ 'recordId' => othersBank.Id, 'fields' => new Map<String, Object>{
                'IBAN__c' => 'HACKED' } }
        });
        Approval_Request__c req = makeRequest(mine.Id, json);

        Test.startTest();
        BrokerBankApprovalService.applyApprovedChanges(new Set<Id>{ req.Id });
        Test.stopTest();

        System.assertEquals('AEOTHER', [SELECT IBAN__c FROM Bank__c WHERE Id = :othersBank.Id].IBAN__c,
            'another account\'s bank must not be changed');
    }

    @isTest
    static void invocable_and_empty_input_are_safe() {
        BrokerBankApprovalService.applyApproved(new List<Id>());        // empty
        BrokerBankApprovalService.applyApprovedChanges(null);           // null
        Account acc = makeAgency();
        Approval_Request__c req = makeRequest(acc.Id, '[]');            // empty array payload
        BrokerBankApprovalService.applyApproved(new List<Id>{ req.Id });
        System.assert(true, 'no exception on empty / null inputs');
    }
}