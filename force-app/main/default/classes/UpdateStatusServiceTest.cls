@IsTest
private class UpdateStatusServiceTest {

    @IsTest
    static void testHandleAccountUpdateSuccess() {
        // Create a test Account record that meets the condition for updating
        Account testAccount = new Account(
            Name = 'Test Account',
            Status__c = 'Incomplete Registration',
            In_Process_Notification__c = false
        );
        insert testAccount;

        // Set up the REST request
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/UpdateAccountStatusService/';
        req.httpMethod = 'POST';
        req.addParameter('accountId', testAccount.Id);
        RestContext.request = req;

        // Call the method
        String response = UpdateStatusService.handleAccountUpdate(testAccount.Id);

        // Verify that the response is successful
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('true', result.get('success'));
        System.assertEquals('Account registration request submitted successfully', result.get('message'));

        // Refresh the account to verify that the status has been updated
        testAccount = [SELECT Status__c, In_Process_Notification__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('In Process', testAccount.Status__c);
    }

    @IsTest
    static void testHandleAccountUpdateFailureStatusAlreadyRegistered() {
        // Create a test Account record that does not meet the condition for updating
        Account testAccount = new Account(
            Name = 'Already Registered Account',
            Status__c = 'Completed',
            In_Process_Notification__c = true
        );
        insert testAccount;

        // Set up the REST request
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/UpdateAccountStatusService/';
        req.httpMethod = 'POST';
        req.addParameter('accountId', testAccount.Id);
        RestContext.request = req;

        // Call the method
        String response = UpdateStatusService.handleAccountUpdate(testAccount.Id);

        // Verify that the response indicates failure
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('false', result.get('success'));
        System.assertEquals('Account already registered', result.get('message'));
    }

    @IsTest
    static void testHandleAccountUpdateExceptionHandling() {
        // Set up the REST request with an invalid Account ID
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/UpdateAccountStatusService/';
        req.httpMethod = 'POST';
        req.addParameter('accountId', 'invalidId');
        RestContext.request = req;

        // Call the method and capture the exception response
        String response = UpdateStatusService.handleAccountUpdate('invalidId');

        // Verify that the response indicates an error
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('false', result.get('success'));
        System.assertNotEquals(null, result.get('error'));
    }
}