@RestResource(urlMapping='/nGeniusWebHookService/*')
global without sharing class NGeniusWebHookService {

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString();

        WebHookPayload payload = (WebHookPayload) JSON.deserialize(requestBody, WebHookPayload.class);

        String eventName = payload.eventName;
        Order order = payload.order;

        String invoiceReference = extractReferenceNumber(payload.order.referrer);
        if(eventName == 'CAPTURED'){
            Booking__c booking = [SELECT Id FROM Booking__c WHERE Invoice_Reference_Number__c = :invoiceReference];
            booking.Status__c = 'EOI Paid';
            update booking;   
        } else if(eventName == 'GATEWAY_RISK_PRE_AUTH_REJECTED'){
            Booking__c booking = [SELECT Id, Invoice_Payment_Attempts__c FROM Booking__c WHERE Invoice_Reference_Number__c = :invoiceReference];
            booking.Invoice_Payment_Attempts__c = 3;
            update booking;
        } else {
            Booking__c booking = [SELECT Id, Invoice_Payment_Attempts__c FROM Booking__c WHERE Invoice_Reference_Number__c = :invoiceReference];
            if(booking.Invoice_Payment_Attempts__c == null){
                booking.Invoice_Payment_Attempts__c = 1;
            } else {
                booking.Invoice_Payment_Attempts__c = booking.Invoice_Payment_Attempts__c + 1;
            }
            update booking;
        }
        RestContext.response.statusCode = 200;
    }

    public static String extractReferenceNumber(String input) {
        if (String.isEmpty(input)) {
            return null;
        }

        Integer lastIndex = input.lastIndexOf(':');

        if (lastIndex != -1) {
            return input.substring(lastIndex + 1);
        }

        return null;
    }

    public class WebHookPayload {
        public String eventId;
        public String eventName;
        public Order order;
    }

    public class Order {
        @JsonProperty('_id')
        public String id;
        
        @JsonProperty('_links')
        public Links links;
        
        public String type;
        public MerchantDefinedData merchantDefinedData;
        public String action;
        public Amount amount;
        public String language;
        public MerchantAttributes merchantAttributes;
        public String emailAddress;
        public String reference;
        public String outletId;
        public String createDateTime;
        public PaymentMethods paymentMethods;
        public OrderSummary orderSummary;
        public BillingAddress billingAddress;
        public String referrer;
        public FormattedOrderSummary formattedOrderSummary;
        public String formattedAmount;
        
        @JsonProperty('_embedded')
        public Embedded embedded;
    }

    public class Links {
        public Link self;
        public Link tenantBrand;
        public Link merchantBrand;
    }

    public class Link {
        public String href;
    }

    public class Amount {
        public String currencyCode;
        public Integer value;
    }

    public class MerchantAttributes {
        public String paymentAttempts;
    }

    public class PaymentMethods {
        public List<String> card;
        public List<String> wallet;
    }

    public class Embedded {
        public List<Payment> payment;
    }

    public class Payment {
        @JsonProperty('_id')
        public String id;
        
        @JsonProperty('_links')
        public Links links;
        
        public PaymentMethod paymentMethod;
        public SavedCard savedCard;
        public String state;
        public Amount amount;
        public String updateDateTime;
        public String outletId;
        public String orderReference;
        public AuthResponse authResponse;
        public ThreeDS2 threeDS2;
        public EmbeddedCapture embedded;
    }

    public class PaymentMethod {
        public String expiry;
        public String cardholderName;
        public String name;
        public String pan;
    }

    public class SavedCard {
        public String maskedPan;
        public String expiry;
        public String cardholderName;
        public String scheme;
        public String cardToken;
    }

    public class AuthResponse {
        public String authorizationCode;
        public Boolean success;
        public String resultCode;
        public String resultMessage;
        public String mid;
        public String rrn;
    }

    public class ThreeDS2 {
        public String eci;
        public String transStatus;
        public String messageVersion;
        public String acsReferenceNumber;
        public String threeDSMethodURL;
        public String threeDSServerTransID;
        public String acsURL;
        public String acsTransID;
        public String directoryServerID;
        public String base64EncodedCReq;
    }

    public class EmbeddedCapture {
        @JsonProperty('cnp:capture')
        public List<Capture> capture;
    }

    public class Capture {
        @JsonProperty('_links')
        public Links links;
        public Amount amount;
        public String createdTime;
        public String state;
    }

    public class BillingAddress {
        public String firstName;
        public String lastName;
    }

    public class MerchantDefinedData {
    }

    public class OrderSummary {
        public List<OrderItem> items;
        public Amount total;
    }

    public class OrderItem {
        public String description;
        public Amount totalPrice;
        public Integer quantity;
    }

    public class FormattedOrderSummary {
        public String total;
        public List<String> items;
    }
}