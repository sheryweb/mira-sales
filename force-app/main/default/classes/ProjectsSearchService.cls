@RestResource(urlMapping='/projectsSearch')
global without sharing class ProjectsSearchService {

    @HttpGet
    global static void doGet() {

        RestRequest req = RestContext.request;
        String minimalPriceParam = req.params.get('minimalPrice');
        String maximalPriceParam = req.params.get('maximalPrice');
        String projectsParam = req.params.get('projects');
        String sortParam = req.params.get('sort');
        String districtsParam = req.params.get('districts');
        String typesParam = req.params.get('types');
        String bedroomsParam = req.params.get('bedrooms');
        String statusParam = req.params.get('status');

        List<String> projects = new List<String>();
        List<String> districts = new List<String>();
        List<String> types = new List<String>();
        List<String> bedrooms = new List<String>();
        List<String> status = new List<String>();

        if(projectsParam != null){
            projects = projectsParam.split(',');
        }

        if(districtsParam != null){
            districts = districtsParam.split(',');
        }

        if(typesParam != null){
            types = typesParam.split(',');
        }

        if(bedroomsParam != null){
            bedrooms = bedroomsParam.split(',');
        }

        if(statusParam != null){
            status = statusParam.split(',');
        }
        String mainQuery = buildQuery(minimalPriceParam, maximalPriceParam, projects, districts, types, status, bedrooms, sortParam);

        List<Unit__c> unitList = Database.query(mainQuery);

        Map<Id, List<File__c>> unitIdToFiles = new Map<Id, List<File__c>>();
        Set<Id> fileIds = new Set<Id>();
        for (Unit__c unit : unitList) {
            if (unit.Files__r != null && !unit.Files__r.isEmpty()) {
                List<File__c> unitFiles = new List<File__c>();

                for(File__c file : unit.Files__r){
                    
                    unitFiles.add(file);
                    fileIds.add(file.Id);
                }
                unitIdToFiles.put(unit.Id, unitFiles);
            }
        }

        Map<String,Object> filesMaps = getAttachedFiles(fileIds);

        Map<Id, ContentDocumentLink> fileToContentDocumentLinkMap = (Map<Id, ContentDocumentLink>)filesMaps.get('fileToContentDocumentLinkMap');
        Map<Id, ContentVersion> cdlToContentVersionMap = (Map<Id, ContentVersion>)filesMaps.get('cdlToContentVersionMap');
        Map<Id, ContentDistribution> cvToContentDistributionMap = (Map<Id, ContentDistribution>)filesMaps.get('cvToContentDistributionMap');

        List<Map<String, Object>> responseList = new List<Map<String, Object>>();
        for (Unit__c unit : unitList) {
                Map<String, Object> unitMap = new Map<String, Object>();
                unitMap.put('id', unit.Id);
                unitMap.put('title', unit.Title_Formula__c);
                unitMap.put('type', unit.Type__c);
                unitMap.put('price', unit.Cost_AED__c);
                unitMap.put('total_area', unit.Total_Area__c);
                unitMap.put('living_area', unit.Living_Space__c);
                unitMap.put('extra_area', unit.Additional_Area__c);
                unitMap.put('floor', unit.Floor__c);
                unitMap.put('bedrooms', unit.Number_of_Bedrooms__c);
                unitMap.put('bathrooms', unit.Number_of_Bathrooms__c);
                unitMap.put('project_title', unit.Project__r.Name);

                if(!unit.Favorites__r.isEmpty()){
                    unitMap.put('is_favourited', true);
                } else {
                    unitMap.put('is_favourited', false);
                }

                String layoutPreview;
                if (unitIdToFiles.get(unit.Id) != null && !unitIdToFiles.get(unit.Id).isEmpty() && fileToContentDocumentLinkMap.containsKey(unitIdToFiles.get(unit.Id)[0].Id)) {
                    ContentDocumentLink cdl = fileToContentDocumentLinkMap.get(unitIdToFiles.get(unit.Id)[0].Id);
        
                    if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                        ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
        
                        if (cvToContentDistributionMap.containsKey(cv.Id)) {
                            ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                            layoutPreview = cd.ContentDownloadUrl;
                        }
                    }
                }
                unitMap.put('layout_preview', layoutPreview);

                responseList.add(unitMap);
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

    private static String buildQuery(String minimalPriceParam, String maximalPriceParam, List<String> projects, List<String> districts, List<String> types, List<String> status, List<String> bedrooms, String sortParam){

        String mainQuery = 'SELECT Id, Title_Formula__c, Project__r.Name, Type__c, Cost_AED__c, Total_Area__c, Living_Space__c, Additional_Area__c, Floor__c, Number_of_Bedrooms__c, Number_of_Bathrooms__c, (SELECT Id FROM Favorites__r WHERE OwnerId = \'' + UserInfo.getUserId() + '\'), (SELECT Id, Type__c FROM Files__r WHERE Type__c = \'Unit Layout Preview\')';
        
        mainQuery += ' FROM Unit__c';
        String whereClause = ' Status__c = \'Published\'';

        if(minimalPriceParam != null){
            if(whereClause != ''){
                whereClause += ' AND';
            }
            whereClause += ' Unit__c.Cost_AED__c >= ' + minimalPriceParam;
        }

        if(maximalPriceParam != null){
            if(whereClause != ''){
                whereClause += ' AND';
            }
            whereClause += ' Unit__c.Cost_AED__c <= ' + maximalPriceParam;
        }

        if(!projects.isEmpty()){
            if(whereClause != ''){
                whereClause += ' AND';
            }
            whereClause += ' Project__c IN (';
            for(Integer i = 0; i < projects.size(); i++){
                if(i == 0){
                    whereClause += '\'' + projects[i] + '\'';
                } else {
                    whereClause += ',\'' + projects[i] + '\'';

                }
            }
            whereClause += ')';
        }

        if(!districts.isEmpty()){
            if(whereClause != ''){
                whereClause += ' AND';
            }
            whereClause += ' Project__r.District__c IN (';
            for(Integer i = 0; i < districts.size(); i++){
                if(i == 0){
                    whereClause += '\'' + districts[i] + '\'';
                } else {
                    whereClause += ',\'' + districts[i] + '\'';

                }
            }
            whereClause += ')';
        }

        if(!types.isEmpty()){
            if(whereClause != ''){
                whereClause += ' AND';
            }
            whereClause += ' Type__c IN (';
            for(Integer i = 0; i < types.size(); i++){
                if(i == 0){
                    whereClause += '\'' + types[i] + '\'';
                } else {
                    whereClause += ',\'' + types[i] + '\'';

                }
            }
            whereClause += ')';
        }

        if(!status.isEmpty()){
            if(whereClause != ''){
                whereClause += ' AND';
            }
            whereClause += ' Project__r.Project_Status__c IN (';
            for(Integer i = 0; i < status.size(); i++){
                if(i == 0){
                    whereClause += '\'' + status[i] + '\'';
                } else {
                    whereClause += ',\'' + status[i] + '\'';

                }
            }
            whereClause += ')';
        }

        whereClause += ' AND Project__r.Publish_Project__c = \'Published\'';

        if(!bedrooms.isEmpty()){
            if(whereClause != ''){
                whereClause += ' AND (';
            }
            Boolean fourOrMore = false;
            if(bedrooms.size() == 1 && bedrooms[0] == '4'){
                whereClause += ' Number_of_Bedrooms__c >= 4';
            } else {
                whereClause += ' Number_of_Bedrooms__c IN (';
                for(Integer i = 0; i < bedrooms.size(); i++){
                    if(i == 0){
                        whereClause += bedrooms[i];
                    } else {
                        whereClause += ',' + bedrooms[i];
    
                    }
                    if(bedrooms[i] == '4'){
                        fourOrMore = true;
                    }
                }
                whereClause += ')';
            }
            if(fourOrMore){
                whereClause += '  OR Number_of_Bedrooms__c >= 4';
            }
            whereClause += ')';
        }

        if(whereClause != ''){
            mainQuery += ' WHERE' + whereClause;
        }

        if(sortParam != null){
            if(sortParam == 'priceASC'){
                mainQuery += ' ORDER BY Cost_AED__c ASC';
            } else if(sortParam == 'priceDESC'){
                mainQuery += ' ORDER BY Cost_AED__c DESC';
            } else if(sortParam == 'footageASC'){
                mainQuery += ' ORDER BY Total_Area__c ASC';
            } else if(sortParam == 'footageDESC'){
                mainQuery += ' ORDER BY Total_Area__c DESC';
            }
        } else {
            mainQuery += ' ORDER BY Cost_AED__c ASC';
        }
        return mainQuery;
    }
}