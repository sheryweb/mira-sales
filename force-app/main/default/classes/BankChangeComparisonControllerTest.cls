@isTest
private class BankChangeComparisonControllerTest {

    private static Approval_Request__c makeRequest(Id acctId, String type, String json) {
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = type,
            Related_Object_Type__c = 'Account',
            Related_Record_Id__c = (acctId == null) ? null : String.valueOf(acctId),
            Field_To_Update__c = 'Bank Details (multiple)',
            Current_Value__c = 'See Bank Changes',
            Requested_Value__c = 'See Bank Changes',
            Justification__c = 'Bank detail update from Broker Portal',
            Profile_Changes_JSON__c = json,
            Status__c = 'Pending'
        );
        insert req;
        return req;
    }

    @isTest
    static void diffs_existing_and_flags_new_bank() {
        Account acc = new Account(Name = 'Bank Cmp Agency', Skip_Trigger__c = true);
        insert acc;
        Bank__c existing = new Bank__c(
            Account__c = acc.Id, Name = 'ENBD', Bank_Account_Name__c = 'ABC LLC',
            Bank_Account_Number__c = '123', IBAN__c = 'AE111', Swift_Code__c = 'EBILAEAD', Branch_Name__c = 'Bur Dubai'
        );
        insert existing;

        // Existing bank: only IBAN changes (all other fields match current). Plus a brand-new bank.
        String json = JSON.serialize(new List<Object>{
            new Map<String, Object>{ 'recordId' => existing.Id, 'fields' => new Map<String, Object>{
                'Name' => 'ENBD', 'Bank_Account_Name__c' => 'ABC LLC', 'Bank_Account_Number__c' => '123',
                'IBAN__c' => 'AE999', 'Swift_Code__c' => 'EBILAEAD', 'Branch_Name__c' => 'Bur Dubai' } },
            new Map<String, Object>{ 'recordId' => '', 'fields' => new Map<String, Object>{
                'Name' => 'ADCB', 'IBAN__c' => 'AE222', 'Bank_Account_Name__c' => '',
                'Bank_Account_Number__c' => '', 'Swift_Code__c' => '', 'Branch_Name__c' => '' } }
        });
        Approval_Request__c req = makeRequest(acc.Id, 'Bank Detail Update', json);

        Test.startTest();
        BankChangeComparisonController.Comparison c =
            BankChangeComparisonController.getBankComparison(req.Id);
        Test.stopTest();

        System.assertEquals(false, c.notApplicable);
        System.assertEquals('Bank Cmp Agency', c.agencyName);
        System.assertEquals(2, c.banks.size(), 'one edited bank + one new bank');

        BankChangeComparisonController.BankGroup edited;
        BankChangeComparisonController.BankGroup added;
        for (BankChangeComparisonController.BankGroup g : c.banks) {
            if (g.isNew) added = g; else edited = g;
        }

        System.assertNotEquals(null, edited, 'existing bank group present');
        System.assertEquals('ENBD', edited.bankLabel);
        System.assertEquals(1, edited.changes.size(), 'only IBAN changed');
        System.assertEquals('IBAN', edited.changes[0].label);
        System.assertEquals('AE111', edited.changes[0].oldValue);
        System.assertEquals('AE999', edited.changes[0].newValue);

        System.assertNotEquals(null, added, 'new bank group present');
        System.assertEquals(true, added.isNew);
        // New bank: Bank (Name) + IBAN are filled; blank fields are skipped.
        System.assertEquals(2, added.changes.size());
        for (BankChangeComparisonController.ChangeRow r : added.changes) {
            System.assertEquals('—', r.oldValue, 'new bank has no prior value');
        }
    }

    @isTest
    static void unchanged_existing_bank_is_not_shown() {
        Account acc = new Account(Name = 'NoChange Agency', Skip_Trigger__c = true);
        insert acc;
        Bank__c existing = new Bank__c(Account__c = acc.Id, Name = 'ENBD', IBAN__c = 'AE111');
        insert existing;

        // Entry identical to current -> no changed fields -> bank skipped -> notApplicable.
        String json = JSON.serialize(new List<Object>{
            new Map<String, Object>{ 'recordId' => existing.Id, 'fields' => new Map<String, Object>{
                'Name' => 'ENBD', 'IBAN__c' => 'AE111', 'Bank_Account_Name__c' => '',
                'Bank_Account_Number__c' => '', 'Swift_Code__c' => '', 'Branch_Name__c' => '' } }
        });
        Approval_Request__c req = makeRequest(acc.Id, 'Bank Detail Update', json);

        BankChangeComparisonController.Comparison c =
            BankChangeComparisonController.getBankComparison(req.Id);
        System.assertEquals(true, c.notApplicable, 'no changed fields -> nothing to compare');
    }

    @isTest
    static void non_bank_request_is_not_applicable() {
        Approval_Request__c req = makeRequest(null, 'Unit Price Change', '[]');
        BankChangeComparisonController.Comparison c =
            BankChangeComparisonController.getBankComparison(req.Id);
        System.assertEquals(true, c.notApplicable);
    }
}