@IsTest
public class AgencyAccountExistsServiceTest {

    @TestSetup
    static void setupData() {
        // Create an Account with a trade license number for testing purposes
        Account acc = new Account(
            Name = 'Test Account',
            Trade_License_Number__c = 'TL-12345',
            Status__c = 'Completed'
        );
        insert acc;
    }

    @IsTest
    static void testGetAccountExistWithValidTradeLicense() {
        // Test case where trade license number exists in the system
        String tradeLicenseNumber = 'TL-12345';
        String response = AgencyAccountExistsService.getAccountExist(tradeLicenseNumber);
        
        // Assert that the response is 'Account Exist'
        System.assertEquals('"Account Exist"', response, 'Response should indicate account exists');
    }

    @IsTest
    static void testGetAccountExistWithInvalidTradeLicense() {
        // Test case where trade license number does not exist in the system
        String tradeLicenseNumber = 'TL-54321';
        String response = AgencyAccountExistsService.getAccountExist(tradeLicenseNumber);
        
        // Assert that the response is 'Account Not Found'
        System.assertEquals('"Account Not Found"', response, 'Response should indicate account not found');
    }

    @IsTest
    static void testGetAccountExistWithBlankTradeLicense() {
        // Test case where trade license number is blank
        String response = AgencyAccountExistsService.getAccountExist('');
        
        // Assert that the response is 'Trade License not provided'
        System.assertEquals('"Trade License not provided"', response, 'Response should indicate no trade license provided');
    }
}