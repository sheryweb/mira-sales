@RestResource(urlMapping='/ReassignLead/*')
global without sharing class ReassignLeadService {
    @HttpPost
    global static String reassignLead() {
        try {
            RestRequest req = RestContext.request;
            Map<String, String> params = req.params != null ? req.params : new Map<String, String>();

            String leadId = params.get('leadId');
            String rmEmail = params.get('rmemail');
            String ownerIdParam = params.get('ownerId');

            String requestBody = req.requestBody != null ? req.requestBody.toString() : null;
            if (String.isNotBlank(requestBody)) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
                if (body != null) {
                    if (String.isBlank(leadId) && body.get('leadId') != null) {
                        leadId = String.valueOf(body.get('leadId'));
                    }
                    if (String.isBlank(rmEmail) && body.get('rmemail') != null) {
                        rmEmail = String.valueOf(body.get('rmemail'));
                    }
                    if (String.isBlank(ownerIdParam) && body.get('ownerId') != null) {
                        ownerIdParam = String.valueOf(body.get('ownerId'));
                    }
                }
            }

            if (String.isBlank(leadId) && String.isBlank(rmEmail) && String.isBlank(ownerIdParam)) {
                return errorResponse('Request parameters are empty');
            }
            if (String.isBlank(leadId)) {
                return errorResponse('leadId is required');
            }
            if (String.isBlank(rmEmail) && String.isBlank(ownerIdParam)) {
                return errorResponse('rmemail or ownerId is required');
            }

            List<Lead> leads = [
                SELECT Id, Status, IsConverted, OwnerId
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];
            if (leads.isEmpty()) {
                return errorResponse('Lead not found');
            }

            Lead leadRecord = leads[0];
            if (leadRecord.IsConverted) {
                return errorResponse('Converted leads cannot be reassigned');
            }

            Id ownerId;
            if (String.isNotBlank(ownerIdParam)) {
                ownerId = ownerIdParam;
            } else {
                List<User> owners = [SELECT Id FROM User WHERE Email = :rmEmail LIMIT 1];
                if (owners.isEmpty()) {
                    return errorResponse('Owner user not found for rmemail');
                }
                ownerId = owners[0].Id;
            }

            leadRecord.OwnerId = ownerId;
            update leadRecord;

            Lead updatedLead = [
                SELECT Id, FirstName, LastName, Email, Status, OwnerId, Owner.Name, Owner.Email,
                       CreatedDate, LastModifiedDate
                FROM Lead
                WHERE Id = :leadRecord.Id
                LIMIT 1
            ];
            return JSON.serialize(updatedLead);
        } catch (DmlException e) {
            return errorResponse('DML Exception: ' + e.getMessage());
        } catch (Exception e) {
            return errorResponse('Exception: ' + e.getMessage());
        }
    }

    private static String errorResponse(String message) {
        return JSON.serialize(new Map<String, String>{
            'status' => 'error',
            'message' => message
        });
    }
}
