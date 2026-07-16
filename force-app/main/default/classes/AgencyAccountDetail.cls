global without sharing class AgencyAccountDetail {
    @RemoteAction
    global static String checkAccountStatus(String registrationNumber) {
        // Create a map to store response
        Map<String, Object> responseMap = new Map<String, Object>();

        try {
            // Query the Account based on the registrationNumber
            Account account = [SELECT Id, Name, Status__c, Registration_Number__c, Is_Agency_International__c, VAT_TRN__c, Agency_Registered_Emirate__c FROM Account 
                               WHERE Registration_Number__c = :registrationNumber LIMIT 1];

            responseMap.put('status', 'success');
            responseMap.put('message', 'Account found');
            responseMap.put('data', account); // Add the queried account data
        } catch (Exception e) {
            responseMap.put('status', 'error');
            responseMap.put('message', e.getMessage());
        }

        // Return JSON string
        return JSON.serialize(responseMap);
    }
}