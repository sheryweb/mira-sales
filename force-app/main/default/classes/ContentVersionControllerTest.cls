@isTest
public class ContentVersionControllerTest {
    @isTest
    static void testGetContentVersions() {
        // Create a test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        // Create a test ContentVersion
        ContentVersion contentVersion = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test file content'),
            FirstPublishLocationId = testAccount.Id,
            Description = 'Category: Test'
        );
        insert contentVersion;

        // Query the ContentDocumentId from the inserted ContentVersion
        contentVersion = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];

        // Check if ContentDocumentLink already exists
        List<ContentDocumentLink> existingLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testAccount.Id AND ContentDocumentId = :contentVersion.ContentDocumentId
        ];

        // Create a test ContentDocumentLink if it doesn't exist
        if (existingLinks.isEmpty()) {
            ContentDocumentLink contentDocumentLink = new ContentDocumentLink(
                LinkedEntityId = testAccount.Id,
                ContentDocumentId = contentVersion.ContentDocumentId,
                ShareType = 'I'
            );
            insert contentDocumentLink;
        }

        // Test the getContentVersions method
        Test.startTest();
        List<ContentVersion> result = ContentVersionController.getContentVersions(testAccount.Id);
        Test.stopTest();

        // Verify the result
        System.assertEquals(1, result.size());
        System.assertEquals('Test File', result[0].Title);
        System.assertEquals('Category: Test', result[0].Description);
        System.assertEquals('PDF', result[0].FileType); // Update to reflect the actual file type
    }

    @isTest
    static void testGetContentVersions_NoResults() {
        // Create a test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        // Test the getContentVersions method with no ContentVersions
        Test.startTest();
        List<ContentVersion> result = ContentVersionController.getContentVersions(testAccount.Id);
        Test.stopTest();

        // Verify the result
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetContentVersions_InvalidAccountId() {
        // Test the getContentVersions method with an invalid accountId
        Test.startTest();
        List<ContentVersion> result = ContentVersionController.getContentVersions(null);
        Test.stopTest();

        // Verify the result
        System.assertEquals(0, result.size());
    }
}