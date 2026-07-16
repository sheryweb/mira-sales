public without sharing class BookingFormPDFController {

    public String getBookingFormPDF() {
        return null;
    }


    public String getTodayDate() {
        return null;
    }

    public Map<String, Object> oppData {get; set;}
    public Set<String> imageUrlToStyleKeySet {get; set;}
    public Map<String, String> imageUrlToStyle{get; set;}
    public Map<String, String> imageUrlToDesc{get; set;}
    public Boolean hasJointOwners { get; private set; }
    public List<Account> jointOwnerAccounts { get; private set; }
    public Map<Id, String> jointOwnersOwnershipById { get; private set; }
    public Map<Id, String> jointOwnersLicenseValuesById { get; private set; }
    public Map<Id, String> jointOwnersIncorporationValuesById { get; private set; }
    public Map<Id, String> jointOwnersIncorporationValuesArabicById { get; private set; }
    public Map<Id, String> jointFundSourceArabicById { get; private set; }
    public Map<Id, String> jointPaymentMethodsArabicById { get; private set; }
    public Map<Id, String> jointArabicNameById { get; private set; }
    public Boolean hasSharedContacts { get; private set; }
    public List<Contact> sharedContactList { get; private set; }
    
    
    /* Format decimal numbers*/
    public static String formatNumber(Decimal numberToFormat) {
        if(numberToFormat == null) {
            return '0.00';
        }
        String numberStr = String.valueOf(numberToFormat);
        if(numberStr != null && numberStr != 'null'){
            
            List<String> parts = numberStr.split('\\.');
            String integerPart = parts[0];
            String decimalPart = parts.size() > 1 ? parts[1] : '00';
            
            integerPart = addCommas(integerPart);
            
            return integerPart + '.' + decimalPart;
        }
        return '0.00';
    }
    /*END*/
    
    /* Add commas to decimal numbers*/
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
    /*END*/
    
    /* String reversal*/
    private static String reverseString(String input) {
        String output = '';
        for (Integer i = input.length() - 1; i >= 0; i--) {
            output += input.substring(i, i + 1);
        }
        return output;
    }
    /*END*/
    
    public static String RegistrationFeeSetup(String RegFee) {
        String registrationFee;
        if (RegFee == null) {
            registrationFee = '٥٠٪؜ تدفع من قبل المشترى ، و ٥٠٪؜  تدفع من قبل البائع ، يدفع المشترى جميع الرسوم الادارية';
        } else if (RegFee == 'Fully paid by the Purchaser') {
            registrationFee = 'مدفوعة بالكامل من قبل المشتري';
        } else if (RegFee == 'Fully paid by the Seller') {
            registrationFee = 'مدفوعة بالكامل من قبل البائع';
        } else If (RegFee == '25% payable by Purchaser, 75% payable by Seller, Purchaser pays all administration fees') {
            registrationFee = '٢٥٪؜ تدفع من قبل المشترى ، و ٧٥٪؜  تدفع من قبل البائع ، يدفع المشترى جميع الرسوم الادارية';
        } else If (RegFee == '75% payable by Purchaser, 25% payable by Seller, Purchaser pays all administration fees') {
            registrationFee = '٧٥٪؜ تدفع من قبل المشترى ، و ٢٥٪؜  تدفع من قبل البائع ، يدفع المشترى جميع الرسوم الادارية';
        } else {
            registrationFee = '٥٠٪؜ تدفع من قبل المشترى ، و ٥٠٪؜  تدفع من قبل البائع ، يدفع المشترى جميع الرسوم الادارية';
        }
        
        return registrationFee;
    }
    
    public static String removeNull(String textPassed) {
        if (textPassed == null) {
            return '';
        } else {
            return textPassed;
        }
    }
    
    public static Date removeNullFromDate(Date datePassed) {
        if (datePassed == null) {
            return date.today();
        } else {
            return datePassed;
        }
    }
    
    public static String addNotReceived(String textPassed) {
        if (textPassed == null) {
            return 'Not Received';
        } else {
            return textPassed;
        }
    }
    
    /*Conversion to Arabic for Source of Funds*/
    public static String arabicConversionFundSource(String engValue) {
        String arabicString;
        
        if(engValue == null) {
            return 'آخر__________';
        }
        
        switch on engValue {
            when 'Salary' {
                arabicString = 'راتب';
            }
            when 'Investments' {
                arabicString = 'استثمارات';
            }
            when 'Business Income' {
                arabicString = 'دخل من الأعمال';
            }
            when 'Loans' {
                arabicString = 'قروض';
            }
            when else {
                arabicString = 'آخر__________';
            }
        }
        
        return arabicString;
    }
    
    /*Conversion to Arabic for Payment Methods*/
    public static String arabicConversionPaymentMethods(String selectedValue) {
        if(selectedValue == null || selectedValue.trim() == '') {
            return 'آخر__________';
        }
        
        List<String> pMethods = new List<String>();
        String managedListMethods = '';
        pMethods.addAll(selectedValue.split(';'));
        for (String pm: pMethods) {
            if(pm != null && pm.trim() != '') {
                switch on pm.trim() {
                    when 'Cash' {
                        managedListMethods = managedListMethods+'نقدأ, ';
                    }
                    when 'Cheques' {
                        managedListMethods = managedListMethods+'شيكات, ';
                    }
                    when 'Bank Transfer' {
                        managedListMethods = managedListMethods+'تحويل بنكى, ';
                    }
                    when else {
                        managedListMethods = managedListMethods+'آخر__________';
                    }
                }
            }
        }
        return managedListMethods.removeEnd(', ');
    }

    private static List<Contact> orderSharedContactsPrimaryFirst(List<Contact> contacts) {
        List<Contact> orderedContacts = new List<Contact>();
        List<Contact> otherContacts = new List<Contact>();
        for (Contact contact : contacts) {
            if (contact.Primary__c == true) {
                orderedContacts.add(contact);
            } else {
                otherContacts.add(contact);
            }
        }
        orderedContacts.addAll(otherContacts);
        return orderedContacts;
    }
    
    /*Conversion to Arabic Map for Payment Terms*/
    public static Map<String, String> convertedToArabicTerms = new Map<String, String> {
        'Booking/ Reservation' => 'حجز القيد/ الحجز',
        'Booking / Reservation' => 'حجز القيد / الحجز',
        'Booking/Reservation' => 'حجز القيد/الحجز',
        'Not Applicable' => 'لا ينطبق',
        '80% of Construction' => 'ثمانون (٨٠٪) من نسبة البناء',
        '80% of Construction (On Handover)' => '٨٠٪ من البناء (عند التسليم)',
        '100% of Construction' => 'مئة بالمائة (١٠٠٪) من نسبة البناء',
        '100% of Construction (On Handover)' => '١٠٠٪ من البناء (عند التسليم)',
        '1 Month after Handover' => '١ شهر بعد التسليم',
        '2 Months after Handover' => '٢ أشهر بعد التسليم',
        '3 Months after Handover' => '٣ أشهر بعد التسليم',
        '4 Months after Handover' => '٤ أشهر بعد التسليم',
        '5 Months after Handover' => '٥ أشهر بعد التسليم',
        '6 Months after Handover' => '٦ أشهر بعد التسليم',
        '7 Months after Handover' => '٧ أشهر بعد التسليم',
        '8 Months after Handover' => '٨ أشهر بعد التسليم',
        '9 Months after Handover' => '٩ أشهر بعد التسليم',
        '10 Months after Handover' => '١٠ أشهر بعد التسليم',    
        '11 Months after Handover' => '١١ شهر بعد التسليم',
        '12 Months after Handover' => '١٢ شهر بعد التسليم',
        '13 Months after Handover' => '١٣ شهر بعد التسليم',
        '14 Months after Handover' => '١٤ شهر بعد التسليم',
        '15 Months after Handover' => '١٥ شهر بعد التسليم',
        '16 Months after Handover' => '١٦ شهر بعد التسليم',
        '17 Months after Handover' => '١٧ شهر بعد التسليم',
        '18 Months after Handover' => '١٨ شهر بعد التسليم',
        '19 Months after Handover' => '١٩ شهر بعد التسليم',
        '20 Months after Handover' => '٢٠ شهر بعد التسليم',
        '21 Months after Handover' => '٢١ شهر بعد التسليم',
        '22 Months after Handover' => '٢٢ شهر بعد التسليم',
        '23 Months after Handover' => '٢٣ شهر بعد التسليم',
        '24 Months after Handover' => '٢٤ شهر بعد التسليم',
        '25 Months after Handover' => '٢٥ شهر بعد التسليم',
        '26 Months after Handover' => '٢٦ شهر بعد التسليم',
        '27 Months after Handover' => '٢٧ شهر بعد التسليم',
        '28 Months after Handover' => '٢٨ شهر بعد التسليم',
        '29 Months after Handover' => '٢٩ شهر بعد التسليم',
        '30 Months after Handover' => '٣٠ شهر بعد التسليم',
        '31 Months after Handover' => '٣١ شهر بعد التسليم',
        '32 Months after Handover' => '٣٢ شهر بعد التسليم',
        '33 Months after Handover' => '٣٣ شهر بعد التسليم',
        '34 Months after Handover' => '٣٤ شهر بعد التسليم',
        '35 Months after Handover' => '٣٥ شهر بعد التسليم',
        '36 Months after Handover' => '٣٦ شهر بعد التسليم',
        '1st Instalment' => 'القسط الأول',
        '2nd Instalment' => 'القسط الثاني',
        '3rd Instalment' => 'القسط الثالث',
        '4th Instalment' => 'القسط الرابع',
        '5th Instalment' => 'القسط الخامس',
        '6th Instalment' => 'القسط السادس', 
        '7th Instalment' => 'القسط السابع',
        '8th Instalment' => 'القسط الثامن',
        '9th Instalment' => 'القسط التاسع',
        '10th Instalment' => 'القسط العاشر',
        '11th Instalment' => 'القسط الحادي عشر',
        '12th Instalment' => 'القسط الثاني عشر',
        '13th Instalment' => 'القسط الثالث عشر',
        '14th Instalment' => 'القسط الرابع عشر',
        '15th Instalment' => 'القسط الخامس عشر',
        '16th Instalment' => 'القسط السادس عشر',
        '17th Instalment' => 'القسط السابع عشر',
        '18th Instalment' => 'القسط الثامن عشر',
        '19th Instalment' => 'القسط التاسع عشر',
        '20th Instalment' => 'القسط العشرون',
        '21st Instalment' => 'القسط الواحد والعشرون',
        '22nd Instalment' => 'القسط الثاني والعشرون',
        '23rd Instalment' => 'القسط الثالث والعشرون',
        '24th Instalment' => 'القسط الرابع والعشرون',
        '25th Instalment' => 'القسط الخامس والعشرون',
        'First Payment' => 'الدفعة الأولى',
        'Second Payment' => 'الدفعة الثانية',
        'Third Payment' => 'الدفعة الثالثة',
        'Fourth Payment' => 'الدفعة الرابعة',
        'Fifth Payment' => 'الدفعة الخامسة'
    };
    
    /*Conversion to Arabic Map for Unit Types*/
    public static Map<String, String> convertedToArabicUnitType = new Map<String, String> {
        'Apartment' => 'شقة',
        'Villa' => 'فيلا',
        'Branded Villa' => 'فيلا',
        'Townhouse' => 'تاون هاوس',
        'Penthouse' => 'بنت هاوس',
        'Duplex' => 'دوبلكس',
        'Mansion' => 'قصر',
        'Branded Mansion' => 'قصر',
        'Office' => 'مكتب',
        'Retail' => 'محل تجاري'
    };
    
    public BookingFormPDFController() {
        Id oppId = ApexPages.currentPage().getParameters().get('oppId');
        hasJointOwners = false;
        jointOwnerAccounts = new List<Account>();
        jointOwnersOwnershipById = new Map<Id, String>();
        jointOwnersLicenseValuesById = new Map<Id, String>();
        jointOwnersIncorporationValuesById = new Map<Id, String>();
        jointOwnersIncorporationValuesArabicById = new Map<Id, String>();
        jointFundSourceArabicById = new Map<Id, String>();
        jointPaymentMethodsArabicById = new Map<Id, String>();
        jointArabicNameById = new Map<Id, String>();
        hasSharedContacts = false;
        sharedContactList = new List<Contact>();
        
        try {
            Map<String, Object> objectValues = new Map<String, Object>();

            List<Opportunity> opportunities = [
            SELECT 
                Id,
                Name,
                CreatedDate,
                Booking_Date_Time__c,
                Registration_Fees__c,
                Ownership_Share_of_the_Main_Purchaser__c,
                Offer_layout__c,
                Unit__r.Community__c,
                Unit__r.Community_Arabic__c,
                Unit__r.Project__r.Name,
                Unit__r.Project_Name_F__c,
                Unit__r.Project__r.Project_Name_Arabic__c,
                Unit__r.Project_Name_Text__c,
                Unit__r.Project_Name_Text_Arabic__c,
                Unit__r.Title_Formula__c,
                Unit__r.Building__c,
                Unit__r.Building_Arabic_Text__c,
                Unit__r.Number_of_bedrooms__c,
                Unit__r.Living_Space__c,
                Unit__r.Total_Area__c,
                Unit__r.Additional_Area__c,
                Unit__r.Cost_AED__c,
                Unit__r.Cost_GEL__c,
                Unit__r.Cost_USD__c,
                Unit__r.Name,
                Unit__r.Title__c,
                Unit__r.Type__c,
                Unit__r.Property_Code_Text__c,
                Unit__r.Floor__c,
                Unit__r.Balcony_Size__c,
                Unit__c,
                Account.PersonBirthdate,
                Account.Date_of_Birth_Arabic__c,
                Account.Place_of_Birth__pc,
                Account.Place_of_Birth_Arabic__pc,
                Account.Occupation__pc,
                Account.Occupation_Arabic__pc,
                Account.Name,
                Account.FirstName,
                Account.MiddleName,
                Account.LastName,
                Account.Nature_of_Business__pc,
                Account.Nature_of_Business_Arabic__pc,
                Account.Contact_First_Name_Arabic__pc,
                Account.Contact_Last_Name_Arabic__pc,
                Account.Contact_Middle_Name_Arabic__pc,
                Account.Bank_Name__pc,
                Account.Bank_Name_Arabic__pc,
                Account.Subject_to_Sanction__pc,
                Account.RecordTypeId,
                toLabel(Account.Nationality__c),
                Account.Nationality_Arabic__c,
                Account.Country_of_Incorporation_Arabic__c,
                Account.Passport_No__c,
                Account.Passport_Issue_Date_D__pc,
                Account.Passport_Place_of_Issue__pc,
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
                Owner.Name
            FROM Opportunity
            WHERE Id = :oppId LIMIT 1
          ];
          
          if(opportunities.isEmpty()) {
              throw new AuraHandledException('Opportunity not found with ID: ' + oppId);
          }
          
          Opportunity opportunity = opportunities[0];
            
            String bookingDate;
            if(opportunity.Booking_Date_Time__c != null) {
                bookingDate = opportunity.Booking_Date_Time__c.format('dd-MMM-yyyy');
            } else if(opportunity.CreatedDate != null) {
                bookingDate = opportunity.CreatedDate.format('dd-MMM-yyyy');
            } else {
                bookingDate = Date.today().format();
            }
            String passportIssueDate;
            if(opportunity.Account.Passport_Issue_Date_D__pc != null) {
                passportIssueDate = DateTime.newInstance(opportunity.Account.Passport_Issue_Date_D__pc.year(),opportunity.Account.Passport_Issue_Date_D__pc.month(),opportunity.Account.Passport_Issue_Date_D__pc.day()).format('dd-MMM-yyyy');
            } else {
                passportIssueDate = 'N/A';
            }
            objectValues.put('Opportunity', opportunity);
            objectValues.put('BookingDate', bookingDate);
            objectValues.put('PassportIssueDate', passportIssueDate);
            objectValues.put('arabicUnitType', convertedToArabicUnitType);
            
            /*Setting up First Installment & Payment Plans*/
            List<Cash_Flow__c> cashFlows = [SELECT Id, Price_Formula__c, Price_GEL__c, VAT_Amount__c, Total_with_VAT__c, Date__c, Name, Percent__c FROM Cash_Flow__c WHERE Unit__c = :opportunity.Unit__c AND Is_Additional_Payment__c = false AND Name != 'Oqood' AND Name != 'DLD Fee' AND Name != 'Registration Fee' AND Name != 'Purchase Taxes' ORDER BY Date__c ASC LIMIT 30];
            List<Cash_Flow__c> cashFlowsContinue = [SELECT ID, Price_Formula__c, Price_GEL__c, VAT_Amount__c, Total_with_VAT__c, Date__c, Name, Percent__c FROM Cash_Flow__c WHERE Unit__c = :opportunity.Unit__c AND Is_Additional_Payment__c = false AND Name != 'Oqood' AND Name != 'DLD Fee' AND Name != 'Registration Fee' AND Name != 'Purchase Taxes' ORDER BY Date__c ASC LIMIT 60];
            List<Cash_Flow__c> cashFlowsContinue90 = [SELECT ID, Price_Formula__c, Price_GEL__c, VAT_Amount__c, Total_with_VAT__c, Date__c, Name, Percent__c FROM Cash_Flow__c WHERE Unit__c = :opportunity.Unit__c AND Is_Additional_Payment__c = false AND Name != 'Oqood' AND Name != 'DLD Fee' AND Name != 'Registration Fee' AND Name != 'Purchase Taxes' ORDER BY Date__c ASC LIMIT 90];
            
            objectValues.put('agentAssistEng', opportunity.Assisted_by_agent__c == true ? 'Yes' : 'No');
            objectValues.put('agentAssistArabic', opportunity.Assisted_by_agent__c == true ? 'نعم' : 'لا');
            //objectValues.put('sourceOfFundArabic', arabicConversionFundSource(opportunity.Account.Source_of_Funds__pc));
            //objectValues.put('paymentMethodsArabic', arabicConversionPaymentMethods(opportunity.Account.Payment_methods__pc));
            List<Map<String,Object>> paymentPlans = new List<Map<String,Object>>();
            List<Map<String,Object>> paymentPlansContinuation = new List<Map<String,Object>>();
            List<Map<String,Object>> paymentPlansContinuation90 = new List<Map<String,Object>>();
    
            for (Integer i = 0; i < cashFlows.size(); i++) {
                String dt;
                    if(i == 0){
                        dt = bookingDate;
                    } else {
                        if(cashFlows[i].Date__c != null) {
                            dt = DateTime.newInstance(cashFlows[i].Date__c.year(),cashFlows[i].Date__c.month(),cashFlows[i].Date__c.day()).format('dd-MMM-yyyy');
                        } else {
                            dt = bookingDate;
                        }
                    }
                    paymentPlans.add(new Map<String,Object>{
                    'numberOfPlan'=>String.valueOf(i+1), 
                    'milestone'=>cashFlows[i].Name != null ? cashFlows[i].Name : '',
                    'percent'=>String.valueOf(cashFlows[i].Percent__c != null ? cashFlows[i].Percent__c : 0),
                    'paymentDate'=>String.valueOf(dt),
                    'amount'=>formatNumber(cashFlows[i].Price_Formula__c),
                    'amountGEL'=>formatNumber(cashFlows[i].Price_GEL__c),
                    'vatAmount'=>formatNumber(cashFlows[i].VAT_Amount__c),
                    'totalWithVAT'=>formatNumber(cashFlows[i].Total_with_VAT__c)
                });
            }

            for(Integer i = 0; i < cashFlowsContinue.size(); i++) {
                if (i > 29) {
                    String dt;
                    if(cashFlowsContinue[i].Date__c != null) {
                        dt = DateTime.newInstance(cashFlowsContinue[i].Date__c.year(),cashFlowsContinue[i].Date__c.month(),cashFlowsContinue[i].Date__c.day()).format('dd-MMM-yyyy');
                    } else {
                        dt = bookingDate;
                    }
                    paymentPlansContinuation.add(new Map<String,Object>{
                        'numberOfPlan'=>String.valueOf(i+1), 
                        'milestone'=>cashFlowsContinue[i].Name != null ? cashFlowsContinue[i].Name : '',
                        'percent'=>String.valueOf(cashFlowsContinue[i].Percent__c != null ? cashFlowsContinue[i].Percent__c : 0),
                        'paymentDate'=>String.valueOf(dt),
                        'amount'=>formatNumber(cashFlowsContinue[i].Price_Formula__c),
                        'amountGEL'=>formatNumber(cashFlowsContinue[i].Price_GEL__c),
                        'vatAmount'=>formatNumber(cashFlowsContinue[i].VAT_Amount__c),
                        'totalWithVAT'=>formatNumber(cashFlowsContinue[i].Total_with_VAT__c)
                    });
                }
            }

            for(Integer i = 0; i < cashFlowsContinue90.size(); i++) {
                if (i > 59) {
                    String dt;
                    dt = DateTime.newInstance(cashFlowsContinue90[i].Date__c.year(),cashFlowsContinue90[i].Date__c.month(),cashFlowsContinue90[i].Date__c.day()).format('dd-MMM-yyyy');
                    paymentPlansContinuation90.add(new Map<String,Object>{
                        'numberOfPlan'=>String.valueOf(i+1), 
                        'milestone'=>cashFlowsContinue90[i].Name != null ? cashFlowsContinue90[i].Name : '',
                        'percent'=>String.valueOf(cashFlowsContinue90[i].Percent__c != null ? cashFlowsContinue90[i].Percent__c : 0),
                        'paymentDate'=>String.valueOf(dt),
                        'amount'=>formatNumber(cashFlowsContinue90[i].Price_Formula__c),
                        'amountGEL'=>formatNumber(cashFlowsContinue90[i].Price_GEL__c),
                        'vatAmount'=>formatNumber(cashFlowsContinue90[i].VAT_Amount__c),
                        'totalWithVAT'=>formatNumber(cashFlowsContinue90[i].Total_with_VAT__c)
                    });
                }
            }

            objectValues.put('paymentPlans', paymentPlans);
            if (paymentPlansContinuation.size() > 0) {
                objectValues.put('paymentPlansContinuation', paymentPlansContinuation);
            } else {
                objectValues.put('paymentPlansContinuation', 'Null');
            }
            if (paymentPlansContinuation90.size() > 0) {
                objectValues.put('paymentPlansContinuation90', paymentPlansContinuation90);
            } else {
                objectValues.put('paymentPlansContinuation90', 'Null');
            }
            objectValues.put('arabicMilestones', convertedToArabicTerms);
            /*END*/
            
            /*Putting all Numbers to format*/
            Map<String, String> numbersToFormat = new Map<String, String>();
            numbersToFormat.put('formattedTotalArea', formatNumber(opportunity.Unit__r.Total_Area__c));
            numbersToFormat.put('formattedPlotArea', opportunity.Unit__r.Additional_Area__c != null && opportunity.Unit__r.Additional_Area__c > 0 ? formatNumber(opportunity.Unit__r.Additional_Area__c) : '');
            numbersToFormat.put('formattedSuiteArea', opportunity.Unit__r.Living_Space__c != null && opportunity.Unit__r.Living_Space__c > 0 ? formatNumber(opportunity.Unit__r.Living_Space__c) : '');
            numbersToFormat.put('formattedUnitCost', formatNumber(opportunity.Unit__r.Cost_AED__c));
            numbersToFormat.put('formattedUnitCostGEL', formatNumber(opportunity.Unit__r.Cost_GEL__c));
            numbersToFormat.put('formattedUnitCostUSD', formatNumber(opportunity.Unit__r.Cost_USD__c));
            numbersToFormat.put('firstInstallment', cashFlows.size() > 0 ? formatNumber(cashFlows[0].Price_Formula__c) : '0.00');
            objectValues.put('formattedNumbers', numbersToFormat);
            /*END*/
            
            /*Setting up Registration Fee*/
            objectValues.put('registrationFee', RegistrationFeeSetup(opportunity.Registration_Fees__c));
            /*END*/
            
            /*Setting up Arabic Account Name*/
            String arabicAccountName;
            if(opportunity.Account.IsPersonAccount) {
                arabicAccountName = removeNull(opportunity.Account.Contact_First_Name_Arabic__pc)+' '+removeNull(opportunity.Account.Contact_Middle_Name_Arabic__pc)+' '+removeNull(opportunity.Account.Contact_Last_Name_Arabic__pc);
            } else {
                arabicAccountName = removeNull(opportunity.Account.Account_Name_Arabic__c);
            }
            objectValues.put('arabicAccountName', arabicAccountName);
            /*END*/
            
            /*Setting up License & Incorporation Country Values for Single Account & Primary Due Deligence*/
            Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Client').getRecordTypeId();
            Map<String, Object> dueDeligenceMap = new Map<String, Object>();
            Map<String, Object> personInformation = new Map<String, Object>();
            
            if(opportunity.Account.RecordTypeId == personAccountRecordTypeId) {
                personInformation.put('personPhone', opportunity.Account.Phone);
                personInformation.put('personEmail', opportunity.Account.PersonEmail);
                personInformation.put('personMobile', opportunity.Account.PersonMobilePhone);
                dueDeligenceMap.put('contactBirthDate', removeNullFromDate(opportunity.Account.PersonBirthdate));
                dueDeligenceMap.put('contactBirthPlace', removeNull(opportunity.Account.Place_of_Birth__pc));
                dueDeligenceMap.put('contactBirthPlaceArabic', removeNull(opportunity.Account.Place_of_Birth_Arabic__pc));
                dueDeligenceMap.put('contactOccupation', removeNull(opportunity.Account.Occupation__pc));
                dueDeligenceMap.put('contactOccupationArabic', removeNull(opportunity.Account.Occupation_Arabic__pc));
                dueDeligenceMap.put('contactBusinessNature', removeNull(opportunity.Account.Nature_of_Business__pc));
                dueDeligenceMap.put('contactBusinessNatureArabic', removeNull(opportunity.Account.Nature_of_Business_Arabic__pc));
                dueDeligenceMap.put('contactFundSource', removeNull(opportunity.Account.Source_of_Funds__pc));
                dueDeligenceMap.put('contactExposedPolitically', removeNull(opportunity.Account.Politically_Exposed__pc));
                dueDeligenceMap.put('contactSubjectSanction', removeNull(opportunity.Account.Subject_to_Sanction__pc));
                dueDeligenceMap.put('contactPaymentMethods', removeNull(opportunity.Account.Payment_methods__pc));
                dueDeligenceMap.put('contactBankName', removeNull(opportunity.Account.Bank_Name__pc));
                dueDeligenceMap.put('contactBankNameArabic', removeNull(opportunity.Account.Bank_Name_Arabic__pc));
                dueDeligenceMap.put('contactCurrency', removeNull(opportunity.Account.Currency__pc));
                dueDeligenceMap.put('contactCurrencyOther', removeNull(opportunity.Account.Currency_Other__pc));
                dueDeligenceMap.put('contactCurrencyOtherArabic', removeNull(opportunity.Account.Currency_Other_Arabic__pc));
                objectValues.put('licenseNumberValue', 'N/A');
                objectValues.put('incorporationCountry', 'N/A');
                objectValues.put('incorporationCountryArabic', 'N/A');
                objectValues.put('sourceOfFundArabic', arabicConversionFundSource(opportunity.Account.Source_of_Funds__pc));
                objectValues.put('paymentMethodsArabic', arabicConversionPaymentMethods(opportunity.Account.Payment_methods__pc));
                
                objectValues.put('sharedContacts', 'Null');
            } else {
                List<Contact> sharedContacts = [
                    SELECT Id, 
                    Name, 
                    FirstName, 
                    MiddleName, 
                    LastName, 
                    Company_Share__c, 
                    Position_in_Company__c, 
                    toLabel(Nationality__c), 
                    Passport_No__c,
                    Birth_Date__c,
                    Place_of_Birth__c,
                    Place_of_Birth_Arabic__c,
                    Occupation__c,
                    Occupation_Arabic__c,
                    Source_of_Funds__c,
                    Source_of_Funds_Other__c,
                    Source_of_Funds_Other_Arabic__c,
                    Subject_to_Sanction__c,
                    Politically_Exposed__c,
                    Politically_Exposed_Person_Text__c,
                    Politically_Exposed_Person_Text_Arabic__c,
                    Payment_methods__c,
                    Payment_Methods_Other__c,
                    Payment_Methods_Other_Arabic__c,
                    Bank_Name__c,
                    Bank_Name_Arabic__c,
                    Nature_of_Business__c,
                    Nature_of_Business_Arabic__c,
                    Currency__c,
                    Currency_Other__c,
                    Currency_Other_Arabic__c,
                    Primary__c
                    FROM Contact WHERE AccountId = :opportunity.AccountId
                ];
                Contact relatedContact = [
                    SELECT Id,
                    Name,
                    FirstName,
                    LastName,
                    Email,
                    Phone,
                    MobilePhone,
                    Birth_Date__c,
                    Place_of_Birth__c,
                    Place_of_Birth_Arabic__c,
                    Occupation__c,
                    Occupation_Arabic__c,
                    Source_of_Funds__c,
                    Source_of_Funds_Other__c,
                    Source_of_Funds_Other_Arabic__c,
                    Subject_to_Sanction__c,
                    Politically_Exposed__c,
                    Politically_Exposed_Person_Text__c,
                    Politically_Exposed_Person_Text_Arabic__c,
                    Payment_methods__c,
                    Payment_Methods_Other__c,
                    Payment_Methods_Other_Arabic__c,
                    Bank_Name__c,
                    Bank_Name_Arabic__c,
                    Nature_of_Business__c,
                    Nature_of_Business_Arabic__c,
                    Currency__c,
                    Currency_Other__c,
                    Currency_Other_Arabic__c
                    FROM Contact WHERE AccountId = :opportunity.AccountId AND Primary__c = true ORDER BY Id ASC Limit 1
                ];
                personInformation.put('personPhone', relatedContact.Phone);
                personInformation.put('personEmail', relatedContact.Email);
                personInformation.put('personMobile', relatedContact.MobilePhone);
                dueDeligenceMap.put('contactBirthDate', removeNullFromDate(relatedContact.Birth_Date__c));
                dueDeligenceMap.put('contactBirthPlace', removeNull(relatedContact.Place_of_Birth__c));
                dueDeligenceMap.put('contactBirthPlaceArabic', removeNull(relatedContact.Place_of_Birth_Arabic__c));
                dueDeligenceMap.put('contactOccupation', removeNull(relatedContact.Occupation__c));
                dueDeligenceMap.put('contactOccupationArabic', removeNull(relatedContact.Occupation_Arabic__c));
                dueDeligenceMap.put('contactBusinessNature', removeNull(relatedContact.Nature_of_Business__c));
                dueDeligenceMap.put('contactBusinessNatureArabic', removeNull(relatedContact.Nature_of_Business_Arabic__c));
                dueDeligenceMap.put('contactFundSource', removeNull(relatedContact.Source_of_Funds__c));
                dueDeligenceMap.put('contactExposedPolitically', removeNull(relatedContact.Politically_Exposed__c));
                dueDeligenceMap.put('contactSubjectSanction', removeNull(relatedContact.Subject_to_Sanction__c));
                dueDeligenceMap.put('contactPaymentMethods', removeNull(relatedContact.Payment_methods__c));
                dueDeligenceMap.put('contactBankName', removeNull(relatedContact.Bank_Name__c));
                dueDeligenceMap.put('contactBankNameArabic', removeNull(relatedContact.Bank_Name_Arabic__c));
                dueDeligenceMap.put('contactCurrency', removeNull(relatedContact.Currency__c));
                dueDeligenceMap.put('contactCurrencyOther', removeNull(relatedContact.Currency_Other__c));
                dueDeligenceMap.put('contactCurrencyOtherArabic', removeNull(relatedContact.Currency_Other_Arabic__c));
                objectValues.put('licenseNumberValue', addNotReceived(opportunity.Account.Trade_License_Number__c));
                objectValues.put('incorporationCountry', addNotReceived(opportunity.Account.Country_of_Incorporation__c));
                objectValues.put('incorporationCountryArabic', addNotReceived(opportunity.Account.Country_of_Incorporation_Arabic__c));
                objectValues.put('sourceOfFundArabic', arabicConversionFundSource(relatedContact.Source_of_Funds__c));
              objectValues.put('paymentMethodsArabic', arabicConversionPaymentMethods(relatedContact.Payment_methods__c));
                
                sharedContactList = orderSharedContactsPrimaryFirst(sharedContacts);
                hasSharedContacts = !sharedContactList.isEmpty();
                objectValues.put('sharedContacts', sharedContactList);
                objectValues.put('primaryContactId', relatedContact.Id);
                
                // Create maps for sharedContacts due diligence (similar to joint owners)
                Map<String, String> sharedContactFundSourceArabic = new Map<String, String>();
                Map<String, String> sharedContactPaymentMethodsArabic = new Map<String, String>();
                
                for (Contact contact : sharedContacts) {
                    sharedContactFundSourceArabic.put(contact.Id, arabicConversionFundSource(contact.Source_of_Funds__c));
                    sharedContactPaymentMethodsArabic.put(contact.Id, arabicConversionPaymentMethods(contact.Payment_methods__c));
                }
                
                objectValues.put('sharedContactFundSourceArabic', sharedContactFundSourceArabic);
                objectValues.put('sharedContactPaymentMethodsArabic', sharedContactPaymentMethodsArabic);
            }
            objectValues.put('personInformation', personInformation);
            objectValues.put('DueDeligence', dueDeligenceMap);
            /*END*/
            
        /*Joint Owners Management*/
        List<Joint_Owners__c> jOwners = [SELECT Id, Account__c, Order__c, Ownership_Share__c FROM Joint_Owners__c WHERE Opportunity__c = :opportunity.Id ORDER BY Order__c Asc];
        //System.debug(opportunity.Joint_Owners__r);
        
        if (jOwners.size() > 0) {
                Map<String, String> jointOwnerIdToOrder = new Map<String, String>();
                Map<String, String> jointOwnerIdToOwnership = new Map<String, String>();
        
                Set<Id> jointOwnersIds = new Set<Id>();
                for(Joint_Owners__c jointOwner : jOwners){
                    if(jointOwner.Account__c == null) {
                        continue;
                    }
                    jointOwnersIds.add(jointOwner.Account__c);
                    jointOwnerIdToOrder.put(jointOwner.Account__c.toString(), jointOwner.Order__c != null ? jointOwner.Order__c.toString() : '');
                    jointOwnerIdToOwnership.put(jointOwner.Account__c.toString(), jointOwner.Ownership_Share__c != null ? jointOwner.Ownership_Share__c.toString() : '');
                    jointOwnersOwnershipById.put(jointOwner.Account__c, jointOwner.Ownership_Share__c != null ? jointOwner.Ownership_Share__c.toString() : '');
                }
                
                objectValues.put('jointOwnersOrder', jointOwnerIdToOrder);
                objectValues.put('jointOwnersOwnership', jointOwnerIdToOwnership);
                
                List<Account> jointOwners = [
                    SELECT 
                        Id,
                        RecordTypeId, 
                        Trade_License_Number__c, 
                        Name,
                        FirstName,
                        MiddleName,
                        LastName,
                        toLabel(Nationality__c), 
                        Passport_No__c, 
                        Passport_Issue_Date_D__pc,
                        Passport_Place_of_Issue__pc,
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
                        Date_of_Birth_Arabic__c,
                        Occupation__pc,
                        Occupation_Arabic__pc,
                        Place_of_Birth__pc,
                        Place_of_Birth_Arabic__pc,
                        Nature_of_Business__pc,
                        Nature_of_Business_Arabic__pc,
                        toLabel(Source_of_Funds__pc),
                        Source_of_Funds_Other__pc,
                        Source_of_Funds_Other_Arabic__pc,
                        Politically_Exposed__pc,
                        Politically_Exposed_Person_Text__pc,
                        Politically_Exposed_Person_Text_Arabic__pc,
                        Subject_to_Sanction__pc,
                        Bank_Name__pc,
                        Bank_Name_Arabic__pc,
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
        
                Map<Id, Account> jointOwnerById = new Map<Id, Account>(jointOwners);
                List<Account> orderedJointOwners = new List<Account>();
                for (Joint_Owners__c jointOwner : jOwners) {
                    if (jointOwner.Account__c != null && jointOwnerById.containsKey(jointOwner.Account__c)) {
                        orderedJointOwners.add(jointOwnerById.get(jointOwner.Account__c));
                    }
                }
                jointOwnerAccounts = orderedJointOwners;
                hasJointOwners = !orderedJointOwners.isEmpty();
                objectValues.put('jointOwners', hasJointOwners ? (Object)orderedJointOwners : 'Null');
                
                Map<String, String> jointOwnerIdToLicenseNumberValue = new Map<String, String>();
                Map<String, String> jointOwnerIdToIncorporationCountry = new Map<String, String>();
                Map<String, String> jointOwnerIdToIncorporationCountryArabic = new Map<String, String>();
                Map<String, String> jointFundSourceArabic = new Map<String, String>();
                Map<String, String> jointPaymentMethodsArabic = new Map<String, String>();
                Map<String, String> jointPurchaserArabicName = new Map<String, String>();
                Map<String, String> jointOwnerIdToPassportIssueDate = new Map<String, String>();
                
                for (Account account : orderedJointOwners) {
                    if(account.Passport_Issue_Date_D__pc != null) {
                        jointOwnerIdToPassportIssueDate.put(account.Id, DateTime.newInstance(account.Passport_Issue_Date_D__pc.year(), account.Passport_Issue_Date_D__pc.month(), account.Passport_Issue_Date_D__pc.day()).format('dd-MMM-yyyy'));
                    } else {
                        jointOwnerIdToPassportIssueDate.put(account.Id, 'N/A');
                    }
                    jointFundSourceArabic.put(account.Id, arabicConversionFundSource(account.Source_of_Funds__pc));
                    jointPaymentMethodsArabic.put(account.Id, arabicConversionPaymentMethods(account.Payment_methods__pc));
                    jointFundSourceArabicById.put(account.Id, arabicConversionFundSource(account.Source_of_Funds__pc));
                    jointPaymentMethodsArabicById.put(account.Id, arabicConversionPaymentMethods(account.Payment_methods__pc));
                    if(account.RecordTypeId == personAccountRecordTypeId) {
                        jointOwnerIdToLicenseNumberValue.put(account.Id, 'N/A');
                        jointOwnerIdToIncorporationCountry.put(account.Id, 'N/A');
                        jointOwnerIdToIncorporationCountryArabic.put(account.Id, 'N/A');
                        jointPurchaserArabicName.put(account.Id, removeNull(account.Contact_First_Name_Arabic__pc)+' '+removeNull(account.Contact_Middle_Name_Arabic__pc)+' '+removeNull(account.Contact_Last_Name_Arabic__pc));
                        jointOwnersLicenseValuesById.put(account.Id, 'N/A');
                        jointOwnersIncorporationValuesById.put(account.Id, 'N/A');
                        jointOwnersIncorporationValuesArabicById.put(account.Id, 'N/A');
                    } else {
                        jointOwnerIdToLicenseNumberValue.put(account.Id, addNotReceived(account.Trade_License_Number__c));
                        jointOwnerIdToIncorporationCountry.put(account.Id, addNotReceived(account.Country_of_Incorporation__c));
                        jointOwnerIdToIncorporationCountryArabic.put(account.Id, addNotReceived(account.Country_of_Incorporation_Arabic__c));
                        jointPurchaserArabicName.put(account.Id, account.Account_Name_Arabic__c);
                        jointOwnersLicenseValuesById.put(account.Id, addNotReceived(account.Trade_License_Number__c));
                        jointOwnersIncorporationValuesById.put(account.Id, addNotReceived(account.Country_of_Incorporation__c));
                        jointOwnersIncorporationValuesArabicById.put(account.Id, addNotReceived(account.Country_of_Incorporation_Arabic__c));
                    }
                    jointArabicNameById.put(account.Id, jointPurchaserArabicName.get(account.Id));
                }
                objectValues.put('jointFundSourceArabic', jointFundSourceArabic);
                objectValues.put('jointPaymentMethodsArabic', jointPaymentMethodsArabic);
                objectValues.put('jointOwnersLicenseValues', jointOwnerIdToLicenseNumberValue);
                objectValues.put('jointOwnersIncorporationValues', jointOwnerIdToIncorporationCountry);
                objectValues.put('jointOwnersIncorporationValuesArabic', jointOwnerIdToIncorporationCountryArabic);
                objectValues.put('jointArabicName', jointPurchaserArabicName);
                objectValues.put('jointOwnersPassportIssueDate', jointOwnerIdToPassportIssueDate);
            } else {
                objectValues.put('jointOwners', 'Null');
            }
            /*END*/
            
            /*Sending Record Type*/
            objectValues.put('personAccountRecordType', personAccountRecordTypeId);
            objectValues.put('accountRecordType', opportunity.Account.RecordTypeId);
            /*END*/
            
            /*Setting up Floor Plan*/
            String pdfFileType;
            if(opportunity.Offer_layout__c == 'Contemporary') {
                pdfFileType = 'Contemporary Floor Plan';
            } else if(opportunity.Offer_layout__c == 'Formal') {
                pdfFileType = 'Formal Floor Plan';
            } else if(opportunity.Offer_layout__c == 'Traditional') {
                pdfFileType = 'Traditional Floor Plan';
            } else {
                pdfFileType = '';
            }

            List<String> projectNames = new List<String>{
                'Trussardi Residences',
                'Trussardi Residences 2',
                'GIANFRANCO FERRE RESIDENCES',
                'Trussardi Residences 2 Offices'
            };
            
            /*if (projectNames.contains(opportunity.Unit__r.Project__r.Name)) {
                pdfFileType = '';
            }*/
            Map<Id, File__c> pdfFile = new Map<Id, File__c>();
            if(opportunity.Unit__c != null) {
                pdfFile = new Map<Id, File__c>([SELECT Id, Description__c FROM File__c WHERE Unit__c = :opportunity.Unit__c AND Type__c = 'Floor Plan' AND Layout__c = :pdfFileType LIMIT 1]);
            }
            
            if (!pdfFile.keySet().isEmpty()) {
                Map<String,String> m = new Map<String,String>();
                List<ContentDocumentLink> cdls = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :pdfFile.keySet()];
                
                Set<Id> cdids = new Set<Id>();
                for(ContentDocumentLink cdl : cdls){
                    cdids.add(cdl.ContentDocumentId);
                    m.put(cdl.ContentDocumentId, pdfFile.get(cdl.LinkedEntityId).Description__c);
                }
                
                List<ContentVersion> cvs = [SELECT Id, ContentDocumentId FROM  ContentVersion WHERE ContentDocumentId IN :cdids ORDER BY Title];
                Map<String,String> imageUrlToStyle = new Map<String,String>();
                Map<String,String> imageUrlToDesc = new Map<String,String>();
                if (opportunity.Unit__r.Project__r.Name == 'GIANFRANCO FERRE RESIDENCES' || opportunity.Unit__r.Project__r.Name == 'Trussardi Residences 2 Offices' || opportunity.Unit__r.Project__r.Name == 'Trussardi Residences MIRA VERDE' || opportunity.Unit__r.Project__r.Name == 'John Richmond District') {
                    //if () {
                        for(Integer i = 0; i < cvs.size(); i++) {
                            imageUrlToStyle.put('/sfc/servlet.shepherd/version/download/' + cvs[i].Id, '100%');
                            imageUrlToDesc.put('/sfc/servlet.shepherd/version/download/' + cvs[i].Id, m.get(cvs[i].ContentDocumentId) != null ? m.get(cvs[i].ContentDocumentId) : '');
                        }
                    //}
                } else {
                    for(Integer i = 0; i < cvs.size(); i++) {
                      if (System.Math.mod(cvs.size(), 2) != 0 && i+1 == cvs.size()) {
                        imageUrlToStyle.put('/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + cvs[i].Id, '');
                      } else {
                        imageUrlToStyle.put('/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + cvs[i].Id, '49%');
                      }
                      imageUrlToDesc.put('/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + cvs[i].Id, m.get(cvs[i].ContentDocumentId) != null ? m.get(cvs[i].ContentDocumentId) : '');
                    }
                }
                this.imageUrlToStyle = imageUrlToStyle;
                this.imageUrlToStyleKeySet = imageUrlToStyle.keySet();
                this.imageUrlToDesc = imageUrlToDesc;
            }
            /*END*/
            
            oppData = objectValues;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}