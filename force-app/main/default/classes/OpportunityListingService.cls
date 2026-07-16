@RestResource(urlMapping='/OpportunityListing/*')
global without sharing class OpportunityListingService {
    private static final Integer PAGE_SIZE = 20;

    @HttpGet
    global static void getOpportunities() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;

        if (request == null) {
            request = new RestRequest();
            RestContext.request = request;
        }
        if (response == null) {
            response = new RestResponse();
            RestContext.response = response;
        }

        try {
            Map<String, String> params = RestContext.request.params;

            // Page size
            Integer pageSize = PAGE_SIZE;
            if (params != null && params.containsKey('pageSize')) {
                try {
                    pageSize = Integer.valueOf(params.get('pageSize'));
                    if (pageSize <= 0) {
                        pageSize = PAGE_SIZE;
                    }
                } catch (Exception e) {
                    pageSize = PAGE_SIZE;
                }
            }

            // Cursor values for keyset pagination
            Datetime lastCreatedDate;
            Id lastId;

            if (params != null && params.containsKey('lastCreatedDate')) {
                try {
                    lastCreatedDate = Datetime.valueOfGmt(params.get('lastCreatedDate'));
                } catch (Exception e) {
                    lastCreatedDate = null;
                }
            }

            if (params != null && params.containsKey('lastId')) {
                try {
                    lastId = (Id) params.get('lastId');
                } catch (Exception e) {
                    lastId = null;
                }
            }

            // Stage filter
            String stageFilter = params != null ? params.get('stageName') : null;

            // Build dynamic SOQL
            String soql = 'SELECT Id, Name, StageName, Project_Name__c, CreatedDate, ' +
                          'Agent__c, Agent__r.Name, Agent__r.Phone, ' +
                          'Agency__c, Agency__r.Name, Agency__r.Company_Email__c, Agency__r.Phone, Agency__r.Landline_Number__c ' +
                          'FROM Opportunity ';

            List<String> whereConditions = new List<String>();

            // Add stage filter if provided
            if (String.isNotBlank(stageFilter)) {
                whereConditions.add('StageName = :stageFilter');
            }

            // Add keyset condition for pagination
            if (lastCreatedDate != null && lastId != null) {
                whereConditions.add('(CreatedDate < :lastCreatedDate OR (CreatedDate = :lastCreatedDate AND Id < :lastId))');
            }

            if (!whereConditions.isEmpty()) {
                soql += 'WHERE ' + String.join(whereConditions, ' AND ') + ' ';
            }

            soql += 'ORDER BY CreatedDate DESC, Id DESC LIMIT :pageSize';

            // Execute query
            List<Opportunity> opportunities = Database.query(soql);

            // Build response records
            List<Map<String, Object>> records = new List<Map<String, Object>>();
            Datetime nextLastCreatedDate = null;
            Id nextLastId = null;

            for (Opportunity opp : opportunities) {
                records.add(buildOpportunityPayload(opp));
                // Track the last record's values for next page cursor
                nextLastCreatedDate = opp.CreatedDate;
                nextLastId = opp.Id;
            }

            // Determine if there are more records
            Boolean hasMore = opportunities.size() == pageSize;

            // Get total count (optional, for backward compatibility)
            Integer totalRecords = 0;
            if (String.isBlank(stageFilter)) {
                totalRecords = [SELECT COUNT() FROM Opportunity];
            } else {
                totalRecords = [SELECT COUNT() FROM Opportunity WHERE StageName = :stageFilter];
            }

            Integer totalPages = totalRecords == 0 ? 0 : Integer.valueOf(Math.ceil((Decimal) totalRecords / pageSize));

            // Build response payload
            Map<String, Object> payload = new Map<String, Object>{
                'success' => true,
                'pageSize' => pageSize,
                'totalRecords' => totalRecords,
                'totalPages' => totalPages,
                'hasMore' => hasMore,
                'records' => records
            };

            // Add cursor values for next page if there are more records
            if (hasMore && nextLastCreatedDate != null && nextLastId != null) {
                // Format datetime in format expected by valueOfGmt: yyyy-MM-dd HH:mm:ss
                payload.put('lastCreatedDate', nextLastCreatedDate.formatGmt('yyyy-MM-dd HH:mm:ss'));
                payload.put('lastId', nextLastId);
            }

            response.statusCode = 200;
            response.responseBody = Blob.valueOf(JSON.serialize(payload));
        } catch (Exception error) {
            response.statusCode = 400;
            response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => error.getMessage()
            }));
        }
    }

    @TestVisible
    private static Map<String, Object> buildOpportunityPayloadForTest(Opportunity opportunityRecord) {
        return buildOpportunityPayload(opportunityRecord);
    }

    private static Map<String, Object> buildOpportunityPayload(Opportunity opportunityRecord) {
        return new Map<String, Object>{
            'opportunityId' => opportunityRecord.Id,
            'name' => opportunityRecord.Name,
            'stageName' => opportunityRecord.StageName,
            'projectName' => opportunityRecord.Project_Name__c,
            'agent' => buildAgentPayload(opportunityRecord),
            'agency' => buildAgencyPayload(opportunityRecord)
        };
    }

    private static Map<String, Object> buildAgentPayload(Opportunity opportunityRecord) {
        return new Map<String, Object>{
            'id' => opportunityRecord.Agent__c,
            'name' => opportunityRecord.Agent__r != null ? opportunityRecord.Agent__r.Name : null,
            'phone' => opportunityRecord.Agent__r != null ? opportunityRecord.Agent__r.Phone : null
        };
    }

    private static Map<String, Object> buildAgencyPayload(Opportunity opportunityRecord) {
        return new Map<String, Object>{
            'id' => opportunityRecord.Agency__c,
            'name' => opportunityRecord.Agency__r != null ? opportunityRecord.Agency__r.Name : null,
            'companyEmail' => opportunityRecord.Agency__r != null ? opportunityRecord.Agency__r.Company_Email__c : null,
            'phone' => opportunityRecord.Agency__r != null ? opportunityRecord.Agency__r.Phone : null,
            'landlineNumber' => opportunityRecord.Agency__r != null ? opportunityRecord.Agency__r.Landline_Number__c : null
        };
    }

}