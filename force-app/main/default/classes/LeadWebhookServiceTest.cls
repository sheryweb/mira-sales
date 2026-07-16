@IsTest
private class LeadWebhookServiceTest {
    private class LeadWebhookMock implements HttpCalloutMock {
        private final Lead expectedLead;

        LeadWebhookMock(Lead expectedLead) {
            this.expectedLead = expectedLead;
        }

        public HTTPResponse respond(HTTPRequest request) {
            System.assertEquals('https://api.backend.ae/core/v1/sf/webhooks', request.getEndpoint(), 'Unexpected endpoint.');
            System.assertEquals('POST', request.getMethod(), 'Unexpected method.');
            System.assertEquals('application/json', request.getHeader('Content-Type'), 'Unexpected content type.');

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            System.assertEquals(String.valueOf(expectedLead.Id), (String) payload.get('leadId'), 'Lead Id mismatch.');
            System.assertEquals(expectedLead.Status, (String) payload.get('status'), 'Status mismatch.');
            System.assertEquals(expectedLead.Email, (String) payload.get('email'), 'Email mismatch.');
            System.assertEquals(expectedLead.Name, (String) payload.get('name'), 'Name mismatch.');

            HTTPResponse response = new HTTPResponse();
            response.setStatusCode(200);
            response.setBody('{"success":true}');
            return response;
        }
    }

    @IsTest
    static void sendLeadWebhook_singleLead_success() {
        Lead leadRecord = new Lead(
            LastName = 'Webhook',
            Company = 'Test Company',
            Status = 'Open - Not Contacted',
            Email = 'webhook@test.com',
            Funnel_Type__c = 'Database'
        );
        insert leadRecord;
        leadRecord = [
            SELECT Id, Status, Email, Name
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];

        LeadWebhookService.LeadWebhookRequest request = new LeadWebhookService.LeadWebhookRequest();
        request.leadId = leadRecord.Id;

        Test.setMock(HttpCalloutMock.class, new LeadWebhookMock(leadRecord));

        Test.startTest();
        LeadWebhookService.sendLeadWebhook(new List<LeadWebhookService.LeadWebhookRequest>{ request });
        Test.stopTest();
    }

    @IsTest
    static void sendLeadWebhook_ignoresMissingLead() {
        Lead leadRecord = new Lead(
            LastName = 'Archived',
            Company = 'Test Company',
            Status = 'Open - Not Contacted',
            Email = 'archived@test.com',
            Funnel_Type__c = 'Database'
        );
        insert leadRecord;
        Id deletedLeadId = leadRecord.Id;
        delete leadRecord;

        LeadWebhookService.LeadWebhookRequest request = new LeadWebhookService.LeadWebhookRequest();
        request.leadId = deletedLeadId;

        Test.startTest();
        LeadWebhookService.sendLeadWebhook(new List<LeadWebhookService.LeadWebhookRequest>{ request });
        Test.stopTest();
    }
}