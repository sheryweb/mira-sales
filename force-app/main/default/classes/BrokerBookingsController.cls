public without sharing class BrokerBookingsController extends BrokerLoginController {

    // Display row for the bookings table
    public class BookingRow {
        public String project { get; set; }
        public String unit { get; set; }
        public String tower { get; set; }
        public String client { get; set; }
        public String stage { get; set; }
        public String badgeClass { get; set; }
        public String price { get; set; }
        public String bookedOn { get; set; }
        public String soldOn { get; set; }
    }

    // Loaded once per request, scoped to the logged-in broker's agency
    private List<Opportunity> opps {
        get {
            if (opps == null) {
                Id acc = getCurrentAccountId();
                opps = (acc == null) ? new List<Opportunity>() : [
                    SELECT Name, StageName, Unit_Title__c, Unit_Tower__c, Unit_Price__c,
                           Booking_Date_Time__c, Sold_Date_Time__c, Account.Name, Project_Name__c
                    FROM Opportunity
                    WHERE Agency__c = :acc AND StageName IN ('New', 'Booked', 'Reserved', 'Sold', 'Cancelled')
                    ORDER BY Booking_Date_Time__c DESC NULLS LAST, CreatedDate DESC
                ];
            }
            return opps;
        }
        set;
    }

    public List<BookingRow> getBookings() {
        List<BookingRow> rows = new List<BookingRow>();
        for (Opportunity o : opps) {
            BookingRow r = new BookingRow();
            r.project = o.Project_Name__c;
            r.unit = String.isBlank(o.Unit_Title__c) ? o.Name : o.Unit_Title__c;
            r.tower = o.Unit_Tower__c;
            r.client = (o.Account != null) ? o.Account.Name : null;
            r.stage = o.StageName;
            r.badgeClass = badgeFor(o.StageName);
            r.price = (o.Unit_Price__c == null) ? '' : 'AED ' + o.Unit_Price__c.setScale(0).format();
            r.bookedOn = (o.Booking_Date_Time__c == null) ? '---' : o.Booking_Date_Time__c.format('dd MMM yyyy');
            r.soldOn = (o.Sold_Date_Time__c == null) ? '---' : o.Sold_Date_Time__c.format('dd MMM yyyy');
            rows.add(r);
        }
        return rows;
    }

    public Boolean getHasBookings() { return !opps.isEmpty(); }

    // KPI tiles (match the design's four stages)
    public Integer getCountNew()       { return countStage('New'); }
    public Integer getCountBooked()    { return countStage('Booked'); }
    public Integer getCountReserved()  { return countStage('Reserved'); }
    public Integer getCountSold()      { return countStage('Sold'); }
    public Integer getCountCancelled() { return countStage('Cancelled'); }

    private Integer countStage(String stage) {
        Integer n = 0;
        for (Opportunity o : opps) {
            if (o.StageName == stage) n++;
        }
        return n;
    }

    private String badgeFor(String stage) {
        if (stage == 'Booked')   return 'b-booked';
        if (stage == 'Sold')     return 'b-sold';
        if (stage == 'New')      return 'b-new';
        if (stage == 'Reserved') return 'b-reserved';
        return 'b-cancelled'; // Cancelled / Transferred
    }
}