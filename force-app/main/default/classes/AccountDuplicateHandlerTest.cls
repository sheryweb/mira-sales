@isTest
public class AccountDuplicateHandlerTest {
    @testSetup
    static void setupTestData() {
        // Create a RecordType for testing
        Id testRecordType = '012Hp000001yUTAIA2';

        // Create existing Account with the same email
        Account existingAccount = new Account(
            Name = 'Existing Account',
            RecordTypeId = testRecordType,
            Company_Email__c = 'test@example.com'
        );
        insert existingAccount;
    }

    @isTest
    static void testDuplicateEmailPreventionOnInsert() {
        // Retrieve the RecordTypeId for testing
        Id testRecordType = '012Hp000001yUTAIA2';

        // Attempt to create a duplicate Account
        Account newAccount = new Account(
            Name = 'Duplicate Account',
            RecordTypeId = testRecordType,
            Company_Email__c = 'test@example.com'
        );

        Test.startTest();
        try {
            insert newAccount;
            System.assert(false, 'Expected a DML exception for duplicate email.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('The Company Email is already in use'),
                'Expected duplicate email error message.');
        }
        Test.stopTest();
    }

    @isTest
    static void testUniqueEmailInsertion() {
        // Retrieve the RecordTypeId for testing
        Id testRecordType = '012Hp000001yUTAIA2';

        // Insert a new Account with a unique email
        Account uniqueAccount = new Account(
            Name = 'Unique Account',
            RecordTypeId = testRecordType,
            Company_Email__c = 'unique@example.com'
        );

        Test.startTest();
        insert uniqueAccount;
        Test.stopTest();

        // Verify that the Account was inserted successfully
        Account insertedAccount = [SELECT Id, Company_Email__c FROM Account WHERE Id = :uniqueAccount.Id];
        System.assertEquals('unique@example.com', insertedAccount.Company_Email__c,
            'Expected unique email to be inserted.');
    }

    @isTest
    static void testUpdateToDuplicateEmail() {
        // Retrieve the RecordTypeId for testing
        Id testRecordType = '012Hp000001yUTAIA2';

        // Create a new Account with a unique email
        Account uniqueAccount = new Account(
            Name = 'Another Unique Account',
            RecordTypeId = testRecordType,
            Company_Email__c = 'another@example.com'
        );
        insert uniqueAccount;

        // Attempt to update this Account to have a duplicate email
        uniqueAccount.Company_Email__c = 'test@example.com';

        Test.startTest();
        try {
            update uniqueAccount;
            System.assert(false, 'Expected a DML exception for duplicate email on update.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('The Company Email is already in use'),
                'Expected duplicate email error message on update.');
        }
        Test.stopTest();
    }

    @isTest
    static void testNonTargetRecordType() {
        // Create a RecordType that is not the target for this trigger
        Id otherRecordType = '012Hp000001yiSEIAY';

        // Create two accounts with the same email under the non-target record type
        Account account1 = new Account(
            Name = 'Non-Target Account 1',
            RecordTypeId = otherRecordType,
            Company_Email__c = 'test@example.com'
        );

        Account account2 = new Account(
            Name = 'Non-Target Account 2',
            RecordTypeId = otherRecordType,
            Company_Email__c = 'test@example.com'
        );

        Test.startTest();
        insert account1;
        insert account2; // Should not throw an error
        Test.stopTest();
    }
}