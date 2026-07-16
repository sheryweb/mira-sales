@RestResource(urlMapping='/projectUnitDetailsService')
global without sharing class ProjectUnitDetailsService {

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        String unitId = req.params.get('Id');

        List<Unit__c> unitList = [
            SELECT Id, Title_Formula__c, Cost_AED__c, Type__c, Total_Area__c, Living_Space__c, Additional_Area__c, Balcony_Size__c, Floor__c, Number_of_Bedrooms__c, Number_of_Bathrooms__c, View__c, Building__c, Panorama_Link__c,
            Project__r.Payment_Plan_Title__c, Project__r.Id, Project__r.Name, Project__r.Description__c, Project__r.District__c, Project__r.Coordinates_Latitude__c, Project__r.Coordinates_Longitude__c,
            (SELECT Id, Type__c, Description__c FROM Files__r WHERE Type__c = 'Photos' OR Type__c = 'Project Interior Photos' OR Type__c = 'Sales Offer' OR Type__c = 'Schemas/PDFs' OR Type__c = 'Unit Layout Preview'),
            (SELECT Id, Name, Price__c FROM Cash_Flow_Sums__r),
            (SELECT Id, Name FROM Favorites__r WHERE OwnerId = :UserInfo.getUserId())
            FROM Unit__c 
            WHERE Id =:unitId AND Project__r.Publish_Project__c = 'Published'
        ];

        Map<String, Object> responseList = new Map<String, Object>();

        if(!unitList.isEmpty()){
            List<Unit__c> relatedUnitList = [
                SELECT Id, Title_Formula__c, Cost_AED__c, Type__c, Total_Area__c, Living_Space__c, Balcony_Size__c, Additional_Area__c, Floor__c, 
                Number_of_Bedrooms__c, Number_of_Bathrooms__c, View__c, Building__c, Panorama_Link__c,
                (SELECT Id, Name FROM Favorites__r WHERE OwnerId = :UserInfo.getUserId()),
                (SELECT Id, Available__c, Type__c, Unit_Attribute_Name__c, Value__c FROM Unit_Attributes__r),
                (SELECT Id, Type__c, Description__c FROM Files__r WHERE Type__c = 'Unit Layout Preview')
                FROM Unit__c 
                WHERE Project__c = :unitList[0].Project__r.Id AND Type__c = :unitList[0].Type__c AND Number_of_Bedrooms__c = :unitList[0].Number_of_Bedrooms__c AND Status__c = 'Published'
            ];

            List<File__c> files = [SELECT Id, Type__c FROM File__c WHERE Project__c = :unitList[0].Project__r.Id AND (Type__c = 'Project Interior Photos' OR Type__c = 'Project Map Image')];
            List<Payment_Plan__c> paymentPlans = [SELECT Id, Name, Date__c, Percent__c FROM Payment_Plan__c WHERE Project__c = :unitList[0].Project__r.Id ORDER BY Date__c ASC];
            List<Cash_Flow__c> cashFlows = [SELECT Id, Name, Percent__c, Date__c, Price_Formula__c, Cash_Flow_Sum__c FROM Cash_Flow__c WHERE Cash_Flow_Sum__c IN :unitList[0].Cash_Flow_Sums__r];

            Map<Id, List<Cash_Flow__c>> cashFlowSumIdToCashFlows = new Map<Id, List<Cash_Flow__c>>();
            for(Cash_Flow__c cashFlow : cashFlows){
                if(cashFlowSumIdToCashFlows.containsKey(cashFlow.Cash_Flow_Sum__c)){
                    List<Cash_Flow__c> cashFlowsList = cashFlowSumIdToCashFlows.get(cashFlow.Cash_Flow_Sum__c);
                    cashFlowsList.add(cashFlow);
                    cashFlowSumIdToCashFlows.put(cashFlow.Cash_Flow_Sum__c, cashFlowsList);
                } else {
                    cashFlowSumIdToCashFlows.put(cashFlow.Cash_Flow_Sum__c, new List<Cash_Flow__c>{cashFlow});
                }
            }

            Set<Id> fileIds = new Set<Id>();
            File__c offerFile;
            File__c layoutPreviewFile;
            File__c projectMapFile;
            List<File__c> picturesFiles = new List<File__c>();
            List<File__c> layoutFiles = new List<File__c>();

            for(File__c file : files){
                if(file.Type__c == 'Project Interior Photos'){
                    fileIds.add(file.Id);
                    picturesFiles.add(file);
                } else if(file.Type__c == 'Project Map Image'){
                    fileIds.add(file.Id);
                    projectMapFile = file;
                }
            }

            for(File__c file : unitList[0].Files__r){
                if(file.Type__c == 'Photos'){
                    fileIds.add(file.Id);
                    picturesFiles.add(file);
                } else if(file.Type__c == 'Sales Offer'){
                    fileIds.add(file.Id);
                    offerFile = file;
                } else if(file.Type__c == 'Schemas/PDFs'){
                    fileIds.add(file.Id);
                    layoutFiles.add(file);
                } else if(file.Type__c == 'Unit Layout Preview'){
                    fileIds.add(file.Id);
                    layoutPreviewFile = file;
                }
            }

            for(Unit__c relatedUnit : relatedUnitList){
                if(relatedUnit.Id == unitList[0].Id){
                    continue;
                }
                for(File__c file : relatedUnit.Files__r){
                    fileIds.add(file.Id);
                }
            }

            Map<String,Object> filesMaps = getAttachedFiles(fileIds);

            Map<Id, List<ContentDocumentLink>> fileToContentDocumentLinkMap = (Map<Id, List<ContentDocumentLink>>)filesMaps.get('fileToContentDocumentLinkMap');
            Map<Id, ContentVersion> cdlToContentVersionMap = (Map<Id, ContentVersion>)filesMaps.get('cdlToContentVersionMap');
            Map<Id, ContentDistribution> cvToContentDistributionMap = (Map<Id, ContentDistribution>)filesMaps.get('cvToContentDistributionMap');

            responseList.put('id', unitList[0].Id);
            responseList.put('title', unitList[0].Title_Formula__c);
            responseList.put('price', unitList[0].Cost_AED__c);
            responseList.put('type', unitList[0].Type__c);
            responseList.put('total_area', unitList[0].Total_Area__c);
            responseList.put('living_area', unitList[0].Living_Space__c);
            responseList.put('balcony_area', unitList[0].Balcony_Size__c);
            responseList.put('extra_area', unitList[0].Additional_Area__c);
            responseList.put('floor', unitList[0].Floor__c);
            responseList.put('bedrooms', unitList[0].Number_of_Bedrooms__c);
            responseList.put('bathrooms', unitList[0].Number_of_Bathrooms__c);
            responseList.put('view', unitList[0].View__c);
            responseList.put('building', unitList[0].Building__c);
            responseList.put('tour', unitList[0].Panorama_Link__c);

            List<Map<String,Object>> relatedUnits = new List<Map<String,Object>>();

            for(Unit__c relatedUnit : relatedUnitList){
                Map<String,Object> relatedUnitMap = new Map<String,Object>();
                if(relatedUnit.Id == unitList[0].Id){
                    continue;
                }
                relatedUnitMap.put('id',relatedUnit.Id);
                relatedUnitMap.put('title',relatedUnit.Title_Formula__c);
                relatedUnitMap.put('price',relatedUnit.Cost_AED__c);
                relatedUnitMap.put('total_area',relatedUnit.Total_Area__c);
                relatedUnitMap.put('living_area',relatedUnit.Living_Space__c);
                relatedUnitMap.put('balcony_area',relatedUnit.Balcony_Size__c);
                relatedUnitMap.put('extra_area',relatedUnit.Additional_Area__c);
                relatedUnitMap.put('floor',relatedUnit.Floor__c);
                relatedUnitMap.put('bedrooms',relatedUnit.Number_of_Bedrooms__c);
                relatedUnitMap.put('bathrooms',relatedUnit.Number_of_Bathrooms__c);
                List<Map<String,Object>> unitAttributes = new List<Map<String,Object>>();
                if(!relatedUnit.Unit_Attributes__r.isEmpty()){
                    for(Unit_Attribute__c relatedAttribute : relatedUnit.Unit_Attributes__r){
                        unitAttributes.add(new Map<String,Object>{
                            'attribute_name' => relatedAttribute.Unit_Attribute_Name__c,
                            'attribute_value' => relatedAttribute.Value__c,
                            'attribute_type'=> relatedAttribute.Type__c,
                            'attribute_availiable' => relatedAttribute.Available__c
                        });
                    }
                }
                relatedUnitMap.put('attributes_array',unitAttributes);

                String layoutPreview;
                if(!relatedUnit.Files__r.isEmpty() && fileToContentDocumentLinkMap.containsKey(relatedUnit.Files__r[0].Id)){
                    ContentDocumentLink cdl = fileToContentDocumentLinkMap.get(relatedUnit.Files__r[0].Id)[0];

                    if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                        ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
                    
                        if (cvToContentDistributionMap.containsKey(cv.Id)) {
                            ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                            layoutPreview = cd.ContentDownloadUrl;
                        }
                    }
                }
                relatedUnitMap.put('layout_preview',layoutPreview);

                if(!relatedUnit.Favorites__r.isEmpty()){
                    relatedUnitMap.put('is_favourited', true);
                } else {
                    relatedUnitMap.put('is_favourited', false);
                }
                relatedUnits.add(relatedUnitMap);
            }

            responseList.put('related_units', relatedUnits);

            String projectMap;
            if(projectMapFile != null){
                if(fileToContentDocumentLinkMap.containsKey(projectMapFile.Id)){
                    ContentDocumentLink cdl = fileToContentDocumentLinkMap.get(projectMapFile.Id)[0];

                    if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                        ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
                    
                        if (cvToContentDistributionMap.containsKey(cv.Id)) {
                            ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                            projectMap = cd.ContentDownloadUrl;
                        }
                    }
                }
            }

            responseList.put('project', new Map<String,Object>{
                'id' => unitList[0].Project__r.Id,
                'title' => unitList[0].Project__r.Name,
                'description' => unitList[0].Project__r.Description__c,
                'district' => unitList[0].Project__r.District__c,
                'map' => projectMap,
                'coordinates' => new Map<String, Object>{'latitude'=>unitList[0].Project__r.Coordinates_Latitude__c, 'longitude'=>unitList[0].Project__r.Coordinates_Longitude__c}
            });

            String offerUrl;
            if(offerFile != null){
                if(fileToContentDocumentLinkMap.containsKey(offerFile.Id)){
                    ContentDocumentLink cdl = fileToContentDocumentLinkMap.get(offerFile.Id)[0];

                    if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                        ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
                    
                        if (cvToContentDistributionMap.containsKey(cv.Id)) {
                            ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                            offerUrl = cd.ContentDownloadUrl;
                        }
                    }
                }
            }
            responseList.put('offer', offerUrl);

            String layoutPreviewUrl;
            if(layoutPreviewFile != null){
                if(fileToContentDocumentLinkMap.containsKey(layoutPreviewFile.Id)){
                    ContentDocumentLink cdl = fileToContentDocumentLinkMap.get(layoutPreviewFile.Id)[0];

                    if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                        ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
                    
                        if (cvToContentDistributionMap.containsKey(cv.Id)) {
                            ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                            layoutPreviewUrl = cd.ContentDownloadUrl;
                        }
                    }
                }
            }
            responseList.put('layout_preview', layoutPreviewUrl);

            List<String> layoutUrls = new List<String>();
            for(File__c layoutFile : layoutFiles){
                if(fileToContentDocumentLinkMap.containsKey(layoutFile.Id)){
                    for(ContentDocumentLink cdl : fileToContentDocumentLinkMap.get(layoutFile.Id)){
                        if (cdlToContentVersionMap.containsKey(cdl.ContentDocumentId)) {
                            ContentVersion cv = cdlToContentVersionMap.get(cdl.ContentDocumentId);
                        
                            if (cvToContentDistributionMap.containsKey(cv.Id)) {
                                ContentDistribution cd = cvToContentDistributionMap.get(cv.Id);
                                layoutUrls.add(cd.ContentDownloadUrl);
                            }
                        }
                    }
                }
            }
            responseList.put('layout', layoutUrls);

            if(!unitList[0].Favorites__r.isEmpty()){
                responseList.put('is_favourited', true);
            } else {
                responseList.put('is_favourited', false);
            }
            List<String> pictures = new List<String>();
            for(File__c file : picturesFiles){
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
            
            responseList.put('pictures', pictures);

            Map<String, Object> paymentPlan = new Map<String, Object>();
            paymentPlan.put('title', unitList[0].Project__r.Payment_Plan_Title__c);
            List<Map<String,Object>> rows = new List<Map<String,Object>>();
            for(Payment_Plan__c paymentPlanRecord : paymentPlans){
                Map<String,Object> row = new Map<String,Object>();
                String dateFormat;
                if(paymentPlanRecord.Date__c != null){
                    dateFormat = DateTime.newInstance(paymentPlanRecord.Date__c.year(), paymentPlanRecord.Date__c.month(), paymentPlanRecord.Date__c.day()).formatGmt('MMM yy');
                }
                row.put('milestone', paymentPlanRecord.Name);
                row.put('percent', paymentPlanRecord.Percent__c);
                row.put('date', dateFormat);
                row.put('price', ( paymentPlanRecord.Percent__c * unitList[0].Cost_AED__c ) / 100 );
                rows.add(row);
            }
            paymentPlan.put('rows', rows);
            responseList.put('payment_plan', paymentPlan);


            List<Map<String, Object>> cashFlowsList = new List<Map<String, Object>>();

            for(Cash_Flow_Sum__c cashFlowSum : unitList[0].Cash_Flow_Sums__r){
                Map<String, Object> cashFlowMap = new Map<String, Object>();
                cashFlowMap.put('title', cashFlowSum.Name);
                cashFlowMap.put('price', cashFlowSum.Price__c);
                List<Map<String,Object>> cashFlowRows = new List<Map<String,Object>>();
                if(cashFlowSumIdToCashFlows.containsKey(cashFlowSum.Id)){

                    for(Cash_Flow__c cashFlow : cashFlowSumIdToCashFlows.get(cashFlowSum.Id)){
                        String dateFormat;
                        if(cashFlow.Date__c != null){
                            dateFormat = DateTime.newInstance(cashFlow.Date__c.year(), cashFlow.Date__c.month(), cashFlow.Date__c.day()).formatGmt('MMM yy');
                        }
                        cashFlowRows.add(new Map<String,Object>{
                            'milestone' => cashFlow.Name,
                            'percent' => cashFlow.Percent__c,
                            'date' => dateFormat,
                            'price' => cashFlow.Price_Formula__c
                        });
                    }
                    cashFlowMap.put('rows', cashFlowRows);
                }
                cashFlowsList.add(cashFlowMap);
            }
            responseList.put('cash_flow', cashFlowsList);

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