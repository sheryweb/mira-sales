global without sharing class AgencyFileUploadController {
    public String accountId { get; set; }
    public Boolean hasError { get; private set; }
    public String errorMessage { get; private set; }

    //Add this constructor for testing
    @TestVisible
    private AgencyFileUploadController(String accId) {
        this.accountId = accId;
        this.hasError = false;
    }

    //Keep the original constructor
    public AgencyFileUploadController() {
        accountId = ApexPages.currentPage().getParameters().get('accountId');
        hasError = false;
        //validateInit();
    }

    @RemoteAction
    public static String checkCategoryExists(String accountId, String category) {
        List<ContentDocumentLink> existingFiles = [
            SELECT Id 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :accountId 
            AND ContentDocument.LatestPublishedVersion.Description = :category
            LIMIT 1
        ];
        return JSON.serialize(new Map<String, Object>{
            'success' => true,
            'exists' => !existingFiles.isEmpty()
        });
    }

    @RemoteAction
    public static String uploadFile(String accountId, String category, String fileName, String base64Data) {
        List<ContentDocumentLink> existingFiles = [
            SELECT Id 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :accountId 
            AND ContentDocument.LatestPublishedVersion.Description = :category
            LIMIT 1
        ];
        
        if(!existingFiles.isEmpty()) {
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Same category cannot be uploaded twice'
            });
        }
        
        ContentVersion contentVersion = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = EncodingUtil.base64Decode(base64Data),
            FirstPublishLocationId = accountId,
            Description = category
        );
        insert contentVersion;

        // Get the user ID dynamically in production, or use running user in test
        Id ownerId;
        if(!Test.isRunningTest()) {
            ownerId = '005Hp00000j94YpIAI'; //Nazeer's User ID in production
        } else {
            ownerId = UserInfo.getUserId(); //Use running user in test context
        }

        //Update the OwnerId of the ContentVersion
        contentVersion = [SELECT Id, OwnerId, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
        contentVersion.OwnerId = ownerId;
        update contentVersion;

        // Make the file visible to the Broker Portal (external/guest) via the Account link, so the
        // broker can see their own documents. Best-effort: an issue here must never break the upload.
        try {
            List<ContentDocumentLink> links = [
                SELECT Id, Visibility FROM ContentDocumentLink
                WHERE ContentDocumentId = :contentVersion.ContentDocumentId AND LinkedEntityId = :accountId
            ];
            for (ContentDocumentLink l : links) l.Visibility = 'AllUsers';
            if (!links.isEmpty()) update links;
        } catch (Exception e) {
            System.debug('Could not set file link visibility to AllUsers: ' + e.getMessage());
        }

        return JSON.serialize(new Map<String, Object>{
            'success' => true,
            'message' => 'File uploaded successfully'
        });
    }

    @RemoteAction
    public static String updateAccountStatus(String accountId) {
        Account account = [SELECT Id, Status__c FROM Account WHERE Id = :accountId LIMIT 1];
        account.Status__c = 'In Process';
        update account;
        
        return JSON.serialize(new Map<String, String>{
            'status' => 'success',
            'message' => 'Account status updated successfully'
        });
    }

    @RemoteAction
    public static String getAccountStatus(String accountId) {
        Account account = [SELECT Status__c FROM Account WHERE Id = :accountId LIMIT 1];
        return account.Status__c;
    }

    @RemoteAction
    public static String getUploadedFiles(String accountId) {
        List<Map<String, String>> filesList = new List<Map<String, String>>();
        List<ContentDocumentLink> contentLinks = [
            SELECT ContentDocument.Id,
                   ContentDocument.Title, 
                   ContentDocument.FileType,
                   ContentDocument.LatestPublishedVersion.Description,
                   ContentDocument.CreatedDate
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :accountId
            ORDER BY ContentDocument.CreatedDate DESC
        ];
        
        for(ContentDocumentLink cdl : contentLinks) {
            filesList.add(new Map<String, String>{
                'fileName' => cdl.ContentDocument.Title,
                'category' => cdl.ContentDocument.LatestPublishedVersion.Description,
                'fileType' => cdl.ContentDocument.FileType,
                'timestamp' => String.valueOf(cdl.ContentDocument.CreatedDate.getTime()),
                'contentDocumentId' => cdl.ContentDocument.Id
            });
        }

        Account account = [SELECT Status__c FROM Account WHERE Id = :accountId LIMIT 1];
        
        return JSON.serialize(new Map<String, Object>{
            'success' => true,
            'files' => filesList,
            'accountStatus' => account.Status__c
        });
    }

    @RemoteAction
    public static String deleteFile(String accountId, String contentDocumentId, String category) {
        try {
            // Query the ContentDocument to delete
            ContentDocument doc = [SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId LIMIT 1];
            delete doc;
            
            return JSON.serialize(new Map<String, Object>{
                'success' => true,
                'message' => 'File deleted successfully',
                'category' => category
            });
        } catch (Exception e) {
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Error deleting file: ' + e.getMessage()
            });
        }
    }
}