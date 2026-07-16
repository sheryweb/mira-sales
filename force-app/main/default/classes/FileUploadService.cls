@RestResource(urlMapping='/FileUploadService/*')
global with sharing class FileUploadService {

    @HttpPost
    global static String handleFileUpload(String accountId, String fileName, String fileContent, String contentType) {
        try {
            Blob fileBlob = EncodingUtil.base64Decode(fileContent);
            
            // Create ContentVersion record to upload the file in Salesforce
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.VersionData = fileBlob;
            contentVersion.PathOnClient = fileName;
            contentVersion.Title = fileName;
            insert contentVersion;

            // Associate the ContentVersion with the Account
            ContentDocumentLink contentLink = new ContentDocumentLink();
            contentLink.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id].ContentDocumentId;
            contentLink.LinkedEntityId = accountId; 
            contentLink.ShareType = 'V'; 
            insert contentLink;

            return JSON.serialize(new Map<String, String>{
                'success' => 'true',
                'message' => 'File uploaded successfully'
            });
        } catch (Exception e) {
            return JSON.serialize(new Map<String, String>{
                'success' => 'false',
                'error' => e.getMessage()
            });
        }
    }
}