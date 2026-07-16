public without sharing class BrokerDashboardController extends BrokerLoginController {

    // ---- Opportunities (loaded once, scoped to the broker's agency; Transferred excluded) ----
    private List<Opportunity> opps {
        get {
            if (opps == null) {
                Id acc = getCurrentAccountId();
                opps = (acc == null) ? new List<Opportunity>() : [
                    SELECT Name, StageName, Unit_Title__c, Unit_Tower__c, Unit_Price__c,
                           Booking_Date_Time__c, Sold_Date_Time__c, Account.Name, Project_Name__c
                    FROM Opportunity
                    WHERE Agency__c = :acc AND StageName != 'Transferred'
                    ORDER BY Booking_Date_Time__c DESC NULLS LAST, CreatedDate DESC
                ];
            }
            return opps;
        }
        set;
    }

    // Active deals = everything except Cancelled / Transferred (same definition as before)
    public Integer getTotalDeals() {
        Integer n = 0;
        for (Opportunity o : opps) if (o.StageName != 'Cancelled') n++;
        return n;
    }

    // Units booked = Booked only
    public Integer getUnitsBooked() {
        Integer n = 0;
        for (Opportunity o : opps) if (o.StageName == 'Booked') n++;
        return n;
    }

    // Units sold = Reserved + Sold
    public Integer getUnitsSold() {
        Integer n = 0;
        for (Opportunity o : opps) if (o.StageName == 'Reserved' || o.StageName == 'Sold') n++;
        return n;
    }

    // ---- Commission KPIs ----
    private List<Commission__c> comms {
        get {
            if (comms == null) {
                Id acc = getCurrentAccountId();
                comms = (acc == null) ? new List<Commission__c>() : [
                    SELECT Total_Commission_Amount__c, Paid_Amount__c, Remaining_Amount__c
                    FROM Commission__c WHERE Agency__c = :acc
                ];
            }
            return comms;
        }
        set;
    }

    public String getTotalCommission() {
        Decimal t = 0;
        for (Commission__c c : comms) if (c.Total_Commission_Amount__c != null) t += c.Total_Commission_Amount__c;
        return aedCompact(t);
    }

    public String getPaidCommission() {
        Decimal t = 0;
        for (Commission__c c : comms) if (c.Paid_Amount__c != null) t += c.Paid_Amount__c;
        return aedCompact(t);
    }

    public String getRemainingCommission() {
        Decimal t = 0;
        for (Commission__c c : comms) if (c.Remaining_Amount__c != null) t += c.Remaining_Amount__c;
        return aedCompact(t);
    }

    // AED 1,240,000 — full amount with thousand separators (same as the Commissions page)
    private String aedCompact(Decimal d) {
        if (d == null) d = 0;
        return 'AED ' + d.setScale(0).format();
    }

    // ---- Donut: deals by stage ----
    public class StageSlice {
        public String label { get; set; }
        public Integer cnt { get; set; }
        public String color { get; set; }
        public String dash { get; set; }   // SVG stroke-dasharray, e.g. "164.93 439.82"
        public String xform { get; set; }  // SVG transform, e.g. "rotate(-90 90 90)"
    }

    private static final List<String> STAGE_ORDER =
        new List<String>{ 'Booked', 'Sold', 'New', 'Reserved', 'Cancelled' };
    private static final Map<String, String> STAGE_COLORS = new Map<String, String>{
        'Booked' => '#2563eb', 'Sold' => '#16a34a', 'New' => '#f59e0b',
        'Reserved' => '#7c3aed', 'Cancelled' => '#dc2626' };

    private Map<String, Integer> stageCounts {
        get {
            if (stageCounts == null) {
                stageCounts = new Map<String, Integer>();
                for (String s : STAGE_ORDER) stageCounts.put(s, 0);
                for (Opportunity o : opps) {
                    if (stageCounts.containsKey(o.StageName)) {
                        stageCounts.put(o.StageName, stageCounts.get(o.StageName) + 1);
                    }
                }
            }
            return stageCounts;
        }
        set;
    }

    // All deals shown in the donut (incl. Cancelled, excl. Transferred)
    public Integer getDonutTotal() {
        Integer t = 0;
        for (Integer n : stageCounts.values()) t += n;
        return t;
    }

    public Boolean getHasDeals() { return getDonutTotal() > 0; }

    public List<StageSlice> getStageSlices() {
        List<StageSlice> slices = new List<StageSlice>();
        Integer total = getDonutTotal();
        if (total == 0) return slices;
        Decimal circ = 439.82;            // 2 * pi * r (r = 70)
        Integer cum = 0;
        for (String s : STAGE_ORDER) {
            Integer n = stageCounts.get(s);
            if (n == 0) continue;
            StageSlice sl = new StageSlice();
            sl.label = s;
            sl.cnt = n;
            sl.color = STAGE_COLORS.get(s);
            sl.dash = (circ * n / total).setScale(2) + ' ' + circ;
            sl.xform = 'rotate(' + (-90 + (360.0 * cum / total)).setScale(2) + ' 90 90)';
            cum += n;
            slices.add(sl);
        }
        return slices;
    }

    // ---- Bars: units booked per month, last 6 calendar months ----
    public class MonthBar {
        public String label { get; set; }
        public Integer cnt { get; set; }         // Booked + Sold
        public String stackStyle { get; set; }   // bar height vs tallest month, e.g. "height:83%"
        public String soldStyle { get; set; }    // Sold share within the bar, e.g. "height:40%"
    }

    private static final List<String> MONTH_NAMES = new List<String>{
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' };

    public List<MonthBar> getMonthlyBars() {
        Date first = Date.today().toStartOfMonth().addMonths(-5);
        List<Integer> booked = new List<Integer>{ 0, 0, 0, 0, 0, 0 };
        List<Integer> sold   = new List<Integer>{ 0, 0, 0, 0, 0, 0 };
        for (Opportunity o : opps) {
            if (o.StageName != 'Booked' && o.StageName != 'Sold') continue;
            // Booked deals bucket by booking date; Sold deals by sold date (fallback: booking date)
            Datetime dt = (o.StageName == 'Sold' && o.Sold_Date_Time__c != null) ? o.Sold_Date_Time__c : o.Booking_Date_Time__c;
            if (dt == null) continue;
            Integer idx = first.monthsBetween(dt.date().toStartOfMonth());
            if (idx < 0 || idx > 5) continue;
            if (o.StageName == 'Sold') sold[idx] = sold[idx] + 1; else booked[idx] = booked[idx] + 1;
        }
        Integer mx = 0;
        for (Integer i = 0; i < 6; i++) if (booked[i] + sold[i] > mx) mx = booked[i] + sold[i];
        List<MonthBar> bars = new List<MonthBar>();
        for (Integer i = 0; i < 6; i++) {
            Date m = first.addMonths(i);
            Integer total = booked[i] + sold[i];
            MonthBar b = new MonthBar();
            b.label = MONTH_NAMES[m.month() - 1];
            b.cnt = total;
            b.stackStyle = 'height:' + ((mx == 0) ? 0 : (Decimal.valueOf(total) / mx * 100).setScale(0)) + '%';
            b.soldStyle = 'height:' + ((total == 0) ? 0 : (Decimal.valueOf(sold[i]) / total * 100).setScale(0)) + '%';
            bars.add(b);
        }
        return bars;
    }

    // ---- Recent bookings (latest 5, same shape as the Bookings page) ----
    public class RecentRow {
        public String project { get; set; }
        public String unit { get; set; }
        public String tower { get; set; }
        public String client { get; set; }
        public String stage { get; set; }
        public String badgeClass { get; set; }
        public String price { get; set; }
        public String bookedOn { get; set; }
    }

    public List<RecentRow> getRecentBookings() {
        List<RecentRow> rows = new List<RecentRow>();
        for (Opportunity o : opps) {
            if (rows.size() == 5) break;
            RecentRow r = new RecentRow();
            r.project = o.Project_Name__c;
            r.unit = String.isBlank(o.Unit_Title__c) ? o.Name : o.Unit_Title__c;
            r.tower = o.Unit_Tower__c;
            r.client = (o.Account != null) ? o.Account.Name : null;
            r.stage = o.StageName;
            r.badgeClass = badgeFor(o.StageName);
            r.price = (o.Unit_Price__c == null) ? '' : 'AED ' + o.Unit_Price__c.setScale(0).format();
            r.bookedOn = (o.Booking_Date_Time__c == null) ? '' : o.Booking_Date_Time__c.format('dd MMM yyyy');
            rows.add(r);
        }
        return rows;
    }

    public Boolean getHasRecent() { return !opps.isEmpty(); }

    private String badgeFor(String stage) {
        if (stage == 'Booked')   return 'b-booked';
        if (stage == 'Sold')     return 'b-sold';
        if (stage == 'New')      return 'b-new';
        if (stage == 'Reserved') return 'b-reserved';
        return 'b-cancelled';
    }
}