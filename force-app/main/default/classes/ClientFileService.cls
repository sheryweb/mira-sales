@RestResource(urlMapping='/ClientFileService/*')
global without sharing class ClientFileService {

    @HttpDelete
    global static void deleteClientFile() {
        RestRequest req = RestContext.request;
        String contentDocumentId = req.params.get('contentDocumentId');
        Map<String, Object> responseList = new Map<String, Object>();
        System.debug(contentDocumentId);

        if(contentDocumentId != null){
            List<ContentDocumentLink> cdlList = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId =:contentDocumentId];
            System.debug(cdlList);

            Set<Id> cdIds = new Set<Id>();
            Set<Id> fileIds = new Set<Id>();
            for(ContentDocumentLink cdl : cdlList){
                cdIds.add(cdl.ContentDocumentId);
                fileIds.add(cdl.LinkedEntityId);
            }
            System.debug(cdlList);

            if(!cdlList.isEmpty()){
                System.debug(cdlList);

                List<File__c> file = [SELECT Id, Type__c FROM File__c WHERE Id IN :fileIds];
                System.debug(file);
                delete file;
                List<ContentDocument> cdList = [SELECT Id FROM ContentDocument WHERE Id IN :cdIds];
                delete cdList;
            }
            
        }
    }

    @HttpGet
    global static void getClientFile() {
        RestRequest req = RestContext.request;
        String clientId = req.params.get('clientId');
        Map<String, Object> responseList = new Map<String, Object>();
        if(clientId != null){
            Map<Id,File__c> clientsFiles = new Map<Id,File__c>([SELECT Id, Type__c FROM File__c WHERE Client__c =:clientId]);
            System.debug(clientsFiles);
            Map<String,Object> filesMaps = getAttachedFiles(clientsFiles.keySet());
            System.debug(filesMaps);

            Map<Id, List<ContentDocumentLink>> fileToContentDocumentLinkMap = (Map<Id, List<ContentDocumentLink>>)filesMaps.get('fileToContentDocumentLinkMap');
            Map<Id, ContentVersion> cdlToContentVersionMap = (Map<Id, ContentVersion>)filesMaps.get('cdlToContentVersionMap');
            Map<Id, ContentDistribution> cvToContentDistributionMap = (Map<Id, ContentDistribution>)filesMaps.get('cvToContentDistributionMap');
            
            List<Map<String,Object>> clientFiles = new List<Map<String,Object>>();
            for(Id fileId : clientsFiles.keySet()){
                if(fileToContentDocumentLinkMap.containsKey(fileId)){
                    for(ContentDocumentLink cdl : fileToContentDocumentLinkMap.get(fileId)){
                        if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                            ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
                        
                            if (cvToContentDistributionMap.containsKey(cv.Id)) {
                                ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                                clientFiles.add(new Map<String,Object>{
                                    'file_type' => clientsFiles.get(fileId).Type__c,
                                    'content_document_id' => cdl.ContentDocumentId,
                                    'file_url' => cd.ContentDownloadUrl
                                });
                                // clientFiles.add(cd.ContentDownloadUrl);
                            }
                        }
                    }
                }
            }
            responseList.put('client_files',clientFiles);
        }

        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(responseList));
    }

    private static Map<String,Object> getAttachedFiles(Set<Id> fileIds){
        Map<String,Object> resultCollections = new Map<String,Object>();
        Map<Id, List<ContentDocumentLink>> fileToContentDocumentLinkMap = new Map<Id, List<ContentDocumentLink>>();
        Map<Id, ContentDistribution> cvToContentDistributionMap = new Map<Id, ContentDistribution>();
        Map<Id, ContentVersion> cdlToContentVersionMap = new Map<Id, ContentVersion>();
        Map<Id, ContentVersion> idToContentVersionMap = new Map<Id, ContentVersion>();
        Set<Id> contentDocumentLinkIds = new Set<Id>();

        List<ContentDocumentLink> cdlList = [SELECT ContentDocumentId, LinkedEntityid FROM ContentDocumentLink WHERE LinkedEntityid IN :fileIds];
        for (ContentDocumentLink cdl : cdlList) {
            if(fileToContentDocumentLinkMap.containsKey(cdl.LinkedEntityid)){
                List<ContentDocumentLink> contentDocumentLinks = fileToContentDocumentLinkMap.get(cdl.LinkedEntityid);
                contentDocumentLinks.add(cdl);
                fileToContentDocumentLinkMap.put(cdl.LinkedEntityid, contentDocumentLinks);
            } else {
                fileToContentDocumentLinkMap.put(cdl.LinkedEntityid, new List<ContentDocumentLink>{cdl});

            }
            contentDocumentLinkIds.add(cdl.ContentDocumentId);
        }


        if (!contentDocumentLinkIds.isEmpty()) {
            List<ContentVersion> cvList = [SELECT ContentDocument.LatestPublishedVersionId, Title, ContentDocumentId FROM ContentVersion WHERE ContentDocumentId IN :contentDocumentLinkIds];
            for (ContentVersion cv : cvList) {
                cdlToContentVersionMap.put(cv.ContentDocumentId, cv);
                idToContentVersionMap.put(cv.Id, cv);
            }
        }

        if (!cdlToContentVersionMap.isEmpty()) {
            List<ContentDistribution> cdList = [SELECT DistributionPublicUrl, ContentDownloadUrl, ContentVersionId FROM ContentDistribution WHERE ContentVersionId IN :idToContentVersionMap.keySet()];
            for (ContentDistribution cd : cdList) {
                cvToContentDistributionMap.put(cd.ContentVersionId, cd);
            }
            List<ContentDistribution> newCds = new List<ContentDistribution>();
            for(Id contentVersionId : idToContentVersionMap.keySet()){
                if(!cvToContentDistributionMap.containsKey(contentVersionId)){
                    ContentDistribution newCd = new ContentDistribution();
                    newCd.Name = idToContentVersionMap.get(contentVersionId).Title;
                    newCd.ContentVersionId = contentVersionId;
                    newCd.PreferencesAllowViewInBrowser = true;
                    newCd.PreferencesNotifyOnVisit = false;
                    newCds.add(newCd);
                }
            }
            insert newCds;
            cdList = [SELECT DistributionPublicUrl, ContentDownloadUrl, ContentVersionId FROM ContentDistribution WHERE ContentVersionId IN :idToContentVersionMap.keySet()];
            for (ContentDistribution cd : cdList) {
                cvToContentDistributionMap.put(cd.ContentVersionId, cd);
            }
        }
        resultCollections.put('fileToContentDocumentLinkMap', fileToContentDocumentLinkMap);
        resultCollections.put('cdlToContentVersionMap', cdlToContentVersionMap);
        resultCollections.put('cvToContentDistributionMap', cvToContentDistributionMap);
        return resultCollections;
    }
}