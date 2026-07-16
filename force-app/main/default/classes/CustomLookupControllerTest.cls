@IsTest
private class CustomLookupControllerTest {

    @TestSetup
    static void setupData() {
        insert new List<Account>{
            new Account(Name = 'Alpha Holding'),
            new Account(Name = 'Alpha Properties'),
            new Account(Name = 'Beta Corp')
        };
    }

    @IsTest
    static void testFindRecords_MatchingResults() {
        Test.startTest();
        List<SObject> results =
            CustomLookupController.findRecords('Alpha', 'Account', 'Name', null, null);
        Test.stopTest();

        System.assert(results.size() >= 2, 'Should return at least 2 matching accounts');
        for (SObject rec : results) {
            System.assert(
                String.valueOf(rec.get('Name')).containsIgnoreCase('Alpha'),
                'Every result should match the search key'
            );
        }
    }

    @IsTest
    static void testFindRecords_LegacyThreeArgSignature() {
        Test.startTest();
        List<SObject> results =
            CustomLookupController.findRecords('Beta', 'Account', 'Name');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Beta Corp', (String) results[0].get('Name'));
    }

    @IsTest
    static void testFindRecords_NoMatch_ReturnsEmpty() {
        Test.startTest();
        List<SObject> results =
            CustomLookupController.findRecords('ZZZNOMATCH', 'Account', 'Name', null, null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'No records should match');
    }

    @IsTest
    static void testFindRecords_PartialMatch() {
        Test.startTest();
        List<SObject> results =
            CustomLookupController.findRecords('Beta', 'Account', 'Name', null, null);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Beta Corp', (String) results[0].get('Name'));
    }

    @IsTest
    static void testFindRecords_MaxTenResults() {
        List<Account> accts = new List<Account>();
        for (Integer i = 1; i <= 12; i++) {
            accts.add(new Account(Name = 'BulkTest Account ' + i));
        }
        insert accts;

        Test.startTest();
        List<SObject> results =
            CustomLookupController.findRecords('BulkTest', 'Account', 'Name', null, null);
        Test.stopTest();

        System.assert(results.size() <= 10, 'Result set is capped at 10');
    }

    @IsTest
    static void testFindRecords_EmptySearchKey_ReturnsResults() {
        Test.startTest();
        List<SObject> results =
            CustomLookupController.findRecords('', 'Account', 'Name', null, null);
        Test.stopTest();

        System.assert(results.size() > 0, 'Empty key should match all accounts (up to LIMIT 10)');
    }

    @IsTest
    static void testFindRecords_InvalidObjectName_ThrowsAura() {
        Test.startTest();
        try {
            CustomLookupController.findRecords('test', 'InvalidObject__xyz', 'Name', null, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertEquals('System.AuraHandledException', e.getTypeName());
        }
        Test.stopTest();
    }

    @IsTest
    static void testFindRecords_InvalidFieldName_ThrowsAura() {
        Test.startTest();
        try {
            CustomLookupController.findRecords('test', 'Account', 'NonExistentField__xyz', null, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertEquals('System.AuraHandledException', e.getTypeName());
        }
        Test.stopTest();
    }

    @IsTest
    static void testFindRecords_InvalidFilterField_ThrowsAura() {
        Test.startTest();
        try {
            CustomLookupController.findRecords(
                'Alpha',
                'Account',
                'Name',
                'NonExistentField__xyz',
                UserInfo.getUserId()
            );
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertEquals('System.AuraHandledException', e.getTypeName());
        }
        Test.stopTest();
    }
}