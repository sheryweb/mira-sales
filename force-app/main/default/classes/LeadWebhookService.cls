public with sharing class LeadWebhookService {
    private static final String WEBHOOK_ENDPOINT = 'https://api.backend.ae/core/v1/sf/webhooks';

    @InvocableMethod(label='Send Lead Webhook' description='Sends selected lead details to the external webhook.' callout=true)
    public static void sendLeadWebhook(List<LeadWebhookRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        Set<Id> leadIds = new Set<Id>();
        for (LeadWebhookRequest request : requests) {
            if (request != null && request.leadId != null) {
                leadIds.add(request.leadId);
            }
        }

        if (leadIds.isEmpty()) {
            return;
        }

        Map<Id, Lead> leads = new Map<Id, Lead>([
            SELECT Id, Status, Email, Name, OwnerId, Owner.Name, Owner.Email, Owner.Phone,
                External_Agent_Name__c, External_Agent_Phone__c
            FROM Lead
            WHERE Id IN :leadIds
        ]);

        Http http = new Http();
        for (Id leadId : leadIds) {
            Lead leadRecord = leads.get(leadId);
            if (leadRecord == null) {
                continue;
            }

            try {
                sendCallout(http, leadRecord);
            } catch (Exception error) {
                System.debug(LoggingLevel.ERROR, 'Failed to send webhook for Lead ' + leadId + ': ' + error.getMessage());
            }
        }
    }

    @TestVisible
    private static void sendCallout(Http http, Lead leadRecord) {
        Map<String, Object> payload = new Map<String, Object>{
            'leadId' => leadRecord.Id,
            'status' => leadRecord.Status,
            'email' => leadRecord.Email,
            'name' => leadRecord.Name,
            'agent' => new Map<String, Object>{
                'id' => leadRecord.OwnerId,
                'name' => leadRecord.Owner != null ? leadRecord.Owner.Name : null,
                'email' => leadRecord.Owner != null ? leadRecord.Owner.Email : null,
                'phone' => leadRecord.Owner != null ? leadRecord.Owner.Phone : null
            },
            'external_agent' => new Map<String, Object>{
                'name' => leadRecord.External_Agent_Name__c,
                'phone' => leadRecord.External_Agent_Phone__c
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

    public class LeadWebhookRequest {
        @InvocableVariable(required=true)
        public Id leadId;
    }
}