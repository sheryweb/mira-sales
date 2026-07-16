@RestResource(urlMapping='/projectDetailsService/*')
global without sharing class ProjectDetailsService {

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        String projectId = req.params.get('Id');

        List<Project__c> projectsList = [
            SELECT Id, Name, Description__c, Minimum_Cost__c, District__c, Coordinates_Latitude__c, Coordinates_Longitude__c, 
            (SELECT Id, Number_of_Bedrooms__c, Type__c FROM Units__r WHERE Status__c = 'Published'), 
            (SELECT Id, Type__c, Description__c FROM Files__r WHERE Type__c = 'Project Exterior Photos' OR Type__c = 'Project Interior Photos' OR Type__c = 'Schemas/PDFs' OR Type__c = 'Project Map Image'),
            (SELECT Id, Name, Description__c FROM Main_Information__r),
            (SELECT Id, Name, Description__c FROM Advantages__r)
            FROM Project__c WHERE Publish_Project__c = 'Published' AND Id =:projectId];

        Map<String, Object> responseList = new Map<String, Object>();

        if(!projectsList.isEmpty()){
            AggregateResult[] groupedResults = [SELECT MIN(Total_Area__c)totalArea, COUNT(Id)unitCount FROM Unit__c WHERE Project__c =:projectId AND Status__c = 'Published'];
            Object minTotalArea = groupedResults[0].get('totalArea');
            Object unitCount = groupedResults[0].get('unitCount');

            List<Map<String,Object>> unitGroups = getUnitGroups(projectsList[0].Units__r);

            Map<Id, List<File__c>> projectIdToPhotos = new Map<Id, List<File__c>>();
            Map<Id, List<File__c>> projectIdToPdfFiles = new Map<Id, List<File__c>>();
            Map<Id, List<File__c>> projectIdToMapImg = new Map<Id, List<File__c>>();
            Set<Id> fileIds = new Set<Id>();
            if (projectsList[0].Files__r != null && !projectsList[0].Files__r.isEmpty()) {
                List<File__c> photoFiles = new List<File__c>();
                List<File__c> pdfFiles = new List<File__c>();
                List<File__c> mapImgs = new List<File__c>();

                for(File__c file : projectsList[0].Files__r){
                    if(file.Type__c == 'Project Exterior Photos' || file.Type__c == 'Project Interior Photos'){
                        photoFiles.add(file);
                        fileIds.add(file.Id);
                    } else if (file.Type__c == 'Schemas/PDFs'){
                        pdfFiles.add(file);
                        fileIds.add(file.Id);
                    } else if(file.Type__c == 'Project Map Image'){
                        mapImgs.add(file);
                        fileIds.add(file.Id);
                    }
                }
                projectIdToPhotos.put(projectsList[0].Id, photoFiles);
                projectIdToPdfFiles.put(projectsList[0].Id, pdfFiles);
                projectIdToMapImg.put(projectsList[0].Id, mapImgs);
            }

            for(Advantage__c advantage : projectsList[0].Advantages__r){
                fileIds.add(advantage.Id);
            }

            Map<String,Object> filesMaps = getAttachedFiles(fileIds);

            Map<Id, List<ContentDocumentLink>> fileToContentDocumentLinkMap = (Map<Id, List<ContentDocumentLink>>)filesMaps.get('fileToContentDocumentLinkMap');
            Map<Id, ContentVersion> cdlToContentVersionMap = (Map<Id, ContentVersion>)filesMaps.get('cdlToContentVersionMap');
            Map<Id, ContentDistribution> cvToContentDistributionMap = (Map<Id, ContentDistribution>)filesMaps.get('cvToContentDistributionMap');

            String mapAttribute;
            if (projectIdToMapImg.get(projectsList[0].Id) != null && !projectIdToMapImg.get(projectsList[0].Id).isEmpty() && fileToContentDocumentLinkMap.containsKey(projectIdToMapImg.get(projectsList[0].Id)[0].Id)) {
                ContentDocumentLink cdl = fileToContentDocumentLinkMap.get(projectIdToMapImg.get(projectsList[0].Id)[0].Id)[0];
    
                if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                    ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
    
                    if (cvToContentDistributionMap.containsKey(cv.Id)) {
                        ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                        mapAttribute = cd.ContentDownloadUrl;
                    }
                }
            }
            responseList.put('map', mapAttribute);


            List<String> pictures = new List<String>();
            if (projectIdToPhotos.get(projectsList[0].Id) != null && !projectIdToPhotos.get(projectsList[0].Id).isEmpty()) {
                for(File__c file : projectIdToPhotos.get(projectsList[0].Id)){
                    if(fileToContentDocumentLinkMap.containsKey(file.Id)){
                        for(ContentDocumentLink cdl : fileToContentDocumentLinkMap.get(file.Id)){
                            
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
            }

            List<Map<String,Object>> information = new List<Map<String, Object>>();

            for(Main_Information__c mainInformation : projectsList[0].Main_Information__r){
                information.add(new Map<String,Object>{'title' => mainInformation.Name, 'description' => mainInformation.Description__c});
            }

            List<Map<String,Object>> advantages = new List<Map<String, Object>>();

            for(Advantage__c advantage : projectsList[0].Advantages__r){
                String url;
                if(fileToContentDocumentLinkMap.containsKey(advantage.Id)){
                        ContentDocumentLink cdl = fileToContentDocumentLinkMap.get(advantage.Id)[0];
                        
                        if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                            ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
                        
                            if (cvToContentDistributionMap.containsKey(cv.Id)) {
                                ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                                url = cd.ContentDownloadUrl;
                            }
                        }
                }
                advantages.add(new Map<String,Object>{'title' => advantage.Name, 'description' => advantage.Description__c, 'picture' => url});
            }

            List<Map<String,Object>> documents = new List<Map<String, Object>>();
            if (projectIdToPdfFiles.get(projectsList[0].Id) != null && !projectIdToPdfFiles.get(projectsList[0].Id).isEmpty()) {
                for(File__c file : projectIdToPdfFiles.get(projectsList[0].Id)){
                    String finalUrl;
                    if(fileToContentDocumentLinkMap.containsKey(file.Id)){
                        for(ContentDocumentLink cdl : fileToContentDocumentLinkMap.get(file.Id)){
                            if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                                ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
                            
                                if (cvToContentDistributionMap.containsKey(cv.Id)) {
                                    ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                                    finalUrl = cd.ContentDownloadUrl;
                                }
                            }
                    }
                    }
                    documents.add(new Map<String,Object>{'url' => finalUrl, 'title' => file.Description__c});

                }
            }

            responseList.put('pictures', pictures);
            responseList.put('documents', documents);
            responseList.put('information', information);
            responseList.put('advantages', advantages);
            responseList.put('id', projectsList[0].Id);
            responseList.put('title', projectsList[0].Name);
            responseList.put('description', projectsList[0].Description__c);
            responseList.put('price', projectsList[0].Minimum_Cost__c);
            responseList.put('area', minTotalArea);
            responseList.put('units_quantity', unitCount);
            responseList.put('district', projectsList[0].District__c);
            responseList.put('coordinates', new Map<String, Object>{'latitude'=>projectsList[0].Coordinates_Latitude__c, 'longitude'=>projectsList[0].Coordinates_Longitude__c} );
            responseList.put('units_groups', unitGroups);
        }

        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(responseList));
    }
    
    public static List<Map<String,Object>> getUnitGroups(List<Unit__c> units){
        Map<String, Map<String,Object>> typeToNames = new Map<String, Map<String,Object>>();
        Map<String, Integer> typeToUnitCount = new Map<String, Integer>();
        Map<String, List<AggregateResult>> typeToGroupedResults = new Map<String, List<AggregateResult>>();
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for(Unit__c unit : units){
            String title;
            if(unit.Number_of_Bedrooms__c == 0 && unit.Type__c == 'Apartment'){
                title = 'Studio';
            } else {
                title = unit.Number_of_Bedrooms__c + ' bedroom ' + unit.Type__c + 's';
            }

            if(!typeToNames.containsKey(title)){
                typeToNames.put(title, new Map<String,Object>{'Type__c' => unit.Type__c, 'Number_of_Bedrooms__c' => unit.Number_of_Bedrooms__c});
            }
            if(typeToUnitCount.containsKey(title)){
                typeToUnitCount.put(title, typeToUnitCount.get(title)+1);
            } else {
                typeToUnitCount.put(title, 1);
            }
        }
            for(String type : typeToNames.keySet()){
                AggregateResult[] groupedResults = [SELECT MAX(Total_Area__c)maxArea, MIN(Total_Area__c)minArea, MAX(Cost_AED__c)maxAed, MIN(Cost_AED__c)minAed FROM Unit__c WHERE Type__c = :(String)typeToNames.get(type).get('Type__c') AND Number_of_Bedrooms__c = :(Decimal)typeToNames.get(type).get('Number_of_Bedrooms__c') AND Status__c = 'Published'];
                typeToGroupedResults.put(type, groupedResults);
            }
            for(String type : typeToGroupedResults.keySet()){
                Map<String,Object> unitGroup = new Map<String,Object>();
                unitGroup.put('title', type);
                unitGroup.put('minimal_area', typeToGroupedResults.get(type)[0].get('minArea'));
                unitGroup.put('maximal_area', typeToGroupedResults.get(type)[0].get('maxArea'));
                unitGroup.put('minimal_price', typeToGroupedResults.get(type)[0].get('minAed'));
                unitGroup.put('maximal_price', typeToGroupedResults.get(type)[0].get('maxAed'));
                unitGroup.put('bedrooms', typeToNames.get(type).get('Number_of_Bedrooms__c'));
                unitGroup.put('type', typeToNames.get(type).get('Type__c'));
                unitGroup.put('quantity', typeToUnitCount.get(type));
                result.add(unitGroup);
            }
        
        return result;
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