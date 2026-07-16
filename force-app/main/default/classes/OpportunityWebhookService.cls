public with sharing class OpportunityWebhookService {
    private static final String WEBHOOK_ENDPOINT = 'https://api.backend.ae/core/v1/sf/webhooks/opportunities';

    @InvocableMethod(label='Send Opportunity Webhook' description='Sends selected opportunity details to the external webhook.' callout=true)
    public static void sendOpportunityWebhook(List<OpportunityWebhookRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        Set<Id> opportunityIds = new Set<Id>();
        for (OpportunityWebhookRequest request : requests) {
            if (request != null && request.opportunityId != null) {
                opportunityIds.add(request.opportunityId);
            }
        }

        if (opportunityIds.isEmpty()) {
            return;
        }

        Map<Id, Opportunity> opportunities = new Map<Id, Opportunity>([
            SELECT Id, Name, StageName, Project_Name__c, Agent__c, Agent__r.Name, Agent__r.Phone
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ]);

        Http http = new Http();
        for (Id opportunityId : opportunityIds) {
            Opportunity opportunityRecord = opportunities.get(opportunityId);
            if (opportunityRecord == null) {
                continue;
            }

            try {
                sendCallout(http, opportunityRecord);
            } catch (Exception error) {
                System.debug(LoggingLevel.ERROR, 'Failed to send webhook for Opportunity ' + opportunityId + ': ' + error.getMessage());
            }
        }
    }

    @TestVisible
    private static void sendCallout(Http http, Opportunity opportunityRecord) {
        Map<String, Object> payload = new Map<String, Object>{
            'opportunityId' => opportunityRecord.Id,
            'name' => opportunityRecord.Name,
            'stageName' => opportunityRecord.StageName,
            'projectName' => opportunityRecord.Project_Name__c,
            'agent' => new Map<String, Object>{
                'id' => opportunityRecord.Agent__c,
                'name' => opportunityRecord.Agent__r != null ? opportunityRecord.Agent__r.Name : null,
                'phone' => opportunityRecord.Agent__r != null ? opportunityRecord.Agent__r.Phone : null
            }
        };

        HttpRequest request = new HttpRequest();
        request.setEndpoint(WEBHOOK_ENDPOINT);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(JSON.serialize(payload));

        HttpResponse response = http.send(request);
        if (response.getStatusCode() >= 400) {
            throw new CalloutException('Webhook returned status ' + response.getStatusCode() + ': ' + response.getBody());
        }
    }

    public class CalloutException extends Exception {}

    public class OpportunityWebhookRequest {
        @InvocableVariable(required=true)
        public Id opportunityId;
    }
}