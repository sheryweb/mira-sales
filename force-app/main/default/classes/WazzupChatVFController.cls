public without sharing class WazzupChatVFController {
    public String iframeUrl { get; set; }
    private static final String WAZZUP_API_ENDPOINT = 'https://api.wazzup24.com/v3/iframe';

    public WazzupChatVFController() {
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
        // Get the Lead ID from the page parameters
        String leadId = ApexPages.currentPage().getParameters().get('id');
        if (String.isBlank(leadId)) {
            leadId = ApexPages.currentPage().getParameters().get('leadId');
        }

        if (String.isBlank(leadId)) {
            return 'Error: Lead ID is required. Please make sure you are accessing this page from a Lead record.';
        }

        // Query the Lead record with Owner details
        Lead leadRecord;
        try {
            leadRecord = [SELECT Id, Name, MobilePhone, Phone, OwnerId, Owner.Name FROM Lead WHERE Id = :leadId LIMIT 1];
        } catch (Exception e) {
            return 'Error: Unable to find Lead record: ' + e.getMessage();
        }

        // Get WhatsApp number
        //String whatsappChatId = ApexPages.currentPage().getParameters().get('whatsappChatId');
        String whatsappChatId = (leadRecord.MobilePhone == '' || leadRecord.MobilePhone == null) ? leadRecord.Phone : leadRecord.MobilePhone;
        if (String.isBlank(whatsappChatId)) {
            return 'Error: WhatsApp number not found. Please update the Lead\'s Mobile number.';
        }

        // Format the phone number correctly
        whatsappChatId = formatPhoneNumber(whatsappChatId);
        System.debug('Formatted WhatsApp ID: ' + whatsappChatId);

        if (whatsappChatId.length() < 10) {
            return 'Error: Invalid phone number format. Please ensure the mobile number is complete.';
        }

        // Fetch Lead owner's details
        String wazzupUserId = leadRecord.OwnerId;
        String wazzupUserName = leadRecord.Owner.Name;

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