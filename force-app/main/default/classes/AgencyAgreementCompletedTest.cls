@isTest
public class AgencyAgreementCompletedTest {
    @isTest
    static void testSendEmailNotification() {
        // Create a test Account
        Account testAccount = new Account(
            Name = 'Test Account',
            Company_Email__c = 'test@example.com',
            Assigned_RM__c = 'Test RM'
        );
        insert testAccount;

        // Create a test ContentVersion (simulating a PDF attachment)
        Blob pdfBlob = Blob.valueOf('This is a test PDF content'); // Simulated PDF content
        ContentVersion testContentVersion = new ContentVersion(
            Title = 'NOC_Broker Agreement - Fully Executed',
            VersionData = pdfBlob,
            IsMajorVersion = true,
            PathOnClient = 'NOC_Broker_Agreement.pdf' // Required for ContentVersion
        );
        insert testContentVersion; // Insert the ContentVersion

        // Query the ContentDocumentId from the inserted ContentVersion
        ContentVersion insertedContentVersion = [
            SELECT ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :testContentVersion.Id 
            LIMIT 1
        ];

        // Now create a ContentDocumentLink to attach the ContentVersion to the Account
        ContentDocumentLink docLink = new ContentDocumentLink(
            ContentDocumentId = insertedContentVersion.ContentDocumentId,
            LinkedEntityId = testAccount.Id,
            ShareType = 'V'
        );
        insert docLink; // Insert the ContentDocumentLink

        // Create a list of record IDs to pass to the method
        List<Id> recordIds = new List<Id> { testAccount.Id };

        // Call the method to send email
        Test.startTest();
        AgencyAgreementCompleted.sendEmailNotification(recordIds);
        Test.stopTest();
    }
}