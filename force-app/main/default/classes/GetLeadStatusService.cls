@RestResource(urlMapping='/GetLeadStatus/*')
global without sharing class GetLeadStatusService {
    @HttpGet
    global static String getLeadStatus() {
        try {
            RestRequest req = RestContext.request;
            Map<String, String> params = req.params;

            String leadId = params != null ? params.get('leadId') : null;
            if (String.isBlank(leadId)) {
                leadId = extractIdFromUri(req.requestURI);
            }

            if (String.isBlank(leadId)) {
                return errorResponse('leadId is required');
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
            Map<String, String> ownerInfo = resolveOwner(leadRecord.OwnerId);
            return JSON.serialize(new Map<String, Object>{
                'id' => leadRecord.Id,
                'status' => leadRecord.Status,
                'isConverted' => leadRecord.IsConverted,
                'ownerId' => leadRecord.OwnerId,
                'ownerName' => ownerInfo.get('name'),
                'ownerEmail' => ownerInfo.get('email')
            });
        } catch (Exception e) {
            return errorResponse('Exception: ' + e.getMessage());
        }
    }

    private static String extractIdFromUri(String requestUri) {
        if (String.isBlank(requestUri)) {
            return null;
        }
        String trimmed = requestUri.endsWith('/')
            ? requestUri.substring(0, requestUri.length() - 1)
            : requestUri;
        Integer lastSlash = trimmed.lastIndexOf('/');
        if (lastSlash < 0) {
            return null;
        }
        String lastSegment = trimmed.substring(lastSlash + 1);
        if (String.isBlank(lastSegment) || lastSegment.equalsIgnoreCase('GetLeadStatus')) {
            return null;
        }
        return lastSegment;
    }

    private static Map<String, String> resolveOwner(Id ownerId) {
        Map<String, String> ownerInfo = new Map<String, String>{
            'name' => null,
            'email' => null
        };
        if (ownerId == null) {
            return ownerInfo;
        }
        List<User> users = [SELECT Name, Email FROM User WHERE Id = :ownerId LIMIT 1];
        if (!users.isEmpty()) {
            ownerInfo.put('name', users[0].Name);
            ownerInfo.put('email', users[0].Email);
            return ownerInfo;
        }
        List<Group> queues = [SELECT Name FROM Group WHERE Id = :ownerId LIMIT 1];
        if (!queues.isEmpty()) {
            ownerInfo.put('name', queues[0].Name);
        }
        return ownerInfo;
    }

    private static String errorResponse(String message) {
        return JSON.serialize(new Map<String, String>{
            'status' => 'error',
            'message' => message
        });
    }
}
