public class MultipleSalesOfferPDFController {

    public String CurrentPage { get; set; }
    public List<Unit__c> unitList {get; set;}
    public List<UnitWrapper> unitWrap {get; set;}
    public String completionDate {get; set;}
    public List<PaymentPlanWrapper> paymentPlansFirst {get; set;}
    public List<PaymentPlanWrapper> paymentPlansRest {get; set;}
    public String todayDate;
    public Boolean lessPayments {get; set;}
    public Set<String> imageUrlToStyleKeySet {get; set;}
    public Map<String,String> imageUrlToStyle{get; set;}
    public Map<String,String> imageUrlToDesc{get; set;}
    public Boolean isOnePic {get; set;}
    public String totalAedCostFormatted {get; set;}
    public String totalUSDCostFormatted {get; set;}
    public String totalUSDCostNumberFormatted {get; set;}
    public String totalUSDFormatted {get; set;}
    public String totalEURFormatted {get; set;}
    public String totalRUBFormatted {get; set;}
    public String totalGBPFormatted {get; set;}
    public String selectedCurrency {get; set;}

    /** True only when a valid secondary currency is selected (USD, EUR, RUB, GBP). False for blank, null, or --None--. */
    public Boolean getShowSecondaryCurrencyTotal() {
        if (String.isBlank(selectedCurrency) || selectedCurrency == '--None--') {
            return false;
        }
        Set<String> valid = new Set<String>{ 'USD', 'EUR', 'RUB', 'GBP', 'AED' };
        return valid.contains(selectedCurrency.trim());
    }

    public String getTodayDate() {
        return  String.valueOf(DateTime.newInstance(Date.today().year(),Date.today().month(),Date.today().day()).format('dd MMM yyyy'));
    }

    public static String formatNumber(Decimal numberToFormat) {
        String numberStr = String.valueOf(numberToFormat);
        if(numberStr != null){
            
            List<String> parts = numberStr.split('\\.');
            String integerPart = parts[0];
            String decimalPart = parts.size() > 1 ? parts[1] : '00';
            
            integerPart = addCommas(integerPart);
            
            return integerPart + '.' + decimalPart;
        }
        return numberStr;
    }

    public static String getFloorTextFranco(Decimal floorValue) {
        if (floorValue == 1) {
            return 'First';
        } else if (floorValue == 2) {
            return 'Second';
        } else if (floorValue == 3) {
            return 'Third';
        } else if (floorValue == 4) {
            return 'Fourth';
        } else if (floorValue == 5) {
            return 'Fifth';
        } else if (floorValue == 6) {
            return 'Sixth';
        } else if (floorValue == 7) {
            return 'Seventh';
        } else if (floorValue == 8) {
            return 'Eighth';
        } else if (floorValue == 9) {
            return 'Ninth';
        } else if (floorValue == 23) {
            return 'Second / Third';
        } else if (floorValue == 34) {
            return 'Third / Fourth';
        } else if (floorValue == 45) {
            return 'Fourth / Fifth';
        } else if (floorValue == 56) {
            return 'Fifth / Sixth';
        } else if (floorValue == 67) {
            return 'Sixth / Seventh';
        } else if (floorValue == 78) {
            return 'Seventh / Eighth';
        } else if (floorValue == 89) {
            return 'Eighth / Ninth';
        } else {
            return '';
        }
    }
    
    private static String addCommas(String integerPart) {
        String reversed = reverseString(integerPart);
        String result = '';
        
        for (Integer i = 0; i < reversed.length(); i++) {
            if (i > 0 && Math.mod(i, 3) == 0) {
                result += ',';
            }
            result += reversed.substring(i, i + 1);
        }
        
        return reverseString(result);
    }
    
    private static String reverseString(String input) {
        String output = '';
        for (Integer i = input.length() - 1; i >= 0; i--) {
            output += input.substring(i, i + 1);
        }
        return output;
    }

    public static String formattedDecimal(Decimal passedDecimal) {
        if(passedDecimal == null) {
            return '';
        }
        return String.valueOf(passedDecimal.intValue());
    }
    
    /*Constructor*/
    public MultipleSalesOfferPDFController() {
        String UnitIdsCollection = ApexPages.currentPage().getParameters().get('unitIds');
        String sCurrency = ApexPages.currentPage().getParameters().get('sCurrency');
        this.selectedCurrency = (sCurrency != null && sCurrency != '' && sCurrency != '--None--') ? sCurrency : '';
        List<String> unitIds = UnitIdsCollection.split(',');
        
        List<Unit__c> units = [
            SELECT 
                Id,
                Project_Name_F__c,
                Title__c,
                Title_Formula__c, 
                Unit_Model__c, 
                Building__c,
                Project__r.Handover__c, 
                Number_of_Bedrooms__c,
                Balcony_Size__c,
                Type__c, 
                Total_Area__c,
                Total_Area_Square_Meter__c,
                Living_Space__c, 
                Additional_Area__c, 
                Cost_AED__c,
                Cost_AED_for_CHF__c,
                Cost_CHF__c,
                Cost_USD__c,
                Cost_USD_Number__c,
                Floor__c, 
                View__c, 
                Number_of_Bathrooms__c, 
                Pool__c,
                Maids_Room__c,
                Panorama_Link__c,
                Amount_USD__c,
                Amount_EUR__c,
                Amount_RUB__c,
                Amount_GBP__c,
                Secondary_Currency__c
            FROM Unit__c WHERE Id IN :unitIds
        ];

        List<UnitWrapper> unitValues = new List<UnitWrapper>();
        Decimal totalAedCost = 0;
        Decimal totalUSDCost = 0;
        Decimal totalUSDCostNumber = 0;
        Decimal totalUSD = 0;
        Decimal totalEUR = 0;
        Decimal totalRUB = 0;
        Decimal totalGBP = 0;

        for (Unit__c unit: units) {
            if (unit.Cost_AED__c != null) {
                totalAedCost += unit.Cost_AED__c;
            }
            if (unit.Cost_USD__c != null) {
                totalUSDCost += unit.Cost_USD__c;
            }
            if (unit.Cost_USD_Number__c != null) {
                totalUSDCostNumber += unit.Cost_USD_Number__c;
            }
            if (unit.Amount_USD__c != null) totalUSD += unit.Amount_USD__c;
            if (unit.Amount_EUR__c != null) totalEUR += unit.Amount_EUR__c;
            if (unit.Amount_RUB__c != null) totalRUB += unit.Amount_RUB__c;
            if (unit.Amount_GBP__c != null) totalGBP += unit.Amount_GBP__c;
            Map<String,String> imageUrlToStyle = new Map<String,String>();
            Map<String,String> imageUrlToDesc = new Map<String,String>();
            
            List<Cash_Flow__c> cashFlows = [SELECT Id, Name, Percent__c, Date__c, Price_Formula__c, Price_CHF__c, Amount_AED__c, Amount_USD__c, Amount_EUR__c, Amount_RUB__c, Amount_GBP__c FROM Cash_Flow__c WHERE Unit__c = :unit.Id AND Is_Additional_Payment__c = false AND Name != 'Oqood' AND Name != 'DLD Fee' AND Name != 'Registration Fee' AND Name != 'Purchase Taxes' ORDER By Date__c];
            List<PaymentPlanWrapper> firstPaymentPlans = new List<PaymentPlanWrapper>();
            List<PaymentPlanWrapper> restOfPaymentPlans = new List<PaymentPlanWrapper>();
            
            Decimal price = 0;
            Decimal priceCHF = 0;
            Decimal priceUSD = 0;
            Decimal priceEUR = 0;
            Decimal priceRUB = 0;
            Decimal priceGBP = 0;
            Decimal priceAED = 0;
            for (Integer i = 0; i < cashFlows.size(); i++) {
                String dt;
                if (i == 0) {
                    dt = DateTime.now().format('dd MMM yyyy');
                } else {
                    dt = DateTime.newInstance(cashFlows[i].Date__c.year(),cashFlows[i].Date__c.month(),cashFlows[i].Date__c.day()).format('dd MMM yyyy');
                }
                if (i < 7) {
                    firstPaymentPlans.add(new PaymentPlanWrapper(
                        String.valueOf(i+1),
                        cashFlows[i].Name,
                        String.valueOf(cashFlows[i].Percent__c),
                        String.valueOf(dt),
                        formatNumber(cashFlows[i].Price_Formula__c),
                        formatNumber(cashFlows[i].Amount_USD__c),
                        formatNumber(cashFlows[i].Amount_EUR__c),
                        formatNumber(cashFlows[i].Amount_RUB__c),
                        formatNumber(cashFlows[i].Amount_GBP__c),
                        formatNumber(cashFlows[i].Price_CHF__c),
                        formatNumber(cashFlows[i].Amount_AED__c)
                    ));
                } else {
                    restOfPaymentPlans.add(new PaymentPlanWrapper(
                        String.valueOf(i+1),
                        cashFlows[i].Name,
                        String.valueOf(cashFlows[i].Percent__c),
                        String.valueOf(dt),
                        formatNumber(cashFlows[i].Price_Formula__c),
                        formatNumber(cashFlows[i].Amount_USD__c),
                        formatNumber(cashFlows[i].Amount_EUR__c),
                        formatNumber(cashFlows[i].Amount_RUB__c),
                        formatNumber(cashFlows[i].Amount_GBP__c),
                        formatNumber(cashFlows[i].Price_CHF__c),
                        formatNumber(cashFlows[i].Amount_AED__c)
                    ));
                }
                price+=cashFlows[i].Price_Formula__c;
                priceAED+=cashFlows[i].Amount_AED__c;
                priceUSD+=cashFlows[i].Amount_USD__c;
                priceEUR+=cashFlows[i].Amount_EUR__c;
                priceRUB+=cashFlows[i].Amount_RUB__c;
                priceGBP+=cashFlows[i].Amount_GBP__c;
                priceCHF+=cashFlows[i].Price_CHF__c;
            }
            if (restOfPaymentPlans.isEmpty()) {
              this.lessPayments = true;
            } else {
              this.lessPayments = false;
            }
            
            String month = String.ValueOf(unit.Project__r.Handover__c.month()).length() == 1 ? '0' + 
            String.ValueOf(unit.Project__r.Handover__c.month()) : String.ValueOf(unit.Project__r.Handover__c.month());
            String day = String.ValueOf(unit.Project__r.Handover__c.day()).length() == 1 ? '0' + 
            String.ValueOf(unit.Project__r.Handover__c.day()) : String.ValueOf(unit.Project__r.Handover__c.day());
            String completionDate = day + '-' + month + '-' + unit.Project__r.Handover__c.year();

            String docType;

            if (unit.Project_Name_F__c == 'POST HOTEL & RESIDENCES By ELIE SAAB') {
                docType = 'Floor Plan';
            } else if (unit.Project_Name_F__c == 'Trussardi Residences MIRA VERDE' || unit.Project_Name_F__c == 'John Richmond Residences') {
                docType = 'Sales Offer';
            } else {
                docType = 'Schemas/PDFs';
            }
            
            Map<Id, File__c> files = new Map<Id, File__c>([SELECT Id, Description__c FROM File__c WHERE Unit__c = :unit.Id AND Type__c = :docType ORDER BY Order__c]);
            if (!files.keySet().isEmpty()) {

              Map<String,String> m = new Map<String,String>();
              List<ContentDocumentLink> cdls = [
                SELECT 
                    ContentDocumentId,
                    LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :files.keySet()
            ];
              Set<Id> cdids = new Set<Id>();
              for (ContentDocumentLink cdl : cdls) {
                cdids.add(cdl.ContentDocumentId);
                m.put(cdl.ContentDocumentId, files.get(cdl.LinkedEntityId).Description__c);
              }
              
              List<ContentVersion> cvs = [SELECT Id, ContentDocumentId FROM  ContentVersion WHERE ContentDocumentId IN:cdids];

              if (unit.Project_Name_F__c == 'POST HOTEL & RESIDENCES By ELIE SAAB' || unit.Project_Name_F__c == 'GIANFRANCO FERRE RESIDENCES' || unit.Project_Name_F__c == 'John Richmond District') {
                for(Integer i = 0; i < cvs.size(); i++) {
                  imageUrlToStyle.put('/sfc/servlet.shepherd/version/download/' + cvs[i].Id, '100%');
                  imageUrlToDesc.put('/sfc/servlet.shepherd/version/download/' + cvs[i].Id, m.get(cvs[i].ContentDocumentId) != null ? m.get(cvs[i].ContentDocumentId) : '');
                }
              } else {
                for(Integer i = 0; i < cvs.size(); i++) {
                    if(System.Math.mod(cvs.size(), 2) != 0 && i+1 == cvs.size()){
                        imageUrlToStyle.put('/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + cvs[i].Id, '100%');
                    } else {
                        imageUrlToStyle.put('/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + cvs[i].Id, '49%');
                    }
                    imageUrlToDesc.put('/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + cvs[i].Id, m.get(cvs[i].ContentDocumentId) != null ? m.get(cvs[i].ContentDocumentId) : '');
                }
              }

              if (imageUrlToStyle.keySet().size() == 1) {
                this.isOnePic = true;
              } else {
                this.isOnePic = false;
              }
            }
            //Unit Wrapper Section//
            UnitWrapper wrapper = UnitWrapper.builder()
                .setBasicInfo(
                    unit.Id,
                    unit.Project_Name_F__c,
                    unit.Title_Formula__c,
                    unit.Title__c
                )
                .setUnitDetails(
                    unit.Unit_Model__c,
                    unit.Building__c,
                    todayDate,
                    unit.Number_of_Bedrooms__c,
                    unit.Number_of_Bathrooms__c,
                    formattedDecimal(unit.Balcony_Size__c),
                    unit.Type__c,
                    formatNumber(unit.Total_Area__c),
                    formatNumber(unit.Total_Area_Square_Meter__c),
                    formatNumber(unit.Living_Space__c),
                    formatNumber(unit.Additional_Area__c),
                    unit.Floor__c,
                    unit.View__c,
                    unit.Pool__c,
                    unit.Maids_Room__c
                )
                .setFinancialInfo(
                    formatNumber(unit.Cost_AED__c),
                    formatNumber(unit.Cost_CHF__c),
                    formatNumber(unit.Cost_AED_for_CHF__c),
                    formatNumber(unit.Cost_USD__c),
                    formatNumber(unit.Cost_USD_Number__c),
                    formatNumber(unit.Amount_USD__c),
                    formatNumber(unit.Amount_EUR__c),
                    formatNumber(unit.Amount_RUB__c),
                    formatNumber(unit.Amount_GBP__c),
                    unit.Secondary_Currency__c,
                    completionDate
                )
                .setPaymentPlans(
                    firstPaymentPlans,
                    restOfPaymentPlans
                )
                .setImageInfo(
                    imageUrlToStyle.KeySet(),
                    imageUrlToStyle,
                    imageUrlToDesc
                )
                .setAdditionalInfo(
                    unit.Panorama_Link__c,
                    isOnePic,
                    this.lessPayments,
                    sCurrency
                )
                .build();
            if (unit.Project_Name_F__c == 'GIANFRANCO FERRE RESIDENCES' || unit.Project_Name_F__c == 'Trussardi Residences 2 Offices' || unit.Project_Name_F__c == 'Trussardi Residences MIRA VERDE' || unit.Project_Name_F__c == 'John Richmond Residences') {
                wrapper.unitFloorText = getFloorTextFranco(unit.Floor__c);
            }
            unitValues.add(wrapper);
            //END//
        }
        this.unitWrap = unitValues;
        this.totalAedCostFormatted = formatNumber(totalAedCost);
        this.totalUSDCostFormatted = formatNumber(totalUSDCost);
        this.totalUSDCostNumberFormatted = formatNumber(totalUSDCostNumber);
        this.totalUSDFormatted = formatNumber(totalUSD);
        this.totalEURFormatted = formatNumber(totalEUR);
        this.totalRUBFormatted = formatNumber(totalRUB);
        this.totalGBPFormatted = formatNumber(totalGBP);
    }
}