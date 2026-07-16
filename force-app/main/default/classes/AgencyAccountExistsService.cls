@RestResource(urlMapping='/AgencyAccountExist/*')
global with sharing class AgencyAccountExistsService {
	public class AccountDetailsResponse {
        public Account account;
    }
    
    @HttpPost
    global static String getAccountExist(String tradeLicenseNumber) {
        if (String.isBlank(tradeLicenseNumber)) {
            return JSON.serialize('Trade License not provided');
        }
        
        // Query for the account using the account name
        List<Account> accountList = [
            SELECT Id, Name, Trade_License_Number__c, Status__c 
            FROM Account 
            WHERE Trade_License_Number__c = :tradeLicenseNumber 
            LIMIT 1
        ];
        
        if (accountList.isEmpty()) {
            return JSON.serialize('Account Not Found');
        } else {
            return JSON.serialize('Account Exist');
        }
    }
}