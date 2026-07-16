public with sharing class FilePreviewAndDownloadController {
    @AuraEnabled(cacheable=true)
        public static Map<ID, String> getRelatedFilesByRecordId(String recordId) {
            //Get Record File ID
            ContentDocumentLink upFileId = [SELECT Id, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :recordId ORDER BY Id DESC Limit 1];
            
            //Get Uploaded document using Content Document Id
            ContentVersion upDoc = [SELECT ContentDocumentId, FileExtension, Title FROM ContentVersion WHERE ContentDocumentId = :upFileId.ContentDocumentId LIMIT 1];
            
            Map<ID, String> mapIdTitle = new Map<ID, String>();
            mapIdTitle.put(upDoc.ContentDocumentId, upDoc.Title);
            
            // Get record file IDs        
            /*List<ContentDocumentLink> files = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :recordId ORDER BY Id DESC LIMIT 1];
            List<ID> fileIDs = new List<ID>();
            for (ContentDocumentLink docLink : files) {
                fileIDs.add(docLink.ContentDocumentId);
            }
     
            List<ContentVersion> docs = [SELECT ContentDocumentId, FileExtension, Title 
                FROM ContentVersion WHERE ContentDocumentId IN : fileIDs];
            Map<ID, String> mapIdTitle = new Map<ID, String>();
            for (ContentVersion docLink : docs) {
                mapIdTitle.put(docLink.ContentDocumentId, docLink.Title);
            }*/
            return mapIdTitle;
        }
}