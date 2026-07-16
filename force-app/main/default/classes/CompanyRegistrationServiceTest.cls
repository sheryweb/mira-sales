@isTest
public class CompanyRegistrationServiceTest {

    @testSetup
    static void setupTestData() {
        // Create some sample data that can be reused across tests if needed
    }

    @isTest
    static void testHandleCompanyRegistration() {
        // Test Data Setup for method parameters
        String internationalAgency = 'No';
        String companyName = 'Test Company';
        String tradeLicense = 'TL-123456';
        String issueDate = '2023-01-01';
        String expiryDate = '2025-01-01';
        String ornNumber = 'ORN123456';
        String trnNumber = 'TRN123456';
        String companyAddress = '123 Test Street';
        String poBox = 'PO12345';
        String email = 'test@company.com';
        String phone = '1234567890';
        String landline = '0987654321';
        String adminEmail = 'admin@company.com';
        String adminMobile = '9999999999';
        String relationManager = 'John Doe';
        String signatoryName = 'Jane Smith';
        String signatoryNumber = '1111111111';
        String signatoryEmail = 'signatory@company.com';

        List<String> shareholderNames = new List<String>{'Shareholder 1', 'Shareholder 2'};
        List<Decimal> shareholderPercentages = new List<Decimal>{40.0, 60.0};

        List<String> bankNames = new List<String>{'Bank 1', 'Bank 2'};
        List<String> accountNames = new List<String>{'Account 1', 'Account 2'};
        List<String> accountNumbers = new List<String>{'123456789', '987654321'};
        List<String> accountIBANs = new List<String>{'IBAN12345', 'IBAN54321'};
        List<String> accountSwiftCodes = new List<String>{'SWIFT12345', 'SWIFT54321'};
        List<String> branchNames = new List<String>{'Branch 1', 'Branch 2'};

        List<String> fileNames = new List<String>{'File 1', 'File 2'};
        List<String> fileContents = new List<String>{'FileContent1', 'FileContent2'};

        Test.startTest();
        // Call the CompanyRegistrationService and capture the response
        List<String> response = CompanyRegistrationService.handleCompanyRegistration(
            internationalAgency,
            companyName,
            tradeLicense,
            issueDate,
            expiryDate,
            ornNumber,
            trnNumber,
            companyAddress,
            poBox,
            email,
            phone,
            landline,
            adminEmail,
            adminMobile,
            relationManager,
            signatoryName,
            signatoryNumber,
            signatoryEmail,
            shareholderNames,
            shareholderPercentages,
            bankNames,
            accountNames,
            accountNumbers,
            accountIBANs,
            accountSwiftCodes,
            branchNames,
            fileNames,
            fileContents
        );
        Test.stopTest();

        // Validate the response
        System.assertEquals(2, response.size(), 'Response should have 2 elements');
        System.assertEquals('Account Added Successfully', response[0], 'The first response message should be success');

        // Query the inserted Account and related Shareholders and Bank Accounts
        Account insertedAccount = [SELECT Id, Name, Trade_License_Number__c FROM Account WHERE Name = :companyName LIMIT 1];
        System.assertNotEquals(null, insertedAccount, 'Account should be inserted');
        System.assertEquals(tradeLicense, insertedAccount.Trade_License_Number__c, 'Trade license should match');

        List<Shareholder__c> insertedShareholders = [SELECT Id, Name, Percent__c, Account__c FROM Shareholder__c WHERE Account__c = :insertedAccount.Id];
        System.assertEquals(2, insertedShareholders.size(), 'There should be 2 shareholders');
        System.assertEquals(40.0, insertedShareholders[0].Percent__c, 'Shareholder 1 percentage should match');
        System.assertEquals(60.0, insertedShareholders[1].Percent__c, 'Shareholder 2 percentage should match');

        List<Bank__c> insertedBankAccounts = [SELECT Id, Name, Bank_Account_Name__c, Account__c FROM Bank__c WHERE Account__c = :insertedAccount.Id];
        System.assertEquals(2, insertedBankAccounts.size(), 'There should be 2 bank accounts');
        System.assertEquals('Account 1', insertedBankAccounts[0].Bank_Account_Name__c, 'Bank Account 1 should match');
        System.assertEquals('Account 2', insertedBankAccounts[1].Bank_Account_Name__c, 'Bank Account 2 should match');
    }

    @isTest
    static void testHandleCompanyRegistrationWithEmptyLists() {
        // Test Data Setup for method parameters with empty lists for shareholders and bank accounts
        String internationalAgency = 'No';
        String companyName = 'Test Company Empty';
        String tradeLicense = 'TL-654321';
        String issueDate = '2023-01-01';
        String expiryDate = '2025-01-01';
        String ornNumber = 'ORN654321';
        String trnNumber = 'TRN654321';
        String companyAddress = '456 Empty Street';
        String poBox = 'PO65432';
        String email = 'empty@company.com';
        String phone = '0987654321';
        String landline = '1234567890';
        String adminEmail = 'adminempty@company.com';
        String adminMobile = '8888888888';
        String relationManager = 'Alice Doe';
        String signatoryName = 'Bob Smith';
        String signatoryNumber = '2222222222';
        String signatoryEmail = 'signatoryempty@company.com';

        List<String> emptyList = new List<String>();
        List<Decimal> emptyDecimalList = new List<Decimal>();

        Test.startTest();
        // Call the CompanyRegistrationService with empty shareholder and bank lists
        List<String> response = CompanyRegistrationService.handleCompanyRegistration(
            internationalAgency,
            companyName,
            tradeLicense,
            issueDate,
            expiryDate,
            ornNumber,
            trnNumber,
            companyAddress,
            poBox,
            email,
            phone,
            landline,
            adminEmail,
            adminMobile,
            relationManager,
            signatoryName,
            signatoryNumber,
            signatoryEmail,
            emptyList,
            emptyDecimalList,
            emptyList,
            emptyList,
            emptyList,
            emptyList,
            emptyList,
            emptyList,
            emptyList,
            emptyList
        );
        Test.stopTest();

        // Validate the response
        System.assertEquals(2, response.size(), 'Response should have 2 elements');
        System.assertEquals('Account Added Successfully', response[0], 'The first response message should be success');

        // Query the inserted Account
        Account insertedAccount = [SELECT Id, Name, Trade_License_Number__c FROM Account WHERE Name = :companyName LIMIT 1];
        System.assertNotEquals(null, insertedAccount, 'Account should be inserted');
        System.assertEquals(tradeLicense, insertedAccount.Trade_License_Number__c, 'Trade license should match');

        // Ensure no shareholders or bank accounts are inserted
        List<Shareholder__c> insertedShareholders = [SELECT Id FROM Shareholder__c WHERE Account__c = :insertedAccount.Id];
        System.assertEquals(0, insertedShareholders.size(), 'There should be no shareholders');

        List<Bank__c> insertedBankAccounts = [SELECT Id FROM Bank__c WHERE Account__c = :insertedAccount.Id];
        System.assertEquals(0, insertedBankAccounts.size(), 'There should be no bank accounts');
    }
}