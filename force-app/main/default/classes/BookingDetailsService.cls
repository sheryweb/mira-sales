@RestResource(urlMapping='/bookingDetailsService/*')
global without sharing class BookingDetailsService {

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        String bookingId = req.params.get('Id');
        Map<String, Object> responseList = new Map<String, Object>();

        List<Booking__c> booking = [SELECT Id, Unit__c, Manager__r.Name, Client__r.First_Name__c, Client__r.Last_Name__c, Client__r.Company_Name__c, Client__r.Type__c FROM Booking__c WHERE Id =:bookingId];
        if(!booking.isEmpty()){

            List<Unit__c> unitList = [
                SELECT Id, Project__r.Id, Project__r.Name, Title_Formula__c, Cost_AED__c, Number_of_Bedrooms__c, Floor__c, Number_of_Bathrooms__c, Total_Area__c, Living_Space__c, Additional_Area__c,
                Project__r.Payment_Plan_Title__c,
                (SELECT Id, Type__c, Description__c FROM Files__r WHERE Type__c = 'Unit Layout Preview')
                FROM Unit__c 
                WHERE Id =:booking[0].Unit__c AND Project__r.Publish_Project__c = 'Published'
            ];
            if(!unitList.isEmpty()){
                List<Payment_Plan__c> paymentPlans = [SELECT Id, Name, Date__c, Percent__c FROM Payment_Plan__c WHERE Project__c = :unitList[0].Project__r.Id ORDER BY Date__c ASC];

                Set<Id> fileIds = new Set<Id>();
                for(File__c file : unitList[0].Files__r){
                    fileIds.add(file.Id);
                }
                Map<String,Object> filesMaps = getAttachedFiles(fileIds);

                Map<Id, List<ContentDocumentLink>> fileToContentDocumentLinkMap = (Map<Id, List<ContentDocumentLink>>)filesMaps.get('fileToContentDocumentLinkMap');
                Map<Id, ContentVersion> cdlToContentVersionMap = (Map<Id, ContentVersion>)filesMaps.get('cdlToContentVersionMap');
                Map<Id, ContentDistribution> cvToContentDistributionMap = (Map<Id, ContentDistribution>)filesMaps.get('cvToContentDistributionMap');
                responseList.put('id', booking[0].Id);
                responseList.put('unitId', unitList[0].Id);
                responseList.put('projetName', unitList[0].Project__r.Name);
                responseList.put('unitName', unitList[0].Title_Formula__c);
                responseList.put('price', unitList[0].Cost_AED__c);
                responseList.put('numberOfBedrooms', unitList[0].Number_of_Bedrooms__c);
                responseList.put('numberOfBathrooms', unitList[0].Number_of_Bathrooms__c);
                responseList.put('extraArea', unitList[0].Additional_Area__c);
                responseList.put('floor', unitList[0].Floor__c);
                responseList.put('livingArea', unitList[0].Living_Space__c);
                responseList.put('totalArea', unitList[0].Total_Area__c);
                responseList.put('managerName', booking[0].Manager__r.Name);
                responseList.put('clientName', booking[0].Client__r.Type__c=='Organization'?booking[0].Client__r.Company_Name__c:booking[0].Client__r.First_Name__c+' '+booking[0].Client__r.Last_Name__c);

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

                String layoutPreviewUrl;
                if(!unitList[0].Files__r.isEmpty()){
                    if(fileToContentDocumentLinkMap.containsKey(unitList[0].Files__r[0].Id)){
                        ContentDocumentLink cdl = fileToContentDocumentLinkMap.get(unitList[0].Files__r[0].Id)[0];

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

            }

            RestContext.response.addHeader('Content-Type', 'application/json');
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(responseList));

        }
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