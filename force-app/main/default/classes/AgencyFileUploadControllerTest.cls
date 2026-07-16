@IsTest
public class AgencyFileUploadControllerTest {
    
    @TestSetup
    static void setup() {
        // Create a test account
        Account testAccount = new Account(Name='Test Account');
        insert testAccount;
        
        // Create a test user (assuming the user ID '005Hp00000j94YpIAI' is valid in the test environment)
        User testUser = new User(
            Alias = 'testusr',
            Email = 'tesssst@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User'].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'tesssst@example.com'
        );
        insert testUser;
    }
    
    @IsTest
    static void testCheckCategoryExists() {
        // Get the test account
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Test when category doesn't exist
        String result = AgencyFileUploadController.checkCategoryExists(testAccount.Id, 'NewCategory');
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assertEquals(true, resultMap.get('success'));
        System.assertEquals(false, resultMap.get('exists'));
        
        // Create a file and test existing category
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('Test Content'),
            FirstPublishLocationId = testAccount.Id,
            Description = 'ExistingCategory'
        );
        insert cv;
        
        result = AgencyFileUploadController.checkCategoryExists(testAccount.Id, 'ExistingCategory');
        resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assertEquals(true, resultMap.get('success'));
        System.assertEquals(true, resultMap.get('exists'));
    }
    
    @IsTest
    static void testUploadFile() {
        // Get the test account
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Test successful upload
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Test Content'));
        String result = AgencyFileUploadController.uploadFile(
            testAccount.Id, 
            'NewCategory', 
            'test.pdf', 
            base64Data
        );
        
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assertEquals(true, resultMap.get('success'));
        
        // Verify file was created
        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion WHERE FirstPublishLocationId = :testAccount.Id];
        System.assertEquals(1, cvs.size());
        
        // Test duplicate category
        result = AgencyFileUploadController.uploadFile(
            testAccount.Id, 
            'NewCategory', 
            'test2.pdf', 
            base64Data
        );
        resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assertEquals(false, resultMap.get('success'));
    }
    
    @IsTest
    static void testUpdateAccountStatus() {
        // Get the test account
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        String result = AgencyFileUploadController.updateAccountStatus(testAccount.Id);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assertEquals('success', resultMap.get('status'));
        
        testAccount = [SELECT Status__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals('In Process', testAccount.Status__c);
    }
    
    @IsTest
    static void testGetUploadedFiles() {
        // Get the test account
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create test files
        List<ContentVersion> versions = new List<ContentVersion>();
        for(Integer i = 0; i < 3; i++) {
            versions.add(new ContentVersion(
                Title = 'Test File ' + i,
                PathOnClient = 'test' + i + '.pdf',
                VersionData = Blob.valueOf('Test Content ' + i),
                FirstPublishLocationId = testAccount.Id,
                Description = 'Category' + i
            ));
        }
        insert versions;
        
        Test.startTest();
        String result = AgencyFileUploadController.getUploadedFiles(testAccount.Id);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assertEquals(true, resultMap.get('success'));
        
        List<Object> files = (List<Object>)resultMap.get('files');
        System.assertEquals(3, files.size());
        
        // Verify contentDocumentId is included in the response
        Map<String, Object> firstFile = (Map<String, Object>)files[0];
        System.assertNotEquals(null, firstFile.get('contentDocumentId'), 'ContentDocumentId should be included in the response');
    }
    
    @IsTest
    static void testDeleteFile() {
        // Get the test account
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create a test file
        ContentVersion cv = new ContentVersion(
            Title = 'Test Delete File',
            PathOnClient = 'testDelete.pdf',
            VersionData = Blob.valueOf('Test Content'),
            FirstPublishLocationId = testAccount.Id,
            Description = 'DeleteCategory'
        );
        insert cv;
        
        // Get the ContentDocument Id
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        String contentDocumentId = cv.ContentDocumentId;
        
        Test.startTest();
        
        // Test successful deletion
        String result = AgencyFileUploadController.deleteFile(
            testAccount.Id,
            contentDocumentId,
            'DeleteCategory'
        );
        
        Map<String, Object> resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assertEquals(true, resultMap.get('success'), 'File deletion should be successful');
        System.assertEquals('DeleteCategory', resultMap.get('category'), 'Category should match in response');
        
        // Verify file was deleted
        List<ContentDocument> remainingDocs = [SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId];
        System.assertEquals(0, remainingDocs.size(), 'ContentDocument should be deleted');
        
        // Test deletion with invalid document Id
        result = AgencyFileUploadController.deleteFile(
            testAccount.Id,
            'invalid_id',
            'DeleteCategory'
        );
        
        resultMap = (Map<String, Object>)JSON.deserializeUntyped(result);
        System.assertEquals(false, resultMap.get('success'), 'Deletion with invalid ID should fail');
        System.assert(((String)resultMap.get('message')).contains('Error deleting file'), 'Error message should be returned');
        
        Test.stopTest();
    }
}