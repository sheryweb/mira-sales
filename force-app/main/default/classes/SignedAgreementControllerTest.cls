@isTest
private class SignedAgreementControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create test account with all required fields
        Account testAcc = new Account(
            Name = 'Test Account',
            Company_Email__c = 'company@example.com',
            Contact_Email_2__c = 'contact@example.com'
        );
        insert testAcc;
    }

    @isTest
    static void testUploadFileToAccount_Success() {
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        String base64Body = EncodingUtil.base64Encode(Blob.valueOf('Test PDF file content'));

        Test.startTest();
        String contentDocId = SignedAgreementController.uploadFileToAccount(
            testAcc.Id,
            'TestFile.pdf',
            base64Body,
            'application/pdf'
        );
        Test.stopTest();

        System.assertNotEquals(null, contentDocId, 'ContentDocumentId should not be null');
        
        // Verify the content version was created correctly
        ContentVersion cv = [
            SELECT Id, Title, PathOnClient, FirstPublishLocationId 
            FROM ContentVersion 
            WHERE ContentDocumentId = :contentDocId
            LIMIT 1
        ];
        System.assertEquals('TestFile.pdf', cv.Title, 'File title should match');
        System.assertEquals(testAcc.Id, cv.FirstPublishLocationId, 'File should be linked to the account');
    }

    @isTest
    static void testUploadFileToAccount_EmptyContent() {
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Boolean exceptionThrown = false;
        
        Test.startTest();
        try {
            SignedAgreementController.uploadFileToAccount(
                testAcc.Id,
                'TestFile.pdf',
                '',
                'application/pdf'
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown for empty content');
        
        // Verify no ContentVersion was created
        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion WHERE FirstPublishLocationId = :testAcc.Id];
        System.assertEquals(0, cvs.size(), 'No ContentVersion should have been created');
    }

    @isTest
    static void testSendEmailWithContentVersion_Success() {
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        // Create test content version
        ContentVersion cv = new ContentVersion(
            Title = 'Test Agreement.pdf',
            PathOnClient = 'Test Agreement.pdf',
            VersionData = Blob.valueOf('Test PDF Content'),
            FirstPublishLocationId = testAcc.Id,
            IsMajorVersion = true
        );
        insert cv;

        // Query for the inserted ContentVersion to get its ID
        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        Test.startTest();
        System.assertEquals(0, Limits.getEmailInvocations(), 'No emails should be sent yet');
        
        SignedAgreementController.sendEmailWithContentVersion(testAcc.Id, cv.Id);
        
        System.assertEquals(1, Limits.getEmailInvocations(), 'One email should have been sent');
        Test.stopTest();

        // Verify account was updated
        testAcc = [SELECT Renewal_Completed__c FROM Account WHERE Id = :testAcc.Id];
        System.assertNotEquals(null, testAcc.Renewal_Completed__c, 'Renewal completion date should be set');
        System.assertEquals(Date.today(), testAcc.Renewal_Completed__c, 'Renewal completion date should be today');
    }

    @isTest
    static void testSendEmailWithContentVersion_NoEmails() {
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        testAcc.Company_Email__c = null;
        testAcc.Contact_Email_2__c = null;
        update testAcc;

        ContentVersion cv = new ContentVersion(
            Title = 'Test Agreement.pdf',
            PathOnClient = 'Test Agreement.pdf',
            VersionData = Blob.valueOf('Test PDF Content'),
            FirstPublishLocationId = testAcc.Id,
            IsMajorVersion = true
        );
        insert cv;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            SignedAgreementController.sendEmailWithContentVersion(testAcc.Id, cv.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown for no recipient emails');
    }

    @isTest
    static void testSendEmailWithContentVersion_InvalidContentVersion() {
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            SignedAgreementController.sendEmailWithContentVersion(testAcc.Id, '068000000000000AAA');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown for invalid content version');
    }

    @isTest
    static void testSendEmailWithContentVersion_InvalidAccount() {
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        ContentVersion cv = new ContentVersion(
            Title = 'Test Agreement.pdf',
            PathOnClient = 'Test Agreement.pdf',
            VersionData = Blob.valueOf('Test PDF Content'),
            FirstPublishLocationId = testAcc.Id,
            IsMajorVersion = true
        );
        insert cv;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            SignedAgreementController.sendEmailWithContentVersion('001000000000000AAA', cv.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An AuraHandledException should have been thrown for invalid account');
    }
}