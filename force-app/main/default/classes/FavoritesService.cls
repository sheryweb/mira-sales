@RestResource(urlMapping='/favoritesService/*')
global without sharing class FavoritesService {

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;

        List<Favorite__c> favoritesList = [
            SELECT Id, Unit__r.Id, Unit__r.Title_Formula__c, 
            Unit__r.Project__r.Name, Unit__r.Type__c, Unit__r.Cost_AED__c,
            Unit__r.Total_Area__c, Unit__r.Living_Space__c, Unit__r.Additional_Area__c,
            Unit__r.Floor__c, Unit__r.Number_of_Bedrooms__c, Unit__r.Number_of_Bathrooms__c
            FROM Favorite__c WHERE OwnerId = :UserInfo.getUserId() AND Unit__r.Status__c = 'Published'
            AND Unit__r.Project__r.Publish_Project__c = 'Published'
        ];
        Map<String,String> favIdToUnitId = new Map<String,String>();
        for (Favorite__c favorite : favoritesList) {
            favIdToUnitId.put(favorite.Id, favorite.Unit__r.Id);
        }
        
        List<File__c> files = [
            SELECT Id, Unit__c
            FROM File__c 
            WHERE Type__c = 'Unit Layout Preview' AND Unit__c IN :favIdToUnitId.values()
        ];

        Map<Id,File__c> unitIdToFile = new Map<Id,File__c>();
        Set<Id> fileIds = new Set<Id> ();
        for(File__c file : files){
            unitIdToFile.put(file.Unit__c, file);
            fileIds.add(file.Id);
        }
        System.debug(fileIds);
        Map<Id, List<ContentDocumentLink>> fileToContentDocumentLinkMap = new Map<Id, List<ContentDocumentLink>>();
        Map<Id, ContentVersion> cdlToContentVersionMap = new Map<Id, ContentVersion>();
        Map<Id, ContentDistribution> cvToContentDistributionMap = new Map<Id, ContentDistribution>();
        if(!fileIds.isEmpty()){
            Map<String,Object> filesMaps = getAttachedFiles(fileIds);

            fileToContentDocumentLinkMap = (Map<Id, List<ContentDocumentLink>>)filesMaps.get('fileToContentDocumentLinkMap');
            cdlToContentVersionMap = (Map<Id, ContentVersion>)filesMaps.get('cdlToContentVersionMap');
            cvToContentDistributionMap = (Map<Id, ContentDistribution>)filesMaps.get('cvToContentDistributionMap');
        }

        List<Map<String, Object>> responseList = new List<Map<String, Object>>();
        for (Favorite__c favorite : favoritesList) {
            Map<String, Object> favoriteMap = new Map<String, Object>();
            favoriteMap.put('id', favorite.Id);
            

            String layoutPreview;
        if(!fileIds.isEmpty()){

            if(unitIdToFile.containsKey(favorite.Unit__r.Id) && fileToContentDocumentLinkMap.containsKey(unitIdToFile.get(favorite.Unit__r.Id).Id)){
                ContentDocumentLink cdl = fileToContentDocumentLinkMap.get(unitIdToFile.get(favorite.Unit__r.Id).Id)[0];

                if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                    ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
                
                    if (cvToContentDistributionMap.containsKey(cv.Id)) {
                        ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                        layoutPreview = cd.ContentDownloadUrl;
                    }
                }
            }
        }
            favoriteMap.put('Unit', new Map<String, Object>{
                'id' => favorite.Unit__r.Id,
                'title'=> favorite.Unit__r.Title_Formula__c,
                'project_title'=> favorite.Unit__r.Project__r.Name,
                'price'=> favorite.Unit__r.Cost_AED__c,
                'type'=> favorite.Unit__r.Type__c,
                'layout_preview' => layoutPreview,
                'total_area' => favorite.Unit__r.Total_Area__c,
                'living_area' => favorite.Unit__r.Living_Space__c,
                'extra_area' => favorite.Unit__r.Additional_Area__c,
                'floor' => favorite.Unit__r.Floor__c,
                'bedrooms' => favorite.Unit__r.Number_of_Bedrooms__c,
                'bathrooms' => favorite.Unit__r.Number_of_Bathrooms__c
            });
            responseList.add(favoriteMap);
        }

        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Map<String,List<Map<String, Object>>>{'favorites' => responseList}));
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