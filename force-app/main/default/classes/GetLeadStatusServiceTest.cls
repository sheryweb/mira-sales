@isTest
private class GetLeadStatusServiceTest {
    private static Lead createLead() {
        Lead leadRecord = new Lead(
            FirstName = 'Status',
            LastName = 'Lead ' + String.valueOf(Crypto.getRandomLong()),
            Company = 'MIRA',
            Email = 'status.lead.' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
            Status = 'New'
        );
        insert leadRecord;
        return [
            SELECT Id, Status, OwnerId, Owner.Name, Owner.Email
            FROM Lead
            WHERE Id = :leadRecord.Id
            LIMIT 1
        ];
    }

    private static void setGetContext(String leadId, String requestUri) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'GET';
        req.requestURI = requestUri;
        if (String.isNotBlank(leadId)) {
            req.addParameter('leadId', leadId);
        }
        RestContext.request = req;
        RestContext.response = res;
    }

    @isTest
    static void testGetLeadStatusByParam() {
        Lead leadRecord = createLead();
        setGetContext(leadRecord.Id, '/services/apexrest/GetLeadStatus/');

        String response = GetLeadStatusService.getLeadStatus();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals(String.valueOf(leadRecord.Id), (String) body.get('id'));
        System.assertEquals(leadRecord.Status, (String) body.get('status'));
        System.assertEquals(String.valueOf(leadRecord.OwnerId), (String) body.get('ownerId'));
        System.assertEquals(false, (Boolean) body.get('isConverted'));
        System.assert(body.containsKey('ownerId'), 'ownerId should be returned');
    }

    @isTest
    static void testGetLeadStatusByUri() {
        Lead leadRecord = createLead();
        setGetContext(null, '/services/apexrest/GetLeadStatus/' + leadRecord.Id);

        String response = GetLeadStatusService.getLeadStatus();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals(String.valueOf(leadRecord.Id), (String) body.get('id'));
        System.assertEquals(leadRecord.Status, (String) body.get('status'));
    }

    @isTest
    static void testMissingLeadId() {
        setGetContext(null, '/services/apexrest/GetLeadStatus/');

        String response = GetLeadStatusService.getLeadStatus();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('error', body.get('status'));
        System.assertEquals('leadId is required', body.get('message'));
    }

    @isTest
    static void testLeadNotFound() {
        setGetContext('00Q000000000001AAA', '/services/apexrest/GetLeadStatus/');

        String response = GetLeadStatusService.getLeadStatus();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('error', body.get('status'));
        System.assertEquals('Lead not found', body.get('message'));
    }

    @isTest
    static void testInvalidLeadIdReturnsError() {
        setGetContext('not-a-valid-id', '/services/apexrest/GetLeadStatus/');

        String response = GetLeadStatusService.getLeadStatus();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('error', body.get('status'));
        System.assertNotEquals(null, body.get('message'));
    }
}
