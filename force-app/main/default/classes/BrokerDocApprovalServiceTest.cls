@isTest
private class BrokerDocApprovalServiceTest {

    private static Id addFile(Id accId, String descr, String title) {
        ContentVersion cv = new ContentVersion(
            Title = title, PathOnClient = 'f.pdf', VersionData = Blob.valueOf('x'),
            FirstPublishLocationId = accId, Description = descr
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
    }

    private static Approval_Request__c makeReq(Id accId, String status, Id newDoc, Id oldDoc) {
        Map<String, Object> p = new Map<String, Object>{
            'restoreDescription' => 'Trade License',
            'newContentDocumentId' => String.valueOf(newDoc),
            'oldContentDocumentId' => (oldDoc == null ? '' : String.valueOf(oldDoc)),
            'fileName' => 'new.pdf'
        };
        Approval_Request__c r = new Approval_Request__c(
            Request_Type__c = 'Document Re-upload', Related_Object_Type__c = 'Account',
            Related_Record_Id__c = String.valueOf(accId), Field_To_Update__c = 'Documents (multiple)',
            Current_Value__c = 'x', Requested_Value__c = 'y', Justification__c = 't',
            Profile_Changes_JSON__c = JSON.serialize(new List<Object>{ p }), Status__c = status   // array payload
        );
        insert r;
        return r;
    }

    private static Account makeAgency() {
        Account a = new Account(Name = 'Doc Agency ' + String.valueOf(Crypto.getRandomLong()), Skip_Trigger__c = true);
        insert a;
        return a;
    }

    @isTest
    static void approved_promotes_new_and_deletes_old() {
        Account acc = makeAgency();
        Id oldDoc = addFile(acc.Id, 'Trade License', 'old_tl');
        Id newDoc = addFile(acc.Id, 'Trade License (Pending Re-upload)', 'new_tl');
        Approval_Request__c req = makeReq(acc.Id, 'Approved', newDoc, oldDoc);

        Test.startTest();
        BrokerDocApprovalService.processDecisions(new Set<Id>{ req.Id });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :oldDoc], 'old file deleted');
        System.assertEquals('Trade License',
            [SELECT Description FROM ContentVersion WHERE ContentDocumentId = :newDoc AND IsLatest = true LIMIT 1].Description,
            'pending file promoted to official category');
        System.assertEquals('Applied', [SELECT Status__c FROM Approval_Request__c WHERE Id = :req.Id].Status__c);
    }

    @isTest
    static void rejected_deletes_pending_keeps_old() {
        Account acc = makeAgency();
        Id oldDoc = addFile(acc.Id, 'Trade License', 'old_tl');
        Id newDoc = addFile(acc.Id, 'Trade License (Pending Re-upload)', 'new_tl');
        Approval_Request__c req = makeReq(acc.Id, 'Rejected', newDoc, oldDoc);

        Test.startTest();
        BrokerDocApprovalService.applyDecision(new List<Id>{ req.Id });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :newDoc], 'pending file discarded');
        System.assertEquals(1, [SELECT COUNT() FROM ContentDocument WHERE Id = :oldDoc], 'official file kept');
    }

    @isTest
    static void ignores_another_accounts_file() {
        Account mine = makeAgency();
        Account other = makeAgency();
        Id othersDoc = addFile(other.Id, 'Trade License', 'others_tl');
        // Tampered: my request points its "old" at another account's file.
        Approval_Request__c req = makeReq(mine.Id, 'Approved', null, othersDoc);

        Test.startTest();
        BrokerDocApprovalService.processDecisions(new Set<Id>{ req.Id });
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM ContentDocument WHERE Id = :othersDoc],
            'another account\'s file must not be deleted');
    }

    @isTest
    static void empty_inputs_safe() {
        BrokerDocApprovalService.applyDecision(new List<Id>());
        BrokerDocApprovalService.processDecisions(null);
        System.assert(true, 'no exception on empty/null');
    }
}