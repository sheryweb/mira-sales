@RestResource(urlMapping='/UserLogin/*')
global without sharing class AppUserLogin {
    
    /**
     * REST endpoint to authenticate App User
     * POST /services/apexrest/UserLogin/
     */
    @HttpPost
    global static LoginResponse loginAppUser() {
        RestResponse response = RestContext.response;
        
        try {
            RestRequest req = RestContext.request;
            String email;
            String password;
            
            // Check if data is sent as JSON in request body
            String requestBody = req.requestBody?.toString();
            
            if (!String.isBlank(requestBody)) {
                // Handle JSON format
                LoginRequest loginRequest = (LoginRequest) JSON.deserialize(requestBody, LoginRequest.class);
                email = loginRequest.email;
                password = loginRequest.password;
            } else {
                // Handle form-encoded format (application/x-www-form-urlencoded)
                Map<String, String> params = req.params;
                if (params.isEmpty()) {
                    throw new IllegalArgumentException('Request body is empty and no form parameters provided');
                }
                email = params.get('email');
                password = params.get('password');
            }
            
            // Validate required fields
            if (String.isBlank(email) || String.isBlank(password)) {
                throw new IllegalArgumentException('Email and Password are required');
            }
            
            // Encrypt password using the same method as registration
            Blob passwordBlob = Blob.valueOf(password);
            Blob encryptedBlob = Crypto.generateDigest('SHA256', passwordBlob);
            String encryptedPassword = EncodingUtil.convertToHex(encryptedBlob);
            
            // Query directly for user with matching email, password, AND active status
            List<App_User__c> matchingUsers = [
                SELECT Id, Full_Name__c, Email__c, Status__c 
                FROM App_User__c 
                WHERE Email__c = :email 
                AND Password__c = :encryptedPassword 
                AND (Status__c != 'Inactive' OR Status__c = NULL)
                LIMIT 1
            ];
            
            // If no match found, either credentials are invalid or user is inactive
            if (matchingUsers.isEmpty()) {
                response.statusCode = 401;
                return new LoginResponse(null, false, 'Invalid email or password', null, null);
            }
            
            App_User__c user = matchingUsers[0];
            
            // Login successful
            response.statusCode = 200;
            return new LoginResponse(user.Email__c, true, 'Login successful', user.Id, user.Full_Name__c);
            
        } catch (Exception e) {
            response.statusCode = 400;
            return new LoginResponse(null, false, 'Error: ' + e.getMessage(), null, null);
        }
    }
    
    /**
     * Helper method to encrypt password for testing/debugging
     */
    @TestVisible
    global static String encryptPassword(String password) {
        if (String.isBlank(password)) {
            return null;
        }
        
        Blob passwordBlob = Blob.valueOf(password);
        Blob encryptedBlob = Crypto.generateDigest('SHA256', passwordBlob);
        return EncodingUtil.convertToHex(encryptedBlob);
    }
    
    // Request/Response Classes
    global class LoginRequest {
        global String email { get; set; }
        global String password { get; set; }
    }
    
    global class LoginResponse {
        global String email { get; set; }
        global Boolean success { get; set; }
        global String message { get; set; }
        global String userId { get; set; }
        global String fullName { get; set; }
        
        global LoginResponse(String email, Boolean success, String message, String userId, String fullName) {
            this.email = email;
            this.success = success;
            this.message = message;
            this.userId = userId;
            this.fullName = fullName;
        }
    }
}