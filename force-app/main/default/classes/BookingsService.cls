@RestResource(urlMapping='/bookingsService/*')
global without sharing class BookingsService {

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;

        List<Booking__c> bookingList = [
            SELECT Id, Status__c, Payment_Date__c, Name, Unit__r.Id, Unit__r.Title_Formula__c, 
            Unit__r.Project__r.Name, Unit__r.Type__c, Unit__r.Cost_AED__c, Client__r.First_Name__c, Client__r.Last_Name__c
            FROM Booking__c WHERE OwnerId = :UserInfo.getUserId() AND Unit__r.Project__r.Publish_Project__c = 'Published'
        ];

        List<Map<String, Object>> responseList = new List<Map<String, Object>>();
        for (Booking__c booking : bookingList) {
            Map<String, Object> bookingMap = new Map<String, Object>();
            bookingMap.put('id', booking.Id);
            bookingMap.put('status', booking.Status__c);
            bookingMap.put('payment_date', booking.Payment_Date__c);
            bookingMap.put('name', booking.Name);
            bookingMap.put('client_name', booking.Client__r.First_Name__c + ' ' + booking.Client__r.Last_Name__c);
            bookingMap.put('unit', new Map<String, Object>{
                'id' => booking.Unit__r.Id,
                'title'=> booking.Unit__r.Title_Formula__c,
                'project_title'=> booking.Unit__r.Project__r.Name,
                'price'=> booking.Unit__r.Cost_AED__c,
                'type'=> booking.Unit__r.Type__c
            });

            responseList.add(bookingMap);
        }

        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Map<String,List<Map<String, Object>>>{'bookings' => responseList}));
    }
}