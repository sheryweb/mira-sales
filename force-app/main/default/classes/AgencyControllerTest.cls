@isTest
public class AgencyControllerTest {
    @isTest
    static void testGetAccountExist() {
        // Create a test account
        Account testAccount = new Account(
            Name = 'Test Account',
            Trade_License_Number__c = 'TL12345',
            Status__c = 'In Process'
        );
        insert testAccount;

        // Test when account exists
        Test.startTest();
        String result = AgencyController.getAccountExist('TL12345');
        System.assertEquals('Account Exist', result);

        // Test when account does not exist
        result = AgencyController.getAccountExist('TL67890');
        System.assertEquals('Account Not Found', result);

        // Test when trade license number is blank
        result = AgencyController.getAccountExist('');
        Test.stopTest();
        System.assertEquals('Trade License not provided', result);
    }

    @isTest
    static void testHandleCompanyRegistrationDubai() {
        // Prepare test data
        List<String> shareholderNames = new List<String>{'Shareholder 1', 'Shareholder 2'};
        List<Decimal> shareholderPercentages = new List<Decimal>{50, 50};
        List<String> bankNames = new List<String>{'Bank 1'};
        List<String> accountNames = new List<String>{'Account 1'};
        List<String> accountNumbers = new List<String>{'123456789'};
        List<String> accountIBANs = new List<String>{'IBAN12345'};
        List<String> accountSwiftCodes = new List<String>{'SWIFT123'};
        List<String> branchNames = new List<String>{'Branch 1'};

        // Test company registration for UAE Agency in Dubai
        Test.startTest();
        List<String> result = AgencyController.handleCompanyRegistration(
            'No', // internationalAgency
            'Test Company', // companyName
            'TL12345', // tradeLicense
            '2023-01-01', // issueDate
            '2024-01-01', // expiryDate
            'ORN12345', // ornNumber (should be required for Dubai)
            'TRN12345', // trnNumber
            'Test Address', // companyAddress
            'PO12345', // poBox
            'test@example.com', // email
            '1234567890', // phone
            '0987654321', // landline
            'admin@example.com', // adminEmail
            '1234567890', // adminMobile
            'Test Manager', // relationManager
            'Signatory Name', // signatoryName
            'signatory@example.com', // signatoryEmail
            '1234567890', // signatoryNumber
            shareholderNames,
            shareholderPercentages,
            bankNames,
            accountNames,
            accountNumbers,
            accountIBANs,
            accountSwiftCodes,
            branchNames,
            'Yes', // trnSwitchValue
            'Dubai' // emirateValue
        );

        // Verify the account was created with Dubai emirate
        Account createdAccount = [SELECT Id, Agency_Registered_Emirate__c, ORN_Number__c FROM Account WHERE Id = :result[1]];
        System.assertEquals('Dubai', createdAccount.Agency_Registered_Emirate__c, 'Emirate should be set to Dubai');
        System.assertEquals('ORN12345', createdAccount.ORN_Number__c, 'ORN Number should be set for Dubai');
        Test.stopTest();
    }

    @isTest
    static void testHandleCompanyRegistrationNonDubai() {
        // Prepare test data
        List<String> shareholderNames = new List<String>{'Shareholder 1', 'Shareholder 2'};
        List<Decimal> shareholderPercentages = new List<Decimal>{50, 50};
        List<String> bankNames = new List<String>{'Bank 1'};
        List<String> accountNames = new List<String>{'Account 1'};
        List<String> accountNumbers = new List<String>{'123456789'};
        List<String> accountIBANs = new List<String>{'IBAN12345'};
        List<String> accountSwiftCodes = new List<String>{'SWIFT123'};
        List<String> branchNames = new List<String>{'Branch 1'};

        // Test company registration for UAE Agency in Abu Dhabi
        Test.startTest();
        List<String> result = AgencyController.handleCompanyRegistration(
            'No', // internationalAgency
            'Test Company', // companyName
            'TL67890', // tradeLicense
            '2023-01-01', // issueDate
            '2024-01-01', // expiryDate
            '', // ornNumber (should be empty for non-Dubai)
            'TRN12345', // trnNumber
            'Test Address', // companyAddress
            'PO12345', // poBox
            'test@example.com', // email
            '1234567890', // phone
            '0987654321', // landline
            'admin@example.com', // adminEmail
            '1234567890', // adminMobile
            'Test Manager', // relationManager
            'Signatory Name', // signatoryName
            'signatory@example.com', // signatoryEmail
            '1234567890', // signatoryNumber
            shareholderNames,
            shareholderPercentages,
            bankNames,
            accountNames,
            accountNumbers,
            accountIBANs,
            accountSwiftCodes,
            branchNames,
            'Yes', // trnSwitchValue
            'Abu Dhabi' // emirateValue
        );

        // Verify the account was created with Abu Dhabi emirate
        Account createdAccount = [SELECT Id, Agency_Registered_Emirate__c, ORN_Number__c FROM Account WHERE Id = :result[1]];
        System.assertEquals('Abu Dhabi', createdAccount.Agency_Registered_Emirate__c, 'Emirate should be set to Abu Dhabi');
        System.assertEquals(null, createdAccount.ORN_Number__c, 'ORN Number should be null for non-Dubai emirate');
        Test.stopTest();
    }

    @isTest
    static void testHandleCompanyRegistrationInternational() {
        // Prepare test data
        List<String> shareholderNames = new List<String>{'Shareholder 1', 'Shareholder 2'};
        List<Decimal> shareholderPercentages = new List<Decimal>{50, 50};
        List<String> bankNames = new List<String>{'Bank 1'};
        List<String> accountNames = new List<String>{'Account 1'};
        List<String> accountNumbers = new List<String>{'123456789'};
        List<String> accountIBANs = new List<String>{'IBAN12345'};
        List<String> accountSwiftCodes = new List<String>{'SWIFT123'};
        List<String> branchNames = new List<String>{'Branch 1'};

        // Test company registration for International Agency
        Test.startTest();
        List<String> result = AgencyController.handleCompanyRegistration(
            'Yes', // internationalAgency
            'Test International Company', // companyName
            'TL67890', // tradeLicense
            '2023-01-01', // issueDate
            '2024-01-01', // expiryDate
            null, // ornNumber (should be null for international)
            '', // trnNumber
            'Test Address', // companyAddress
            'PO12345', // poBox
            'test@example.com', // email
            '1234567890', // phone
            '0987654321', // landline
            'admin@example.com', // adminEmail
            '1234567890', // adminMobile
            'Test Manager', // relationManager
            'Signatory Name', // signatoryName
            'signatory@example.com', // signatoryEmail
            '1234567890', // signatoryNumber
            shareholderNames,
            shareholderPercentages,
            bankNames,
            accountNames,
            accountNumbers,
            accountIBANs,
            accountSwiftCodes,
            branchNames,
            'No', // trnSwitchValue
            '' // emirateValue
        );

        // Verify the account was created without an emirate
        Account createdAccount = [SELECT Id, Agency_Registered_Emirate__c, ORN_Number__c FROM Account WHERE Id = :result[1]];
        System.assertEquals(null, createdAccount.Agency_Registered_Emirate__c, 'Emirate should be null for international agency');
        System.assertEquals(null, createdAccount.ORN_Number__c, 'ORN Number should be null for international agency');
        Test.stopTest();
    }
}