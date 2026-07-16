public without sharing class FireBaseController {
    
    @AuraEnabled
    public static void sendNotifications(String notificationId){
        try {
            FireBaseInfo__mdt firebaseInfo = getFirebaseInfo();
            String jwtToken = generateJWT(firebaseInfo.Private_Key__c, firebaseInfo.Issuer__c);

            String accessToken = getAccessToken(jwtToken);
            if (accessToken != null) {
                handleSendNotifications(accessToken, notificationId);
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static FireBaseInfo__mdt getFirebaseInfo() {
        return [SELECT Issuer__c, Private_Key__c FROM FireBaseInfo__mdt LIMIT 1];
    }

    private static String generateJWT(String privateKey, String issuer) {
        String audience = 'https://oauth2.googleapis.com/token';
        String scope = 'https://www.googleapis.com/auth/firebase.messaging';
        return JWTGenerator.generateJWT(privateKey, issuer, audience, scope);
    }

    private static String getAccessToken(String jwtToken) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();

        req.setEndpoint('https://oauth2.googleapis.com/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        String grantString = 'urn:ietf:params:oauth:grant-type:jwt-bearer';
        req.setBody('grant_type=' + EncodingUtil.urlEncode(grantString, 'UTF-8') + '&assertion=' + EncodingUtil.urlEncode(jwtToken, 'UTF-8'));

        res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) responseMap.get('access_token');
        } else {
            if (Test.isRunningTest()) {
                return 'dummyAccessToken';
            }
            return null;
        }
    }

    @future(callout = true)
    public static void handleSendNotifications(String accessToken, String notificationId) {
        List<Contact> contacts = getContactsToSendNotifications();
        Notification__c notification = getNotification(notificationId);

        for (Contact con : contacts) {
            sendNotificationToFirebase(con.FireBase_token__c, accessToken, notification.Name, notification.Description__c);
        }
    }

    private static List<Contact> getContactsToSendNotifications() {
        return [SELECT FireBase_token__c FROM Contact WHERE FireBase_token__c != null];
    }

    private static Notification__c getNotification(String notificationId) {
        return [SELECT Id, Name, Description__c FROM Notification__c WHERE Id = :notificationId LIMIT 1];
    }

    private static void sendNotificationToFirebase(String fireBaseToken, String accessToken, String notificationTitle, String notificationBody) {
        String endpoint = 'https://fcm.googleapis.com/v1/projects/mira-app-f92f9/messages:send';

        String authToken = 'Bearer ' + accessToken;

        String body = '{"validate_only": false, "message": {"token": "' + fireBaseToken + '", "notification": {"title": "' + notificationTitle + '", "body": "' + notificationBody + '"}}}';

        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('POST');
        request.setHeader('Authorization', authToken);
        request.setHeader('Content-Type', 'application/json');
        request.setBody(body);

        Http http = new Http();
        HttpResponse response = http.send(request);
        System.debug(response.getBody());
    }

}