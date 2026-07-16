public without sharing class BrokerCommissionsController extends BrokerLoginController {

    public class CommissionRow {
        public String commNo { get; set; }
        public String project { get; set; }
        public String unit { get; set; }
        public String tower { get; set; }
        public String baseAmount { get; set; }
        public String rate { get; set; }
        public String commission { get; set; }
        public String status { get; set; }
        public String badgeClass { get; set; }
    }

    private List<Commission__c> recs {
        get {
            if (recs == null) {
                Id acc = getCurrentAccountId();
                recs = (acc == null) ? new List<Commission__c>() : [
                    SELECT Name, Unit__r.Title__c, Unit__r.Building__c, Unit__r.Project_Name_F__c,
                           Base_Amount__c, Commission_Rate__c,
                           Commission_Amount__c, Paid_Amount__c, Outstanding_Amount__c, Status__c
                    FROM Commission__c
                    WHERE Agency__c = :acc
                    ORDER BY CreatedDate DESC
                ];
            }
            return recs;
        }
        set;
    }

    public Boolean getHasCommissions() { return !recs.isEmpty(); }

    public List<CommissionRow> getCommissions() {
        List<CommissionRow> rows = new List<CommissionRow>();
        for (Commission__c c : recs) {
            CommissionRow r = new CommissionRow();
            r.commNo = c.Name;
            r.project = (c.Unit__r != null) ? c.Unit__r.Project_Name_F__c : null;
            r.unit = (c.Unit__r != null) ? c.Unit__r.Title__c : null;
            r.tower = (c.Unit__r != null) ? c.Unit__r.Building__c : null;
            r.baseAmount = aed(c.Base_Amount__c);
            r.rate = (c.Commission_Rate__c == null) ? '' : c.Commission_Rate__c.stripTrailingZeros().toPlainString() + '%';
            r.commission = aed(c.Commission_Amount__c);
            r.status = c.Status__c;
            r.badgeClass = badgeFor(c.Status__c);
            rows.add(r);
        }
        return rows;
    }

    // ---- KPI totals (computed once) ----
    private Decimal tEarned = 0, tPaid = 0, tOut = 0, rateSum = 0;
    private Integer rateCnt = 0;
    private Boolean computed = false;

    private void compute() {
        if (computed) return;
        for (Commission__c c : recs) {
            if (c.Commission_Amount__c != null) tEarned += c.Commission_Amount__c;
            if (c.Paid_Amount__c != null) tPaid += c.Paid_Amount__c;
            if (c.Outstanding_Amount__c != null) tOut += c.Outstanding_Amount__c;
            if (c.Commission_Rate__c != null) { rateSum += c.Commission_Rate__c; rateCnt++; }
        }
        computed = true;
    }

    public String getTotalEarned()      { compute(); return aed(tEarned); }
    public String getPaidTotal()        { compute(); return aed(tPaid); }
    public String getOutstandingTotal() { compute(); return aed(tOut); }
    public String getAvgRate()          { compute(); return (rateCnt == 0) ? '0%' : (rateSum / rateCnt).setScale(1).format() + '%'; }

    private String aed(Decimal d) { return (d == null) ? '' : 'AED ' + d.setScale(0).format(); }

    private String badgeFor(String s) {
        if (s == 'Fully Paid')     return 'b-paid';
        if (s == 'Partially Paid') return 'b-unpaid';
        if (s == 'Invoiced')       return 'b-booked';
        if (s == 'On Hold')        return 'b-reserved';
        if (s == 'Cancelled')      return 'b-cancelled';
        return 'b-new'; // Eligible / default
    }
}