public class PaymentGatewayService {

    public static String requestAccessToken(N_Genius_Configuration__mdt nGeniusConf){
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(nGeniusConf.URL__c + '/identity/auth/access-token?umid=' + nGeniusConf.Reference_Number__c);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/vnd.ni-identity.v1+json');
        request.setHeader('Accept', 'application/vnd.ni-identity.v1+json');
        request.setBody('');
        request.setHeader('Authorization', 'Basic ' + nGeniusConf.API_Key__c);
        HttpResponse response = http.send(request);
        if(response.getStatusCode() == 200){
            Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            return (String)results.get('access_token');
        } else {
            return 'Bad request';
        }
    }

    public static String requestCreateInvoice(String accessToken, N_Genius_Configuration__mdt nGeniusConf, Booking__c booking){
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(nGeniusConf.URL__c + '/invoices/outlets/' + nGeniusConf.Reference_Number__c + '/invoice');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/vnd.ni-invoice.v1+json');
        request.setHeader('Accept', 'application/vnd.ni-invoice.v1+json');
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        Map<String, Object> paymentRequest = new Map<String, Object>();
        paymentRequest.put('firstName', booking.Client__r.First_Name__c);
        paymentRequest.put('lastName', booking.Client__r.Last_Name__c);
        paymentRequest.put('email', booking.Client__r.Email__c);
        paymentRequest.put('transactionType', 'SALE');
        paymentRequest.put('emailSubject', 'Invoice from M I R A  Developments');
        DateTime now = DateTime.now();
        DateTime tomorrow = now.addDays(1);
        String invoiceExpiryDate = tomorrow.format('yyyy-MM-dd');
        paymentRequest.put('invoiceExpiryDate', invoiceExpiryDate);
        List<Map<String, Object>> items = new List<Map<String, Object>>();
        Map<String, Object> item1 = new Map<String, Object>();
        item1.put('description', booking.Unit__r.Project__r.Name + ' ' + booking.Unit__r.Title_Formula__c + ' Booking');
        Map<String, Object> totalPrice1 = new Map<String, Object>();
        totalPrice1.put('currencyCode', 'AED');
        paymentRequest.put('paymentAttempts', 3);
        totalPrice1.put('value', nGeniusConf.aedValue__c);
        item1.put('totalPrice', totalPrice1);
        item1.put('quantity', 1);
        items.add(item1);

        paymentRequest.put('items', items);
        paymentRequest.put('total', new Map<String, Object>{'currencyCode'=>'AED', 'value'=>nGeniusConf.aedValue__c});
        paymentRequest.put('message', ' ');

        String requestBody = JSON.serialize(paymentRequest);
        request.setBody(requestBody);

        HttpResponse response = http.send(request);
        if(response.getStatusCode() == 201){
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            String orderReference = (String)jsonResponse.get('reference');
            return orderReference;
        } else {
            return 'Bad request';
        }
    }

    public static String requestResendInvoice(String accessToken, N_Genius_Configuration__mdt nGeniusConf, Booking__c booking){
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(nGeniusConf.URL__c + '/invoices/outlets/' + nGeniusConf.Reference_Number__c + '/invoice/'+ booking.Invoice_Reference_Number__c +'/resend');
        request.setMethod('PUT');
        request.setHeader('Content-Type', 'application/vnd.ni-invoice.v1+json');
        request.setHeader('Accept', 'application/vnd.ni-invoice.v1+json');
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        Map<String, Object> paymentRequest = new Map<String, Object>();
        paymentRequest.put('email', booking.Client__r.Email__c);
        DateTime now = DateTime.now();
        DateTime tomorrow = now.addDays(1);
        String invoiceExpiryDate = tomorrow.format('yyyy-MM-dd');
        paymentRequest.put('invoiceExpiryDate', invoiceExpiryDate);

        String requestBody = JSON.serialize(paymentRequest);
        request.setBody(requestBody);

        HttpResponse response = http.send(request);
        if(response.getStatusCode() == 200){
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            String orderReference = (String)jsonResponse.get('orderReference');
            return orderReference;
        } else {
            return 'Bad request';
        }
    }
}