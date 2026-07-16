public class SalesOfferPDFController {

    public String CurrentPage { get; set; }

    public String FormattedCostDollar { get; set; }

    public Unit__c unitObject {get; set;}
    public String completionDate {get; set;}
    public List<PaymentPlanWrapper> paymentPlansFirst {get; set;}
    public List<PaymentPlanWrapper> paymentPlansRest {get; set;}
    public String todayDate;
    public String typeOfUnit {get; set;}
    public String isMaidsRoom {get; set;}
    public String isPool {get; set;}
    public Boolean lessPayments {get; set;}
    public String purchasePrice {get; set;}
    public String purchasePriceUSD {get; set;}
    public String purchasePriceEUR {get; set;}
    public String purchasePriceRUB {get; set;}
    public String purchasePriceGBP {get; set;}
    public String purchasePriceCHF {get; set;}
    public String purchasePriceAED {get; set;}
    public Set<String> imageUrlToStyleKeySet {get; set;}
    public Map<String,String> imageUrlToStyle{get; set;}
    public Map<String,String> imageUrlToDesc{get; set;}
    public Boolean isOnePic {get; set;}

    public String getTodayDate() {
        return  String.valueOf(DateTime.newInstance(Date.today().year(),Date.today().month(),Date.today().day()).format('dd MMM YYYY'));
    }


    public String getFormattedLivingSpace() {
        return formatNumber(unitObject.Living_Space__c);
    }

    public String getFormattedAdditionalArea() {
        return String.valueOf(unitObject.Additional_Area__c);
    }

    public String getFormattedBalcony() {
        return String.valueOf(unitObject.Balcony_Size__c.intValue());
    }

    public String getFormattedTotalArea() {
        return formatNumber(unitObject.Total_Area__c);
    }

    public String getFormattedTotalAreaSquareMeter() {
        return String.valueOf(unitObject.Total_Area_Square_Meter__c.intValue());
    }

    public String getFormattedCost() {
        return formatNumber(unitObject.Cost_AED__c);
    }

    public String getFormattedCostAEDForCHF() {
        return formatNumber(unitObject.Cost_AED_for_CHF__c);
    }

    public String getFormattedCHFValue() {
        return formatNumber(unitObject.Cost_CHF__c);
    }

    public String getFormattedCostUSDValue() {
        return formatNumber(unitObject.Cost_USD__c);
    }

    public String getFormattedCostUSDNumberValue() {
        return formatNumber(unitObject.Cost_USD_Number__c);
    }

    public String getFormattedDollarValue() {
        return formatNumber(unitObject.Amount_USD__c);
    }

    public String getFormattedEuroValue() {
        return formatNumber(unitObject.Amount_EUR__c);
    }

    public String getFormattedRubValue() {
        return formatNumber(unitObject.Amount_RUB__c);
    }

    
    public String getFormattedGbpValue() {
        return formatNumber(unitObject.Amount_GBP__c);
    }

    public String getFormattedPaymentAmount(Decimal amount) {
        return formatNumber(amount);
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

    public String getFloorText() {
        if (unitObject.Floor__c == 9) {
            return 'Ground';
        } else if (unitObject.Floor__c == 1) {
            return 'First';
        } else if (unitObject.Floor__c == 2) {
            return 'Second';
        } else if (unitObject.Floor__c == 3) {
            return 'Third';
        } else if (unitObject.Floor__c == 4) {
            return 'Fourth';
        } else if (unitObject.Floor__c == 5) {
            return 'Fifth';
        } else if (unitObject.Floor__c == 6) {
            return 'Sixth';
        } else if (unitObject.Floor__c == 7) {
            return 'Seventh';
        } else if (unitObject.Floor__c == 8) {
            return 'Eighth';
        } else if (unitObject.Floor__c == 91) {
            return 'Ground / First';
        } else if (unitObject.Floor__c == 12) {
            return 'First / Second';
        } else if (unitObject.Floor__c == 23) {
            return 'Second / Third';
        } else if (unitObject.Floor__c == 34) {
            return 'Third / Fourth';
        } else if (unitObject.Floor__c == 123) {
            return 'First / Second / Third';
        }  else {
            return '';
        }
    }

    public String getFloorTextFranco() {
        if (unitObject.Floor__c == 1) {
            return 'First';
        } else if (unitObject.Floor__c == 2) {
            return 'Second';
        } else if (unitObject.Floor__c == 3) {
            return 'Third';
        } else if (unitObject.Floor__c == 4) {
            return 'Fourth';
        } else if (unitObject.Floor__c == 5) {
            return 'Fifth';
        } else if (unitObject.Floor__c == 6) {
            return 'Sixth';
        } else if (unitObject.Floor__c == 7) {
            return 'Seventh';
        } else if (unitObject.Floor__c == 8) {
            return 'Eighth';
        } else if (unitObject.Floor__c == 9) {
            return 'Ninth';
        } else if (unitObject.Floor__c == 23) {
            return 'Second / Third';
        } else if (unitObject.Floor__c == 34) {
            return 'Third / Fourth';
        } else if (unitObject.Floor__c == 45) {
            return 'Fourth / Fifth';
        } else if (unitObject.Floor__c == 56) {
            return 'Fifth / Sixth';
        } else if (unitObject.Floor__c == 67) {
            return 'Sixth / Seventh';
        } else if (unitObject.Floor__c == 78) {
            return 'Seventh / Eighth';
        } else if (unitObject.Floor__c == 89) {
            return 'Eighth / Ninth';
        }  else {
            return '';
        }
    }
    
    public SalesOfferPDFController() {
        System.debug(ApexPages.currentPage().getParameters().get('unitId'));
        Id unitId = ApexPages.currentPage().getParameters().get('unitId');
        Unit__c unit = [
            SELECT 
                Id, 
                Project_Name_F__c, 
                Title_Formula__c, 
                Title__c, 
                Building__c, 
                Unit_Model__c, 
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
            FROM Unit__c
            WHERE Id = :unitId LIMIT 1
        ];
        // Broker Portal only: an optional 'sCurrency' URL param overrides the secondary currency for
        // THIS render (in memory, never saved). When the param is absent — i.e. the internal Sales
        // Offer generation and every existing caller — behaviour is unchanged (uses the Unit's field).
        String sCurrencyParam = ApexPages.currentPage().getParameters().get('sCurrency');
        if (String.isNotBlank(sCurrencyParam)) {
            // 'NONE' explicitly suppresses the secondary column; any other value selects that currency.
            unit.Secondary_Currency__c = (sCurrencyParam == 'NONE') ? '' : sCurrencyParam;
        }
        this.unitObject = unit;
        this.typeOfUnit = unit.Type__c;
        if(unit.Pool__c){
          this.isPool = 'Yes';
        } else {
          this.isPool = 'No';
        }
        if(unit.Maids_Room__c){
          this.isMaidsRoom = 'Yes';
        } else {
          this.isMaidsRoom = 'No';
        }
        String month = String.ValueOf(unit.Project__r.Handover__c.month()).length() == 1 ? '0' + 
            String.ValueOf(unit.Project__r.Handover__c.month()) : String.ValueOf(unit.Project__r.Handover__c.month());
        String day = String.ValueOf(unit.Project__r.Handover__c.day()).length() == 1 ? '0' + 
            String.ValueOf(unit.Project__r.Handover__c.day()) : String.ValueOf(unit.Project__r.Handover__c.day());
        this.completionDate = day + '-' + month + '-' + unit.Project__r.Handover__c.year() ;

        List<Cash_Flow__c> cashFlows = [SELECT Id, Name, Percent__c, Date__c, Price_Formula__c, Price_CHF__c, Amount_AED__c, Amount_USD__c, Amount_EUR__c, Amount_RUB__c, Amount_GBP__c FROM Cash_Flow__c WHERE Unit__c = :unitId AND Is_Additional_Payment__c = false AND Name != 'Oqood' AND Name != 'DLD Fee' AND Name != 'Registration Fee' AND Name != 'Purchase Taxes' ORDER By Date__c];

        List<PaymentPlanWrapper> firstPaymentPlans = new List<PaymentPlanWrapper>();
        List<PaymentPlanWrapper> restOfPaymentPlans = new List<PaymentPlanWrapper>();
        Decimal price = 0;
        Decimal priceCHF = 0;
        Decimal priceUSD = 0;
        Decimal priceEUR = 0;
        Decimal priceRUB = 0;
        Decimal priceGBP = 0;
        Decimal priceAED = 0;
        for(Integer i = 0; i < cashFlows.size(); i++) {
            String dt;
            if(i == 0){
                dt = DateTime.now().format('dd MMM yyyy');
            } else {
                dt = DateTime.newInstance(cashFlows[i].Date__c.year(),cashFlows[i].Date__c.month(),cashFlows[i].Date__c.day()).format('dd MMM yyyy');
            }
            if(i < 8){
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
            priceUSD+=cashFlows[i].Amount_USD__c;
            priceEUR+=cashFlows[i].Amount_EUR__c;
            priceRUB+=cashFlows[i].Amount_RUB__c;
            priceGBP+=cashFlows[i].Amount_GBP__c;
            priceCHF+=cashFlows[i].Price_CHF__c;
            priceAED+=cashFlows[i].Amount_AED__c;
        }
        this.paymentPlansFirst = firstPaymentPlans;
        this.paymentPlansRest = restOfPaymentPlans;
        if(restOfPaymentPlans.isEmpty()){
          this.lessPayments = true;
        } else {
          this.lessPayments = false;

        }
        this.purchasePrice = formatNumber(price);
        this.purchasePriceUSD = formatNumber(priceUSD);
        this.purchasePriceEUR = formatNumber(priceEUR);
        this.purchasePriceRUB = formatNumber(priceRUB);
        this.purchasePriceGBP = formatNumber(priceGBP);
        this.purchasePriceCHF = formatNumber(priceCHF);
        this.purchasePriceAED = formatNumber(priceAED);
        String docType;

        if (unit.Project_Name_F__c == 'POST HOTEL & RESIDENCES By ELIE SAAB') {
            docType = 'Floor Plan';
        } else if (unit.Project_Name_F__c == 'Trussardi Residences MIRA VERDE' || unit.Project_Name_F__c == 'John Richmond Residences') {
            docType = 'Sales Offer';
        } else {
            docType = 'Schemas/PDFs';
        }

        Map<Id, File__c> files = new Map<Id, File__c>([SELECT Id, Description__c FROM File__c WHERE Unit__c = :unitId AND Type__c = :docType ORDER BY Order__c]);
        if(!files.keySet().isEmpty()){

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
          
          List<ContentVersion> cvs = [
                      SELECT Id, ContentDocumentId
                      FROM ContentVersion
                      WHERE ContentDocumentId IN:cdids];
          Map<String,String> imageUrlToStyle = new Map<String,String>();
          Map<String,String> imageUrlToDesc = new Map<String,String>();

          if (unit.Project_Name_F__c == 'POST HOTEL & RESIDENCES By ELIE SAAB' || unit.Project_Name_F__c == 'John Richmond District') {
            // Keep original behavior for POST: use the original file download (no thumbnailing).
            for (Integer i = 0; i < cvs.size(); i++) {
              String url = '/sfc/servlet.shepherd/version/download/' + cvs[i].Id;
              imageUrlToStyle.put(url, '100%');
              imageUrlToDesc.put(url, m.get(cvs[i].ContentDocumentId) != null ? m.get(cvs[i].ContentDocumentId) : '');
            }
          } else if (unit.Project_Name_F__c == 'GIANFRANCO FERRE RESIDENCES') {
            // Apply the "fit + smaller file size" fix ONLY for Gianfranco: use a bounded rendition.
            for (Integer i = 0; i < cvs.size(); i++) {
              String url = '/sfc/servlet.shepherd/version/download/' + cvs[i].Id;
              imageUrlToStyle.put(url, '100%');
              imageUrlToDesc.put(url, m.get(cvs[i].ContentDocumentId) != null ? m.get(cvs[i].ContentDocumentId) : '');
            }
          } else {
            for(Integer i = 0; i < cvs.size(); i++) {
              if (System.Math.mod(cvs.size(), 2) != 0 && i+1 == cvs.size()) {
                // If there's an odd last image, render it full-width so it doesn't float into a narrow column.
                String url = '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + cvs[i].Id;
                imageUrlToStyle.put(url, '100%');
                imageUrlToDesc.put(url, m.get(cvs[i].ContentDocumentId) != null ? m.get(cvs[i].ContentDocumentId) : '');
              } else {
                String url = '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + cvs[i].Id;
                imageUrlToStyle.put(url, '49%');
                imageUrlToDesc.put(url, m.get(cvs[i].ContentDocumentId) != null ? m.get(cvs[i].ContentDocumentId) : '');
              }
            }
          }
          this.imageUrlToStyle = imageUrlToStyle;
          this.imageUrlToStyleKeySet = imageUrlToStyle.keySet();
          this.imageUrlToDesc = imageUrlToDesc;
          if(imageUrlToStyle.keySet().size() == 1){
            this.isOnePic = true;
          } else {
            this.isOnePic = false;
          }
        }
    }
}