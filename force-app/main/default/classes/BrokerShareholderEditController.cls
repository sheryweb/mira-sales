public without sharing class BrokerShareholderEditController extends BrokerLoginController {

    // One editable shareholder row (existing or newly added), two-way bound on the page.
    public class Row {
        public String rowKey   { get; set; }   // stable client key for add/remove
        public String recordId { get; set; }   // blank => a new shareholder
        public String holder   { get; set; }   // Shareholder Name
        public String percent  { get; set; }   // whole-number percent as text
    }

    public List<Row> rows { get; private set; }
    public String message { get; private set; }
    public Boolean submitted { get; private set; }
    public Boolean locked { get; private set; }
    public String removeKey { get; set; }       // set by the Remove button's <apex:param>

    private List<String> deletedIds = new List<String>();
    private Integer nextKey = 0;

    public BrokerShareholderEditController() {
        submitted = false;
        rows = new List<Row>();
        Id accId = getCurrentAccountId();
        locked = (accId == null);
        if (accId != null) loadRows(accId);
    }

    private void loadRows(Id accId) {
        for (Shareholder__c sh : [
            SELECT Id, Name, Percent__c FROM Shareholder__c WHERE Account__c = :accId ORDER BY Percent__c DESC
        ]) {
            Row r = newRow();
            r.recordId = sh.Id;
            r.holder = (sh.Name == null) ? '' : sh.Name;
            r.percent = (sh.Percent__c == null) ? '' : sh.Percent__c.stripTrailingZeros().toPlainString();
            rows.add(r);
        }
    }

    private Row newRow() {
        Row r = new Row();
        r.rowKey = String.valueOf(nextKey++);
        r.recordId = '';
        r.holder = '';
        r.percent = '';
        return r;
    }

    public Boolean getHasRows() { return rows != null && !rows.isEmpty(); }

    // Live total of the entered percentages (for display; the authoritative check is in save()).
    public String getTotalPercent() {
        Decimal total = 0;
        for (Row r : rows) {
            Decimal p = parsePercent(r.percent);
            if (p != null) total += p;
        }
        return total.stripTrailingZeros().toPlainString();
    }

    // ---- row actions (postback + reRender) ----
    public PageReference addRow() {
        message = null;
        rows.add(newRow());
        return null;
    }

    public PageReference removeRow() {
        message = null;
        if (String.isBlank(removeKey)) return null;
        for (Integer i = 0; i < rows.size(); i++) {
            if (rows[i].rowKey == removeKey) {
                if (String.isNotBlank(rows[i].recordId)) deletedIds.add(rows[i].recordId);
                rows.remove(i);
                break;
            }
        }
        removeKey = null;
        return null;
    }

    public PageReference save() {
        message = null;
        Id accId = getCurrentAccountId();
        if (accId == null) { message = 'Your session has expired. Please log in again.'; return null; }

        List<Object> upserts = new List<Object>();
        Decimal total = 0;
        for (Row r : rows) {
            String nm = (r.holder == null) ? '' : r.holder.trim();
            String pctRaw = (r.percent == null) ? '' : r.percent.trim();
            if (String.isBlank(nm) && String.isBlank(pctRaw)) continue;   // ignore a fully-blank row

            if (String.isBlank(nm)) { message = 'Each shareholder needs a name.'; return null; }
            Decimal pct = parsePercent(pctRaw);
            if (pct == null || pct < 0) { message = 'Enter a valid percentage for "' + nm + '".'; return null; }

            total += pct;
            upserts.add(new Map<String, Object>{
                'recordId' => (r.recordId == null) ? '' : r.recordId,
                'name' => nm,
                'percent' => pct
            });
        }

        if (upserts.isEmpty() && deletedIds.isEmpty()) { message = 'No changes to save.'; return null; }
        if (total != 100) {
            message = 'Shareholder percentages must total exactly 100%. Current total is ' + total.stripTrailingZeros().toPlainString() + '%.';
            return null;
        }

        Map<String, Object> payload = new Map<String, Object>{
            'upserts' => upserts,
            'deletes' => deletedIds
        };

        // Guests can't write records; escape to system context via a platform event that applies immediately.
        EventBus.publish(new Broker_Shareholder_Apply__e(
            Account_Id__c = String.valueOf(accId),
            Changes_JSON__c = JSON.serialize(payload)
        ));

        submitted = true;
        message = 'Your shareholder details have been updated.';
        return null;
    }

    // Accepts a whole-number or decimal percent string; returns null if not a valid number.
    private Decimal parsePercent(String s) {
        if (String.isBlank(s)) return null;
        try { return Decimal.valueOf(s.trim()); } catch (Exception e) { return null; }
    }
}