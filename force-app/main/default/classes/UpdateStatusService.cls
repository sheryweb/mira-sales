@RestResource(urlMapping='/UpdateAccountStatusService/*')
global with sharing class UpdateStatusService {

    @HttpPost
    global static String handleAccountUpdate(String accountId) {
        try {
            // Create ContentVersion record to upload the file in Salesforce
            Account acct = [SELECT Id, Status__c, In_Process_Notification__c FROM Account WHERE Id = :accountId];
            
            if (acct.Status__c == 'Incomplete Registration' && acct.In_Process_Notification__c == false) {
                acct.Status__c = 'In Process';
                update acct;
    
                return JSON.serialize(new Map<String, String> {
                    'success' => 'true',
                    'message' => 'Account registration request submitted successfully'
                });
            } else {
                return JSON.serialize(new Map<String, String> {
                    'success' => 'false',
                    'message' => 'Account already registered'
                });
            }
        } catch (Exception e) {
            return JSON.serialize(new Map<String, String> {
                'success' => 'false',
                'error' => e.getMessage()
            });
        }
    }
}