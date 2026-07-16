@RestResource(urlMapping='/UserOpportunityList/*')
global without sharing class AppUserOpportunityListService {
    
    /**
     * REST endpoint to get Opportunity list for App User based on stage type
     * GET /services/apexrest/UserOpportunityList/new - for New opportunities
     * GET /services/apexrest/UserOpportunityList/booked - for Booked/Reserved/Sold opportunities
     * GET /services/apexrest/UserOpportunityList/cancelled - for Cancelled/Transferred opportunities
     */
    @HttpGet
    global static void getOpportunityList() {
        RestResponse response = RestContext.response;
        
        try {
            RestRequest req = RestContext.request;
            String userId;
            String stageType;
            
            // Extract stage type from URL path
            String[] pathParts = req.requestURI.split('/');
            if (pathParts.size() > 0) {
                stageType = pathParts[pathParts.size() - 1];
            }
            
            // Check if userId is provided as URL parameter
            Map<String, String> params = req.params;
            userId = params.get('userId');
            
            // Validate required parameter
            if (String.isBlank(userId)) {
                throw new IllegalArgumentException('userId parameter is required');
            }
            
            // Validate stage type
            if (String.isBlank(stageType) || (!stageType.equals('new') && !stageType.equals('booked') && !stageType.equals('cancelled'))) {
                throw new IllegalArgumentException('Invalid stage type. Use "new", "booked", or "cancelled"');
            }
            
            // Verify the App_User__c exists and is active
            List<App_User__c> appUsers = [
                SELECT Id, Full_Name__c, Email__c, Status__c 
                FROM App_User__c 
                WHERE Id = :userId 
                AND (Status__c != 'Inactive' OR Status__c = NULL)
                LIMIT 1
            ];
            
            if (appUsers.isEmpty()) {
                response.statusCode = 404;
                Map<String, Object> errorResponse = new Map<String, Object>();
                errorResponse.put('success', false);
                errorResponse.put('message', 'App User not found or inactive');
                errorResponse.put('opportunities', null);
                response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
                return;
            }
            
            List<Opportunity> opportunities;
            String successMessage;
            
            if (stageType == 'new') {
                // Query for New opportunities
                opportunities = [
                    SELECT Id, Name, Account.Name, StageName, CloseDate, CreatedDate
                    FROM Opportunity 
                    WHERE App_User__c = :userId
                    AND StageName = 'New'
                    ORDER BY CreatedDate DESC
                ];
                successMessage = 'New opportunities retrieved successfully';
            } else if (stageType == 'booked') {
                // Query for Booked/Reserved/Sold opportunities
                opportunities = [
                    SELECT Id, Name, Account.Name, StageName, CloseDate, CreatedDate
                    FROM Opportunity 
                    WHERE App_User__c = :userId
                    AND StageName IN ('Booked', 'Reserved', 'Sold')
                    ORDER BY CreatedDate DESC
                ];
                successMessage = 'Booked/Reserved/Sold opportunities retrieved successfully';
            } else { // stageType == 'cancelled'
                // Query for Cancelled/Transferred opportunities
                opportunities = [
                    SELECT Id, Name, Account.Name, StageName, CloseDate, CreatedDate
                    FROM Opportunity 
                    WHERE App_User__c = :userId
                    AND StageName IN ('Cancelled', 'Transferred')
                    ORDER BY CreatedDate DESC
                ];
                successMessage = 'Cancelled/Transferred opportunities retrieved successfully';
            }
            
            List<Object> opportunityInfoList = new List<Object>();
            
            for (Opportunity opp : opportunities) {
                Map<String, Object> opportunityMap = new Map<String, Object>();
                opportunityMap.put('id', opp.Id);
                opportunityMap.put('name', opp.Name);
                opportunityMap.put('account', opp.Account?.Name);
                opportunityMap.put('stageName', opp.StageName);
                opportunityMap.put('closeDate', opp.CloseDate);
                opportunityMap.put('createdDate', opp.CreatedDate);
                
                opportunityInfoList.add(opportunityMap);
            }
            
            response.statusCode = 200;
            Map<String, Object> successResponse = new Map<String, Object>();
            successResponse.put('success', true);
            successResponse.put('message', successMessage);
            successResponse.put('opportunities', opportunityInfoList);
            response.responseBody = Blob.valueOf(JSON.serialize(successResponse));
            
        } catch (Exception e) {
            response.statusCode = 400;
            Map<String, Object> errorResponse = new Map<String, Object>();
            errorResponse.put('success', false);
            errorResponse.put('message', 'Error: ' + e.getMessage());
            errorResponse.put('opportunities', null);
            response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
        }
    }
    
    /**
     * POST method to support form-encoded requests
     * POST /services/apexrest/UserOpportunityList/
     */
    @HttpPost
    global static void getOpportunityListPost() {
        RestResponse response = RestContext.response;
        
        try {
            RestRequest req = RestContext.request;
            String userId;
            String stageType;
            
            // Check if data is sent as JSON in request body
            String requestBody = req.requestBody?.toString();
            
            if (!String.isBlank(requestBody)) {
                // Handle JSON format
                OpportunityListRequest oppRequest = (OpportunityListRequest) JSON.deserialize(requestBody, OpportunityListRequest.class);
                userId = oppRequest.userId;
                stageType = oppRequest.stageType;
            } else {
                // Handle form-encoded format
                Map<String, String> params = req.params;
                userId = params.get('userId');
                stageType = params.get('stageType');
            }
            
            // Validate required parameters
            if (String.isBlank(userId)) {
                throw new IllegalArgumentException('userId parameter is required');
            }
            
            if (String.isBlank(stageType) || (!stageType.equals('new') && !stageType.equals('booked') && !stageType.equals('cancelled'))) {
                throw new IllegalArgumentException('stageType parameter is required. Use "new", "booked", or "cancelled"');
            }
            
            // Verify the App_User__c exists and is active
            List<App_User__c> appUsers = [
                SELECT Id, Full_Name__c, Email__c, Status__c 
                FROM App_User__c 
                WHERE Id = :userId 
                AND (Status__c != 'Inactive' OR Status__c = NULL)
                LIMIT 1
            ];
            
            if (appUsers.isEmpty()) {
                response.statusCode = 404;
                Map<String, Object> errorResponse = new Map<String, Object>();
                errorResponse.put('success', false);
                errorResponse.put('message', 'App User not found or inactive');
                errorResponse.put('opportunities', null);
                response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
                return;
            }
            
            List<Opportunity> opportunities;
            String successMessage;
            
            if (stageType == 'new') {
                // Query for New opportunities
                opportunities = [
                    SELECT Id, Name, Account.Name, StageName, CloseDate, CreatedDate
                    FROM Opportunity 
                    WHERE App_User__c = :userId
                    AND StageName = 'New'
                    ORDER BY CreatedDate DESC
                ];
                successMessage = 'New opportunities retrieved successfully';
            } else if (stageType == 'booked') {
                // Query for Booked/Reserved/Sold opportunities
                opportunities = [
                    SELECT Id, Name, Account.Name, StageName, CloseDate, CreatedDate
                    FROM Opportunity 
                    WHERE App_User__c = :userId
                    AND StageName IN ('Booked', 'Reserved', 'Sold')
                    ORDER BY CreatedDate DESC
                ];
                successMessage = 'Booked/Reserved/Sold opportunities retrieved successfully';
            } else { // stageType == 'cancelled'
                // Query for Cancelled/Transferred opportunities
                opportunities = [
                    SELECT Id, Name, Account.Name, StageName, CloseDate, CreatedDate
                    FROM Opportunity 
                    WHERE App_User__c = :userId
                    AND StageName IN ('Cancelled', 'Transferred')
                    ORDER BY CreatedDate DESC
                ];
                successMessage = 'Cancelled/Transferred opportunities retrieved successfully';
            }
            
            List<Object> opportunityInfoList = new List<Object>();
            
            for (Opportunity opp : opportunities) {
                Map<String, Object> opportunityMap = new Map<String, Object>();
                opportunityMap.put('id', opp.Id);
                opportunityMap.put('name', opp.Name);
                opportunityMap.put('account', opp.Account?.Name);
                opportunityMap.put('stageName', opp.StageName);
                opportunityMap.put('closeDate', opp.CloseDate);
                opportunityMap.put('createdDate', opp.CreatedDate);
                
                opportunityInfoList.add(opportunityMap);
            }
            
            response.statusCode = 200;
            Map<String, Object> successResponse = new Map<String, Object>();
            successResponse.put('success', true);
            successResponse.put('message', successMessage);
            successResponse.put('opportunities', opportunityInfoList);
            response.responseBody = Blob.valueOf(JSON.serialize(successResponse));
            
        } catch (Exception e) {
            response.statusCode = 400;
            Map<String, Object> errorResponse = new Map<String, Object>();
            errorResponse.put('success', false);
            errorResponse.put('message', 'Error: ' + e.getMessage());
            errorResponse.put('opportunities', null);
            response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
        }
    }
    
    // Request/Response Classes
    global class OpportunityListRequest {
        global String userId { get; set; }
        global String stageType { get; set; }
    }
    
    global class OpportunityListResponse {
        global Boolean success { get; set; }
        global String message { get; set; }
        global List<Object> opportunities { get; set; }
        
        global OpportunityListResponse(Boolean success, String message, List<Object> opportunities) {
            this.success = success;
            this.message = message;
            this.opportunities = opportunities;
        }
    }
}