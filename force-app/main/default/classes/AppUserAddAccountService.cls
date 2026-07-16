@RestResource(urlMapping='/UserAddAccount/*')
global without sharing class AppUserAddAccountService {
    
    // Record Type Constants
    private static final String PERSON_ACCOUNT_RECORD_TYPE_ID = '012Hp000001yUTFIA2';
    private static final String COMPANY_RECORD_TYPE_ID = '012Hp000001yiSEIAY';
    
    /**
     * REST endpoint to create a new Person Account
     * POST /services/apexrest/UserAddAccount/
     */
    @HttpPost
    global static void addAccount() {
        processAccountRequest('POST');
    }
    
    /**
     * REST endpoint to update a Person Account
     * PUT /services/apexrest/UserAddAccount/
     */
    @HttpPut
    global static void updateAccount() {
        processAccountRequest('PUT');
    }
    
    /**
     * REST endpoint to update a Person Account (partial update)
     * PATCH /services/apexrest/UserAddAccount/
     */
    @HttpPatch
    global static void patchAccount() {
        processAccountRequest('PATCH');
    }
    
    /**
     * Unified method to handle both insert and update operations
     */
    private static void processAccountRequest(String httpMethod) {
        RestResponse response = RestContext.response;
        
        try {
            RestRequest req = RestContext.request;
            String requestBody = req.requestBody?.toString();
            
            // Extract record ID from URL if present
            String recordId = extractRecordIdFromUrl(req.requestURI);
            
            AddAccountRequest addRequest = new AddAccountRequest();
            
            // Debug information about the request
            String contentType = req.headers?.get('Content-Type');
            
            // Check if data is sent in request body
            if (!String.isBlank(requestBody)) {
                // Determine if it's JSON or form-encoded based on Content-Type
                if (contentType != null && contentType.toLowerCase().contains('application/json')) {
                    try {
                        // Handle JSON format
                        addRequest = (AddAccountRequest) JSON.deserialize(requestBody, AddAccountRequest.class);
                    } catch (JSONException e) {
                        throw new IllegalArgumentException('JSON parsing failed: ' + e.getMessage() + '. Request body: ' + requestBody);
                    }
                } else {
                    // Handle form-encoded data
                    Map<String, String> formParams = parseFormEncodedData(requestBody);
                    addRequest.recordTypeId = formParams.get('recordTypeId');
                    addRequest.name = formParams.get('name');
                    addRequest.salutation = formParams.get('salutation');
                    addRequest.email = formParams.get('email');
                    addRequest.phone = formParams.get('phone');
                    addRequest.passportNo = formParams.get('passportNo');
                    addRequest.appUserId = formParams.get('appUserId');
                    
                    // Additional passport and ID fields
                    addRequest.passportIssueDate = formParams.get('passportIssueDate');
                    addRequest.passportExpirationDate = formParams.get('passportExpirationDate');
                    addRequest.nationality = formParams.get('nationality');
                    addRequest.countryOfResidence = formParams.get('countryOfResidence');
                    addRequest.emiratesIdCardNumber = formParams.get('emiratesIdCardNumber');
                    addRequest.emiratesIdNumber = formParams.get('emiratesIdNumber');
                    addRequest.emiratesIdExpiryDate = formParams.get('emiratesIdExpiryDate');
                    
                    // Visa fields
                    addRequest.visaNumber = formParams.get('visaNumber');
                                         addRequest.visaPlaceIssue = formParams.get('visaPlaceIssue');
                    addRequest.visaDateOfIssue = formParams.get('visaDateOfIssue');
                    addRequest.visaExpireDate = formParams.get('visaExpireDate');
                    
                    // Personal information
                    addRequest.personBirthdate = formParams.get('personBirthdate');
                    addRequest.placeOfBirth = formParams.get('placeOfBirth');
                    addRequest.occupation = formParams.get('occupation');
                    addRequest.natureOfBusiness = formParams.get('natureOfBusiness');
                    addRequest.sourceOfFunds = formParams.get('sourceOfFunds');
                    
                                         // Compliance fields
                     addRequest.complianceStatus = formParams.get('complianceStatus');
                     addRequest.politicallyExposed = formParams.get('politicallyExposed');
                     addRequest.politicallyExposedPersonText = formParams.get('politicallyExposedPersonText');
                     addRequest.subjectToSanction = formParams.get('subjectToSanction');
                    
                    // Banking and payment
                    addRequest.paymentMethods = formParams.get('paymentMethods');
                    addRequest.bankName = formParams.get('bankName');
                    addRequest.currencyOther = formParams.get('currencyOther');
                    
                    // POA fields
                    addRequest.poaHolderName = formParams.get('poaHolderName');
                    addRequest.poaHolderEmiratesIdNumber = formParams.get('poaHolderEmiratesIdNumber');
                    addRequest.poaHolderPassportNumber = formParams.get('poaHolderPassportNumber');
                    addRequest.poaHolderPassportExpiryDate = formParams.get('poaHolderPassportExpiryDate');
                    
                    // Billing Address fields
                    addRequest.billingStreet = formParams.get('billingStreet');
                    addRequest.billingCity = formParams.get('billingCity');
                    addRequest.billingState = formParams.get('billingState');
                    addRequest.billingPostalCode = formParams.get('billingPostalCode');
                    addRequest.billingCountry = formParams.get('billingCountry');
                    
                    // Additional fields
                    String residentOfUAEStr = formParams.get('residentOfUAE');
                    if (!String.isBlank(residentOfUAEStr)) {
                        addRequest.residentOfUAE = Boolean.valueOf(residentOfUAEStr);
                    }
                    
                    // Company Record Type specific fields
                    addRequest.companyEmail = formParams.get('companyEmail');
                    addRequest.tradeLicenseNumber = formParams.get('tradeLicenseNumber');
                    addRequest.tradeLicenseIssueDate = formParams.get('tradeLicenseIssueDate');
                    addRequest.tradeLicenseExpiryDate = formParams.get('tradeLicenseExpiryDate');
                    addRequest.taxRegistrationNumber = formParams.get('taxRegistrationNumber');
                    addRequest.countryOfIncorporation = formParams.get('countryOfIncorporation');
                    addRequest.cityOfIncorporation = formParams.get('cityOfIncorporation');
                    addRequest.dateOfIncorporation = formParams.get('dateOfIncorporation');
                    addRequest.status = formParams.get('status');
                    
                    // Contact fields for Company Record Type
                    addRequest.contactSalutation = formParams.get('contactSalutation');
                    addRequest.contactName = formParams.get('contactName');
                    addRequest.contactTitle = formParams.get('contactTitle');
                    addRequest.contactEmail = formParams.get('contactEmail');
                    addRequest.contactPhone = formParams.get('contactPhone');
                    addRequest.contactMobilePhone = formParams.get('contactMobilePhone');
                    addRequest.companyShare = formParams.get('companyShare');
                    addRequest.contactPassportNo = formParams.get('contactPassportNo');
                    addRequest.positionInCompany = formParams.get('positionInCompany');
                    addRequest.contactNationality = formParams.get('contactNationality');
                    addRequest.contactBirthDate = formParams.get('contactBirthDate');
                    addRequest.contactPlaceOfBirth = formParams.get('contactPlaceOfBirth');
                    addRequest.contactOccupation = formParams.get('contactOccupation');
                    addRequest.contactNatureOfBusiness = formParams.get('contactNatureOfBusiness');
                    addRequest.contactSourceOfFunds = formParams.get('contactSourceOfFunds');
                    addRequest.contactPoliticallyExposed = formParams.get('contactPoliticallyExposed');
                    addRequest.contactSubjectToSanction = formParams.get('contactSubjectToSanction');
                    addRequest.contactPaymentMethods = formParams.get('contactPaymentMethods');
                    addRequest.contactBankName = formParams.get('contactBankName');
                    addRequest.contactVisaNumber = formParams.get('contactVisaNumber');
                    addRequest.contactVisaPlaceOfIssue = formParams.get('contactVisaPlaceOfIssue');
                    addRequest.contactVisaDateOfIssue = formParams.get('contactVisaDateOfIssue');
                    addRequest.contactVisaExpireDate = formParams.get('contactVisaExpireDate');
                    addRequest.contactEmiratesIdNumber = formParams.get('contactEmiratesIdNumber');
                    addRequest.contactEmiratesIdCardNumber = formParams.get('contactEmiratesIdCardNumber');
                    addRequest.contactEmiratesIdExpiryDate = formParams.get('contactEmiratesIdExpiryDate');
                    addRequest.contactPoaHolderName = formParams.get('contactPoaHolderName');
                    addRequest.contactPoaHolderEmiratesIdNumber = formParams.get('contactPoaHolderEmiratesIdNumber');
                    addRequest.contactPoaHolderPassportNumber = formParams.get('contactPoaHolderPassportNumber');
                    addRequest.contactPoaHolderPassportExpiryDate = formParams.get('contactPoaHolderPassportExpiryDate');
                }
            } else {
                // Handle URL parameters (for GET-style requests)
                Map<String, String> params = req.params;
                addRequest.recordTypeId = params.get('recordTypeId');
                addRequest.name = params.get('name');
                addRequest.salutation = params.get('salutation');
                addRequest.email = params.get('email');
                addRequest.phone = params.get('phone');
                addRequest.passportNo = params.get('passportNo');
                addRequest.appUserId = params.get('appUserId');
                
                // Additional passport and ID fields
                addRequest.passportIssueDate = params.get('passportIssueDate');
                addRequest.passportExpirationDate = params.get('passportExpirationDate');
                addRequest.nationality = params.get('nationality');
                addRequest.countryOfResidence = params.get('countryOfResidence');
                addRequest.emiratesIdCardNumber = params.get('emiratesIdCardNumber');
                addRequest.emiratesIdNumber = params.get('emiratesIdNumber');
                addRequest.emiratesIdExpiryDate = params.get('emiratesIdExpiryDate');
                
                // Visa fields
                addRequest.visaNumber = params.get('visaNumber');
                                 addRequest.visaPlaceIssue = params.get('visaPlaceIssue');
                addRequest.visaDateOfIssue = params.get('visaDateOfIssue');
                addRequest.visaExpireDate = params.get('visaExpireDate');
                
                // Personal information
                addRequest.personBirthdate = params.get('personBirthdate');
                addRequest.placeOfBirth = params.get('placeOfBirth');
                addRequest.occupation = params.get('occupation');
                addRequest.natureOfBusiness = params.get('natureOfBusiness');
                addRequest.sourceOfFunds = params.get('sourceOfFunds');
                
                                 // Compliance fields
                 addRequest.complianceStatus = params.get('complianceStatus');
                 addRequest.politicallyExposed = params.get('politicallyExposed');
                 addRequest.politicallyExposedPersonText = params.get('politicallyExposedPersonText');
                 addRequest.subjectToSanction = params.get('subjectToSanction');
                
                // Banking and payment
                addRequest.paymentMethods = params.get('paymentMethods');
                addRequest.bankName = params.get('bankName');
                addRequest.currencyOther = params.get('currencyOther');
                
                // POA fields
                addRequest.poaHolderName = params.get('poaHolderName');
                addRequest.poaHolderEmiratesIdNumber = params.get('poaHolderEmiratesIdNumber');
                addRequest.poaHolderPassportNumber = params.get('poaHolderPassportNumber');
                addRequest.poaHolderPassportExpiryDate = params.get('poaHolderPassportExpiryDate');
                
                // Billing Address fields
                addRequest.billingStreet = params.get('billingStreet');
                addRequest.billingCity = params.get('billingCity');
                addRequest.billingState = params.get('billingState');
                addRequest.billingPostalCode = params.get('billingPostalCode');
                addRequest.billingCountry = params.get('billingCountry');
                
                // Additional fields
                String residentOfUAEStr = params.get('residentOfUAE');
                if (!String.isBlank(residentOfUAEStr)) {
                    addRequest.residentOfUAE = Boolean.valueOf(residentOfUAEStr);
                }
                
                // Company Record Type specific fields
                addRequest.companyEmail = params.get('companyEmail');
                addRequest.tradeLicenseNumber = params.get('tradeLicenseNumber');
                addRequest.tradeLicenseIssueDate = params.get('tradeLicenseIssueDate');
                addRequest.tradeLicenseExpiryDate = params.get('tradeLicenseExpiryDate');
                addRequest.taxRegistrationNumber = params.get('taxRegistrationNumber');
                addRequest.countryOfIncorporation = params.get('countryOfIncorporation');
                addRequest.cityOfIncorporation = params.get('cityOfIncorporation');
                addRequest.dateOfIncorporation = params.get('dateOfIncorporation');
                addRequest.status = params.get('status');
                
                // Contact fields for Company Record Type
                addRequest.contactSalutation = params.get('contactSalutation');
                addRequest.contactName = params.get('contactName');
                addRequest.contactTitle = params.get('contactTitle');
                addRequest.contactEmail = params.get('contactEmail');
                addRequest.contactPhone = params.get('contactPhone');
                addRequest.contactMobilePhone = params.get('contactMobilePhone');
                addRequest.companyShare = params.get('companyShare');
                addRequest.contactPassportNo = params.get('contactPassportNo');
                addRequest.positionInCompany = params.get('positionInCompany');
                addRequest.contactNationality = params.get('contactNationality');
                addRequest.contactBirthDate = params.get('contactBirthDate');
                addRequest.contactPlaceOfBirth = params.get('contactPlaceOfBirth');
                addRequest.contactOccupation = params.get('contactOccupation');
                addRequest.contactNatureOfBusiness = params.get('contactNatureOfBusiness');
                addRequest.contactSourceOfFunds = params.get('contactSourceOfFunds');
                addRequest.contactPoliticallyExposed = params.get('contactPoliticallyExposed');
                addRequest.contactSubjectToSanction = params.get('contactSubjectToSanction');
                addRequest.contactPaymentMethods = params.get('contactPaymentMethods');
                addRequest.contactBankName = params.get('contactBankName');
                addRequest.contactVisaNumber = params.get('contactVisaNumber');
                addRequest.contactVisaPlaceOfIssue = params.get('contactVisaPlaceOfIssue');
                addRequest.contactVisaDateOfIssue = params.get('contactVisaDateOfIssue');
                addRequest.contactVisaExpireDate = params.get('contactVisaExpireDate');
                addRequest.contactEmiratesIdNumber = params.get('contactEmiratesIdNumber');
                addRequest.contactEmiratesIdCardNumber = params.get('contactEmiratesIdCardNumber');
                addRequest.contactEmiratesIdExpiryDate = params.get('contactEmiratesIdExpiryDate');
                addRequest.contactPoaHolderName = params.get('contactPoaHolderName');
                addRequest.contactPoaHolderEmiratesIdNumber = params.get('contactPoaHolderEmiratesIdNumber');
                addRequest.contactPoaHolderPassportNumber = params.get('contactPoaHolderPassportNumber');
                addRequest.contactPoaHolderPassportExpiryDate = params.get('contactPoaHolderPassportExpiryDate');
                
                // If no body and no params, throw error
                if (String.isBlank(addRequest.name) && String.isBlank(addRequest.email)) {
                    throw new IllegalArgumentException('No request data found. Please provide data in JSON format in request body or as form/URL parameters.');
                }
            }
            
            // Determine operation type: UPDATE if record ID exists and method is PUT/PATCH, otherwise INSERT
            Boolean isUpdateOperation = !String.isBlank(recordId) && (httpMethod == 'PUT' || httpMethod == 'PATCH');
            
            if (isUpdateOperation) {
                handleUpdateOperation(addRequest, recordId, response, httpMethod);
            } else {
                // For create operations (POST), check if URL parameter is a record type ID
                if (!String.isBlank(recordId) && httpMethod == 'POST') {
                    // If it's a POST with URL parameter, treat it as recordTypeId
                    addRequest.recordTypeId = recordId;
                    System.debug('DEBUG: Setting recordTypeId from URL parameter: ' + recordId);
                }
                handleInsertOperation(addRequest, response);
            }
            
        } catch (DmlException e) {
            response.statusCode = 400;
            Map<String, Object> errorResponse = new Map<String, Object>();
            errorResponse.put('success', false);
            errorResponse.put('message', 'Database error: ' + e.getMessage());
            errorResponse.put('account', null);
            response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
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
     * Extract record ID from the URL path
     * URL format: /services/apexrest/UserAddAccount/{recordId}
     */
    private static String extractRecordIdFromUrl(String requestURI) {
        if (String.isBlank(requestURI)) {
            return null;
        }
        
        // Split the URI by '/' and find the part after 'UserAddAccount'
        List<String> uriParts = requestURI.split('/');
        Boolean foundUserAddAccount = false;
        
        for (String part : uriParts) {
            if (foundUserAddAccount && !String.isBlank(part)) {
                // This should be the record ID
                return part;
            }
            if (part == 'UserAddAccount') {
                foundUserAddAccount = true;
            }
        }
        
        return null;
    }
    
    /**
     * Helper method to parse date string to Date object
     */
    private static Date parseDate(String dateString) {
        if (String.isBlank(dateString)) {
            return null;
        }
        
        try {
            // Try different date formats
            if (dateString.contains('/')) {
                // MM/dd/yyyy or dd/MM/yyyy format
                return Date.parse(dateString);
            } else if (dateString.contains('-')) {
                // yyyy-MM-dd format
                List<String> parts = dateString.split('-');
                if (parts.size() == 3) {
                    return Date.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), Integer.valueOf(parts[2]));
                }
            }
            // If no separators, assume it's a valid date string
            return Date.valueOf(dateString);
        } catch (Exception e) {
            System.debug('Error parsing date: ' + dateString + ', Error: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Parse form-encoded data into a map
     */
    private static Map<String, String> parseFormEncodedData(String formData) {
        Map<String, String> result = new Map<String, String>();
        
        if (String.isBlank(formData)) {
            return result;
        }
        
        // Split by & to get key-value pairs
        List<String> pairs = formData.split('&');
        
        for (String pair : pairs) {
            if (pair.contains('=')) {
                List<String> keyValue = pair.split('=', 2);
                String key = keyValue[0];
                String value = keyValue.size() > 1 ? EncodingUtil.urlDecode(keyValue[1], 'UTF-8') : '';
                result.put(key, value);
            }
        }
        
        return result;
    }
    
    /**
     * Handle insert operation for new accounts
     */
    private static void handleInsertOperation(AddAccountRequest addRequest, RestResponse response) {
        // Determine record type - default to Person Account if not specified
        String recordTypeId = addRequest.recordTypeId;
        
        // DEBUG: Log the received recordTypeId
        System.debug('DEBUG: Received recordTypeId = ' + recordTypeId);
        System.debug('DEBUG: Is recordTypeId blank? ' + String.isBlank(recordTypeId));
        System.debug('DEBUG: Person Account ID = ' + PERSON_ACCOUNT_RECORD_TYPE_ID);
        System.debug('DEBUG: Company Account ID = ' + COMPANY_RECORD_TYPE_ID);
        
        if (String.isBlank(recordTypeId)) {
            System.debug('DEBUG: recordTypeId was blank, defaulting to Person Account');
            recordTypeId = PERSON_ACCOUNT_RECORD_TYPE_ID;
        }
        
        System.debug('DEBUG: Final recordTypeId being used = ' + recordTypeId);
        
        // Validate record type
        if (recordTypeId != PERSON_ACCOUNT_RECORD_TYPE_ID && recordTypeId != COMPANY_RECORD_TYPE_ID) {
            throw new IllegalArgumentException('Invalid recordTypeId. Must be ' + PERSON_ACCOUNT_RECORD_TYPE_ID + ' or ' + COMPANY_RECORD_TYPE_ID);
        }
        
        // Validate required parameters for insert based on record type
        if (String.isBlank(addRequest.name)) {
            throw new IllegalArgumentException('name parameter is required');
        }
        if (String.isBlank(addRequest.appUserId)) {
            throw new IllegalArgumentException('appUserId parameter is required');
        }
        
        // Record type specific validation
        System.debug('DEBUG: About to validate. recordTypeId = ' + recordTypeId);
        System.debug('DEBUG: recordTypeId == PERSON_ACCOUNT_RECORD_TYPE_ID? ' + (recordTypeId == PERSON_ACCOUNT_RECORD_TYPE_ID));
        System.debug('DEBUG: recordTypeId == COMPANY_RECORD_TYPE_ID? ' + (recordTypeId == COMPANY_RECORD_TYPE_ID));
        
        if (recordTypeId == PERSON_ACCOUNT_RECORD_TYPE_ID) {
            System.debug('DEBUG: Validating as Person Account');
            if (String.isBlank(addRequest.email)) {
                throw new IllegalArgumentException('email parameter is required for Person Account');
            }
            if (String.isBlank(addRequest.phone)) {
                throw new IllegalArgumentException('phone parameter is required for Person Account');
            }
            if (String.isBlank(addRequest.passportNo)) {
                throw new IllegalArgumentException('passportNo parameter is required for Person Account');
            }
        } else if (recordTypeId == COMPANY_RECORD_TYPE_ID) {
            System.debug('DEBUG: Validating as Company Account');
            if (String.isBlank(addRequest.companyEmail)) {
                throw new IllegalArgumentException('companyEmail parameter is required for Company Record Type');
            }
            if (String.isBlank(addRequest.phone)) {
                throw new IllegalArgumentException('phone parameter is required for Company Record Type');
            }
            if (String.isBlank(addRequest.tradeLicenseNumber)) {
                throw new IllegalArgumentException('tradeLicenseNumber parameter is required for Company Record Type');
            }
        }
        
        // Verify the App_User__c exists and is active
        List<App_User__c> appUsers = [
            SELECT Id, Full_Name__c, Email__c, Status__c 
            FROM App_User__c 
            WHERE Id = :addRequest.appUserId 
            AND (Status__c != 'Inactive' OR Status__c = NULL)
            LIMIT 1
        ];
        
        if (appUsers.isEmpty()) {
            throw new IllegalArgumentException('App User not found or inactive');
        }
        
        // Create new Account based on record type
        Account newAccount = new Account();
        newAccount.RecordTypeId = recordTypeId;
        newAccount.App_User__c = addRequest.appUserId;
        
        if (recordTypeId == PERSON_ACCOUNT_RECORD_TYPE_ID) {
            // Parse the Name field to FirstName and LastName for Person Account
            String firstName = '';
            String lastName = '';
            
            if (addRequest.name.contains(' ')) {
                List<String> nameParts = addRequest.name.split(' ');
                firstName = nameParts[0];
                List<String> lastNameParts = new List<String>();
                for (Integer i = 1; i < nameParts.size(); i++) {
                    lastNameParts.add(nameParts[i]);
                }
                lastName = String.join(lastNameParts, ' ');
            } else {
                lastName = addRequest.name;
            }
            
            // Set Person Account specific fields
            newAccount.FirstName = firstName;
            newAccount.LastName = lastName;
            if (!String.isBlank(addRequest.salutation)) {
                newAccount.Salutation = addRequest.salutation;
            }
            newAccount.PersonEmail = addRequest.email;
            newAccount.Phone = addRequest.phone;
            newAccount.PersonMobilePhone = addRequest.phone;
            newAccount.Passport_No__pc = addRequest.passportNo;
            newAccount.Passport_No__c = addRequest.passportNo;
        } else if (recordTypeId == COMPANY_RECORD_TYPE_ID) {
            // Set Company Record Type specific fields for insert
            newAccount.Name = addRequest.name;
            newAccount.Company_Email__c = addRequest.companyEmail;
            newAccount.Phone = addRequest.phone;
            newAccount.Trade_License_Number__c = addRequest.tradeLicenseNumber;
            
            // Trade License dates for insert
            if (!String.isBlank(addRequest.tradeLicenseIssueDate)) {
                newAccount.Trade_License_Issue_Date__c = parseDate(addRequest.tradeLicenseIssueDate);
            }
            if (!String.isBlank(addRequest.tradeLicenseExpiryDate)) {
                newAccount.Trade_License_Expiry_Date__c = parseDate(addRequest.tradeLicenseExpiryDate);
            }
            
            // Additional Company Record Type fields for insert
            if (!String.isBlank(addRequest.taxRegistrationNumber)) {
                newAccount.Tax_Registration_Number__c = addRequest.taxRegistrationNumber;
            }
            if (!String.isBlank(addRequest.countryOfIncorporation)) {
                newAccount.Country_of_Incorporation__c = addRequest.countryOfIncorporation;
            }
            if (!String.isBlank(addRequest.cityOfIncorporation)) {
                newAccount.City_of_Incorporation__c = addRequest.cityOfIncorporation;
            }
            if (!String.isBlank(addRequest.dateOfIncorporation)) {
                newAccount.Date_of_Incorporation__c = parseDate(addRequest.dateOfIncorporation);
            }
            if (!String.isBlank(addRequest.status)) {
                newAccount.Status__c = addRequest.status;
            }
            
            // Billing Address fields for Company Record Type
            if (!String.isBlank(addRequest.billingStreet)) {
                newAccount.BillingStreet = addRequest.billingStreet;
            }
            if (!String.isBlank(addRequest.billingCity)) {
                newAccount.BillingCity = addRequest.billingCity;
            }
            if (!String.isBlank(addRequest.billingState)) {
                newAccount.BillingState = addRequest.billingState;
            }
            if (!String.isBlank(addRequest.billingPostalCode)) {
                newAccount.BillingPostalCode = addRequest.billingPostalCode;
            }
            if (!String.isBlank(addRequest.billingCountry)) {
                newAccount.BillingCountry = addRequest.billingCountry;
            }
            if (addRequest.residentOfUAE != null) {
                newAccount.Resident_of_UAE__c = addRequest.residentOfUAE;
            }
        }
        
        // Person Account specific fields only
        if (recordTypeId == PERSON_ACCOUNT_RECORD_TYPE_ID) {
            // Additional passport and ID fields
            if (!String.isBlank(addRequest.passportIssueDate)) {
                Date parsedDate = parseDate(addRequest.passportIssueDate);
                if (parsedDate != null) {
                    newAccount.Passport_Issue_Date__pc = parsedDate.format();
                }
            }
            if (!String.isBlank(addRequest.passportExpirationDate)) {
                newAccount.Passport_Expiration_Date__c = parseDate(addRequest.passportExpirationDate);
            }
            if (!String.isBlank(addRequest.nationality)) {
                newAccount.Nationality__pc = addRequest.nationality;
            }
            if (!String.isBlank(addRequest.countryOfResidence)) {
                newAccount.Country_of_Residence__c = addRequest.countryOfResidence;
            }
            if (!String.isBlank(addRequest.emiratesIdCardNumber)) {
                try {
                    newAccount.Emirates_ID_Card_Number__pc = Decimal.valueOf(addRequest.emiratesIdCardNumber);
                } catch (Exception e) {
                    System.debug('Error parsing Emirates ID Card Number: ' + addRequest.emiratesIdCardNumber);
                }
            }
            if (!String.isBlank(addRequest.emiratesIdNumber)) {
                newAccount.Emirates_ID_Number__pc = addRequest.emiratesIdNumber;
            }
            if (!String.isBlank(addRequest.emiratesIdExpiryDate)) {
                newAccount.Emirates_ID_Expiry_Date__pc = parseDate(addRequest.emiratesIdExpiryDate);
            }
            
            // Visa fields
            if (!String.isBlank(addRequest.visaNumber)) {
                newAccount.Visa_Number__pc = addRequest.visaNumber;
            }
            if (!String.isBlank(addRequest.visaPlaceIssue)) {
                newAccount.Visa_Place_Issue__pc = addRequest.visaPlaceIssue;
                //newAccount.Visa_Place_of_Issue__pc = addRequest.visaPlaceIssue; // Same value as requested
            }
            if (!String.isBlank(addRequest.visaDateOfIssue)) {
                newAccount.Visa_Date_of_Issue__pc = parseDate(addRequest.visaDateOfIssue);
            }
            if (!String.isBlank(addRequest.visaExpireDate)) {
                newAccount.Visa_Expire_Date__pc = parseDate(addRequest.visaExpireDate);
            }
            
            // Personal information
            if (!String.isBlank(addRequest.personBirthdate)) {
                newAccount.PersonBirthdate = parseDate(addRequest.personBirthdate);
            }
            if (!String.isBlank(addRequest.placeOfBirth)) {
                newAccount.Place_of_Birth__pc = addRequest.placeOfBirth;
            }
            if (!String.isBlank(addRequest.occupation)) {
                newAccount.Occupation__pc = addRequest.occupation;
            }
            if (!String.isBlank(addRequest.natureOfBusiness)) {
                newAccount.Nature_of_Business__pc = addRequest.natureOfBusiness;
            }
            if (!String.isBlank(addRequest.sourceOfFunds)) {
                newAccount.Source_of_Funds__pc = addRequest.sourceOfFunds;
            }
            
            // Compliance fields
            if (!String.isBlank(addRequest.complianceStatus)) {
                newAccount.Compliance_Status__c = addRequest.complianceStatus;
            }
            if (!String.isBlank(addRequest.politicallyExposed)) {
                newAccount.Politically_Exposed__pc = addRequest.politicallyExposed;
            }
            if (!String.isBlank(addRequest.politicallyExposedPersonText)) {
                newAccount.Politically_Exposed_Person_Text__pc = addRequest.politicallyExposedPersonText;
            }
            if (!String.isBlank(addRequest.subjectToSanction)) {
                newAccount.Subject_to_Sanction__pc = addRequest.subjectToSanction;
            }
            
            // Banking and payment
            if (!String.isBlank(addRequest.paymentMethods)) {
                newAccount.Payment_methods__pc = addRequest.paymentMethods;
            }
            if (!String.isBlank(addRequest.bankName)) {
                newAccount.Bank_Name__pc = addRequest.bankName;
            }
            if (!String.isBlank(addRequest.currencyOther)) {
                newAccount.Currency_Other__pc = addRequest.currencyOther;
            }
            
            // POA (Power of Attorney) fields
            if (!String.isBlank(addRequest.poaHolderName)) {
                newAccount.POA_Holder_Name__pc = addRequest.poaHolderName;
            }
            if (!String.isBlank(addRequest.poaHolderEmiratesIdNumber)) {
                newAccount.POA_Holder_Emirates_ID_Number__pc = addRequest.poaHolderEmiratesIdNumber;
            }
            if (!String.isBlank(addRequest.poaHolderPassportNumber)) {
                newAccount.POA_Holder_Passport_Number__pc = addRequest.poaHolderPassportNumber;
            }
            if (!String.isBlank(addRequest.poaHolderPassportExpiryDate)) {
                newAccount.POA_Holder_Passport_Expiry_Date__pc = parseDate(addRequest.poaHolderPassportExpiryDate);
            }
            
            // Billing Address fields for Person Account
            if (!String.isBlank(addRequest.billingStreet)) {
                newAccount.BillingStreet = addRequest.billingStreet;
            }
            if (!String.isBlank(addRequest.billingCity)) {
                newAccount.BillingCity = addRequest.billingCity;
            }
            if (!String.isBlank(addRequest.billingState)) {
                newAccount.BillingState = addRequest.billingState;
            }
            if (!String.isBlank(addRequest.billingPostalCode)) {
                newAccount.BillingPostalCode = addRequest.billingPostalCode;
            }
            if (!String.isBlank(addRequest.billingCountry)) {
                newAccount.BillingCountry = addRequest.billingCountry;
            }
            if (addRequest.residentOfUAE != null) {
                newAccount.Resident_of_UAE__c = addRequest.residentOfUAE;
            }
        }
        
        // Insert the account
        insert newAccount;
        
        // Query the created account to get all fields based on record type
        Account createdAccount;
        if (recordTypeId == PERSON_ACCOUNT_RECORD_TYPE_ID) {
            createdAccount = [
                SELECT Id, FirstName, LastName, Salutation, PersonEmail, Phone, PersonMobilePhone, Passport_No__pc, Passport_No__c, App_User__c, CreatedDate,
                       Passport_Issue_Date__pc, Passport_Expiration_Date__c, Nationality__pc, Country_of_Residence__c,
                       Emirates_ID_Card_Number__pc, Emirates_ID_Number__pc, Emirates_ID_Expiry_Date__pc,
                       Visa_Number__pc, Visa_Place_Issue__pc, Visa_Place_of_Issue__pc, Visa_Date_of_Issue__pc, Visa_Expire_Date__pc,
                       PersonBirthdate, Place_of_Birth__pc, Occupation__pc, Nature_of_Business__pc, Source_of_Funds__pc,
                       Compliance_Status__c, Politically_Exposed__pc, Politically_Exposed_Person_Text__pc, Subject_to_Sanction__pc,
                       Payment_methods__pc, Bank_Name__pc, Currency_Other__pc,
                       POA_Holder_Name__pc, POA_Holder_Emirates_ID_Number__pc, POA_Holder_Passport_Number__pc, POA_Holder_Passport_Expiry_Date__pc,
                       Status__c, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, Resident_of_UAE__c
                FROM Account 
                WHERE Id = :newAccount.Id
                LIMIT 1
            ];
        } else if (recordTypeId == COMPANY_RECORD_TYPE_ID) {
            createdAccount = [
                SELECT Id, Name, Company_Email__c, Phone, Trade_License_Number__c, App_User__c, CreatedDate,
                       Trade_License_Issue_Date__c, Trade_License_Expiry_Date__c, Tax_Registration_Number__c,
                       Country_of_Incorporation__c, City_of_Incorporation__c, Date_of_Incorporation__c,
                       Status__c, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, Resident_of_UAE__c
                FROM Account 
                WHERE Id = :newAccount.Id
                LIMIT 1
            ];
        }
        
        // Send success response
        sendAccountResponse(response, createdAccount, 'Account created successfully', 201, recordTypeId);
    }
    
    /**
     * Handle update operation for existing accounts
     */
    private static void handleUpdateOperation(AddAccountRequest addRequest, String recordId, RestResponse response, String httpMethod) {
        // Validate record ID
        if (String.isBlank(recordId)) {
            throw new IllegalArgumentException('id parameter is required for update operations');
        }
        
        // First, determine the record type of the existing account
        List<Account> accountRecordTypeCheck = [
            SELECT Id, RecordTypeId 
            FROM Account 
            WHERE Id = :recordId 
            LIMIT 1
        ];
        
        if (accountRecordTypeCheck.isEmpty()) {
            throw new IllegalArgumentException('Account not found');
        }
        
        String existingRecordTypeId = accountRecordTypeCheck[0].RecordTypeId;
        
        // Validate record type
        if (existingRecordTypeId != PERSON_ACCOUNT_RECORD_TYPE_ID && existingRecordTypeId != COMPANY_RECORD_TYPE_ID) {
            throw new IllegalArgumentException('Account record type not supported for updates');
        }
        
        // Query existing account based on record type
        List<Account> existingAccounts;
        if (existingRecordTypeId == PERSON_ACCOUNT_RECORD_TYPE_ID) {
            existingAccounts = [
                SELECT Id, FirstName, LastName, Salutation, PersonEmail, Phone, PersonMobilePhone, Passport_No__pc, Passport_No__c, App_User__c, LastModifiedDate,
                       Passport_Issue_Date__pc, Passport_Expiration_Date__c, Nationality__pc, Country_of_Residence__c,
                       Emirates_ID_Card_Number__pc, Emirates_ID_Number__pc, Emirates_ID_Expiry_Date__pc,
                       Visa_Number__pc, Visa_Place_Issue__pc, Visa_Place_of_Issue__pc, Visa_Date_of_Issue__pc, Visa_Expire_Date__pc,
                       PersonBirthdate, Place_of_Birth__pc, Occupation__pc, Nature_of_Business__pc, Source_of_Funds__pc,
                       Compliance_Status__c, Politically_Exposed__pc, Politically_Exposed_Person_Text__pc, Subject_to_Sanction__pc,
                       Payment_methods__pc, Bank_Name__pc, Currency_Other__pc,
                       POA_Holder_Name__pc, POA_Holder_Emirates_ID_Number__pc, POA_Holder_Passport_Number__pc, POA_Holder_Passport_Expiry_Date__pc,
                       Status__c, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, Resident_of_UAE__c
                FROM Account 
                WHERE Id = :recordId
                LIMIT 1
            ];
        } else if (existingRecordTypeId == COMPANY_RECORD_TYPE_ID) {
            existingAccounts = [
                SELECT Id, Name, Company_Email__c, Phone, Trade_License_Number__c, App_User__c, LastModifiedDate,
                       Trade_License_Issue_Date__c, Trade_License_Expiry_Date__c, Tax_Registration_Number__c,
                       Country_of_Incorporation__c, City_of_Incorporation__c, Date_of_Incorporation__c,
                       Status__c, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, Resident_of_UAE__c
                FROM Account 
                WHERE Id = :recordId
                LIMIT 1
            ];
        }
        
        if (existingAccounts.isEmpty()) {
            throw new IllegalArgumentException('Account not found');
        }
        
        Account accountToUpdate = existingAccounts[0];
        
        // Update fields based on record type (PATCH allows partial updates)
        if (existingRecordTypeId == PERSON_ACCOUNT_RECORD_TYPE_ID) {
            // Person Account specific field updates
            if (!String.isBlank(addRequest.name)) {
                // Parse the Name field to FirstName and LastName
                if (addRequest.name.contains(' ')) {
                    List<String> nameParts = addRequest.name.split(' ');
                    accountToUpdate.FirstName = nameParts[0];
                    List<String> lastNameParts = new List<String>();
                    for (Integer i = 1; i < nameParts.size(); i++) {
                        lastNameParts.add(nameParts[i]);
                    }
                    accountToUpdate.LastName = String.join(lastNameParts, ' ');
                } else {
                    accountToUpdate.FirstName = '';
                    accountToUpdate.LastName = addRequest.name;
                }
            }
            
            if (!String.isBlank(addRequest.salutation)) {
                accountToUpdate.Salutation = addRequest.salutation;
            }
            
            if (!String.isBlank(addRequest.email)) {
                accountToUpdate.PersonEmail = addRequest.email;
            }
            
            if (!String.isBlank(addRequest.phone)) {
                accountToUpdate.Phone = addRequest.phone;
                accountToUpdate.PersonMobilePhone = addRequest.phone;
            }
            
            if (!String.isBlank(addRequest.passportNo)) {
                accountToUpdate.Passport_No__pc = addRequest.passportNo;
                accountToUpdate.Passport_No__c = addRequest.passportNo;
            }
            
            // Additional passport and ID fields for Person Account
            if (!String.isBlank(addRequest.passportIssueDate)) {
                Date parsedDate = parseDate(addRequest.passportIssueDate);
                if (parsedDate != null) {
                    accountToUpdate.Passport_Issue_Date__pc = parsedDate.format();
                }
            }
            if (!String.isBlank(addRequest.passportExpirationDate)) {
                accountToUpdate.Passport_Expiration_Date__c = parseDate(addRequest.passportExpirationDate);
            }
            if (!String.isBlank(addRequest.nationality)) {
                accountToUpdate.Nationality__pc = addRequest.nationality;
            }
            if (!String.isBlank(addRequest.countryOfResidence)) {
                accountToUpdate.Country_of_Residence__c = addRequest.countryOfResidence;
            }
            if (!String.isBlank(addRequest.emiratesIdCardNumber)) {
                try {
                    accountToUpdate.Emirates_ID_Card_Number__pc = Decimal.valueOf(addRequest.emiratesIdCardNumber);
                } catch (Exception e) {
                    System.debug('Error parsing Emirates ID Card Number: ' + addRequest.emiratesIdCardNumber);
                }
            }
            if (!String.isBlank(addRequest.emiratesIdNumber)) {
                accountToUpdate.Emirates_ID_Number__pc = addRequest.emiratesIdNumber;
            }
            if (!String.isBlank(addRequest.emiratesIdExpiryDate)) {
                accountToUpdate.Emirates_ID_Expiry_Date__pc = parseDate(addRequest.emiratesIdExpiryDate);
            }
            
            // Visa fields for Person Account
            if (!String.isBlank(addRequest.visaNumber)) {
                accountToUpdate.Visa_Number__pc = addRequest.visaNumber;
            }
            if (!String.isBlank(addRequest.visaPlaceIssue)) {
                accountToUpdate.Visa_Place_Issue__pc = addRequest.visaPlaceIssue;
            }
            if (!String.isBlank(addRequest.visaDateOfIssue)) {
                accountToUpdate.Visa_Date_of_Issue__pc = parseDate(addRequest.visaDateOfIssue);
            }
            if (!String.isBlank(addRequest.visaExpireDate)) {
                accountToUpdate.Visa_Expire_Date__pc = parseDate(addRequest.visaExpireDate);
            }
            
            // Personal information for Person Account
            if (!String.isBlank(addRequest.personBirthdate)) {
                accountToUpdate.PersonBirthdate = parseDate(addRequest.personBirthdate);
            }
            if (!String.isBlank(addRequest.placeOfBirth)) {
                accountToUpdate.Place_of_Birth__pc = addRequest.placeOfBirth;
            }
            if (!String.isBlank(addRequest.occupation)) {
                accountToUpdate.Occupation__pc = addRequest.occupation;
            }
            if (!String.isBlank(addRequest.natureOfBusiness)) {
                accountToUpdate.Nature_of_Business__pc = addRequest.natureOfBusiness;
            }
            if (!String.isBlank(addRequest.sourceOfFunds)) {
                accountToUpdate.Source_of_Funds__pc = addRequest.sourceOfFunds;
            }
            
            // Compliance fields for Person Account
            if (!String.isBlank(addRequest.complianceStatus)) {
                accountToUpdate.Compliance_Status__c = addRequest.complianceStatus;
            }
            if (!String.isBlank(addRequest.politicallyExposed)) {
                accountToUpdate.Politically_Exposed__pc = addRequest.politicallyExposed;
            }
            if (!String.isBlank(addRequest.politicallyExposedPersonText)) {
                accountToUpdate.Politically_Exposed_Person_Text__pc = addRequest.politicallyExposedPersonText;
            }
            if (!String.isBlank(addRequest.subjectToSanction)) {
                accountToUpdate.Subject_to_Sanction__pc = addRequest.subjectToSanction;
            }
            
            // Banking and payment for Person Account
            if (!String.isBlank(addRequest.paymentMethods)) {
                accountToUpdate.Payment_methods__pc = addRequest.paymentMethods;
            }
            if (!String.isBlank(addRequest.bankName)) {
                accountToUpdate.Bank_Name__pc = addRequest.bankName;
            }
            if (!String.isBlank(addRequest.currencyOther)) {
                accountToUpdate.Currency_Other__pc = addRequest.currencyOther;
            }
            
            // POA fields for Person Account
            if (!String.isBlank(addRequest.poaHolderName)) {
                accountToUpdate.POA_Holder_Name__pc = addRequest.poaHolderName;
            }
            if (!String.isBlank(addRequest.poaHolderEmiratesIdNumber)) {
                accountToUpdate.POA_Holder_Emirates_ID_Number__pc = addRequest.poaHolderEmiratesIdNumber;
            }
            if (!String.isBlank(addRequest.poaHolderPassportNumber)) {
                accountToUpdate.POA_Holder_Passport_Number__pc = addRequest.poaHolderPassportNumber;
            }
            if (!String.isBlank(addRequest.poaHolderPassportExpiryDate)) {
                accountToUpdate.POA_Holder_Passport_Expiry_Date__pc = parseDate(addRequest.poaHolderPassportExpiryDate);
            }
            
            // Status field for Person Account
            if (!String.isBlank(addRequest.status)) {
                accountToUpdate.Status__c = addRequest.status;
            }
            
            // Billing Address fields for Person Account
            if (!String.isBlank(addRequest.billingStreet)) {
                accountToUpdate.BillingStreet = addRequest.billingStreet;
            }
            if (!String.isBlank(addRequest.billingCity)) {
                accountToUpdate.BillingCity = addRequest.billingCity;
            }
            if (!String.isBlank(addRequest.billingState)) {
                accountToUpdate.BillingState = addRequest.billingState;
            }
            if (!String.isBlank(addRequest.billingPostalCode)) {
                accountToUpdate.BillingPostalCode = addRequest.billingPostalCode;
            }
            if (!String.isBlank(addRequest.billingCountry)) {
                accountToUpdate.BillingCountry = addRequest.billingCountry;
            }
            if (addRequest.residentOfUAE != null) {
                accountToUpdate.Resident_of_UAE__c = addRequest.residentOfUAE;
            }
        } else if (existingRecordTypeId == COMPANY_RECORD_TYPE_ID) {
            // Company Record Type specific field updates
            if (!String.isBlank(addRequest.name)) {
                accountToUpdate.Name = addRequest.name;
            }
            
            if (!String.isBlank(addRequest.companyEmail)) {
                accountToUpdate.Company_Email__c = addRequest.companyEmail;
            }
            
            if (!String.isBlank(addRequest.phone)) {
                accountToUpdate.Phone = addRequest.phone;
            }
            
            if (!String.isBlank(addRequest.tradeLicenseNumber)) {
                accountToUpdate.Trade_License_Number__c = addRequest.tradeLicenseNumber;
            }
            
            // Company Record Type additional fields for edit
            if (!String.isBlank(addRequest.tradeLicenseIssueDate)) {
                accountToUpdate.Trade_License_Issue_Date__c = parseDate(addRequest.tradeLicenseIssueDate);
            }
            if (!String.isBlank(addRequest.tradeLicenseExpiryDate)) {
                accountToUpdate.Trade_License_Expiry_Date__c = parseDate(addRequest.tradeLicenseExpiryDate);
            }
            if (!String.isBlank(addRequest.taxRegistrationNumber)) {
                accountToUpdate.Tax_Registration_Number__c = addRequest.taxRegistrationNumber;
            }
            if (!String.isBlank(addRequest.countryOfIncorporation)) {
                accountToUpdate.Country_of_Incorporation__c = addRequest.countryOfIncorporation;
            }
            if (!String.isBlank(addRequest.cityOfIncorporation)) {
                accountToUpdate.City_of_Incorporation__c = addRequest.cityOfIncorporation;
            }
            if (!String.isBlank(addRequest.dateOfIncorporation)) {
                accountToUpdate.Date_of_Incorporation__c = parseDate(addRequest.dateOfIncorporation);
            }
            
            if (!String.isBlank(addRequest.status)) {
                accountToUpdate.Status__c = addRequest.status;
            }
            
            // Billing Address fields for Company Record Type edit
            if (!String.isBlank(addRequest.billingStreet)) {
                accountToUpdate.BillingStreet = addRequest.billingStreet;
            }
            if (!String.isBlank(addRequest.billingCity)) {
                accountToUpdate.BillingCity = addRequest.billingCity;
            }
            if (!String.isBlank(addRequest.billingState)) {
                accountToUpdate.BillingState = addRequest.billingState;
            }
            if (!String.isBlank(addRequest.billingPostalCode)) {
                accountToUpdate.BillingPostalCode = addRequest.billingPostalCode;
            }
            if (!String.isBlank(addRequest.billingCountry)) {
                accountToUpdate.BillingCountry = addRequest.billingCountry;
            }
        }
        
        // Common fields for both record types
        if (!String.isBlank(addRequest.appUserId)) {
            // Verify the App_User__c exists and is active
            List<App_User__c> appUsers = [
                SELECT Id, Full_Name__c, Email__c, Status__c 
                FROM App_User__c 
                WHERE Id = :addRequest.appUserId 
                AND (Status__c != 'Inactive' OR Status__c = NULL)
                LIMIT 1
            ];
            
            if (appUsers.isEmpty()) {
                throw new IllegalArgumentException('App User not found or inactive');
            }
            
            accountToUpdate.App_User__c = addRequest.appUserId;
        }
        
        // Update the account
        update accountToUpdate;
        
        // Create Contact for Company Record Type during edit operation
        if (existingRecordTypeId == COMPANY_RECORD_TYPE_ID && !String.isBlank(addRequest.contactName)) {
            Contact newContact = new Contact();
            newContact.AccountId = accountToUpdate.Id;
            
            if (!String.isBlank(addRequest.contactSalutation)) {
                newContact.Salutation = addRequest.contactSalutation;
            }
            // Parse contact name into FirstName and LastName since Name field is read-only
            if (!String.isBlank(addRequest.contactName)) {
                if (addRequest.contactName.contains(' ')) {
                    List<String> nameParts = addRequest.contactName.split(' ');
                    newContact.FirstName = nameParts[0];
                    List<String> lastNameParts = new List<String>();
                    for (Integer i = 1; i < nameParts.size(); i++) {
                        lastNameParts.add(nameParts[i]);
                    }
                    newContact.LastName = String.join(lastNameParts, ' ');
                } else {
                    newContact.LastName = addRequest.contactName;
                }
            }
            if (!String.isBlank(addRequest.contactTitle)) {
                newContact.Title = addRequest.contactTitle;
            }
            if (!String.isBlank(addRequest.contactEmail)) {
                newContact.Email = addRequest.contactEmail;
            }
            if (!String.isBlank(addRequest.contactPhone)) {
                newContact.Phone = addRequest.contactPhone;
                newContact.MobilePhone = addRequest.contactPhone; // Same as Phone as requested
            }
            
            // Company specific Contact fields
            if (!String.isBlank(addRequest.companyShare)) {
                try {
                    newContact.Company_Share__c = Decimal.valueOf(addRequest.companyShare);
                } catch (Exception e) {
                    System.debug('Error parsing Company Share: ' + addRequest.companyShare);
                }
            }
            if (!String.isBlank(addRequest.contactPassportNo)) {
                newContact.Passport_No__c = addRequest.contactPassportNo;
            }
            if (!String.isBlank(addRequest.positionInCompany)) {
                newContact.Position_in_Company__c = addRequest.positionInCompany;
            }
            if (!String.isBlank(addRequest.contactNationality)) {
                newContact.Nationality__c = addRequest.contactNationality;
            }
            newContact.Primary__c = true; // Always true as requested
            
            // Additional Contact fields
            if (!String.isBlank(addRequest.contactBirthDate)) {
                newContact.Birth_Date__c = parseDate(addRequest.contactBirthDate);
            }
            if (!String.isBlank(addRequest.contactPlaceOfBirth)) {
                newContact.Place_of_Birth__c = addRequest.contactPlaceOfBirth;
            }
            if (!String.isBlank(addRequest.contactOccupation)) {
                newContact.Occupation__c = addRequest.contactOccupation;
            }
            if (!String.isBlank(addRequest.contactNatureOfBusiness)) {
                newContact.Nature_of_Business__c = addRequest.contactNatureOfBusiness;
            }
            if (!String.isBlank(addRequest.contactSourceOfFunds)) {
                newContact.Source_of_Funds__c = addRequest.contactSourceOfFunds;
            }
            if (!String.isBlank(addRequest.contactPoliticallyExposed)) {
                newContact.Politically_Exposed__c = addRequest.contactPoliticallyExposed;
            }
            if (!String.isBlank(addRequest.contactSubjectToSanction)) {
                newContact.Subject_to_Sanction__c = addRequest.contactSubjectToSanction;
            }
            if (!String.isBlank(addRequest.contactPaymentMethods)) {
                newContact.Payment_methods__c = addRequest.contactPaymentMethods;
            }
            if (!String.isBlank(addRequest.contactBankName)) {
                newContact.Bank_Name__c = addRequest.contactBankName;
            }
            if (!String.isBlank(addRequest.contactVisaNumber)) {
                newContact.Visa_Number__c = addRequest.contactVisaNumber;
            }
            if (!String.isBlank(addRequest.contactVisaPlaceOfIssue)) {
                newContact.Visa_Place_of_Issue__c = addRequest.contactVisaPlaceOfIssue;
            }
            if (!String.isBlank(addRequest.contactVisaDateOfIssue)) {
                newContact.Visa_Date_of_Issue__c = parseDate(addRequest.contactVisaDateOfIssue);
            }
            if (!String.isBlank(addRequest.contactVisaExpireDate)) {
                newContact.Visa_Expire_Date__c = parseDate(addRequest.contactVisaExpireDate);
            }
            if (!String.isBlank(addRequest.contactEmiratesIdNumber)) {
                newContact.Emirates_ID_Number__c = addRequest.contactEmiratesIdNumber;
            }
            if (!String.isBlank(addRequest.contactEmiratesIdCardNumber)) {
                try {
                    newContact.Emirates_ID_Card_Number__c = Decimal.valueOf(addRequest.contactEmiratesIdCardNumber);
                } catch (Exception e) {
                    System.debug('Error parsing Contact Emirates ID Card Number: ' + addRequest.contactEmiratesIdCardNumber);
                }
            }
            if (!String.isBlank(addRequest.contactEmiratesIdExpiryDate)) {
                newContact.Emirates_ID_Expiry_Date__c = parseDate(addRequest.contactEmiratesIdExpiryDate);
            }
            if (!String.isBlank(addRequest.contactPoaHolderName)) {
                newContact.POA_Holder_Name__c = addRequest.contactPoaHolderName;
            }
            if (!String.isBlank(addRequest.contactPoaHolderEmiratesIdNumber)) {
                newContact.POA_Holder_Emirates_ID_Number__c = addRequest.contactPoaHolderEmiratesIdNumber;
            }
            if (!String.isBlank(addRequest.contactPoaHolderPassportNumber)) {
                newContact.POA_Holder_Passport_Number__c = addRequest.contactPoaHolderPassportNumber;
            }
            if (!String.isBlank(addRequest.contactPoaHolderPassportExpiryDate)) {
                newContact.POA_Holder_Passport_Expiry_Date__c = parseDate(addRequest.contactPoaHolderPassportExpiryDate);
            }
            
            insert newContact;
        }
        
        // Query the updated account to get all fields based on record type
        Account updatedAccount;
        if (existingRecordTypeId == PERSON_ACCOUNT_RECORD_TYPE_ID) {
            updatedAccount = [
                SELECT Id, FirstName, LastName, Salutation, PersonEmail, Phone, PersonMobilePhone, Passport_No__pc, Passport_No__c, App_User__c, LastModifiedDate,
                       Passport_Issue_Date__pc, Passport_Expiration_Date__c, Nationality__pc, Country_of_Residence__c,
                       Emirates_ID_Card_Number__pc, Emirates_ID_Number__pc, Emirates_ID_Expiry_Date__pc,
                       Visa_Number__pc, Visa_Place_Issue__pc, Visa_Place_of_Issue__pc, Visa_Date_of_Issue__pc, Visa_Expire_Date__pc,
                       PersonBirthdate, Place_of_Birth__pc, Occupation__pc, Nature_of_Business__pc, Source_of_Funds__pc,
                       Compliance_Status__c, Politically_Exposed__pc, Politically_Exposed_Person_Text__pc, Subject_to_Sanction__pc,
                       Payment_methods__pc, Bank_Name__pc, Currency_Other__pc,
                       POA_Holder_Name__pc, POA_Holder_Emirates_ID_Number__pc, POA_Holder_Passport_Number__pc, POA_Holder_Passport_Expiry_Date__pc,
                       Status__c, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, Resident_of_UAE__c
                FROM Account 
                WHERE Id = :accountToUpdate.Id
                LIMIT 1
            ];
        } else if (existingRecordTypeId == COMPANY_RECORD_TYPE_ID) {
            updatedAccount = [
                SELECT Id, Name, Company_Email__c, Phone, Trade_License_Number__c, App_User__c, LastModifiedDate,
                       Trade_License_Issue_Date__c, Trade_License_Expiry_Date__c, Tax_Registration_Number__c,
                       Country_of_Incorporation__c, City_of_Incorporation__c, Date_of_Incorporation__c,
                       Status__c, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, Resident_of_UAE__c
                FROM Account 
                WHERE Id = :accountToUpdate.Id
                LIMIT 1
            ];
        }
        
        // Send success response
        sendAccountResponse(response, updatedAccount, 'Account updated successfully', 200, existingRecordTypeId);
    }
    
    /**
     * Helper method to send account response
     */
    private static void sendAccountResponse(RestResponse response, Account account, String message, Integer statusCode, String recordTypeId) {
        Map<String, Object> accountData = new Map<String, Object>();
        accountData.put('Id', account.Id);
        accountData.put('App_User__c', account.App_User__c);
        accountData.put('RecordTypeId', recordTypeId);
        
        if (recordTypeId == PERSON_ACCOUNT_RECORD_TYPE_ID) {
            // Person Account response format
            String fullName = (account.FirstName != null ? account.FirstName + ' ' : '') + 
                            (account.LastName != null ? account.LastName : '');
            
            accountData.put('Name', fullName.trim());
            accountData.put('Salutation', account.Salutation);
            accountData.put('Email', account.PersonEmail);
            accountData.put('Phone', account.Phone);
            accountData.put('PersonMobilePhone', account.PersonMobilePhone);
            accountData.put('PassportNo', account.Passport_No__pc);
            
            // Additional passport and ID fields for Person Account
            accountData.put('PassportIssueDate', account.Passport_Issue_Date__pc);
            accountData.put('PassportExpirationDate', account.Passport_Expiration_Date__c);
            accountData.put('Nationality', account.Nationality__pc);
            accountData.put('CountryOfResidence', account.Country_of_Residence__c);
            accountData.put('EmiratesIdCardNumber', account.Emirates_ID_Card_Number__pc);
            accountData.put('EmiratesIdNumber', account.Emirates_ID_Number__pc);
            accountData.put('EmiratesIdExpiryDate', account.Emirates_ID_Expiry_Date__pc);
            
            // Visa fields for Person Account
            accountData.put('VisaNumber', account.Visa_Number__pc);
            accountData.put('VisaPlaceIssue', account.Visa_Place_Issue__pc);
            accountData.put('VisaDateOfIssue', account.Visa_Date_of_Issue__pc);
            accountData.put('VisaExpireDate', account.Visa_Expire_Date__pc);
            
            // Personal information for Person Account
            accountData.put('PersonBirthdate', account.PersonBirthdate);
            accountData.put('PlaceOfBirth', account.Place_of_Birth__pc);
            accountData.put('Occupation', account.Occupation__pc);
            accountData.put('NatureOfBusiness', account.Nature_of_Business__pc);
            accountData.put('SourceOfFunds', account.Source_of_Funds__pc);
            
            // Compliance fields for Person Account
            accountData.put('ComplianceStatus', account.Compliance_Status__c);
            accountData.put('PoliticallyExposed', account.Politically_Exposed__pc);
            accountData.put('PoliticallyExposedPersonText', account.Politically_Exposed_Person_Text__pc);
            accountData.put('SubjectToSanction', account.Subject_to_Sanction__pc);
            
            // Banking and payment for Person Account
            accountData.put('PaymentMethods', account.Payment_methods__pc);
            accountData.put('BankName', account.Bank_Name__pc);
            accountData.put('CurrencyOther', account.Currency_Other__pc);
            
            // POA (Power of Attorney) fields for Person Account
            accountData.put('PoaHolderName', account.POA_Holder_Name__pc);
            accountData.put('PoaHolderEmiratesIdNumber', account.POA_Holder_Emirates_ID_Number__pc);
            accountData.put('PoaHolderPassportNumber', account.POA_Holder_Passport_Number__pc);
            accountData.put('PoaHolderPassportExpiryDate', account.POA_Holder_Passport_Expiry_Date__pc);
            
            // Status field for Person Account
            accountData.put('Status', account.Status__c);
            
            // Billing Address fields for Person Account
            accountData.put('BillingStreet', account.BillingStreet);
            accountData.put('BillingCity', account.BillingCity);
            accountData.put('BillingState', account.BillingState);
            accountData.put('BillingPostalCode', account.BillingPostalCode);
            accountData.put('BillingCountry', account.BillingCountry);
        } else if (recordTypeId == COMPANY_RECORD_TYPE_ID) {
            // Company Record Type response format
            accountData.put('Name', account.Name);
            accountData.put('CompanyEmail', account.Company_Email__c);
            accountData.put('Phone', account.Phone);
            accountData.put('TradeLicenseNumber', account.Trade_License_Number__c);
            accountData.put('TradeLicenseIssueDate', account.Trade_License_Issue_Date__c);
            accountData.put('TradeLicenseExpiryDate', account.Trade_License_Expiry_Date__c);
            accountData.put('TaxRegistrationNumber', account.Tax_Registration_Number__c);
            accountData.put('CountryOfIncorporation', account.Country_of_Incorporation__c);
            accountData.put('CityOfIncorporation', account.City_of_Incorporation__c);
            accountData.put('DateOfIncorporation', account.Date_of_Incorporation__c);
            accountData.put('Status', account.Status__c);
            
            // Billing Address fields for Company Record Type
            accountData.put('BillingStreet', account.BillingStreet);
            accountData.put('BillingCity', account.BillingCity);
            accountData.put('BillingState', account.BillingState);
            accountData.put('BillingPostalCode', account.BillingPostalCode);
            accountData.put('BillingCountry', account.BillingCountry);
        }
        
        // Common fields for both record types
        accountData.put('ResidentOfUAE', account.Resident_of_UAE__c);
        
        if (statusCode == 201) {
            accountData.put('CreatedAt', account.get('CreatedDate'));
        } else {
            accountData.put('LastModifiedAt', account.get('LastModifiedDate'));
        }
        
        response.statusCode = statusCode;
        Map<String, Object> successResponse = new Map<String, Object>();
        successResponse.put('success', true);
        successResponse.put('message', message);
        successResponse.put('account', accountData);
        response.responseBody = Blob.valueOf(JSON.serialize(successResponse));
    }
    
    // Request/Response Classes
    global class AddAccountRequest {
        global String recordTypeId { get; set; }
        global String name { get; set; }
        global String salutation { get; set; }
        global String email { get; set; }
        global String phone { get; set; }
        global String passportNo { get; set; }
        global String appUserId { get; set; }
        
        // Additional passport and ID fields
        global String passportIssueDate { get; set; }
        global String passportExpirationDate { get; set; }
        global String nationality { get; set; }
        global String countryOfResidence { get; set; }
        global String emiratesIdCardNumber { get; set; }
        global String emiratesIdNumber { get; set; }
        global String emiratesIdExpiryDate { get; set; }
        
        // Visa fields
        global String visaNumber { get; set; }
        global String visaPlaceIssue { get; set; }
        global String visaDateOfIssue { get; set; }
        global String visaExpireDate { get; set; }
        
        // Personal information
        global String personBirthdate { get; set; }
        global String placeOfBirth { get; set; }
        global String occupation { get; set; }
        global String natureOfBusiness { get; set; }
        global String sourceOfFunds { get; set; }
        
        // Compliance fields
        global String complianceStatus { get; set; }
        global String politicallyExposed { get; set; }
        global String politicallyExposedPersonText { get; set; }
        global String subjectToSanction { get; set; }
        
        // Banking and payment
        global String paymentMethods { get; set; }
        global String bankName { get; set; }
        global String currencyOther { get; set; }
        
        // POA (Power of Attorney) fields
        global String poaHolderName { get; set; }
        global String poaHolderEmiratesIdNumber { get; set; }
        global String poaHolderPassportNumber { get; set; }
        global String poaHolderPassportExpiryDate { get; set; }
        
        // Billing Address fields
        global String billingStreet { get; set; }
        global String billingCity { get; set; }
        global String billingState { get; set; }
        global String billingPostalCode { get; set; }
        global String billingCountry { get; set; }
        
        // Additional fields
        global Boolean residentOfUAE { get; set; }
        
        // Company Record Type specific fields for insert
        global String companyEmail { get; set; }
        global String tradeLicenseNumber { get; set; }
        
        // Company Record Type additional fields for edit
        global String tradeLicenseIssueDate { get; set; }
        global String tradeLicenseExpiryDate { get; set; }
        global String taxRegistrationNumber { get; set; }
        global String countryOfIncorporation { get; set; }
        global String cityOfIncorporation { get; set; }
        global String dateOfIncorporation { get; set; }
        global String status { get; set; }
        
        // Contact fields for Company Record Type
        global String contactSalutation { get; set; }
        global String contactName { get; set; }
        global String contactTitle { get; set; }
        global String contactEmail { get; set; }
        global String contactPhone { get; set; }
        global String contactMobilePhone { get; set; }
        global String companyShare { get; set; }
        global String contactPassportNo { get; set; }
        global String positionInCompany { get; set; }
        global String contactNationality { get; set; }
        global String contactBirthDate { get; set; }
        global String contactPlaceOfBirth { get; set; }
        global String contactOccupation { get; set; }
        global String contactNatureOfBusiness { get; set; }
        global String contactSourceOfFunds { get; set; }
        global String contactPoliticallyExposed { get; set; }
        global String contactSubjectToSanction { get; set; }
        global String contactPaymentMethods { get; set; }
        global String contactBankName { get; set; }
        global String contactVisaNumber { get; set; }
        global String contactVisaPlaceOfIssue { get; set; }
        global String contactVisaDateOfIssue { get; set; }
        global String contactVisaExpireDate { get; set; }
        global String contactEmiratesIdNumber { get; set; }
        global String contactEmiratesIdCardNumber { get; set; }
        global String contactEmiratesIdExpiryDate { get; set; }
        global String contactPoaHolderName { get; set; }
        global String contactPoaHolderEmiratesIdNumber { get; set; }
        global String contactPoaHolderPassportNumber { get; set; }
        global String contactPoaHolderPassportExpiryDate { get; set; }
    }
    
    global class AddAccountResponse {
        global Boolean success { get; set; }
        global String message { get; set; }
        global Map<String, Object> account { get; set; }
        
        global AddAccountResponse(Boolean success, String message, Map<String, Object> account) {
            this.success = success;
            this.message = message;
            this.account = account;
        }
    }
}