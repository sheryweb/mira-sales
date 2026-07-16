public with sharing class ContentVersionController {
    @AuraEnabled(cacheable=true)
    public static List<ContentVersion> getContentVersions(Id accountId) {
        System.debug('Fetching ContentVersions for Account Id: ' + accountId);
        
        // Ensure accountId is not null
        if (accountId == null) {
            return new List<ContentVersion>();
        }
        
        try {
            // Query ContentDocumentLink to get ContentDocumentIds
            List<ContentDocumentLink> contentDocumentLinks = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :accountId
            ];
            
            // Extract ContentDocumentIds
            Set<Id> contentDocumentIds = new Set<Id>();
            for (ContentDocumentLink link : contentDocumentLinks) {
                contentDocumentIds.add(link.ContentDocumentId);
            }
            
            // Query ContentVersion using ContentDocumentIds
            List<ContentVersion> contentVersions = new List<ContentVersion>();
            if (!contentDocumentIds.isEmpty()) {
                contentVersions = [
                    SELECT Id, Title, Description, FileType, CreatedDate, ContentDocumentId
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :contentDocumentIds
                    ORDER BY CreatedDate DESC
                ];
            }
            
            System.debug('Fetched ContentVersions: ' + contentVersions);
            return contentVersions;
        } catch (System.QueryException e) {
            System.debug('QueryException: ' + e.getMessage());
            return new List<ContentVersion>();
        }
    }
}