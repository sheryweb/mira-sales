@IsTest
private class FileUploadServiceTest {

    @TestSetup
    static void setup() {
        // Create test data - a test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
    }

    @IsTest
    static void testHandleFileUploadSuccess() {
        // Retrieve the test account created in the TestSetup method
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        // Simulate file content (Base64 encoded)
        String fileName = 'TestFile.txt';
        String fileContent = EncodingUtil.base64Encode(Blob.valueOf('Test file content'));
        String contentType = 'text/plain';

        Test.startTest();
        // Call the method with test data
        String response = FileUploadService.handleFileUpload(testAccount.Id, fileName, fileContent, contentType);
        Test.stopTest();

        // Parse the response as a Map<String, Object>
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response);

        // Assertions
        System.assertEquals('true', responseMap.get('success'), 'Expected success to be true');
        System.assertEquals('File uploaded successfully', responseMap.get('message'), 'Expected success message');
        
        // Verify ContentVersion was created
        ContentVersion contentVersion = [SELECT Id, Title FROM ContentVersion WHERE Title = :fileName LIMIT 1];
        System.assertNotEquals(null, contentVersion, 'ContentVersion should be created');

        // Verify ContentDocumentLink was created
        ContentDocumentLink contentLink = [SELECT Id, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :testAccount.Id LIMIT 1];
        System.assertNotEquals(null, contentLink, 'ContentDocumentLink should be created');
    }

    @IsTest
    static void testHandleFileUploadFailure() {
        // Simulate invalid file content to trigger an exception
        String invalidFileContent = 'invalidBase64Content';
        String fileName = 'InvalidFile.txt';
        String contentType = 'text/plain';

        Test.startTest();
        // Call the method with invalid file content to trigger an exception
        String response = FileUploadService.handleFileUpload(null, fileName, invalidFileContent, contentType);
        Test.stopTest();

        // Parse the response as a Map<String, Object>
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response);

        // Assertions
        System.assertEquals('false', responseMap.get('success'), 'Expected success to be false');
        System.assertNotEquals(null, responseMap.get('error'), 'Expected error message');
    }
}