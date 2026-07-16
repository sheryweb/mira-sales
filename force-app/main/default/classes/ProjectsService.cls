@RestResource(urlMapping='/projectsService/*')
global without sharing class ProjectsService {

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;

        List<Project__c> projectsList = [
            SELECT Id, Name, District__c, Coordinates_Latitude__c, Coordinates_Longitude__c, Minimum_Cost__c, 
            (SELECT Id, Number_of_Bedrooms__c FROM Units__r WHERE Status__c = 'Published'), 
            (SELECT Id, Type__c FROM Files__r WHERE Type__c = 'Project Preview' OR Type__c = 'Project Cover Image') 
            FROM Project__c WHERE Publish_Project__c = 'Published'];



        Map<Id, List<File__c>> projectsIdToPreviewFiles = new Map<Id, List<File__c>>();
        Map<Id, List<File__c>> projectsIdToCoverImageFiles = new Map<Id, List<File__c>>();
        Set<Id> fileIds = new Set<Id>();
        for (Project__c project : projectsList) {
            if (project.Files__r != null && !project.Files__r.isEmpty()) {
                List<File__c> projectPreviewFiles = new List<File__c>();
                List<File__c> coverImageFiles = new List<File__c>();
    
                for(File__c file : project.Files__r){
                    
                    if(file.Type__c == 'Project Preview'){
                        projectPreviewFiles.add(file);
                        fileIds.add(file.Id);
                    } else if (file.Type__c == 'Project Cover Image'){
                        coverImageFiles.add(file);
                        fileIds.add(file.Id);
                    }
                }
                projectsIdToPreviewFiles.put(project.Id, projectPreviewFiles);
                projectsIdToCoverImageFiles.put(project.Id, coverImageFiles);
            }
        }
    
        Map<String,Object> filesMaps = getAttachedFiles(fileIds);

        Map<Id, ContentDocumentLink> fileToContentDocumentLinkMap = (Map<Id, ContentDocumentLink>)filesMaps.get('fileToContentDocumentLinkMap');
        Map<Id, ContentVersion> cdlToContentVersionMap = (Map<Id, ContentVersion>)filesMaps.get('cdlToContentVersionMap');
        Map<Id, ContentDistribution> cvToContentDistributionMap = (Map<Id, ContentDistribution>)filesMaps.get('cvToContentDistributionMap');

        Map<Id, String> projectIdtounitsDescription = new Map<Id, String>();
        for (Project__c project : projectsList) {
            Set<Decimal> unitsCount = new Set<Decimal>();
            String unitsDescriptionString = '';
            for(Unit__c unit : project.Units__r){
                unitsCount.add(unit.Number_of_Bedrooms__c);
            }
            if(unitsCount.contains(0)){
                unitsDescriptionString += 'Studio';
                unitsCount.remove(0);
            }
        
            if(unitsCount.contains(1) && unitsCount.contains(2) && unitsCount.contains(3) && unitsCount.contains(4) && unitsCount.contains(5)){
                if(unitsDescriptionString != ''){
                    unitsDescriptionString += ', ';
                }
                unitsDescriptionString += '1 - 5';
            } else {

                List<Decimal> unitsList = new List<Decimal>(unitsCount);
                unitsList.sort();
                for(Decimal unitCount : unitsList){
                    if(unitsDescriptionString != ''){
                        unitsDescriptionString += ', ';
                    }
                    unitsDescriptionString += unitCount;
                }
            }
            if(unitsDescriptionString == '1'){
                unitsDescriptionString += ' bedroom';
            } else if(unitsDescriptionString != 'Studio' && unitsDescriptionString != ''){
                unitsDescriptionString += ' bedrooms';
            }
            projectIdtounitsDescription.put(project.Id, unitsDescriptionString);
        }

        List<Map<String, Object>> responseList = new List<Map<String, Object>>();
        for (Project__c project : projectsList) {
                Map<String, Object> projectMap = new Map<String, Object>();
                projectMap.put('id', project.Id);
                projectMap.put('title', project.Name);
                projectMap.put('district', project.District__c);
                projectMap.put('price', project.Minimum_Cost__c);
                projectMap.put('units_description', projectIdtounitsDescription.get(project.Id));
                projectMap.put('coordinates', new Map<String, Object>{'latitude'=>project.Coordinates_Latitude__c, 'longitude'=>project.Coordinates_Longitude__c} );

                String preview;
                if (projectsIdToPreviewFiles.get(project.Id) != null && !projectsIdToPreviewFiles.get(project.Id).isEmpty() && fileToContentDocumentLinkMap.containsKey(projectsIdToPreviewFiles.get(project.Id)[0].Id)) {
                    ContentDocumentLink cdl = fileToContentDocumentLinkMap.get(projectsIdToPreviewFiles.get(project.Id)[0].Id);
        
                    if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                        ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
        
                        if (cvToContentDistributionMap.containsKey(cv.Id)) {
                            ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                            preview = cd.ContentDownloadUrl;
                        }
                    }
                }
                projectMap.put('preview', preview);

                String cover;
                if (projectsIdToCoverImageFiles.get(project.Id) != null && !projectsIdToCoverImageFiles.get(project.Id).isEmpty() && fileToContentDocumentLinkMap.containsKey(projectsIdToCoverImageFiles.get(project.Id)[0].Id)) {
                    ContentDocumentLink cdl = fileToContentDocumentLinkMap.get(projectsIdToCoverImageFiles.get(project.Id)[0].Id);
        
                    if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                        ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
        
                        if (cvToContentDistributionMap.containsKey(cv.Id)) {
                            ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                            cover = cd.ContentDownloadUrl;
                        }
                    }
                }
                projectMap.put('cover', cover);

                responseList.add(projectMap);
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

}