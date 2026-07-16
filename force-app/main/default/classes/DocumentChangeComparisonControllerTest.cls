@isTest
private class DocumentChangeComparisonControllerTest {

    private static Id addFile(Id accId, String title) {
        ContentVersion cv = new ContentVersion(
            Title = title, PathOnClient = 'f.pdf', VersionData = Blob.valueOf('x'), FirstPublishLocationId = accId
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
    }

    private static Approval_Request__c makeReq(Id accId, String type, String json) {
        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = type, Related_Object_Type__c = 'Account',
            Related_Record_Id__c = (accId == null) ? null : String.valueOf(accId),
            Field_To_Update__c = 'Documents (multiple)', Current_Value__c = 'x', Requested_Value__c = 'y',
            Justification__c = 'Document re-upload from Broker Portal',
            Profile_Changes_JSON__c = json, Status__c = 'Pending'
        );
        insert req;
        return req;
    }

    @isTest
    static void returns_document_pairs() {
        Account acc = new Account(Name = 'Doc Cmp Agency', Skip_Trigger__c = true);
        insert acc;
        Id oldId = addFile(acc.Id, 'Trade License');
        Id newId = addFile(acc.Id, 'Trade License NEW');

        String json = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'oldContentDocumentId' => String.valueOf(oldId), 'newContentDocumentId' => String.valueOf(newId),
                'oldFileName' => 'Trade License', 'newFileName' => 'Trade License NEW', 'restoreDescription' => ''
            }
        });
        Approval_Request__c req = makeReq(acc.Id, 'Document Re-upload', json);

        Test.startTest();
        DocumentChangeComparisonController.Comparison c =
            DocumentChangeComparisonController.getDocComparison(req.Id);
        Test.stopTest();

        System.assertEquals(false, c.notApplicable);
        System.assertEquals('Doc Cmp Agency', c.agencyName);
        System.assertEquals(1, c.docs.size());
        System.assertEquals('Trade License', c.docs[0].oldFileName);
        System.assertEquals('Trade License NEW', c.docs[0].newFileName);
        System.assertEquals(String.valueOf(oldId), c.docs[0].oldDocId);
        System.assertEquals(String.valueOf(newId), c.docs[0].newDocId);
    }

    @isTest
    static void non_doc_request_is_not_applicable() {
        Approval_Request__c req = makeReq(null, 'Unit Price Change', '[]');
        DocumentChangeComparisonController.Comparison c =
            DocumentChangeComparisonController.getDocComparison(req.Id);
        System.assertEquals(true, c.notApplicable);
    }
}