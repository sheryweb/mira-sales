@IsTest
private class BookUnitControllerTest {
    @TestSetup
    static void setupData() {
        Map<String, RecordTypeInfo> accountRecordTypesByName = Schema.SObjectType.Account.getRecordTypeInfosByName();
        Id clientRecordTypeId = accountRecordTypesByName.containsKey('Client')
            ? accountRecordTypesByName.get('Client').getRecordTypeId()
            : accountRecordTypesByName.get('Master').getRecordTypeId();
        Id agencyRecordTypeId = accountRecordTypesByName.containsKey('Agency')
            ? accountRecordTypesByName.get('Agency').getRecordTypeId()
            : clientRecordTypeId;
        Set<Id> personAccountRtIds = new Set<Id>();
        for (RecordType rt : [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND IsPersonType = true]) {
            personAccountRtIds.add(rt.Id);
        }
        Boolean isPersonAccount = personAccountRtIds.contains(clientRecordTypeId);

        Account agencyAccount = new Account(
            Name = 'Test Agency Account',
            RecordTypeId = agencyRecordTypeId,
            Status__c = 'Completed',
            Company_Email__c = 'agency@test.com'
        );
        insert agencyAccount;

        Account clientAccount;
        if (isPersonAccount) {
            clientAccount = new Account(
                FirstName = 'Test',
                LastName = 'Client Account',
                RecordTypeId = clientRecordTypeId,
                PersonEmail = 'client@test.com'
            );
        } else {
            clientAccount = new Account(
                Name = 'Test Client Account',
                RecordTypeId = clientRecordTypeId,
                Company_Email__c = 'client@test.com'
            );
        }
        insert clientAccount;

        Contact agentContact = new Contact(
            FirstName = 'Test',
            LastName = 'Agent',
            AccountId = agencyAccount.Id
        );
        insert agentContact;

        Unit__c testUnit = new Unit__c(
            Title__c = 'Test Unit 101'
        );
        insert testUnit;
    }

    @IsTest
    static void searchClientAccounts_returnsResults() {
        Test.startTest();
        List<Account> results = BookUnitController.searchClientAccounts('Test');
        Test.stopTest();
        System.assertNotEquals(null, results, 'Should return a list');
    }

    @IsTest
    static void searchClientAccounts_shortSearchReturnsInitialList() {
        Test.startTest();
        List<Account> results = BookUnitController.searchClientAccounts('T');
        Test.stopTest();
        System.assertNotEquals(null, results, 'Should return a list');
    }

    @IsTest
    static void searchAgencyAccounts_returnsResults() {
        Test.startTest();
        List<Account> results = BookUnitController.searchAgencyAccounts('Test');
        Test.stopTest();
        System.assertNotEquals(null, results, 'Should return a list');
    }

    @IsTest
    static void searchContactsByAccount_returnsResults() {
        Account agencyAccount = [SELECT Id FROM Account WHERE Name = 'Test Agency Account' LIMIT 1];
        Test.startTest();
        List<Contact> results = BookUnitController.searchContactsByAccount('Test', agencyAccount.Id);
        Test.stopTest();
        System.assertNotEquals(null, results, 'Should return a list');
    }

    @IsTest
    static void searchContactsByAccount_nullAccountReturnsEmpty() {
        Test.startTest();
        List<Contact> results = BookUnitController.searchContactsByAccount('Test', null);
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Null account should return empty');
    }

    @IsTest
    static void createBookingOpportunity_withoutAgent() {
        Account clientAccount = [SELECT Id, Name FROM Account WHERE LastName = 'Client Account' OR Name = 'Test Client Account' LIMIT 1];
        Unit__c testUnit = [SELECT Id, Title__c FROM Unit__c WHERE Title__c = 'Test Unit 101' LIMIT 1];

        Test.startTest();
        Id oppId = BookUnitController.createBookingOpportunity(
            clientAccount.Id,
            testUnit.Id,
            null,
            null,
            false
        );
        Test.stopTest();

        System.assertNotEquals(null, oppId, 'Should return opportunity Id');
        Opportunity opp = [SELECT Id, Name, AccountId, Unit__c, StageName, Assisted_by_Agent__c, Agency__c, Agent__c FROM Opportunity WHERE Id = :oppId LIMIT 1];
        System.assertEquals(clientAccount.Id, opp.AccountId, 'AccountId should match client');
        System.assertEquals(testUnit.Id, opp.Unit__c, 'Unit__c should match');
        System.assertEquals('Booked', opp.StageName, 'StageName should be Booked');
        System.assertEquals(false, opp.Assisted_by_Agent__c, 'Assisted by Agent should be false');
    }

    @IsTest
    static void createBookingOpportunity_withAgent() {
        Account clientAccount = [SELECT Id, Name FROM Account WHERE LastName = 'Client Account' OR Name = 'Test Client Account' LIMIT 1];
        Account agencyAccount = [SELECT Id FROM Account WHERE Name = 'Test Agency Account' LIMIT 1];
        Contact agentContact = [SELECT Id FROM Contact WHERE LastName = 'Agent' LIMIT 1];
        Unit__c testUnit = [SELECT Id, Title__c FROM Unit__c WHERE Title__c = 'Test Unit 101' LIMIT 1];

        Test.startTest();
        Id oppId = BookUnitController.createBookingOpportunity(
            clientAccount.Id,
            testUnit.Id,
            agencyAccount.Id,
            agentContact.Id,
            true
        );
        Test.stopTest();

        System.assertNotEquals(null, oppId, 'Should return opportunity Id');
        Opportunity opp = [SELECT Id, Agency__c, Agent__c, Assisted_by_Agent__c FROM Opportunity WHERE Id = :oppId LIMIT 1];
        System.assertEquals(agencyAccount.Id, opp.Agency__c, 'Agency__c should match');
        System.assertEquals(agentContact.Id, opp.Agent__c, 'Agent__c should match');
        System.assertEquals(true, opp.Assisted_by_Agent__c, 'Assisted by Agent should be true');
    }

    @IsTest
    static void createBookingOpportunity_nullAccountThrows() {
        Unit__c testUnit = [SELECT Id FROM Unit__c WHERE Title__c = 'Test Unit 101' LIMIT 1];
        Boolean threw = false;
        try {
            Test.startTest();
            BookUnitController.createBookingOpportunity(null, testUnit.Id, null, null, false);
            Test.stopTest();
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Should throw for null account');
    }

    @IsTest
    static void createBookingOpportunity_nullUnitThrows() {
        Account clientAccount = [SELECT Id FROM Account WHERE LastName = 'Client Account' OR Name = 'Test Client Account' LIMIT 1];
        Boolean threw = false;
        try {
            Test.startTest();
            BookUnitController.createBookingOpportunity(clientAccount.Id, null, null, null, false);
            Test.stopTest();
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Should throw for null unit');
    }
}