@RestResource(urlMapping='/AgencyAccountDetail/*')
global with sharing class AgencyAccountDetailService {
    public class AccountDetailsResponse {
        public Account account;
        public List<Shareholder__c> shareholders;
        public List<Bank__c> banks;
    }

    public class CustomException extends Exception {}

    @HttpPost
    global static String getAccountDetails(String registrationNumber) {
        if (String.isBlank(registrationNumber)) {
            throw new CustomException('Account not found');
        }

        // Query for the account using the registration number
        List<Account> accountList = [
            SELECT Id, Name, Registration_Number__c, Status__c, Is_Agency_International__c 
            FROM Account 
            WHERE Registration_Number__c = :registrationNumber 
            LIMIT 1
        ];
        
        // If no account is found, throw an exception
        if (accountList.isEmpty()) {
            //throw new CustomException('Account not found');
            return JSON.serialize('Account Not Found');
        }

        Account account = accountList[0];

        // Query related shareholders
        List<Shareholder__c> shareholders = [
            SELECT Id, Name, Percent__c 
            FROM Shareholder__c 
            WHERE Account__c = :account.Id
        ];

        // Query related bank accounts
        List<Bank__c> banks = [
            SELECT Id, Name, Bank_Account_Name__c, Bank_Account_Number__c, IBAN__c, Swift_Code__c, Branch_Name__c 
            FROM Bank__c 
            WHERE Account__c = :account.Id
        ];

        // Create the response object
        AccountDetailsResponse response = new AccountDetailsResponse();
        response.account = account;
        response.shareholders = shareholders;
        response.banks = banks;

        // Return the response as a JSON string
        return JSON.serialize(response);
    }
}