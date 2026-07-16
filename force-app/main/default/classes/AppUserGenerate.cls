@RestResource(urlMapping='/CreateAppUser/*')
global without sharing class AppUserGenerate {
    
    /**
     * REST endpoint to create App User
     * POST /services/apexrest/appuser/
     */
    @HttpPost
    global static AppUserResponse createAppUser() {
        RestResponse response = RestContext.response;
        
        try {
            String requestBody = RestContext.request.requestBody.toString();
            System.debug('Request Body: ' + requestBody);
            
            if (String.isBlank(requestBody)) {
                throw new IllegalArgumentException('Request body is empty');
            }
            
            AppUserRequest userRequest = (AppUserRequest) JSON.deserialize(requestBody, AppUserRequest.class);
            
            // Validate required fields
            if (String.isBlank(userRequest.email) || String.isBlank(userRequest.fullName) || String.isBlank(userRequest.password)) {
                throw new IllegalArgumentException('Email, Full Name, and Password are required');
            }
            
            // Encrypt password
            Blob passwordBlob = Blob.valueOf(userRequest.password);
            Blob encryptedBlob = Crypto.generateDigest('SHA256', passwordBlob);
            String encryptedPassword = EncodingUtil.convertToHex(encryptedBlob);
            
            // Create App_User__c record
            App_User__c newAppUser = new App_User__c(
                Full_Name__c = userRequest.fullName,
                Email__c = userRequest.email,
                Password__c = encryptedPassword,
                Status__c = userRequest.status
            );
            
            insert newAppUser;
            
            response.statusCode = 201;
            return new AppUserResponse(true, 'App User created successfully', newAppUser.Id);
            
        } catch (Exception e) {
            response.statusCode = 400;
            return new AppUserResponse(false, 'Error: ' + e.getMessage(), null);
        }
    }
    
    // Request/Response Classes
    global class AppUserRequest {
        global String email { get; set; }
        global String fullName { get; set; }
        global String password { get; set; }
        global String status { get; set; }
    }
    
    global class AppUserResponse {
        global Boolean success { get; set; }
        global String message { get; set; }
        global String userId { get; set; }
        
        global AppUserResponse(Boolean success, String message, String userId) {
            this.success = success;
            this.message = message;
            this.userId = userId;
        }
    }
}