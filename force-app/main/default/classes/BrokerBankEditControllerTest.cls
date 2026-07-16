@isTest
private class BrokerBankEditControllerTest {

    private static Id agencyRtId() {
        Map<String, Schema.RecordTypeInfo> m = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (m.containsKey('Agency') && m.get('Agency').isAvailable()) return m.get('Agency').getRecordTypeId();
        for (Schema.RecordTypeInfo i : m.values()) if (i.isAvailable() && !i.isMaster()) return i.getRecordTypeId();
        return null;
    }

    private static Broker_User__c setup(Boolean withBank) {
        String u = String.valueOf(Crypto.getRandomLong());
        Account agency = new Account(Name = 'Bank Agency ' + u, Skip_Trigger__c = true);
        Id rt = agencyRtId(); if (rt != null) agency.RecordTypeId = rt;
        insert agency;
        if (withBank) {
            insert new Bank__c(Account__c = agency.Id, Name = 'Emirates NBD',
                Bank_Account_Name__c = 'ABC LLC', Bank_Account_Number__c = '123',
                IBAN__c = 'AE111', Swift_Code__c = 'EBILAEAD', Branch_Name__c = 'Bur Dubai');
        }
        Broker_User__c bu = new Broker_User__c(Account__c = agency.Id, Email__c = 'bank' + u + '@example.com', Active__c = true);
        insert bu;
        return bu;
    }

    private static void loginAs(Broker_User__c bu) {
        Test.setCurrentPage(Page.BrokerBankEdit);
        ApexPages.currentPage().getCookies().put('brokerSession',
            new Cookie('brokerSession', BrokerLoginController.buildSessionToken(bu.Id), '/', 3600, true));
    }

    @isTest
    static void loads_existing_bank_only() {
        Broker_User__c bu = setup(true);
        loginAs(bu);
        BrokerBankEditController c = new BrokerBankEditController();
        System.assertEquals(false, c.locked, 'no pending request');
        System.assertEquals(1, c.rows.size(), 'only the existing bank (no add-new row)');
        System.assertEquals('Emirates NBD', c.rows[0].bankName);
        System.assertEquals(true, c.getHasRows());
    }

    @isTest
    static void no_banks_on_file_shows_empty() {
        Broker_User__c bu = setup(false);
        loginAs(bu);
        BrokerBankEditController c = new BrokerBankEditController();
        System.assertEquals(0, c.rows.size(), 'no banks -> no rows');
        System.assertEquals(false, c.getHasRows());
    }

    @isTest
    static void edit_existing_bank_creates_request() {
        Broker_User__c bu = setup(true);
        loginAs(bu);
        BrokerBankEditController c = new BrokerBankEditController();
        c.rows[0].iban = 'AE999999';   // change the IBAN on the existing bank

        Test.startTest();
        c.save();
        Test.stopTest();

        System.assertEquals(true, c.submitted);
        List<Approval_Request__c> reqs = [
            SELECT Status__c, Profile_Changes_JSON__c FROM Approval_Request__c
            WHERE Related_Record_Id__c = :String.valueOf(bu.Account__c) AND Request_Type__c = 'Bank Detail Update'
        ];
        System.assertEquals(1, reqs.size(), 'one bank request created');
        System.assertEquals('Pending', reqs[0].Status__c);
        System.assert(reqs[0].Profile_Changes_JSON__c.contains('AE999999'), 'JSON has the new IBAN');
    }

    @isTest
    static void no_changes_shows_message() {
        Broker_User__c bu = setup(true);
        loginAs(bu);
        BrokerBankEditController c = new BrokerBankEditController();
        c.save(); // nothing edited
        System.assertEquals(false, c.submitted);
        System.assertNotEquals(null, c.message);
        System.assertEquals(0, [SELECT COUNT() FROM Approval_Request__c WHERE Related_Record_Id__c = :String.valueOf(bu.Account__c)]);
    }

    @isTest
    static void locked_when_request_pending() {
        Broker_User__c bu = setup(true);
        insert new Approval_Request__c(
            Request_Type__c = 'Bank Detail Update', Related_Object_Type__c = 'Account',
            Related_Record_Id__c = String.valueOf(bu.Account__c), Field_To_Update__c = 'x',
            Current_Value__c = 'x', Requested_Value__c = 'x', Justification__c = 'pending one',
            Status__c = 'Pending');
        loginAs(bu);
        BrokerBankEditController c = new BrokerBankEditController();
        System.assertEquals(true, c.locked, 'locked because a bank request is pending');
    }
}