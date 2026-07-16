public without sharing class BookingOfferPDFController {

    @AuraEnabled
    public static Map<String,Object> getData(String oppId){
        try {
            Map<String,Object> resultMap = new Map<String,Object>();
            Opportunity opportunity = [
            SELECT 
                Id,
                Name,
                Booking_Date_Time__c,
                Registration_Fees__c,
                Ownership_Share_of_the_Main_Purchaser__c,
                Offer_layout__c,
                Unit__r.Project__r.Name,
                Unit__r.Project__r.Project_Name_Arabic__c,
                Unit__r.Title_Formula__c,
                Unit__r.Building__c,
                Unit__r.Number_of_bedrooms__c,
                Unit__r.Total_Area__c,
                Unit__r.Cost_AED__c,
                Unit__r.Name,
                Unit__c,
                Account.PersonBirthdate,
                Account.Date_of_Birth_Arabic__c,
                Account.Place_of_Birth__pc,
                Account.Place_of_Birth_Arabic__pc,
                Account.Occupation__pc,
                Account.Occupation_Arabic__pc,
                Account.Name,
                Account.Contact_First_Name_Arabic__pc,
                Account.Contact_Last_Name_Arabic__pc,
                Account.Contact_Middle_Name_Arabic__pc,
                Account.RecordTypeId,
                toLabel(Account.Nationality__c),
                Account.Nationality_Arabic__c,
                Account.Country_of_Incorporation_Arabic__c,
                Account.Passport_No__c,
                Account.BillingPostalCode,
                Account.BillingCity,
                Account.BillingCountry,
                Account.BillingStreet,
                Account.PersonMobilePhone,
                Account.Phone,
                Account.PersonEmail,
                Account.Postal_Code_Arabic__c,
                Account.Country_Arabic__c,
                Account.Address__c,
                Account.City_Arabic__c,
                toLabel(Account.Source_of_Funds__pc),
                Account.Source_of_Funds_Other__pc,
                Account.Source_of_Funds_Other_Arabic__pc,
                Account.Politically_Exposed__pc,
                Account.Politically_Exposed_Person_Text__pc,
                Account.Politically_Exposed_Person_Text_Arabic__pc,
                Account.Estimated_duration__pc,
                Account.Payment_Methods_Other__pc,
                Account.Payment_Methods_Other_Arabic__pc,
                Account.Currency_Other__pc,
                Account.Currency_Other_Arabic__pc,
                Account.IsPersonAccount,
                Account.Account_Name_Arabic__c,
                toLabel(Account.Country_of_Incorporation__c),
                toLabel(Account.Currency__pc),
                toLabel(Account.Payment_methods__pc),
                Account.Trade_License_Number__c,
                Assisted_by_agent__c,
                Agency__r.Name,
                Agency__r.Account_Name_Arabic__c,
                Agent__r.Name,
                Agent__r.Contact_First_Name_Arabic__c,
                Agent__r.Contact_Middle_Name_Arabic__c,
                Agent__r.Contact_Last_Name_Arabic__c,
                Owner.Name,
                (SELECT Id, Account__c, Order__c, Ownership_Share__c FROM Joint_Owners__r ORDER BY Order__c ASC)
            FROM Opportunity
            WHERE Id = :oppId LIMIT 1
        ];
        String bookingDate = Opportunity.Booking_Date_Time__c.format('dd-MMM-yyyy');
        //String bookingDate = String.valueOf(opportunity.Booking_Date_Time__c.day()+'/'+opportunity.Booking_Date_Time__c.month()+'/'+opportunity.Booking_Date_Time__c.year());
        resultMap.put('opportunity', opportunity);

        Map<String,String> jointOwnerIdToOrder = new Map<String,String>();
        Map<String,String> jointOwnerIdToOwnership = new Map<String,String>();

        Set<Id> jointOwnersIds = new Set<Id>();
        for(Joint_Owners__c jointOwner : opportunity.Joint_Owners__r){
            jointOwnersIds.add(jointOwner.Account__c);
            jointOwnerIdToOrder.put(jointOwner.Account__c.toString(), jointOwner.Order__c != null ? jointOwner.Order__c.toString() : '');
            jointOwnerIdToOwnership.put(jointOwner.Account__c.toString(), jointOwner.Ownership_Share__c != null ? jointOwner.Ownership_Share__c.toString() : '');
        }
        resultMap.put('jointOwnersOrder', jointOwnerIdToOrder);
        resultMap.put('jointOwnersOwnership', jointOwnerIdToOwnership);

        List<Account> jointOwners = [
            SELECT 
                Id, 
                RecordTypeId, 
                Trade_License_Number__c, 
                Name,
                toLabel(Nationality__c), 
                Passport_No__c, 
                BillingPostalCode, 
                BillingCity, 
                BillingCountry, 
                BillingStreet, 
                PersonMobilePhone, 
                Phone, 
                PersonEmail, 
                Contact_First_Name_Arabic__pc, 
                Contact_Middle_Name_Arabic__pc, 
                Contact_Last_Name_Arabic__pc, 
                Country_of_Incorporation_Arabic__c, 
                Nationality_Arabic__c, 
                Postal_Code_Arabic__c, 
                City_Arabic__c, 
                Country_Arabic__c, 
                Address__c,
                PersonBirthdate,
                Occupation__pc,
                Occupation_Arabic__pc,
                Place_of_Birth__pc,
                toLabel(Source_of_Funds__pc),
                Source_of_Funds_Other__pc,
                Source_of_Funds_Other_Arabic__pc,
                Politically_Exposed__pc,
                Politically_Exposed_Person_Text__pc,
                Politically_Exposed_Person_Text_Arabic__pc,
                Estimated_duration__pc,
                Payment_Methods_Other__pc,
                Payment_Methods_Other_Arabic__pc,
                Currency_Other__pc,
                Currency_Other_Arabic__pc,
                IsPersonAccount,
                Account_Name_Arabic__c,
                toLabel(Country_of_Incorporation__c),
                toLabel(Currency__pc),
                toLabel(Payment_methods__pc)
            FROM Account WHERE Id IN:jointOwnersIds 
        ];

        resultMap.put('jointOwners', jointOwners);

        Map<String,String> jointOwnerIdToLicenseNumberValue = new Map<String,String>();
        Map<String,String> jointOwnerIdToIncorporationCountry = new Map<String,String>();
        Map<String,String> jointOwnerIdToIncorporationCountryArabic = new Map<String,String>();
        Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Client').getRecordTypeId();

        for(Account account : jointOwners){
            if(account.RecordTypeId == personAccountRecordTypeId){
                jointOwnerIdToLicenseNumberValue.put(account.Id, 'N/A');
                jointOwnerIdToIncorporationCountry.put(account.Id, 'N/A');
                jointOwnerIdToIncorporationCountryArabic.put(account.Id, 'N/A');
            } else {
                jointOwnerIdToLicenseNumberValue.put(account.Id, account.Trade_License_Number__c);
                jointOwnerIdToIncorporationCountry.put(account.Id, account.Country_of_Incorporation__c);
                jointOwnerIdToIncorporationCountryArabic.put(account.Id, account.Country_of_Incorporation_Arabic__c);
            }
        }
        resultMap.put('jointOwnersLicenseValues', jointOwnerIdToLicenseNumberValue);
        resultMap.put('jointOwnersIncorporationValues', jointOwnerIdToIncorporationCountry);
        resultMap.put('jointOwnersIncorporationValuesArabic', jointOwnerIdToIncorporationCountryArabic);

        if(opportunity.Account.RecordTypeId == personAccountRecordTypeId){
            resultMap.put('licenseNumberValue', 'N/A');
            resultMap.put('incorporationCountry', 'N/A');
            resultMap.put('incorporationCountryArabic', 'N/A');

        } else {
            resultMap.put('licenseNumberValue', opportunity.Account.Trade_License_Number__c);
            resultMap.put('incorporationCountry', opportunity.Account.Country_of_Incorporation__c);
            resultMap.put('incorporationCountryArabic', opportunity.Account.Country_of_Incorporation_Arabic__c);

        }
        List<Cash_Flow__c> cashFlows = [SELECT Id, Price_Formula__c, Date__c, Name, Percent__c FROM Cash_Flow__c WHERE Unit__c = :opportunity.Unit__c AND Is_Additional_Payment__c = false ORDER BY Date__c ASC];
        resultMap.put('firstIntallment', cashFlows[0].Price_Formula__c);
        resultMap.put('agentAssistEng', opportunity.Assisted_by_agent__c == true ? 'Yes' : 'No');
        resultMap.put('agentAssistArabic', opportunity.Assisted_by_agent__c == true ? 'نعم' : 'لا');
        List<Map<String,Object>> paymentPlans = new List<Map<String,Object>>();

        for(Integer i = 0; i < cashFlows.size(); i++) {
            String dt;
                if(i == 0){
                    dt = bookingDate;
                } else {
                    dt = DateTime.newInstance(cashFlows[i].Date__c.year(),cashFlows[i].Date__c.month(),cashFlows[i].Date__c.day()).format('dd-MMM-YYYY');
                }
                paymentPlans.add(new Map<String,Object>{
                'numberOfPlan'=>String.valueOf(i+1), 
                'milestone'=>cashFlows[i].Name,
                'percent'=>String.valueOf(cashFlows[i].Percent__c),
                'paymentDate'=>String.valueOf(dt),
                'amount'=>String.valueOf(cashFlows[i].Price_Formula__c)
            });
        }
        resultMap.put('paymentPlans', paymentPlans);

        String pdfFileType;
        if(opportunity.Offer_layout__c == 'Contemporary'){
            pdfFileType = 'Contemporary Floor Plan';
        } else if(opportunity.Offer_layout__c == 'Formal'){
            pdfFileType = 'Formal Floor Plan';
        } else if(opportunity.Offer_layout__c == 'Traditional'){
            pdfFileType = 'Traditional Floor Plan';
        } else {
            pdfFileType = '';
        }
        Map<Id, File__c> pdfFile = new Map<Id, File__c>([SELECT Id FROM File__c WHERE Unit__c = :opportunity.Unit__c AND Type__c = 'Floor Plan' AND Layout__c = :pdfFileType LIMIT 1]);
        if(!pdfFile.keySet().isEmpty()){
            List<ContentDocumentLink> cdls = [
              SELECT 
                  ContentDocumentId, 
                  LinkedEntityId
              FROM ContentDocumentLink
              WHERE LinkedEntityId IN :pdfFile.keySet()
              ];
            Set<Id> cdids = new Set<Id>();
            for(ContentDocumentLink cdl : cdls){
              cdids.add(cdl.ContentDocumentId);
            }
            String pdfData;
            List<ContentVersion> cvs = [SELECT Id, ContentDocumentId, VersionData FROM  ContentVersion
                        WHERE ContentDocumentId IN:cdids];
            pdfData = EncodingUtil.base64Encode(cvs[0].VersionData);
            resultMap.put('pdfData', pdfData);
        }
        resultMap.put('date', bookingDate);

        return resultMap;
    
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}