public without sharing class WazzupChatAgencyController {
    public String iframeUrl { get; set; }
    private static final String WAZZUP_API_ENDPOINT = 'https://api.wazzup24.com/v3/iframe';
    // Add predefined Wazzup user ID and name
    private static final String WAZZUP_USER_ID = '1234'; // Replace with your actual Wazzup user ID
    private static final String WAZZUP_USER_NAME = 'Mira Agent'; // Replace with your actual Wazzup user name

    public WazzupChatAgencyController() {
        try {
            iframeUrl = fetchWazzupIframe();
        } catch(Exception e) {
            iframeUrl = 'Error: ' + e.getMessage();
        }
    }

    public String formatPhoneNumber(String phoneNumber) {
        if (String.isBlank(phoneNumber)) return '';
    
        // Remove all non-numeric characters
        String cleanNumber = phoneNumber.replaceAll('[^0-9]', '');
    
        // Remove leading '00' or '0' **ONLY if more than 10 digits remain**
        if (cleanNumber.startsWith('00') && cleanNumber.length() > 10) {
            cleanNumber = cleanNumber.substring(2);
        } else if (cleanNumber.startsWith('0') && cleanNumber.length() > 10) {
            cleanNumber = cleanNumber.substring(1);
        }
    
        System.debug('🔍 Final Formatted Phone Number: ' + cleanNumber);
        
        return cleanNumber;
    }

    private String fetchWazzupIframe() {
        // Get the Agency RM ID from the page parameters
        String agencyRMId = ApexPages.currentPage().getParameters().get('id');

        if (String.isBlank(agencyRMId)) {
            agencyRMId = ApexPages.currentPage().getParameters().get('agencyRMId');
        }

        if (String.isBlank(agencyRMId)) {
            return 'Error: Agency RM ID is required. Please make sure you are accessing this page from an Agency RM record.';
        }

        // Query the Agency_Rm__c record with Owner details
        Agency_Rm__c agencyRecord;
        try {
            agencyRecord = [SELECT Id, Name, Agency_Phone__c, OwnerId, Owner.Name, Owner.Profile.Name, Owner.IsActive 
                           FROM Agency_Rm__c 
                           WHERE Id = :agencyRMId LIMIT 1];
            
            // Debug information
            System.debug('Agency Record Owner Details:');
            System.debug('Owner ID: ' + agencyRecord.OwnerId);
            System.debug('Owner Name: ' + agencyRecord.Owner.Name);
            System.debug('Owner Profile: ' + agencyRecord.Owner.Profile.Name);
            System.debug('Owner Is Active: ' + agencyRecord.Owner.IsActive);
            
        } catch (Exception e) {
            return 'Error: Unable to find Agency RM record: ' + e.getMessage();
        }

        // Get WhatsApp number from Agency_Phone__c
        String whatsappChatId = agencyRecord.Agency_Phone__c;
        if (String.isBlank(whatsappChatId)) {
            return 'Error: WhatsApp number not found. Please update the Agency RM\'s Phone number.';
        }

        // Format the phone number correctly
        whatsappChatId = formatPhoneNumber(whatsappChatId);
        System.debug('Formatted WhatsApp ID: ' + whatsappChatId);

        if (whatsappChatId.length() < 10) {
            return 'Error: Invalid phone number format. Please ensure the phone number is complete.';
        }

        // Get owner details for Wazzup authentication
        String wazzupUserId = agencyRecord.OwnerId;
        String wazzupUserName = agencyRecord.Owner.Name;

        // Prepare HTTP request
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(WAZZUP_API_ENDPOINT);
        request.setMethod('POST');

        String apiKey = 'b0e67577a2764f0ba75324f79e6581af';
        request.setHeader('Authorization', 'Bearer ' + apiKey);
        request.setHeader('Content-Type', 'application/json');

        // Construct JSON request body
        Map<String, Object> requestBody = new Map<String, Object>{
            'user' => new Map<String, String>{
                'id' => wazzupUserId,
                'name' => wazzupUserName
            },
            'scope' => 'card',
            'filter' => new List<Map<String, String>>{
                new Map<String, String>{
                    'chatType' => 'whatsapp',
                    'chatId' => whatsappChatId
                }
            },
            'activeChat' => new Map<String, String>{
                'chatType' => 'whatsapp',
                'chatId' => whatsappChatId
            }
        };

        String jsonBody = JSON.serialize(requestBody);
        request.setBody(jsonBody);
        System.debug('Request Body: ' + jsonBody);

        // Send HTTP request
        try {
            HttpResponse response = http.send(request);
            System.debug('Response Status Code: ' + response.getStatusCode());
            System.debug('Response Body: ' + response.getBody());

            if (response.getStatusCode() == 200) {
                Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String url = (String) responseBody.get('url');
                if (String.isBlank(url)) {
                    return 'Error: No iframe URL returned from Wazzup API. Response: ' + response.getBody();
                }
                return url;
            } else {
                Map<String, Object> errorResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                String errorMessage = 'Error loading chat: ';
                if (errorResponse.containsKey('description')) {
                    errorMessage += (String) errorResponse.get('description');
                } else {
                    errorMessage += response.getBody();
                }
                errorMessage += '\nPhone Number: ' + whatsappChatId;
                errorMessage += '\nRequest Body: ' + jsonBody;
                return errorMessage;
            }
        } catch (Exception e) {
            System.debug('Error making HTTP request: ' + e.getMessage());
            return 'Error making HTTP request: ' + e.getMessage() + '\nRequest Body: ' + jsonBody;
        }
    }
}