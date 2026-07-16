@IsTest
private class OpportunityWebhookServiceTest {
    private class SuccessWebhookMock implements HttpCalloutMock {
        public HttpRequest capturedRequest;

        public HTTPResponse respond(HTTPRequest request) {
            this.capturedRequest = request;

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"status":"ok"}');
            return response;
        }
    }

    private class ErrorWebhookMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setBody('{"status":"error"}');
            return response;
        }
    }

    @IsTest
    static void sendOpportunityWebhook_successfulCallout() {
        Account agencyAccount = new Account(
            Name = 'Test Agency',
            Type = 'Agency',
            Company_Email__c = 'testagency@test.com',
            RecordTypeId = '012Hp000001yUTAIA2'
        );
        insert agencyAccount;

        Contact agentContact = createAgentContact(agencyAccount.Id);
        
        // Requery contact to ensure Name is properly populated
        agentContact = [SELECT Id, Name, Phone FROM Contact WHERE Id = :agentContact.Id];

        Account accountRecord = new Account(Name = 'Test Account');
        insert accountRecord;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'Pipeline Deal',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Assisted_by_Agent__c = true,
            Agency__c = agencyAccount.Id,
            Agent__c = agentContact.Id,
            AccountId = accountRecord.Id
        );
        insert opportunityRecord;
        
        // Requery to ensure all fields are properly populated
        opportunityRecord = [
            SELECT Id, Name, StageName, Project_Name__c, Agent__c, Agent__r.Name, Agent__r.Phone
            FROM Opportunity
            WHERE Id = :opportunityRecord.Id
        ];

        OpportunityWebhookService.OpportunityWebhookRequest requestWrapper =
            new OpportunityWebhookService.OpportunityWebhookRequest();
        requestWrapper.opportunityId = opportunityRecord.Id;

        SuccessWebhookMock mock = new SuccessWebhookMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        OpportunityWebhookService.sendOpportunityWebhook(new List<OpportunityWebhookService.OpportunityWebhookRequest>{
            requestWrapper, null
        });
        Test.stopTest();

        System.assertNotEquals(null, mock.capturedRequest, 'Request should be sent');
        System.assertEquals(
            'https://api.backend.ae/core/v1/sf/webhooks/opportunities',
            mock.capturedRequest.getEndpoint(),
            'Endpoint should match expected webhook URL'
        );

        String jsonBody = mock.capturedRequest.getBody();
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        
        // Verify all expected keys exist
        System.assert(payload.containsKey('opportunityId'), 'Payload should contain opportunityId');
        System.assert(payload.containsKey('name'), 'Payload should contain name');
        System.assert(payload.containsKey('stageName'), 'Payload should contain stageName');
        System.assert(payload.containsKey('agent'), 'Payload should contain agent');
        
        // Verify values
        System.assertEquals(String.valueOf(opportunityRecord.Id), String.valueOf(payload.get('opportunityId')), 'Opportunity ID mismatch');
        System.assertEquals(opportunityRecord.Name, String.valueOf(payload.get('name')), 'Opportunity Name mismatch');
        System.assertEquals(opportunityRecord.StageName, String.valueOf(payload.get('stageName')), 'Stage Name mismatch');
        System.assertEquals(null, payload.get('projectName'), 'Project Name should be null');

        Map<String, Object> agentPayload = (Map<String, Object>) payload.get('agent');
        System.assertNotEquals(null, agentPayload, 'Agent payload should not be null');
        System.assertEquals(String.valueOf(agentContact.Id), String.valueOf(agentPayload.get('id')), 'Agent ID mismatch');
        System.assertEquals(agentContact.Name, String.valueOf(agentPayload.get('name')), 'Agent Name mismatch');
        System.assertEquals(agentContact.Phone, String.valueOf(agentPayload.get('phone')), 'Agent Phone mismatch');
    }

    @IsTest
    static void sendOpportunityWebhook_withoutAgent() {
        Account accountRecord = new Account(Name = 'No Agent Account');
        insert accountRecord;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'Direct Deal',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Assisted_by_Agent__c = false,
            AccountId = accountRecord.Id
        );
        insert opportunityRecord;

        OpportunityWebhookService.OpportunityWebhookRequest requestWrapper =
            new OpportunityWebhookService.OpportunityWebhookRequest();
        requestWrapper.opportunityId = opportunityRecord.Id;

        SuccessWebhookMock mock = new SuccessWebhookMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        OpportunityWebhookService.sendOpportunityWebhook(new List<OpportunityWebhookService.OpportunityWebhookRequest>{
            requestWrapper
        });
        Test.stopTest();

        System.assertNotEquals(null, mock.capturedRequest, 'Request should be sent');
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(mock.capturedRequest.getBody());
        Map<String, Object> agentPayload = (Map<String, Object>) payload.get('agent');
        System.assertEquals(null, agentPayload.get('id'), 'Agent ID should be null when no agent');
        System.assertEquals(null, agentPayload.get('name'), 'Agent name should be null when no agent');
        System.assertEquals(null, agentPayload.get('phone'), 'Agent phone should be null when no agent');
    }

    @IsTest
    static void sendOpportunityWebhook_handlesNullAndEmptyRequests() {
        Test.startTest();
        OpportunityWebhookService.sendOpportunityWebhook(null);
        OpportunityWebhookService.sendOpportunityWebhook(new List<OpportunityWebhookService.OpportunityWebhookRequest>());
        OpportunityWebhookService.sendOpportunityWebhook(new List<OpportunityWebhookService.OpportunityWebhookRequest>{
            new OpportunityWebhookService.OpportunityWebhookRequest()
        });
        Test.stopTest();

        // Should complete without errors
        System.assert(true, 'Should handle null and empty requests gracefully');
    }

    @IsTest
    static void sendOpportunityWebhook_handlesErrorResponse() {
        Account agencyAccount = new Account(
            Name = 'Error Agency',
            Type = 'Agency',
            Company_Email__c = 'erroragency@test.com',
            RecordTypeId = '012Hp000001yUTAIA2'
        );
        insert agencyAccount;

        Contact agentContact = createAgentContact(agencyAccount.Id);

        Account accountRecord = new Account(Name = 'Error Account');
        insert accountRecord;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'At Risk Deal',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15),
            Assisted_by_Agent__c = true,
            Agency__c = agencyAccount.Id,
            Agent__c = agentContact.Id,
            AccountId = accountRecord.Id
        );
        insert opportunityRecord;

        OpportunityWebhookService.OpportunityWebhookRequest requestWrapper =
            new OpportunityWebhookService.OpportunityWebhookRequest();
        requestWrapper.opportunityId = opportunityRecord.Id;

        Test.setMock(HttpCalloutMock.class, new ErrorWebhookMock());

        Test.startTest();
        OpportunityWebhookService.sendOpportunityWebhook(new List<OpportunityWebhookService.OpportunityWebhookRequest>{
            requestWrapper
        });
        Test.stopTest();

        // No exception should propagate even though the callout returns an error.
        System.assert(true, 'Execution should continue despite webhook error');
    }

    private static Contact createAgentContact(Id accountId) {
        Contact agentContact = new Contact(
            FirstName = 'Agent',
            LastName = 'Contact',
            Email = 'agent.contact@example.com',
            Phone = '+1-555-000-1111',
            AccountId = accountId
        );

        insert agentContact;
        return agentContact;
    }
}