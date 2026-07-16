@RestResource(urlMapping='/SendSalesOfferPdfViaEmail/*')
global without sharing class SalesOfferService {

    @HttpPut
    global static String manageSendSalesOfferPdfViaEmail() {
        RestRequest req = RestContext.request;
        String bookingId = req.params.get('bookingId');
        RestResponse res = RestContext.response;
        OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'M I R A  Developments'];
        EmailTemplate template = [SELECT Id, HtmlValue, Subject FROM EmailTemplate WHERE DeveloperName = 'Sales_Offer_PDF'];
        List<Booking__c> booking = [SELECT Id, Status__c, Client__c, Client__r.Email__c, Client__r.First_Name__c, Client__r.Last_Name__c, Unit__c, Unit__r.Project__r.Name, Unit__r.Title_Formula__c, Invoice_Reference_Number__c, Invoice_Payment_Attempts__c FROM Booking__c WHERE Id = :bookingId LIMIT 1];
        if (!booking.isEmpty()) {
            List<String> emptyFields = checkEmptyFields(booking[0]);
            if(!emptyFields.isEmpty()){
                return  String.join(emptyFields, ',');
            }

            String response;
            String createInvoiceResult;
            if(booking[0].Status__c == 'EOI Paid'){
                return 'Invoice paid';
            }
            List<N_Genius_Configuration__mdt> nGeniusConf = [SELECT Id, API_Key__c, Reference_Number__c, URL__c, aedValue__c FROM N_Genius_Configuration__mdt WHERE DeveloperName = 'paymentGatewayConfig'];
            String accessToken = PaymentGatewayService.requestAccessToken(nGeniusConf[0]);
            if(accessToken == 'Bad request'){
                return 'Error occured while requesting access token';
            }else{
                if(booking[0].Invoice_Reference_Number__c != null && booking[0].Invoice_Payment_Attempts__c < 3){
                    createInvoiceResult = PaymentGatewayService.requestResendInvoice(accessToken, nGeniusConf[0], booking[0]);
                } else {
                    createInvoiceResult = PaymentGatewayService.requestCreateInvoice(accessToken, nGeniusConf[0], booking[0]);

                    booking[0].Invoice_Reference_Number__c = createInvoiceResult;
                    booking[0].Invoice_Payment_Attempts__c = 0;
                    update booking;
                }
                if(createInvoiceResult == 'Bad request'){
                    return 'Error occured while creating an invoice';
                }
            }

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setHtmlBody(template.HtmlValue);
            mail.setSubject(template.Subject);
            mail.setOrgWideEmailAddressId(owea.get(0).Id);
            mail.setToAddresses(new List<String>{booking[0].Client__r.Email__c});
            PageReference pdfPage = Page.SalesOfferPDF;
            pdfPage.getParameters().put('unitId',booking[0].Unit__c);
            Blob pdfBody;
            if(!test.isRunningTest()){
                pdfBody = pdfPage.getContent();
            }else{
                pdfBody = blob.valueof('TEST');
            }
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            efa.setFileName('SalesOffer.pdf');
            efa.setBody(pdfBody);
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] {efa});
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailmessage[] {mail});
            for (Messaging.SendEmailResult mailResult : results) {
                if (mailResult.isSuccess()) {
                    response = 'Email sent successfully';
                }
                else {
                    response = 'The following errors occurred: ' + mailResult.getErrors();                 
                }
            }
            return response;
        } else {
            return 'Booking not found';
        }
    }

    public static List<String> checkEmptyFields(Booking__c boooking) {
        List<String> emptyFields = new List<String>();

        if (boooking.Client__c == null) {
            emptyFields.add('Client__c');
        }
        if (boooking.Unit__c == null) {
            emptyFields.add('Unit__c');
        }
        if (boooking.Client__c != null && boooking.Client__r.Email__c == null) {
            emptyFields.add('Client__r.Email__c');
        }
        if (boooking.Client__c != null && boooking.Client__r.First_Name__c == null) {
            emptyFields.add('Client__r.First_Name__c');
        }
        if (boooking.Client__c != null && boooking.Client__r.Last_Name__c == null) {
            emptyFields.add('Client__r.Last_Name__c');
        }

        return emptyFields;
    }
}