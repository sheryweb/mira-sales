/**
 * Ensures files linked to an Agency account are visible to that agency's Broker Portal login
 * (a Force.com Site guest can only see ContentDocumentLinks with Visibility='AllUsers').
 * Files uploaded INTERNALLY (via the Account Files related list) default to 'InternalUsers',
 * so the broker can't see them — this flips those links to 'AllUsers'.
 *
 * Scoped tightly: it does nothing unless a freshly-linked file points at an Account that is an
 * Agency (by record type) or is portal-enabled (has a Broker_User__c). Brand-new component.
 */
public without sharing class BrokerDocLinkVisibilityHandler {

    // Files whose name starts with this keyword are INTERNAL-ONLY: they are never shared to the
    // agency (guest) and are hidden from the Broker Portal Documents tab, even on an agency account.
    public static final String INTERNAL_PREFIX = 'INTERNAL';

    public static Boolean isInternalOnly(String title) {
        return String.isNotBlank(title) && title.trim().toLowerCase().startsWith(INTERNAL_PREFIX.toLowerCase());
    }

    public static void makeAgencyFilesVisible(List<ContentDocumentLink> links) {
        Set<Id> acctIds = new Set<Id>();
        Set<Id> linkIds = new Set<Id>();
        for (ContentDocumentLink l : links) {
            if (l.Id != null) linkIds.add(l.Id);
            // Only Account-linked files matter (Account key prefix = 001).
            if (l.LinkedEntityId != null && String.valueOf(l.LinkedEntityId).startsWith('001')) {
                acctIds.add(l.LinkedEntityId);
            }
        }
        if (acctIds.isEmpty()) return;   // no account file-links in this batch — nothing to do

        // An account qualifies if it's an Agency record type OR has a Broker Portal login.
        Set<Id> agencyAccts = new Set<Id>();
        Id agencyRt = agencyRecordTypeId();
        if (agencyRt != null) {
            for (Account a : [SELECT Id FROM Account WHERE Id IN :acctIds AND RecordTypeId = :agencyRt]) {
                agencyAccts.add(a.Id);
            }
        }
        for (Broker_User__c bu : [SELECT Account__c FROM Broker_User__c WHERE Account__c IN :acctIds]) {
            agencyAccts.add(bu.Account__c);
        }
        if (agencyAccts.isEmpty()) return;

        List<ContentDocumentLink> candidates = [
            SELECT Id, LinkedEntityId, ContentDocumentId, Visibility FROM ContentDocumentLink WHERE Id IN :linkIds
        ];
        // Identify internal-only files (by name) so they are NOT shared to the agency.
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : candidates) {
            if (agencyAccts.contains(l.LinkedEntityId) && l.Visibility != 'AllUsers') docIds.add(l.ContentDocumentId);
        }
        if (docIds.isEmpty()) return;
        Set<Id> internalDocIds = new Set<Id>();
        for (ContentVersion cv : [
            SELECT ContentDocumentId, Title FROM ContentVersion WHERE ContentDocumentId IN :docIds AND IsLatest = true
        ]) {
            if (isInternalOnly(cv.Title)) internalDocIds.add(cv.ContentDocumentId);
        }

        List<ContentDocumentLink> toUpdate = new List<ContentDocumentLink>();
        for (ContentDocumentLink l : candidates) {
            if (agencyAccts.contains(l.LinkedEntityId) && l.Visibility != 'AllUsers'
                    && !internalDocIds.contains(l.ContentDocumentId)) {
                l.Visibility = 'AllUsers';
                toUpdate.add(l);
            }
        }
        if (!toUpdate.isEmpty()) {
            // Best-effort: a guest-context link (e.g. broker upload) may not be updatable here; the
            // approval apply path covers those. Never let this break the file operation.
            try { update toUpdate; } catch (Exception e) {
                System.debug('CDL visibility update failed: ' + e.getMessage());
            }
        }
    }

    private static Id agencyRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> m = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        return m.containsKey('Agency') ? m.get('Agency').getRecordTypeId() : null;
    }
}