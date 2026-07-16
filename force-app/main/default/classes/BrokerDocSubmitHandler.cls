/**
 * Handles Broker_Doc_Submit__e platform events. Runs in the Automated Process (system) context —
 * NOT the site guest — so it can submit the Approval_Request__c into the native Approval Process
 * on behalf of the Account owner. Parallel to BrokerBank/ProfileSubmitHandler; filters to the
 * 'Document Re-upload' request type so the existing flows are left untouched.
 */
public without sharing class BrokerDocSubmitHandler {

    public static void handle(List<Broker_Doc_Submit__e> events) {
        Set<Id> reqIds = new Set<Id>();
        for (Broker_Doc_Submit__e e : events) {
            if (String.isNotBlank(e.Approval_Request_Id__c)) {
                try { reqIds.add(Id.valueOf(e.Approval_Request_Id__c)); } catch (Exception ignored) {}
            }
        }
        if (reqIds.isEmpty()) return;

        Map<Id, Approval_Request__c> reqs = new Map<Id, Approval_Request__c>([
            SELECT Id, Related_Record_Id__c, Status__c
            FROM Approval_Request__c
            WHERE Id IN :reqIds AND Request_Type__c = 'Document Re-upload'
        ]);
        if (reqs.isEmpty()) return;

        Set<Id> acctIds = new Set<Id>();
        for (Approval_Request__c r : reqs.values()) {
            if (String.isNotBlank(r.Related_Record_Id__c)) {
                try { acctIds.add(Id.valueOf(r.Related_Record_Id__c)); } catch (Exception ignored) {}
            }
        }
        Map<Id, Account> accts = acctIds.isEmpty()
            ? new Map<Id, Account>()
            : new Map<Id, Account>([SELECT Id, OwnerId FROM Account WHERE Id IN :acctIds]);

        for (Approval_Request__c r : reqs.values()) {
            Id ownerId;
            if (String.isNotBlank(r.Related_Record_Id__c)) {
                Account a = accts.get(Id.valueOf(r.Related_Record_Id__c));
                if (a != null) ownerId = a.OwnerId;
            }
            try {
                Approval.ProcessSubmitRequest psr = new Approval.ProcessSubmitRequest();
                psr.setObjectId(r.Id);
                if (ownerId != null) psr.setSubmitterId(ownerId);
                psr.setComments('Document re-upload submitted from the MIRA Broker Portal.');
                Approval.process(psr);
            } catch (Exception ex) {
                System.debug('BrokerDocSubmit: could not submit ' + r.Id + ' :: ' + ex.getMessage());
            }
        }
    }
}