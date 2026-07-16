@IsTest
private class OpportunityListingServiceTest {
    private static final Integer SETUP_OPPORTUNITY_COUNT = 25;

    @TestSetup
    static void setupData() {
        String stageOne = getPrimaryTestStage();
        String stageTwo = getAlternateStage(stageOne);

        Account agencyAccount = new Account(
            Name = 'Test Agency',
            Type = 'Agency',
            Company_Email__c = 'agency@test.com',
            Phone = '+971-555-000-1111',
            Landline_Number__c = '+971-4-000-2222'
        );
        applyAgencyRecordTypeIfAvailable(agencyAccount);
        insert agencyAccount;

        Contact agentContact = new Contact(
            FirstName = 'Agent',
            LastName = 'Contact',
            Email = 'agent.contact@test.com',
            Phone = '+1-555-000-2222',
            AccountId = agencyAccount.Id
        );
        insert agentContact;

        Account primaryAccount = new Account(Name = 'Primary Account');
        insert primaryAccount;

        List<Opportunity> opportunities = new List<Opportunity>();
        for (Integer index = 0; index < 25; index++) {
            String stageName = Math.mod(index, 2) == 0 ? stageOne : stageTwo;
            opportunities.add(new Opportunity(
                Name = 'Opportunity ' + index,
                StageName = stageName,
                CloseDate = Date.today().addDays(index + 1),
                Assisted_by_Agent__c = true,
                Agency__c = agencyAccount.Id,
                Agent__c = agentContact.Id,
                AccountId = primaryAccount.Id
            ));
        }

        insert opportunities;
    }

    @IsTest
    static void getOpportunities_returnsFirstPage() {
        Integer totalRecords = [SELECT COUNT() FROM Opportunity];

        RestRequest request = new RestRequest();
        request.httpMethod = 'GET';
        RestResponse response = new RestResponse();

        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OpportunityListingService.getOpportunities();
        Test.stopTest();

        Map<String, Object> payload = parsePayload();
        System.assertEquals(true, payload.get('success'));
        System.assertEquals(20, payload.get('pageSize'));
        System.assertEquals(totalRecords, payload.get('totalRecords'));

        Integer expectedTotalPages = totalRecords == 0
            ? 0
            : Integer.valueOf(Math.ceil((Decimal) totalRecords / 20));
        System.assertEquals(expectedTotalPages, payload.get('totalPages'));
        System.assertEquals(totalRecords > 20, payload.get('hasMore'));

        if (totalRecords > 20) {
            System.assert(payload.containsKey('lastCreatedDate'), 'Should include lastCreatedDate for next page');
            System.assert(payload.containsKey('lastId'), 'Should include lastId for next page');
        }

        List<Object> records = (List<Object>) payload.get('records');
        Integer expectedFirstPageSize = Math.min(20, totalRecords);
        System.assertEquals(expectedFirstPageSize, records.size(), 'First page size should match total or page limit');
        validateResponse(RestContext.response.responseBody.toString(), expectedFirstPageSize, totalRecords > 20, expectedTotalPages, totalRecords);
    }

    @IsTest
    static void getOpportunities_respectsStageFilter() {
        List<Opportunity> sampleOpps = [SELECT StageName FROM Opportunity LIMIT 1];
        System.assert(!sampleOpps.isEmpty(), 'Test setup should create opportunities');
        String stageFilter = sampleOpps[0].StageName;
        Integer expectedCount = [SELECT COUNT() FROM Opportunity WHERE StageName = :stageFilter];

        RestRequest request = new RestRequest();
        request.httpMethod = 'GET';
        request.addParameter('stageName', stageFilter);
        RestResponse response = new RestResponse();

        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OpportunityListingService.getOpportunities();
        Test.stopTest();

        Map<String, Object> payload = parsePayload();
        System.assertEquals(true, payload.get('success'), getErrorMessage(payload));
        System.assertEquals(20, payload.get('pageSize'));
        System.assertEquals(expectedCount, payload.get('totalRecords'));
        System.assertEquals(expectedCount > 20, payload.get('hasMore'));

        List<Object> records = (List<Object>) payload.get('records');
        System.assertEquals(Math.min(expectedCount, 20), records.size());

        Map<String, Object> recordWithAgency = findRecordWithAgency(records);
        System.assertNotEquals(null, recordWithAgency, 'At least one opportunity should include agency data');

        Map<String, Object> agency = (Map<String, Object>) recordWithAgency.get('agency');
        System.assertEquals(stageFilter, recordWithAgency.get('stageName'));
        System.assertNotEquals(null, agency.get('id'), 'Agency Id should be present');
        System.assertEquals('Test Agency', agency.get('name'));
        System.assertEquals('agency@test.com', agency.get('companyEmail'));
        System.assertEquals('+971-555-000-1111', agency.get('phone'));
        System.assertEquals('+971-4-000-2222', agency.get('landlineNumber'));
    }

    @IsTest
    static void getOpportunities_returnsSecondPage() {
        Integer totalRecords = [SELECT COUNT() FROM Opportunity];
        System.assert(totalRecords > 20, 'Test setup should create more than one page of opportunities');

        RestRequest firstRequest = new RestRequest();
        firstRequest.httpMethod = 'GET';
        RestResponse firstResponse = new RestResponse();
        RestContext.request = firstRequest;
        RestContext.response = firstResponse;

        OpportunityListingService.getOpportunities();
        Map<String, Object> firstPayload = parsePayload();
        String lastCreatedDate = (String) firstPayload.get('lastCreatedDate');
        String lastId = (String) firstPayload.get('lastId');

        RestRequest request = new RestRequest();
        request.httpMethod = 'GET';
        request.addParameter('lastCreatedDate', lastCreatedDate);
        request.addParameter('lastId', lastId);
        RestResponse response = new RestResponse();

        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OpportunityListingService.getOpportunities();
        Test.stopTest();

        Map<String, Object> payload = parsePayload();
        System.assertEquals(true, payload.get('success'));
        System.assertEquals(totalRecords, payload.get('totalRecords'));

        List<Object> records = (List<Object>) payload.get('records');
        System.assertEquals(totalRecords - 20, records.size(), 'Second page should return remaining records');
        System.assertEquals(false, payload.get('hasMore'));
    }

    @IsTest
    static void getOpportunities_usesKeysetPagination() {
        RestRequest firstRequest = new RestRequest();
        firstRequest.httpMethod = 'GET';
        RestResponse firstResponse = new RestResponse();
        RestContext.request = firstRequest;
        RestContext.response = firstResponse;

        OpportunityListingService.getOpportunities();
        Map<String, Object> firstPayload = parsePayload();

        RestRequest request = new RestRequest();
        request.httpMethod = 'GET';
        request.addParameter('lastCreatedDate', (String) firstPayload.get('lastCreatedDate'));
        request.addParameter('lastId', (String) firstPayload.get('lastId'));
        RestResponse response = new RestResponse();

        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OpportunityListingService.getOpportunities();
        Test.stopTest();

        Map<String, Object> payload = parsePayload();
        System.assertEquals(true, payload.get('success'));
        List<Object> records = (List<Object>) payload.get('records');
        System.assertEquals([SELECT COUNT() FROM Opportunity] - 20, records.size());
        System.assertEquals(false, payload.get('hasMore'));
    }

    @IsTest
    static void getOpportunities_handlesNullRequestAndResponse() {
        RestContext.request = null;
        RestContext.response = null;

        Test.startTest();
        OpportunityListingService.getOpportunities();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response, 'Response should be created');
        System.assertNotEquals(null, RestContext.request, 'Request should be created');
    }

    @IsTest
    static void getOpportunities_handlesInvalidCursorValues() {
        RestRequest request = new RestRequest();
        request.httpMethod = 'GET';
        request.addParameter('lastCreatedDate', 'invalid-date');
        request.addParameter('lastId', 'invalid-id');
        RestResponse response = new RestResponse();

        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OpportunityListingService.getOpportunities();
        Test.stopTest();

        Map<String, Object> payload = parsePayload();
        System.assertEquals(true, payload.get('success'), getErrorMessage(payload));
        List<Object> records = (List<Object>) payload.get('records');
        System.assert(records.size() > 0, 'Should return records even with invalid cursor');
    }

    @IsTest
    static void getOpportunities_handlesPartialCursorValues() {
        RestRequest request = new RestRequest();
        request.httpMethod = 'GET';
        request.addParameter('lastCreatedDate', Datetime.now().formatGmt('yyyy-MM-dd HH:mm:ss'));
        RestResponse response = new RestResponse();

        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OpportunityListingService.getOpportunities();
        Test.stopTest();

        Map<String, Object> payload = parsePayload();
        System.assertEquals(true, payload.get('success'), getErrorMessage(payload));
        List<Object> records = (List<Object>) payload.get('records');
        System.assert(records.size() > 0, 'Should return records even with partial cursor');
    }

    @IsTest
    static void getOpportunities_handlesOpportunitiesWithoutAgents() {
        Opportunity oppWithoutAgent = new Opportunity(
            Name = 'No Agent Opp',
            Agent__c = null,
            Agency__c = null
        );

        Test.startTest();
        Map<String, Object> record = OpportunityListingService.buildOpportunityPayloadForTest(oppWithoutAgent);
        Test.stopTest();

        Map<String, Object> agent = (Map<String, Object>) record.get('agent');
        System.assertEquals(null, agent.get('id'), 'Agent ID should be null');
        System.assertEquals(null, agent.get('name'), 'Agent name should be null');
        System.assertEquals(null, agent.get('phone'), 'Agent phone should be null');

        Map<String, Object> agency = (Map<String, Object>) record.get('agency');
        System.assertEquals(null, agency.get('id'), 'Agency ID should be null');
        System.assertEquals(null, agency.get('name'), 'Agency name should be null');
        System.assertEquals(null, agency.get('companyEmail'), 'Agency company email should be null');
        System.assertEquals(null, agency.get('phone'), 'Agency phone should be null');
        System.assertEquals(null, agency.get('landlineNumber'), 'Agency landline should be null');
    }

    @IsTest
    static void getOpportunities_handlesEmptyResultSet() {
        RestRequest request = new RestRequest();
        request.httpMethod = 'GET';
        request.addParameter('stageName', 'NonExistentStage_' + String.valueOf(Crypto.getRandomInteger()));
        RestResponse response = new RestResponse();

        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OpportunityListingService.getOpportunities();
        Test.stopTest();

        Map<String, Object> payload = parsePayload();
        System.assertEquals(true, payload.get('success'));
        System.assertEquals(0, payload.get('totalRecords'));
        System.assertEquals(0, payload.get('totalPages'));
        System.assertEquals(false, payload.get('hasMore'));

        List<Object> records = (List<Object>) payload.get('records');
        System.assertEquals(0, records.size());
    }

    @IsTest
    static void getOpportunities_respectsPageSize() {
        Integer totalRecords = [SELECT COUNT() FROM Opportunity];

        RestRequest request = new RestRequest();
        request.httpMethod = 'GET';
        request.addParameter('pageSize', '10');
        RestResponse response = new RestResponse();

        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OpportunityListingService.getOpportunities();
        Test.stopTest();

        Map<String, Object> payload = parsePayload();
        System.assertEquals(true, payload.get('success'));
        System.assertEquals(10, payload.get('pageSize'));
        System.assertEquals(totalRecords, payload.get('totalRecords'));
        System.assertEquals(totalRecords > 10, payload.get('hasMore'));

        List<Object> records = (List<Object>) payload.get('records');
        System.assertEquals(Math.min(10, totalRecords), records.size());
    }

    @IsTest
    static void getOpportunities_handlesInvalidPageSize() {
        Integer totalRecords = [SELECT COUNT() FROM Opportunity];

        RestRequest request = new RestRequest();
        request.httpMethod = 'GET';
        request.addParameter('pageSize', 'invalid');
        RestResponse response = new RestResponse();

        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OpportunityListingService.getOpportunities();
        Test.stopTest();

        Map<String, Object> payload = parsePayload();
        System.assertEquals(true, payload.get('success'));
        System.assertEquals(20, payload.get('pageSize'));

        List<Object> records = (List<Object>) payload.get('records');
        System.assertEquals(Math.min(20, totalRecords), records.size());
    }

    private static Map<String, Object> findRecordWithAgency(List<Object> records) {
        for (Object recordObj : records) {
            Map<String, Object> record = (Map<String, Object>) recordObj;
            Map<String, Object> agency = (Map<String, Object>) record.get('agency');
            if (agency != null && agency.get('id') != null) {
                return record;
            }
        }
        return null;
    }

    private static Map<String, Object> parsePayload() {
        return (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
    }

    private static String getErrorMessage(Map<String, Object> payload) {
        return payload.containsKey('message')
            ? String.valueOf(payload.get('message'))
            : 'Unexpected API failure';
    }

    private static String getPrimaryTestStage() {
        if (isActiveStage('New')) {
            return 'New';
        }
        if (isActiveStage('Prospecting')) {
            return 'Prospecting';
        }

        for (Schema.PicklistEntry entry : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (entry.isActive() && !isRestrictedStage(entry.getValue())) {
                return entry.getValue();
            }
        }

        return Opportunity.StageName.getDescribe().getPicklistValues()[0].getValue();
    }

    private static String getAlternateStage(String firstStage) {
        for (Schema.PicklistEntry entry : Opportunity.StageName.getDescribe().getPicklistValues()) {
            String stageName = entry.getValue();
            if (entry.isActive() && stageName != firstStage && !isRestrictedStage(stageName)) {
                return stageName;
            }
        }
        return firstStage;
    }

    private static Boolean isActiveStage(String stageName) {
        for (Schema.PicklistEntry entry : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == stageName) {
                return true;
            }
        }
        return false;
    }

    private static Boolean isRestrictedStage(String stageName) {
        return stageName == 'Booked';
    }

    private static void applyAgencyRecordTypeIfAvailable(Account account) {
        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND (Id = '012Hp000001yUTAIA2' OR DeveloperName = 'Agency')
            LIMIT 1
        ];

        if (!recordTypes.isEmpty()) {
            account.RecordTypeId = recordTypes[0].Id;
        }
    }

    private static void validateResponse(
        String responseBody,
        Integer expectedRecordCount,
        Boolean expectedHasMore,
        Integer expectedTotalPages,
        Integer expectedTotalRecords
    ) {
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        System.assertEquals(true, payload.get('success'));
        System.assertEquals(expectedTotalPages, payload.get('totalPages'));
        System.assertEquals(expectedTotalRecords, payload.get('totalRecords'));
        System.assertEquals(expectedHasMore, payload.get('hasMore'));

        List<Object> records = (List<Object>) payload.get('records');
        System.assertEquals(expectedRecordCount, records.size());

        if (!records.isEmpty()) {
            Map<String, Object> firstRecord = (Map<String, Object>) records[0];
            System.assert(firstRecord.containsKey('opportunityId'), 'Opportunity Id should be present');
            System.assert(firstRecord.containsKey('name'), 'Opportunity name should be present');
            System.assert(firstRecord.containsKey('stageName'), 'Opportunity stage should be present');
            System.assert(firstRecord.containsKey('projectName'), 'Project name attribute should be present');
            System.assert(firstRecord.containsKey('agent'), 'Agent attribute should be present');
            System.assert(firstRecord.containsKey('agency'), 'Agency attribute should be present');
        }
    }
}