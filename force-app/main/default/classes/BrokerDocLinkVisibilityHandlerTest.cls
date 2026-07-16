@isTest
private class BrokerDocLinkVisibilityHandlerTest {

    private static Id agencyRtId() {
        Map<String, Schema.RecordTypeInfo> m = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (m.containsKey('Agency') && m.get('Agency').isAvailable()) return m.get('Agency').getRecordTypeId();
        for (Schema.RecordTypeInfo i : m.values()) if (i.isAvailable() && !i.isMaster()) return i.getRecordTypeId();
        return null;
    }

    private static Id newDoc() {
        return newDoc('Agency File ' + String.valueOf(Crypto.getRandomLong()));
    }
    private static Id newDoc(String title) {
        ContentVersion cv = new ContentVersion(Title = title, PathOnClient = 'd.pdf', VersionData = Blob.valueOf('x'));
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
    }

    @isTest
    static void flips_agency_account_link_to_allusers() {
        String u = String.valueOf(Crypto.getRandomLong());
        Account a = new Account(Name = 'Vis Agency ' + u, Skip_Trigger__c = true);
        Id rt = agencyRtId(); if (rt != null) a.RecordTypeId = rt;
        insert a;
        insert new Broker_User__c(Account__c = a.Id, Email__c = 'vis' + u + '@example.com', Active__c = true);

        Id cdId = newDoc();
        Test.startTest();
        // Simulate an internal upload: link the file to the account with InternalUsers visibility.
        insert new ContentDocumentLink(ContentDocumentId = cdId, LinkedEntityId = a.Id,
            ShareType = 'V', Visibility = 'InternalUsers');
        Test.stopTest();

        ContentDocumentLink after = [
            SELECT Visibility FROM ContentDocumentLink
            WHERE ContentDocumentId = :cdId AND LinkedEntityId = :a.Id LIMIT 1
        ];
        System.assertEquals('AllUsers', after.Visibility, 'agency file link flipped to AllUsers');
    }

    @isTest
    static void internal_named_file_stays_internal() {
        String u = String.valueOf(Crypto.getRandomLong());
        Account a = new Account(Name = 'Vis Agency 3 ' + u, Skip_Trigger__c = true);
        Id rt = agencyRtId(); if (rt != null) a.RecordTypeId = rt;
        insert a;
        insert new Broker_User__c(Account__c = a.Id, Email__c = 'vis3' + u + '@example.com', Active__c = true);

        Id cdId = newDoc('INTERNAL Audit Notes');   // name starts with INTERNAL -> stays hidden
        Test.startTest();
        insert new ContentDocumentLink(ContentDocumentId = cdId, LinkedEntityId = a.Id,
            ShareType = 'V', Visibility = 'InternalUsers');
        Test.stopTest();

        System.assertEquals('InternalUsers',
            [SELECT Visibility FROM ContentDocumentLink WHERE ContentDocumentId = :cdId AND LinkedEntityId = :a.Id LIMIT 1].Visibility,
            'internal-named file is NOT shared to the agency');
        System.assertEquals(true, BrokerDocLinkVisibilityHandler.isInternalOnly('internal stuff'));
        System.assertEquals(false, BrokerDocLinkVisibilityHandler.isInternalOnly('Trade License'));
    }

    @isTest
    static void leaves_non_account_link_untouched() {
        String u = String.valueOf(Crypto.getRandomLong());
        Account a = new Account(Name = 'Vis Agency 2 ' + u, Skip_Trigger__c = true);
        Id rt = agencyRtId(); if (rt != null) a.RecordTypeId = rt;
        insert a;
        Broker_User__c bu = new Broker_User__c(Account__c = a.Id, Email__c = 'vis2' + u + '@example.com', Active__c = true);
        insert bu;

        Id cdId = newDoc();
        Test.startTest();
        // Link to the Broker_User__c record (not an Account) -> trigger should skip it.
        insert new ContentDocumentLink(ContentDocumentId = cdId, LinkedEntityId = bu.Id,
            ShareType = 'V', Visibility = 'InternalUsers');
        Test.stopTest();

        ContentDocumentLink after = [
            SELECT Visibility FROM ContentDocumentLink
            WHERE ContentDocumentId = :cdId AND LinkedEntityId = :bu.Id LIMIT 1
        ];
        System.assertEquals('InternalUsers', after.Visibility, 'non-account link untouched');
    }
}