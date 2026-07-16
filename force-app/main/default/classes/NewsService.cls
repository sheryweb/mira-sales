@RestResource(urlMapping='/newsService/*')
global without sharing class NewsService {

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        String createdDateFilter = req.params.get('createdDate');
        String unitIdFilter = req.params.get('unitId');
        String limitRowsFilter = req.params.get('limitRows');
        String orderByFilter = req.params.get('orderBy');
        String offsetFilter = req.params.get('offset');
        String dateFilter = req.params.get('date');


        String mainQuery = buildQuery(unitIdFilter, dateFilter, createdDateFilter, orderByFilter, limitRowsFilter, offsetFilter);

        List<News__c> newsList = Database.query(mainQuery);
        System.debug(mainQuery);
        System.debug(newsList);
        Map<Id, List<File__c>> newsIdToPreviewFiles = new Map<Id, List<File__c>>();
        Map<Id, List<File__c>> newsIdToPictureFiles = new Map<Id, List<File__c>>();
        Set<Id> fileIds = new Set<Id>();
        for (News__c news : newsList) {
            if (news.Files__r != null && !news.Files__r.isEmpty()) {
                List<File__c> newsPreviewFiles = new List<File__c>();
                List<File__c> newsPictureFiles = new List<File__c>();

                for(File__c file : news.Files__r){
                    if(file.Type__c == 'News Preview'){
                        newsPreviewFiles.add(file);
                        fileIds.add(file.Id);
                    } else if (file.Type__c == 'News Content Photo'){
                        newsPictureFiles.add(file);
                        fileIds.add(file.Id);
                    }
                }
                newsIdToPreviewFiles.put(news.Id, newsPreviewFiles);
                newsIdToPictureFiles.put(news.Id, newsPictureFiles);
            }
        }

        Map<String,Object> filesMaps = getAttachedFiles(fileIds);

        Map<Id, ContentDocumentLink> fileToContentDocumentLinkMap = (Map<Id, ContentDocumentLink>)filesMaps.get('fileToContentDocumentLinkMap');
        Map<Id, ContentVersion> cdlToContentVersionMap = (Map<Id, ContentVersion>)filesMaps.get('cdlToContentVersionMap');
        Map<Id, ContentDistribution> cvToContentDistributionMap = (Map<Id, ContentDistribution>)filesMaps.get('cvToContentDistributionMap');

        List<Map<String, Object>> responseList = new List<Map<String, Object>>();
        for (News__c news : newsList) {
            if(unitIdFilter != null && newsIdToPreviewFiles.get(news.Id) == null){
                continue;
            } else {
                Map<String, Object> newsMap = new Map<String, Object>();
                newsMap.put('Name', news.Name);
                newsMap.put('Description__c', news.Description__c);
                newsMap.put('CreatedDate', news.CreatedDate);
                newsMap.put('Date', news.Date__c);

                List<String> pictures = new List<String>();
                if (newsIdToPictureFiles.get(news.Id) != null && !newsIdToPictureFiles.get(news.Id).isEmpty()) {
                    for(File__c file : newsIdToPictureFiles.get(news.Id)){
                        if(fileToContentDocumentLinkMap.containsKey(file.Id)){
                            ContentDocumentLink cdl = fileToContentDocumentLinkMap.get(file.Id);
                            if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                                ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
                                if (cvToContentDistributionMap.containsKey(cv.Id)) {
                                    ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                                    pictures.add(cd.ContentDownloadUrl);
                                }
                            }
                        }
                    }
                }
                newsMap.put('Pictures', pictures);

                if (newsIdToPreviewFiles.get(news.Id) != null && !newsIdToPreviewFiles.get(news.Id).isEmpty() && fileToContentDocumentLinkMap.containsKey(newsIdToPreviewFiles.get(news.Id)[0].Id)) {
                    ContentDocumentLink cdl = fileToContentDocumentLinkMap.get(newsIdToPreviewFiles.get(news.Id)[0].Id);
        
                    if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                        ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
        
                        if (cvToContentDistributionMap.containsKey(cv.Id)) {
                            ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                            newsMap.put('News_preview', cd.ContentDownloadUrl);
                        }
                    }
                }
                responseList.add(newsMap);
            }
        }

        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(responseList));
    }

    private static Map<String,Object> getAttachedFiles(Set<Id> fileIds){
        Map<String,Object> resultCollections = new Map<String,Object>();
        Map<Id, ContentDocumentLink> fileToContentDocumentLinkMap = new Map<Id, ContentDocumentLink>();
        Map<Id, ContentVersion> cdlToContentVersionMap = new Map<Id, ContentVersion>();
        Map<Id, ContentDistribution> cvToContentDistributionMap = new Map<Id, ContentDistribution>();
        Map<Id, ContentVersion> idToContentVersionMap = new Map<Id, ContentVersion>();
        Set<Id> contentDocumentLinkIds = new Set<Id>();

        if (!fileIds.isEmpty()) {
            List<ContentDocumentLink> cdlList = [SELECT ContentDocumentId, LinkedEntityid FROM ContentDocumentLink WHERE LinkedEntityid IN :fileIds];
            for (ContentDocumentLink cdl : cdlList) {
                fileToContentDocumentLinkMap.put(cdl.LinkedEntityid, cdl);
                contentDocumentLinkIds.add(cdl.ContentDocumentId);
            }
        }



        if (!fileToContentDocumentLinkMap.isEmpty()) {
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

    private static String buildQuery(String unitIdFilter, String dateFilter, String createdDateFilter, String orderByFilter, String limitRowsFilter, String offsetFilter){

        String mainQuery = 'SELECT Id, Name, Description__c, CreatedDate, Date__c, '+
        '(SELECT Id, Type__c FROM Files__r WHERE (Type__c = \'News Preview\' OR Type__c = \'News Content Photo\') ';

        if (unitIdFilter != null) {
            mainQuery += ' AND Unit__c = \'' + unitIdFilter + '\'';
        }

        mainQuery += ' ORDER BY CreatedDate ASC) FROM News__c';

        // if(createdDateFilter != null || dateFilter != null){
            mainQuery += ' WHERE Status__c != \'Draft\''; 
        // }

        if (createdDateFilter != null) {
            mainQuery += ' AND CreatedDate ' + createdDateFilter;
        }

        // if(createdDateFilter != null && dateFilter != null){
        //     mainQuery += ' AND '; 
        // }

        if (dateFilter != null) {
            mainQuery += ' AND Date__c ' + dateFilter;
        }

        if (orderByFilter != null) {
            mainQuery += ' ORDER BY ' + orderByFilter;
        }

        if (limitRowsFilter != null) {
            mainQuery += ' LIMIT ' + Integer.valueOf(limitRowsFilter);
        }

        if (offsetFilter != null) {
            mainQuery += ' OFFSET ' + offsetFilter;
        }

        return mainQuery;
    }
}