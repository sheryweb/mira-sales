@RestResource(urlMapping='/UserAccountDetail/*')
global without sharing class AppUserAccountDetailService {
    
    /**
     * REST endpoint to get Account details by Account Id
     * GET /services/apexrest/UserAccountDetail/{accountId}
     */
    @HttpGet
    global static void getAccountDetail() {
        RestResponse response = RestContext.response;
        
        try {
            RestRequest req = RestContext.request;
            String accountId;
            
            // Get accountId from URL path
            String requestURI = req.requestURI;
            String[] uriParts = requestURI.split('/');
            
            if (uriParts.size() > 0) {
                accountId = uriParts[uriParts.size() - 1];
            }
            
            // Validate required parameter
            if (String.isBlank(accountId)) {
                throw new IllegalArgumentException('Account Id is required');
            }
            
            // Query for Account details
            List<Account> accounts = [
                SELECT Id, FirstName, LastName, Salutation, PersonEmail, Phone, PersonMobilePhone, 
                       Passport_No__pc, Passport_No__c, Compliance_Status__c, CreatedDate,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, 
                       Resident_of_UAE__c, Country_of_Residence__c, Nationality__pc, 
                       Passport_Issue_Date__pc, Passport_Expiration_Date__c, PersonBirthdate, 
                       Place_of_Birth__pc, Occupation__pc, Nature_of_Business__pc, Source_of_Funds__pc, 
                       Politically_Exposed__pc, Subject_to_Sanction__pc, Payment_methods__pc, 
                       Bank_Name__pc, Visa_Number__pc, Visa_Place_of_Issue__pc, Visa_Date_of_Issue__pc, 
                       Visa_Expire_Date__pc, Emirates_ID_Card_Number__pc, Emirates_ID_Number__pc, 
                       Emirates_ID_Expiry_Date__pc, POA_Holder_Name__pc, POA_Holder_Emirates_ID_Number__pc, 
                       POA_Holder_Passport_Number__pc, POA_Holder_Passport_Expiry_Date__pc
                FROM Account 
                WHERE Id = :accountId
                LIMIT 1
            ];
            
            if (accounts.isEmpty()) {
                response.statusCode = 404;
                Map<String, Object> errorResponse = new Map<String, Object>();
                errorResponse.put('success', false);
                errorResponse.put('message', 'Account not found');
                errorResponse.put('account', null);
                response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
                return;
            }
            
            Account acc = accounts[0];
            
            // Build response data
            Map<String, Object> accountData = new Map<String, Object>();
            accountData.put('id', acc.Id);
            accountData.put('firstName', acc.FirstName);
            accountData.put('lastName', acc.LastName);
            accountData.put('salutation', acc.Salutation);
            accountData.put('personEmail', acc.PersonEmail);
            accountData.put('phone', acc.Phone);
            accountData.put('personMobilePhone', acc.PersonMobilePhone);
            accountData.put('passportNumber', acc.Passport_No__pc != null ? acc.Passport_No__pc : acc.Passport_No__c);
            accountData.put('complianceStatus', acc.Compliance_Status__c);
            accountData.put('createdDate', acc.CreatedDate);
            accountData.put('billingStreet', acc.BillingStreet);
            accountData.put('billingCity', acc.BillingCity);
            accountData.put('billingState', acc.BillingState);
            accountData.put('billingPostalCode', acc.BillingPostalCode);
            accountData.put('billingCountry', acc.BillingCountry);
            accountData.put('residentOfUAE', acc.Resident_of_UAE__c);
            accountData.put('countryOfResidence', acc.Country_of_Residence__c);
            accountData.put('nationality', acc.Nationality__pc);
            accountData.put('passportIssueDate', acc.Passport_Issue_Date__pc);
            accountData.put('passportExpirationDate', acc.Passport_Expiration_Date__c);
            accountData.put('personBirthdate', acc.PersonBirthdate);
            accountData.put('placeOfBirth', acc.Place_of_Birth__pc);
            accountData.put('occupation', acc.Occupation__pc);
            accountData.put('natureOfBusiness', acc.Nature_of_Business__pc);
            accountData.put('sourceOfFunds', acc.Source_of_Funds__pc);
            accountData.put('politicallyExposed', acc.Politically_Exposed__pc);
            accountData.put('subjectToSanction', acc.Subject_to_Sanction__pc);
            accountData.put('paymentMethods', acc.Payment_methods__pc);
            accountData.put('bankName', acc.Bank_Name__pc);
            accountData.put('visaNumber', acc.Visa_Number__pc);
            accountData.put('visaPlaceIssue', acc.Visa_Place_of_Issue__pc);
            accountData.put('visaDateOfIssue', acc.Visa_Date_of_Issue__pc);
            accountData.put('visaExpireDate', acc.Visa_Expire_Date__pc);
            accountData.put('emiratesIdCardNumber', acc.Emirates_ID_Card_Number__pc);
            accountData.put('emiratesIdNumber', acc.Emirates_ID_Number__pc);
            accountData.put('emiratesIdExpiryDate', acc.Emirates_ID_Expiry_Date__pc);
            accountData.put('poaHolderName', acc.POA_Holder_Name__pc);
            accountData.put('poaHolderEmiratesIdNumber', acc.POA_Holder_Emirates_ID_Number__pc);
            accountData.put('poaHolderPassportNumber', acc.POA_Holder_Passport_Number__pc);
            accountData.put('poaHolderPassportExpiryDate', acc.POA_Holder_Passport_Expiry_Date__pc);
            
            response.statusCode = 200;
            Map<String, Object> successResponse = new Map<String, Object>();
            successResponse.put('success', true);
            successResponse.put('message', 'Account details retrieved successfully');
            successResponse.put('account', accountData);
            response.responseBody = Blob.valueOf(JSON.serialize(successResponse));
            
        } catch (Exception e) {
            response.statusCode = 400;
            Map<String, Object> errorResponse = new Map<String, Object>();
            errorResponse.put('success', false);
            errorResponse.put('message', 'Error: ' + e.getMessage());
            errorResponse.put('account', null);
            response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
        }
    }
    
    /**
     * POST method to support JSON requests with accountId in body
     * POST /services/apexrest/UserAccountDetail/
     */
    @HttpPost
    global static void getAccountDetailPost() {
        RestResponse response = RestContext.response;
        
        try {
            RestRequest req = RestContext.request;
            String accountId;
            
            // Check if data is sent as JSON in request body
            String requestBody = req.requestBody?.toString();
            
            if (!String.isBlank(requestBody)) {
                // Handle JSON format
                AccountDetailRequest detailRequest = (AccountDetailRequest) JSON.deserialize(requestBody, AccountDetailRequest.class);
                accountId = detailRequest.accountId;
            } else {
                // Handle form-encoded format
                Map<String, String> params = req.params;
                accountId = params.get('accountId');
            }
            
            // Validate required parameter
            if (String.isBlank(accountId)) {
                throw new IllegalArgumentException('accountId parameter is required');
            }
            
            // Query for Account details
            List<Account> accounts = [
                SELECT Id, FirstName, LastName, Salutation, PersonEmail, Phone, PersonMobilePhone, 
                       Passport_No__pc, Passport_No__c, Compliance_Status__c, CreatedDate,
                       BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, 
                       Resident_of_UAE__c, Country_of_Residence__c, Nationality__pc, 
                       Passport_Issue_Date__pc, Passport_Expiration_Date__c, PersonBirthdate, 
                       Place_of_Birth__pc, Occupation__pc, Nature_of_Business__pc, Source_of_Funds__pc, 
                       Politically_Exposed__pc, Subject_to_Sanction__pc, Payment_methods__pc, 
                       Bank_Name__pc, Visa_Number__pc, Visa_Place_of_Issue__pc, Visa_Date_of_Issue__pc, 
                       Visa_Expire_Date__pc, Emirates_ID_Card_Number__pc, Emirates_ID_Number__pc, 
                       Emirates_ID_Expiry_Date__pc, POA_Holder_Name__pc, POA_Holder_Emirates_ID_Number__pc, 
                       POA_Holder_Passport_Number__pc, POA_Holder_Passport_Expiry_Date__pc
                FROM Account 
                WHERE Id = :accountId
                LIMIT 1
            ];
            
            if (accounts.isEmpty()) {
                response.statusCode = 404;
                Map<String, Object> errorResponse = new Map<String, Object>();
                errorResponse.put('success', false);
                errorResponse.put('message', 'Account not found');
                errorResponse.put('account', null);
                response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
                return;
            }
            
            Account acc = accounts[0];
            
            // Build response data
            Map<String, Object> accountData = new Map<String, Object>();
            accountData.put('id', acc.Id);
            accountData.put('firstName', acc.FirstName);
            accountData.put('lastName', acc.LastName);
            accountData.put('salutation', acc.Salutation);
            accountData.put('personEmail', acc.PersonEmail);
            accountData.put('phone', acc.Phone);
            accountData.put('personMobilePhone', acc.PersonMobilePhone);
            accountData.put('passportNumber', acc.Passport_No__pc != null ? acc.Passport_No__pc : acc.Passport_No__c);
            accountData.put('complianceStatus', acc.Compliance_Status__c);
            accountData.put('createdDate', acc.CreatedDate);
            accountData.put('billingStreet', acc.BillingStreet);
            accountData.put('billingCity', acc.BillingCity);
            accountData.put('billingState', acc.BillingState);
            accountData.put('billingPostalCode', acc.BillingPostalCode);
            accountData.put('billingCountry', acc.BillingCountry);
            accountData.put('residentOfUAE', acc.Resident_of_UAE__c);
            accountData.put('countryOfResidence', acc.Country_of_Residence__c);
            accountData.put('nationality', acc.Nationality__pc);
            accountData.put('passportIssueDate', acc.Passport_Issue_Date__pc);
            accountData.put('passportExpirationDate', acc.Passport_Expiration_Date__c);
            accountData.put('personBirthdate', acc.PersonBirthdate);
            accountData.put('placeOfBirth', acc.Place_of_Birth__pc);
            accountData.put('occupation', acc.Occupation__pc);
            accountData.put('natureOfBusiness', acc.Nature_of_Business__pc);
            accountData.put('sourceOfFunds', acc.Source_of_Funds__pc);
            accountData.put('politicallyExposed', acc.Politically_Exposed__pc);
            accountData.put('subjectToSanction', acc.Subject_to_Sanction__pc);
            accountData.put('paymentMethods', acc.Payment_methods__pc);
            accountData.put('bankName', acc.Bank_Name__pc);
            accountData.put('visaNumber', acc.Visa_Number__pc);
            accountData.put('visaPlaceIssue', acc.Visa_Place_of_Issue__pc);
            accountData.put('visaDateOfIssue', acc.Visa_Date_of_Issue__pc);
            accountData.put('visaExpireDate', acc.Visa_Expire_Date__pc);
            accountData.put('emiratesIdCardNumber', acc.Emirates_ID_Card_Number__pc);
            accountData.put('emiratesIdNumber', acc.Emirates_ID_Number__pc);
            accountData.put('emiratesIdExpiryDate', acc.Emirates_ID_Expiry_Date__pc);
            accountData.put('poaHolderName', acc.POA_Holder_Name__pc);
            accountData.put('poaHolderEmiratesIdNumber', acc.POA_Holder_Emirates_ID_Number__pc);
            accountData.put('poaHolderPassportNumber', acc.POA_Holder_Passport_Number__pc);
            accountData.put('poaHolderPassportExpiryDate', acc.POA_Holder_Passport_Expiry_Date__pc);
            
            response.statusCode = 200;
            Map<String, Object> successResponse = new Map<String, Object>();
            successResponse.put('success', true);
            successResponse.put('message', 'Account details retrieved successfully');
            successResponse.put('account', accountData);
            response.responseBody = Blob.valueOf(JSON.serialize(successResponse));
            
        } catch (Exception e) {
            response.statusCode = 400;
            Map<String, Object> errorResponse = new Map<String, Object>();
            errorResponse.put('success', false);
            errorResponse.put('message', 'Error: ' + e.getMessage());
            errorResponse.put('account', null);
            response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
        }
    }
    
    // Request/Response Classes
    global class AccountDetailRequest {
        global String accountId { get; set; }
    }
    
    global class AccountDetailResponse {
        global Boolean success { get; set; }
        global String message { get; set; }
        global Map<String, Object> account { get; set; }
        
        global AccountDetailResponse(Boolean success, String message, Map<String, Object> account) {
            this.success = success;
            this.message = message;
            this.account = account;
        }
    }
}