public without sharing class BrokerInvoiceController extends BrokerLoginController {

    private static final Decimal VAT_RATE = 0.05; // UAE VAT 5%

    public class InvoiceData {
        public String commNo { get; set; }
        public String dateStr { get; set; }
        public String agencyName { get; set; }
        public String agencyTrn { get; set; }
        public String unit { get; set; }
        public String tower { get; set; }
        public String rate { get; set; }
        public String commissionAmount { get; set; }
        public String vatAmount { get; set; }
        public String totalAmount { get; set; }
    }

    private Boolean loaded = false;
    private Boolean valid = false;
    private InvoiceData data;

    private void load() {
        if (loaded) return;
        loaded = true;

        Id acc = getCurrentAccountId();
        String cid = ApexPages.currentPage().getParameters().get('id');
        if (acc == null || String.isBlank(cid)) return;

        List<Commission__c> cs = [
            SELECT Name, Status__c, Commission_Rate__c, Commission_Amount__c,
                   Unit__r.Title__c, Unit__r.Building__c,
                   Agency__r.Name, Agency__r.VAT_TRN__c, Agency__r.TRN_Number__c
            FROM Commission__c
            WHERE Id = :cid AND Agency__c = :acc          /* scope: broker's own commission only */
            LIMIT 1
        ];
        if (cs.isEmpty()) return;
        Commission__c c = cs[0];

        // Only generate when the commission is Eligible AND the agency is VAT eligible
        if (c.Status__c != 'Eligible' || c.Agency__r.VAT_TRN__c != 'Yes') return;

        Decimal amt = (c.Commission_Amount__c == null) ? 0 : c.Commission_Amount__c;
        Decimal vat = (amt * VAT_RATE).setScale(2);

        InvoiceData d = new InvoiceData();
        d.commNo = c.Name;
        d.dateStr = Date.today().format();
        d.agencyName = c.Agency__r.Name;
        d.agencyTrn = c.Agency__r.TRN_Number__c;
        d.unit = (c.Unit__r != null) ? c.Unit__r.Title__c : null;
        d.tower = (c.Unit__r != null) ? c.Unit__r.Building__c : null;
        d.rate = (c.Commission_Rate__c == null) ? '' : c.Commission_Rate__c.stripTrailingZeros().toPlainString() + '%';
        d.commissionAmount = fmt(amt);
        d.vatAmount = fmt(vat);
        d.totalAmount = fmt(amt + vat);

        data = d;
        valid = true;
    }

    public Boolean getIsValid() { load(); return valid; }
    public InvoiceData getInvoice() { load(); return data; }

    private String fmt(Decimal d) { return (d == null ? 0 : d).setScale(2).format(); }
}