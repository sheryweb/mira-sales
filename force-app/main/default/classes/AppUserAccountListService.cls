@RestResource(urlMapping='/UserAccountList/*')
global without sharing class AppUserAccountListService {
    
    // Record Type Constants
    private static final String AGENCY_RECORD_TYPE_ID = '012Hp000001yUTAIA2';
    private static final String PERSON_ACCOUNT_RECORD_TYPE_ID = '012Hp000001yUTFIA2';
    private static final String COMPANY_RECORD_TYPE_ID = '012Hp000001yiSEIAY';
    
    /**
     * REST endpoint to get Account list for App User
     * GET /services/apexrest/UserAccountList/
     */
    @HttpGet
    global static void getAccountList() {
        RestResponse response = RestContext.response;
        
        try {
            RestRequest req = RestContext.request;
            String userId;
            String recordTypeId;
            
            // Check if userId and recordTypeId are provided as URL parameters
            Map<String, String> params = req.params;
            userId = params.get('userId');
            recordTypeId = params.get('recordTypeId');
            
            // Validate required parameters
            if (String.isBlank(userId)) {
                throw new IllegalArgumentException('userId parameter is required');
            }
            if (String.isBlank(recordTypeId)) {
                throw new IllegalArgumentException('recordTypeId parameter is required');
            }
            
            // Validate recordTypeId
            if (recordTypeId != AGENCY_RECORD_TYPE_ID && recordTypeId != PERSON_ACCOUNT_RECORD_TYPE_ID && recordTypeId != COMPANY_RECORD_TYPE_ID) {
                throw new IllegalArgumentException('Invalid recordTypeId. Must be ' + AGENCY_RECORD_TYPE_ID + ', ' + PERSON_ACCOUNT_RECORD_TYPE_ID + ', or ' + COMPANY_RECORD_TYPE_ID);
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
                errorResponse.put('accounts', null);
                response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
                return;
            }
            
            List<Object> accountInfoList = new List<Object>();
            
            if (recordTypeId == AGENCY_RECORD_TYPE_ID) {
                // Query for Agency Record Type
                List<Account> agencyAccounts = [
                    SELECT Id, Name, Company_Email__c, Admin_Number__c, Trade_License_Number__c, 
                           TRN_Number__c, ORN_Number__c, Status__c, CreatedDate
                    FROM Account 
                    WHERE App_User__c = :userId 
                    AND RecordTypeId = :recordTypeId
                    ORDER BY Name ASC
                ];
                
                for (Account acc : agencyAccounts) {
                    Map<String, Object> agencyMap = new Map<String, Object>();
                    agencyMap.put('id', acc.Id);
                    agencyMap.put('name', acc.Name);
                    agencyMap.put('companyEmail', acc.Company_Email__c);
                    agencyMap.put('adminNumber', acc.Admin_Number__c);
                    agencyMap.put('tradeLicenseNumber', acc.Trade_License_Number__c);
                    agencyMap.put('trnNumber', acc.TRN_Number__c);
                    agencyMap.put('ornNumber', acc.ORN_Number__c);
                    agencyMap.put('status', acc.Status__c);
                    agencyMap.put('createdAt', acc.CreatedDate);
                    
                    accountInfoList.add(agencyMap);
                }
            } else if (recordTypeId == COMPANY_RECORD_TYPE_ID) {
                // Query for Company Record Type (similar to Agency)
                List<Account> companyAccounts = [
                    SELECT Id, Name, Company_Email__c, Phone, Trade_License_Number__c, 
                           Tax_Registration_Number__c, Country_of_Incorporation__c, City_of_Incorporation__c, Status__c, CreatedDate
                    FROM Account 
                    WHERE App_User__c = :userId 
                    AND RecordTypeId = :recordTypeId
                    ORDER BY Name ASC
                ];
                
                for (Account acc : companyAccounts) {
                    Map<String, Object> companyMap = new Map<String, Object>();
                    companyMap.put('id', acc.Id);
                    companyMap.put('name', acc.Name);
                    companyMap.put('companyEmail', acc.Company_Email__c);
                    companyMap.put('phone', acc.Phone);
                    companyMap.put('tradeLicenseNumber', acc.Trade_License_Number__c);
                    companyMap.put('taxRegistrationNumber', acc.Tax_Registration_Number__c);
                    companyMap.put('countryOfIncorporation', acc.Country_of_Incorporation__c);
                    companyMap.put('cityOfIncorporation', acc.City_of_Incorporation__c);
                    companyMap.put('status', acc.Status__c);
                    companyMap.put('createdAt', acc.CreatedDate);
                    
                    accountInfoList.add(companyMap);
                }
            } else if (recordTypeId == PERSON_ACCOUNT_RECORD_TYPE_ID) {
                // Query for Person Account Record Type
                List<Account> personAccounts = [
                    SELECT Id, FirstName, LastName, Salutation, PersonEmail, Phone, PersonMobilePhone, Passport_No__pc, Passport_No__c, Compliance_Status__c, CreatedDate,
                           BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, Resident_of_UAE__c, Country_of_Residence__c, Nationality__pc, 
                           Passport_Issue_Date__pc, Passport_Expiration_Date__c, PersonBirthdate, Place_of_Birth__pc, Occupation__pc, Nature_of_Business__pc, Source_of_Funds__pc, 
                           Politically_Exposed__pc, Subject_to_Sanction__pc, Payment_methods__pc, Bank_Name__pc, Visa_Number__pc, Visa_Place_Issue__pc, Visa_Place_of_Issue__pc, Visa_Date_of_Issue__pc, 
                           Visa_Expire_Date__pc, Emirates_ID_Card_Number__pc, Emirates_ID_Number__pc, Emirates_ID_Expiry_Date__pc, POA_Holder_Name__pc, POA_Holder_Emirates_ID_Number__pc, 
                           POA_Holder_Passport_Number__pc, POA_Holder_Passport_Expiry_Date__pc
                    FROM Account 
                    WHERE App_User__c = :userId 
                    AND RecordTypeId = :recordTypeId
                    ORDER BY LastName ASC, FirstName ASC
                ];
                
                for (Account acc : personAccounts) {
                    String fullName = (acc.FirstName != null ? acc.FirstName + ' ' : '') + 
                                    (acc.LastName != null ? acc.LastName : '');
                    String phoneToUse = acc.Phone != null ? acc.Phone : acc.PersonMobilePhone;
                    
                    // Determine which passport field has a value
                    String passportNumber = '';
                    if (!String.isBlank(acc.Passport_No__pc)) {
                        passportNumber = acc.Passport_No__pc;
                    } else if (!String.isBlank(acc.Passport_No__c)) {
                        passportNumber = acc.Passport_No__c;
                    }
                    
                    Map<String, Object> personMap = new Map<String, Object>();
                    personMap.put('id', acc.Id);
                    personMap.put('name', fullName.trim());
                    personMap.put('salutation', acc.Salutation);
                    personMap.put('personEmail', acc.PersonEmail);
                    personMap.put('phone', phoneToUse);
                    if (!String.isBlank(passportNumber)) {
                        personMap.put('passportNumber', passportNumber);
                    }
                    personMap.put('complianceStatus', acc.Compliance_Status__c);
                    personMap.put('createdAt', acc.CreatedDate);
                    
                    // Add the new fields to the response
                    personMap.put('billingStreet', acc.BillingStreet);
                    personMap.put('billingCity', acc.BillingCity);
                    personMap.put('billingState', acc.BillingState);
                    personMap.put('billingPostalCode', acc.BillingPostalCode);
                    personMap.put('billingCountry', acc.BillingCountry);
                    personMap.put('residentOfUAE', acc.Resident_of_UAE__c);
                    personMap.put('countryOfResidence', acc.Country_of_Residence__c);
                    personMap.put('nationality', acc.Nationality__pc);
                    personMap.put('passportIssueDate', acc.Passport_Issue_Date__pc);
                    personMap.put('passportExpirationDate', acc.Passport_Expiration_Date__c);
                    personMap.put('personBirthdate', acc.PersonBirthdate);
                    personMap.put('placeOfBirth', acc.Place_of_Birth__pc);
                    personMap.put('occupation', acc.Occupation__pc);
                    personMap.put('natureOfBusiness', acc.Nature_of_Business__pc);
                    personMap.put('sourceOfFunds', acc.Source_of_Funds__pc);
                    personMap.put('politicallyExposed', acc.Politically_Exposed__pc);
                    personMap.put('subjectToSanction', acc.Subject_to_Sanction__pc);
                    personMap.put('paymentMethods', acc.Payment_methods__pc);
                    personMap.put('bankName', acc.Bank_Name__pc);
                    personMap.put('visaNumber', acc.Visa_Number__pc);
                    personMap.put('visaPlaceIssue', acc.Visa_Place_Issue__pc);
                    personMap.put('visaDateOfIssue', acc.Visa_Date_of_Issue__pc);
                    personMap.put('visaExpireDate', acc.Visa_Expire_Date__pc);
                    personMap.put('emiratesIdCardNumber', acc.Emirates_ID_Card_Number__pc);
                    personMap.put('emiratesIdNumber', acc.Emirates_ID_Number__pc);
                    personMap.put('emiratesIdExpiryDate', acc.Emirates_ID_Expiry_Date__pc);
                    personMap.put('poaHolderName', acc.POA_Holder_Name__pc);
                    personMap.put('poaHolderEmiratesIdNumber', acc.POA_Holder_Emirates_ID_Number__pc);
                    personMap.put('poaHolderPassportNumber', acc.POA_Holder_Passport_Number__pc);
                    personMap.put('poaHolderPassportExpiryDate', acc.POA_Holder_Passport_Expiry_Date__pc);
                    
                    accountInfoList.add(personMap);
                }
            }
            
            response.statusCode = 200;
            Map<String, Object> successResponse = new Map<String, Object>();
            successResponse.put('success', true);
            successResponse.put('message', 'Accounts retrieved successfully');
            successResponse.put('accounts', accountInfoList);
            response.responseBody = Blob.valueOf(JSON.serialize(successResponse));
            
        } catch (Exception e) {
            response.statusCode = 400;
            Map<String, Object> errorResponse = new Map<String, Object>();
            errorResponse.put('success', false);
            errorResponse.put('message', 'Error: ' + e.getMessage());
            errorResponse.put('accounts', null);
            response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
        }
    }
    
    /**
     * POST method to support form-encoded requests
     * POST /services/apexrest/UserAccountList/
     */
    @HttpPost
    global static void getAccountListPost() {
        RestResponse response = RestContext.response;
        
        try {
            RestRequest req = RestContext.request;
            String userId;
            String recordTypeId;
            
            // Check if data is sent as JSON in request body
            String requestBody = req.requestBody?.toString();
            
            if (!String.isBlank(requestBody)) {
                // Handle JSON format
                UserAccountRequest userRequest = (UserAccountRequest) JSON.deserialize(requestBody, UserAccountRequest.class);
                userId = userRequest.userId;
                recordTypeId = userRequest.recordTypeId;
            } else {
                // Handle form-encoded format
                Map<String, String> params = req.params;
                userId = params.get('userId');
                recordTypeId = params.get('recordTypeId');
            }
            
            // Validate required parameters
            if (String.isBlank(userId)) {
                throw new IllegalArgumentException('userId parameter is required');
            }
            if (String.isBlank(recordTypeId)) {
                throw new IllegalArgumentException('recordTypeId parameter is required');
            }
            
            // Validate recordTypeId
            if (recordTypeId != AGENCY_RECORD_TYPE_ID && recordTypeId != PERSON_ACCOUNT_RECORD_TYPE_ID && recordTypeId != COMPANY_RECORD_TYPE_ID) {
                throw new IllegalArgumentException('Invalid recordTypeId. Must be ' + AGENCY_RECORD_TYPE_ID + ', ' + PERSON_ACCOUNT_RECORD_TYPE_ID + ', or ' + COMPANY_RECORD_TYPE_ID);
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
                errorResponse.put('accounts', null);
                response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
                return;
            }
            
            List<Object> accountInfoList = new List<Object>();
            
            if (recordTypeId == AGENCY_RECORD_TYPE_ID) {
                // Query for Agency Record Type
                List<Account> agencyAccounts = [
                    SELECT Id, Name, Company_Email__c, Admin_Number__c, Trade_License_Number__c, 
                           TRN_Number__c, ORN_Number__c, Status__c, CreatedDate
                    FROM Account 
                    WHERE App_User__c = :userId 
                    AND RecordTypeId = :recordTypeId
                    ORDER BY Name ASC
                ];
                
                for (Account acc : agencyAccounts) {
                    Map<String, Object> agencyMap = new Map<String, Object>();
                    agencyMap.put('id', acc.Id);
                    agencyMap.put('name', acc.Name);
                    agencyMap.put('companyEmail', acc.Company_Email__c);
                    agencyMap.put('adminNumber', acc.Admin_Number__c);
                    agencyMap.put('tradeLicenseNumber', acc.Trade_License_Number__c);
                    agencyMap.put('trnNumber', acc.TRN_Number__c);
                    agencyMap.put('ornNumber', acc.ORN_Number__c);
                    agencyMap.put('status', acc.Status__c);
                    agencyMap.put('createdAt', acc.CreatedDate);
                    
                    accountInfoList.add(agencyMap);
                }
            } else if (recordTypeId == COMPANY_RECORD_TYPE_ID) {
                // Query for Company Record Type (similar to Agency)
                List<Account> companyAccounts = [
                    SELECT Id, Name, Company_Email__c, Phone, Trade_License_Number__c, 
                           Tax_Registration_Number__c, Country_of_Incorporation__c, City_of_Incorporation__c, Status__c, CreatedDate
                    FROM Account 
                    WHERE App_User__c = :userId 
                    AND RecordTypeId = :recordTypeId
                    ORDER BY Name ASC
                ];
                
                for (Account acc : companyAccounts) {
                    Map<String, Object> companyMap = new Map<String, Object>();
                    companyMap.put('id', acc.Id);
                    companyMap.put('name', acc.Name);
                    companyMap.put('companyEmail', acc.Company_Email__c);
                    companyMap.put('phone', acc.Phone);
                    companyMap.put('tradeLicenseNumber', acc.Trade_License_Number__c);
                    companyMap.put('taxRegistrationNumber', acc.Tax_Registration_Number__c);
                    companyMap.put('countryOfIncorporation', acc.Country_of_Incorporation__c);
                    companyMap.put('cityOfIncorporation', acc.City_of_Incorporation__c);
                    companyMap.put('status', acc.Status__c);
                    companyMap.put('createdAt', acc.CreatedDate);
                    
                    accountInfoList.add(companyMap);
                }
            } else if (recordTypeId == PERSON_ACCOUNT_RECORD_TYPE_ID) {
                // Query for Person Account Record Type
                List<Account> personAccounts = [
                    SELECT Id, FirstName, LastName, Salutation, PersonEmail, Phone, PersonMobilePhone, Passport_No__pc, Passport_No__c, Compliance_Status__c, CreatedDate,
                           BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, Resident_of_UAE__c, Country_of_Residence__c, Nationality__pc, 
                           Passport_Issue_Date__pc, Passport_Expiration_Date__c, PersonBirthdate, Place_of_Birth__pc, Occupation__pc, Nature_of_Business__pc, Source_of_Funds__pc, 
                           Politically_Exposed__pc, Subject_to_Sanction__pc, Payment_methods__pc, Bank_Name__pc, Visa_Number__pc, Visa_Place_Issue__pc, Visa_Place_of_Issue__pc, Visa_Date_of_Issue__pc, 
                           Visa_Expire_Date__pc, Emirates_ID_Card_Number__pc, Emirates_ID_Number__pc, Emirates_ID_Expiry_Date__pc, POA_Holder_Name__pc, POA_Holder_Emirates_ID_Number__pc, 
                           POA_Holder_Passport_Number__pc, POA_Holder_Passport_Expiry_Date__pc
                    FROM Account 
                    WHERE App_User__c = :userId 
                    AND RecordTypeId = :recordTypeId
                    ORDER BY LastName ASC, FirstName ASC
                ];
                
                for (Account acc : personAccounts) {
                    String fullName = (acc.FirstName != null ? acc.FirstName + ' ' : '') + 
                                    (acc.LastName != null ? acc.LastName : '');
                    String phoneToUse = acc.Phone != null ? acc.Phone : acc.PersonMobilePhone;
                    
                    // Determine which passport field has a value
                    String passportNumber = '';
                    if (!String.isBlank(acc.Passport_No__pc)) {
                        passportNumber = acc.Passport_No__pc;
                    } else if (!String.isBlank(acc.Passport_No__c)) {
                        passportNumber = acc.Passport_No__c;
                    }
                    
                    Map<String, Object> personMap = new Map<String, Object>();
                    personMap.put('id', acc.Id);
                    personMap.put('name', fullName.trim());
                    personMap.put('salutation', acc.Salutation);
                    personMap.put('personEmail', acc.PersonEmail);
                    personMap.put('phone', phoneToUse);
                    if (!String.isBlank(passportNumber)) {
                        personMap.put('passportNumber', passportNumber);
                    }
                    personMap.put('complianceStatus', acc.Compliance_Status__c);
                    personMap.put('createdAt', acc.CreatedDate);
                    
                    // Add the new fields to the response
                    personMap.put('billingStreet', acc.BillingStreet);
                    personMap.put('billingCity', acc.BillingCity);
                    personMap.put('billingState', acc.BillingState);
                    personMap.put('billingPostalCode', acc.BillingPostalCode);
                    personMap.put('billingCountry', acc.BillingCountry);
                    personMap.put('residentOfUAE', acc.Resident_of_UAE__c);
                    personMap.put('countryOfResidence', acc.Country_of_Residence__c);
                    personMap.put('nationality', acc.Nationality__pc);
                    personMap.put('passportIssueDate', acc.Passport_Issue_Date__pc);
                    personMap.put('passportExpirationDate', acc.Passport_Expiration_Date__c);
                    personMap.put('personBirthdate', acc.PersonBirthdate);
                    personMap.put('placeOfBirth', acc.Place_of_Birth__pc);
                    personMap.put('occupation', acc.Occupation__pc);
                    personMap.put('natureOfBusiness', acc.Nature_of_Business__pc);
                    personMap.put('sourceOfFunds', acc.Source_of_Funds__pc);
                    personMap.put('politicallyExposed', acc.Politically_Exposed__pc);
                    personMap.put('subjectToSanction', acc.Subject_to_Sanction__pc);
                    personMap.put('paymentMethods', acc.Payment_methods__pc);
                    personMap.put('bankName', acc.Bank_Name__pc);
                    personMap.put('visaNumber', acc.Visa_Number__pc);
                    personMap.put('visaPlaceIssue', acc.Visa_Place_Issue__pc);
                    personMap.put('visaDateOfIssue', acc.Visa_Date_of_Issue__pc);
                    personMap.put('visaExpireDate', acc.Visa_Expire_Date__pc);
                    personMap.put('emiratesIdCardNumber', acc.Emirates_ID_Card_Number__pc);
                    personMap.put('emiratesIdNumber', acc.Emirates_ID_Number__pc);
                    personMap.put('emiratesIdExpiryDate', acc.Emirates_ID_Expiry_Date__pc);
                    personMap.put('poaHolderName', acc.POA_Holder_Name__pc);
                    personMap.put('poaHolderEmiratesIdNumber', acc.POA_Holder_Emirates_ID_Number__pc);
                    personMap.put('poaHolderPassportNumber', acc.POA_Holder_Passport_Number__pc);
                    personMap.put('poaHolderPassportExpiryDate', acc.POA_Holder_Passport_Expiry_Date__pc);
                    
                    accountInfoList.add(personMap);
                }
            }
            
            response.statusCode = 200;
            Map<String, Object> successResponse = new Map<String, Object>();
            successResponse.put('success', true);
            successResponse.put('message', 'Accounts retrieved successfully');
            successResponse.put('accounts', accountInfoList);
            response.responseBody = Blob.valueOf(JSON.serialize(successResponse));
            
        } catch (Exception e) {
            response.statusCode = 400;
            Map<String, Object> errorResponse = new Map<String, Object>();
            errorResponse.put('success', false);
            errorResponse.put('message', 'Error: ' + e.getMessage());
            errorResponse.put('accounts', null);
            response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
        }
    }
    
    // Request/Response Classes
    global class UserAccountRequest {
        global String userId { get; set; }
        global String recordTypeId { get; set; }
    }
    
    global class AccountListResponse {
        global Boolean success { get; set; }
        global String message { get; set; }
        global List<Object> accounts { get; set; }
        
        global AccountListResponse(Boolean success, String message, List<Object> accounts) {
            this.success = success;
            this.message = message;
            this.accounts = accounts;
        }
    }
}