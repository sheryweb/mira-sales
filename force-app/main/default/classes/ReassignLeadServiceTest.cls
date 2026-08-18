@isTest
private class ReassignLeadServiceTest {
    private static User createUser(String emailPrefix) {
        String unique = String.valueOf(Crypto.getRandomLong());
        User testUser = new User(
            FirstName = 'Reassign',
            LastName = 'Owner',
            Email = emailPrefix + unique + '@example.com',
            Username = emailPrefix + unique + '@example.com',
            Alias = 'rown' + unique.left(4),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        return testUser;
    }

    private static Lead createLead(Id ownerId) {
        Lead leadRecord = new Lead(
            FirstName = 'Reassign',
            LastName = 'Lead ' + String.valueOf(Crypto.getRandomLong()),
            Company = 'MIRA',
            Email = 'reassign.lead.' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
            Status = 'New',
            OwnerId = ownerId
        );
        insert leadRecord;
        return leadRecord;
    }

    private static void setPostContext(Map<String, String> params, String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/ReassignLead/';
        if (params != null) {
            for (String key : params.keySet()) {
                req.addParameter(key, params.get(key));
            }
        }
        if (String.isNotBlank(jsonBody)) {
            req.requestBody = Blob.valueOf(jsonBody);
        }
        RestContext.request = req;
        RestContext.response = res;
    }

    @isTest
    static void testReassignByRmEmail() {
        User currentOwner = createUser('current.owner.');
        User newOwner = createUser('new.owner.');
        Lead leadRecord;
        System.runAs(currentOwner) {
            leadRecord = createLead(currentOwner.Id);
        }

        setPostContext(new Map<String, String>{
            'leadId' => leadRecord.Id,
            'rmemail' => newOwner.Email
        }, null);

        String response = ReassignLeadService.reassignLead();

        Lead updated = (Lead) JSON.deserialize(response, Lead.class);
        System.assertEquals(leadRecord.Id, updated.Id);
        System.assertEquals(newOwner.Id, updated.OwnerId);
        System.assertEquals(newOwner.Id, [
            SELECT OwnerId FROM Lead WHERE Id = :leadRecord.Id
        ].OwnerId);
    }

    @isTest
    static void testReassignByJsonOwnerId() {
        User newOwner = createUser('json.owner.');
        Lead leadRecord;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            leadRecord = createLead(UserInfo.getUserId());
        }

        setPostContext(null, JSON.serialize(new Map<String, String>{
            'leadId' => leadRecord.Id,
            'ownerId' => newOwner.Id
        }));

        String response = ReassignLeadService.reassignLead();

        Lead updated = (Lead) JSON.deserialize(response, Lead.class);
        System.assertEquals(newOwner.Id, updated.OwnerId);
    }

    @isTest
    static void testEmptyRequest() {
        setPostContext(null, null);

        String response = ReassignLeadService.reassignLead();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('error', body.get('status'));
        System.assertEquals('Request parameters are empty', body.get('message'));
    }

    @isTest
    static void testMissingLeadId() {
        setPostContext(new Map<String, String>{ 'rmemail' => 'someone@example.com' }, null);

        String response = ReassignLeadService.reassignLead();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('error', body.get('status'));
        System.assertEquals('leadId is required', body.get('message'));
    }

    @isTest
    static void testMissingOwner() {
        Lead leadRecord = createLead(UserInfo.getUserId());
        setPostContext(new Map<String, String>{ 'leadId' => leadRecord.Id }, null);

        String response = ReassignLeadService.reassignLead();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('error', body.get('status'));
        System.assertEquals('rmemail or ownerId is required', body.get('message'));
    }

    @isTest
    static void testLeadNotFound() {
        setPostContext(new Map<String, String>{
            'leadId' => '00Q000000000001AAA',
            'ownerId' => UserInfo.getUserId()
        }, null);

        String response = ReassignLeadService.reassignLead();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('error', body.get('status'));
        System.assertEquals('Lead not found', body.get('message'));
    }

    @isTest
    static void testOwnerEmailNotFound() {
        Lead leadRecord = createLead(UserInfo.getUserId());
        setPostContext(new Map<String, String>{
            'leadId' => leadRecord.Id,
            'rmemail' => 'missing.owner@example.com'
        }, null);

        String response = ReassignLeadService.reassignLead();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('error', body.get('status'));
        System.assertEquals('Owner user not found for rmemail', body.get('message'));
    }

    @isTest
    static void testConvertedLeadCannotBeReassigned() {
        User newOwner = createUser('converted.owner.');
        Lead leadRecord;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            leadRecord = createLead(UserInfo.getUserId());
            LeadStatus convertStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
            Database.LeadConvert converter = new Database.LeadConvert();
            converter.setLeadId(leadRecord.Id);
            converter.setConvertedStatus(convertStatus.MasterLabel);
            converter.setDoNotCreateOpportunity(true);
            Database.convertLead(converter);
        }

        setPostContext(new Map<String, String>{
            'leadId' => leadRecord.Id,
            'ownerId' => newOwner.Id
        }, null);

        String response = ReassignLeadService.reassignLead();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('error', body.get('status'));
        System.assertEquals('Converted leads cannot be reassigned', body.get('message'));
    }

    @isTest
    static void testInvalidOwnerIdReturnsError() {
        Lead leadRecord = createLead(UserInfo.getUserId());
        setPostContext(new Map<String, String>{
            'leadId' => leadRecord.Id,
            'ownerId' => '005000000000001AAA'
        }, null);

        String response = ReassignLeadService.reassignLead();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('error', body.get('status'));
        System.assertNotEquals(null, body.get('message'));
    }
}
