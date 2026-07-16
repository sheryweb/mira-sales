/**
 * Handles Broker_Shareholder_Apply__e platform events. Runs in the Automated Process (system)
 * context — NOT the site guest — so it can write Shareholder__c records (guests can't edit records).
 * Shareholder edits are applied immediately (no approval process, per requirements).
 *
 * Payload (Changes_JSON__c) is:
 *   { "upserts":[ {"recordId":"a0Y..","name":"John","percent":60},   // recordId present -> update
 *                 {"recordId":"",      "name":"Jane","percent":40} ],// blank recordId  -> insert
 *     "deletes":[ "a0Z..", "a0W.." ] }                                // existing ids removed by the broker
 *
 * Brand-new component; does not touch any existing class/trigger.
 */
public without sharing class BrokerShareholderApplyHandler {

    public static void handle(List<Broker_Shareholder_Apply__e> events) {
        List<Shareholder__c> toUpsert = new List<Shareholder__c>();
        List<Shareholder__c> toDelete = new List<Shareholder__c>();

        for (Broker_Shareholder_Apply__e e : events) {
            if (String.isBlank(e.Account_Id__c) || String.isBlank(e.Changes_JSON__c)) continue;

            Id acctId;
            try { acctId = Id.valueOf(e.Account_Id__c); } catch (Exception ex) { continue; }

            Map<String, Object> payload;
            try { payload = (Map<String, Object>) JSON.deserializeUntyped(e.Changes_JSON__c); }
            catch (Exception ex) { continue; }

            // Only this Account's shareholders may be touched (defence-in-depth).
            Set<Id> ownIds = new Set<Id>();
            for (Shareholder__c sh : [SELECT Id FROM Shareholder__c WHERE Account__c = :acctId]) ownIds.add(sh.Id);

            // Upserts
            Object upsertsObj = payload.get('upserts');
            if (upsertsObj instanceof List<Object>) {
                for (Object o : (List<Object>) upsertsObj) {
                    if (!(o instanceof Map<String, Object>)) continue;
                    Map<String, Object> row = (Map<String, Object>) o;
                    String recordId = String.valueOf(row.get('recordId'));
                    String nm = (row.get('name') == null) ? null : String.valueOf(row.get('name'));
                    Decimal pct = toDecimal(row.get('percent'));

                    Shareholder__c sh;
                    if (String.isBlank(recordId) || recordId == 'null') {
                        sh = new Shareholder__c(Account__c = acctId);          // new
                    } else {
                        Id sid;
                        try { sid = Id.valueOf(recordId); } catch (Exception ex) { continue; }
                        if (!ownIds.contains(sid)) continue;                    // not this account's — skip
                        sh = new Shareholder__c(Id = sid);
                    }
                    sh.Name = nm;
                    sh.Percent__c = pct;
                    toUpsert.add(sh);
                }
            }

            // Deletes
            Object deletesObj = payload.get('deletes');
            if (deletesObj instanceof List<Object>) {
                for (Object o : (List<Object>) deletesObj) {
                    Id sid;
                    try { sid = Id.valueOf(String.valueOf(o)); } catch (Exception ex) { continue; }
                    if (ownIds.contains(sid)) toDelete.add(new Shareholder__c(Id = sid));
                }
            }
        }

        if (!toUpsert.isEmpty()) upsert toUpsert;
        if (!toDelete.isEmpty()) delete toDelete;
    }

    private static Decimal toDecimal(Object v) {
        if (v == null) return null;
        String s = String.valueOf(v);
        if (String.isBlank(s)) return null;
        try { return Decimal.valueOf(s.trim()); } catch (Exception e) { return null; }
    }
}