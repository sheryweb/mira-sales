public class SpaJohnRichmondController {
    public String getTodayDate() {
        return null;
    }

    public Map<String, Object> oppData {get; set;}
    public Set<String> imageUrlToStyleKeySet {get; set;}
    public Map<String, String> imageUrlToStyle{get; set;}
    public Map<String, String> imageUrlToDesc{get; set;}
    
    
    /* Format decimal numbers*/
    public static String formatNumber(Decimal numberToFormat) {
        String numberStr = String.valueOf(numberToFormat);
        if (numberStr != null) {
            
            List<String> parts = numberStr.split('\\.');
            String integerPart = parts[0];
            String decimalPart = parts.size() > 1 ? parts[1] : '00';
            
            integerPart = addCommas(integerPart);
            
            return integerPart + '.' + decimalPart;
        }
        return numberStr;
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
        if (RegFee == 'Fully paid by the Purchaser') {
            registrationFee = 'مدفوعة بالكامل من قبل المشتري';
        } else if (RegFee == 'Fully paid by the Seller') {
            registrationFee = 'مدفوعة بالكامل من قبل البائع';
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
        if (textPassed == null || textPassed == '') {
            return 'Not Received';
        } else {
            return textPassed;
        }
    }
    
    public static String addNotApplicable(String textPassed) {
        if (textPassed == null || textPassed == '') {
            return 'Not Applicable';
        } else {
            return textPassed;
        }
    }
    
    public static String addNotApplicableArabic(String textPassed) {
        if (textPassed == null || textPassed == '') {
            return 'لا ينطبق';
        } else {
            return textPassed;
        }
    }
    
    /*Conversion to Arabic for Source of Funds*/
    public static String arabicConversionFundSource(String engValue) {
        String arabicString;
        
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
        List<String> pMethods = new List<String>();
            String managedListMethods = '';
            pMethods.addAll(selectedValue.split(';'));
            for (String pm: pMethods) {
                switch on pm {
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
        return managedListMethods.removeEnd(', ');
    }
    
    public static String formatDate(Date passedDate) {
        if (passedDate == null) {
            return 'Not Applicable';
        }
        String formatedDate;
        formatedDate = DateTime.newInstance(passedDate.year(), passedDate.month(), passedDate.day()).format('dd-MMM-YYYY');
        return formatedDate;
    }
    
    public static String arabicDate(Date passedDate) {
        if (passedDate == null) {
            return 'لا ينطبق';
        }
    	String resultedDate;
        resultedDate = convertToArabicNumber.get(passedDate.day())+'-'+convertToArabicMonth.get(passedDate.month())+'-'+convertToArabicYear.get(passedDate.year());

        return resultedDate;
    }
    
    public static String arabicAnticipatedDate(Date passedDate) {
    	String resultedDate;
        resultedDate = convertToArabicMonth.get(passedDate.month())+' '+convertToArabicYear.get(passedDate.year());

        return resultedDate;
    }
    
    public static String arabicState(String passedState) {
        return convertToArabicStates.get(passedState);
    }
    
    public static String arabicNumbers(String passedString) {
        if (passedString == null || passedString == '') {
            return 'لا ينطبق';
        }
        
        String engNumbers = '0, 1, 2, 3, 4, 5, 6, 7, 8, 9';
        String arNumbers =  '٩,٨ ,٧ ,٦ ,٥ ,٤ ,٣ ,٢ ,١ ,٠';
        
        String str1 = passedString.replace('1','١');
        String str2 = str1.replace('2', '٢');
        String str3 = str2.replace('3', '٣');
        String str4 = str3.replace('4', '٤');
        String str5 = str4.replace('5', '٥');
        String str6 = str5.replace('6', '٦');
        String str7 = str6.replace('7', '٧');
        String str8 = str7.replace('8', '٨');
        String str9 = str8.replace('9', '٩');
        String str10 = str9.replace('0', '٠');
        
        return str10;
    }
    
    /*Conversion to Arabic Map for Salutations*/
    public static Map<String, String> convertToArabicSalutation = new Map<String, String> {
        'Mr.' => 'السيد.', 'Mrs.' => 'السّيدة.', 'Miss.' => 'الأنسه.', 'Ms.' => 'الأنسه.'
    };
    
    /*Convertion to Arabic Month*/
    public static Map<Integer, String> convertToArabicMonth = new Map<Integer, String> {
        1 => 'يناير',2 => 'فبراير',3 => 'مارس',4 => 'أبريل',5 => 'مايو',6 => 'يونيو',7 => 'يوليو',8 => 'أغسطس',9 => 'سبتمبر',10 => 'أكتوبر',11 => 'نوفمبر',12 => 'ديسمبر'
    };
        
    /*Convertion to Arabic Year*/
    public static Map<Integer, String> convertToArabicYear = new Map<Integer, String> {
        2022 => '٢٠٢٢', 2023 => '٢٠٢٣', 2024 => '٢٠٢٤', 2025 => '٢٠٢٥', 2026 => '٢٠٢٦', 2027 => '٢٠٢٧', 2028 => '٢٠٢٨', 2029 => '٢٠٢٩', 2030 => '٢٠٣٠', 2031 => '٢٠٣١', 2032 => '٢٠٣٢', 2033 => '٢٠٣٣', 2034 => '٢٠٣٤',
        2035 => '٢٠٣٥', 2036 => '٢٠٣٦', 2037 => '٢٠٣٧', 2038 => '٢٠٣٨', 2039 => '٢٠٣٩', 2040 => '٢٠٤٠', 2041 => '٢٠٤١', 2042 => '٢٠٤٢', 2043 => '٢٠٤٣', 2044 => '٢٠٤٤', 2045 => '٢٠٤٥',
        2046 => '٢٠٤٦', 2047 => '٢٠٤٧', 2048 => '٢٠٤٨', 2049 => '٢٠٤٩', 2050 => '٢٠٥٠'
    };
    
    /*Conversion to Arabic Map for Payment Terms*/
    public static Map<String, String> convertedToArabicTerms = new Map<String, String> {
        'Booking/ Reservation' => 'حجز القيد/ الحجز', 'Booking / Reservation' => 'حجز القيد / الحجز', 'Booking/Reservation' => 'حجز القيد/الحجز', 'Not Applicable' => 'لا ينطبق','100% of Construction' => 'مئة بالمائة (١٠٠٪) من نسبة البناء','1 Month after Handover' => '١ شهر بعد التسليم',
        '2 Months after Handover' => '٢ أشهر بعد التسليم','3 Months after Handover' => '٣ أشهر بعد التسليم','4 Months after Handover' => '٤ أشهر بعد التسليم','5 Months after Handover' => '٥ أشهر بعد التسليم','6 Months after Handover' => '٦ أشهر بعد التسليم',
        '7 Months after Handover' => '٧ أشهر بعد التسليم','8 Months after Handover' => '٨ أشهر بعد التسليم','9 Months after Handover' => '٩ أشهر بعد التسليم','10 Months after Handover' => '١٠ أشهر بعد التسليم','11 Months after Handover' => '١١ شهر بعد التسليم',
        '12 Months after Handover' => '١٢ شهر بعد التسليم','13 Months after Handover' => '١٣ شهر بعد التسليم','14 Months after Handover' => '١٤ شهر بعد التسليم','15 Months after Handover' => '١٥ شهر بعد التسليم','16 Months after Handover' => '١٦ شهر بعد التسليم',
        '17 Months after Handover' => '١٧ شهر بعد التسليم','18 Months after Handover' => '١٨ شهر بعد التسليم','19 Months after Handover' => '١٩ شهر بعد التسليم','20 Months after Handover' => '٢٠ شهر بعد التسليم','21 Months after Handover' => '٢١ شهر بعد التسليم',
        '22 Months after Handover' => '٢٢ شهر بعد التسليم','23 Months after Handover' => '٢٣ شهر بعد التسليم','24 Months after Handover' => '٢٤ شهر بعد التسليم','25 Months after Handover' => '٢٥ شهر بعد التسليم',
        '26 Months after Handover' => '٢٦ شهر بعد التسليم','27 Months after Handover' => '٢٧ شهر بعد التسليم','28 Months after Handover' => '٢٨ شهر بعد التسليم','29 Months after Handover' => '٢٩ شهر بعد التسليم','30 Months after Handover' => '٣٠ شهر بعد التسليم',
        '31 Months after Handover' => '٣١ شهر بعد التسليم','32 Months after Handover' => '٣٢ شهر بعد التسليم','33 Months after Handover' => '٣٣ شهر بعد التسليم','34 Months after Handover' => '٣٤ شهر بعد التسليم',
        '35 Months after Handover' => '٣٥ شهر بعد التسليم','36 Months after Handover' => '٣٦ شهر بعد التسليم'
    };
    
    /*Conversion to Arabic Map for Unit Types*/
    public static Map<String, String> convertToArabicUnitType = new Map<String, String> {
        'Apartment' => 'شقة', 'Villa' => 'فيلا', 'Townhouse' => 'تاون هاوس', 'Penthouse' => 'بنت هاوس', 'Duplex' => 'دوبلكس', 'Mansion' => 'قصر'
    };
    
    /*Convertion to Single Arabic Numbers*/
    /*public static Map<Integer, String> convertToSingleArabicNumber = new Map<Integer, String> {
        0 => '٠', 1 => '١', 2 => '٢', 3 => '٣', 4 => '٤', 5 => '٥', 6 => '٦', 7 => '٧', 8 => '٨', 9 => '٩'
    };*/
        
    /*Conversion to Arabic Numbers*/
    public static Map<Integer, String> convertToArabicNumber = new Map<Integer, String> {
        0 => '٠', 1 => '١', 2 => '٢', 3 => '٣', 4 => '٤', 5 => '٥', 6 => '٦', 7 => '٧', 8 => '٨', 9 => '٩', 10 => '١٠', 11 => '١١', 12 => '١٢', 13 => '١٣', 14 => '١٤', 15 => '١٥', 16 => '١٦',
        17 => '١٧', 18 => '١٨', 19 => '١٩', 20 => '٢٠', 21 => '٢١', 22 => '٢٢', 23 => '٢٣', 24 => '٢٤', 25 => '٢٥', 26 => '٢٦', 27 => '٢٧', 28 => '٢٨', 29 => '٢٩', 30 => '٣٠', 31 => '٣١',
        32 => '٣٢', 33 => '٣٣', 34 => '٣٤', 35 => '٣٥', 36 => '٣٦', 37 => '٣٧', 38 => '٣٨', 39 => '٣٩', 40 => '٤٠', 41 => '٤١', 42 => '٤٢', 43 => '٤٣', 44 => '٤٤', 45 => '٤٥', 46 => '٤٦',
        47 => '٤٧', 48 => '٤٨', 49 => '٤٩', 50 => '٥٠', 51 => '٥١', 52 => '٥٢', 53 => '٥٣', 54 => '٥٤', 55 => '٥٥', 56 => '٥٦', 57 => '٥٧', 58 => '٥٨', 59 => '٥٩', 60 => '٦٠', 61 => '٦١',
        62 => '٦٢', 63 => '٦٣', 64 => '٦٤', 65 => '٦٥', 66 => '٦٦', 67 => '٦٧', 68 => '٦٨', 69 => '٦٩', 70 => '٧٠', 71 => '٧١', 72 => '٧٢', 73 => '٧٣', 74 => '٧٤', 75 => '٧٥', 76 => '٧٦',
        77 => '٧٧', 78 => '٧٨', 79 => '٧٩', 80 => '٨٠', 81 => '٨١', 82 => '٨٢', 83 => '٨٣', 84 => '٨٤', 85 => '٨٥', 86 => '٨٦', 87 => '٨٧', 88 => '٨٨', 89 => '٨٩', 90 => '٩٠', 91 => '٩١',
        92 => '٩٢', 93 => '٩٣', 94 => '٩٤', 95 => '٩٥', 96 => '٩٦', 97 => '٩٧', 98 => '٩٨', 99 => '٩٩', 100 => '١٠٠'
    };
    
    /*Payment Plan Description Field*/
    public static Map<Integer, String> paymentPlanDescription = new Map<Integer, String> {
        0 => 'Booking / Reservation', 1 => '1st', 2 => '2nd', 3 => '3rd', 4 => '4th', 5 => '5th', 6 => '6th', 7 => '7th', 8 => '8th', 9 => '9th', 10 => '10th', 11 => '11th', 12 => '12th',
        13 => '13th', 14 => '14th', 15 => '15th', 16 => '16th', 17 => '17th', 18 => '18th', 19 => '19th', 20 => '20th', 21 => '21st', 22 => '22nd', 23 => '23rd', 24 => '24th', 25 => '25th',
        26 => '26th', 27 => '27th', 28 => '28th', 29 => '29th', 30 => '30th', 31 => '31st', 32 => '32nd', 33 => '33rd', 34 => '34th', 35 => '35th', 36 => '36th', 37 => '37th', 38 => '38th',
        39 => '39th', 40 => '40th', 41 => '41st', 42 => '42nd', 43 => '43rd', 44 => '44th', 45 => '45th', 46 => '46th', 47 => '47th', 48 => '48th', 49 => '49th', 50 => '50th', 51 => '51st',
        52 => '52nd', 53 => '53rd', 54 => '54th', 55 => '55th', 56 => '56th', 57 => '57th', 58 => '58th', 59 => '59th', 60 => '60th'
    };
        
    /*Payment Plan Description Arabic Field*/
    public static Map<Integer, String> paymentPlanDescriptionArabic = new Map<Integer, String> {
        0 => 'حجز القيد/ الحجز',1 => 'القسط الأول',2 => 'القسط الثاني',3 => 'القسط الثالث',4 => 'القسط الرابع',5 => 'القسط الخامس',6 => 'القسط السادس',7 => 'القسط السابع',8 => 'القسط الثامن',9 => 'القسط التاسع',10 => 'القسط العاشر',
        11 => 'القسط الحادي عشر',12 => 'القسط الثاني عشر',13 => 'القسط الثالث عشر',14 => 'القسط الرابع عشر',15 => 'القسط الخامس عشر',16 => 'القسط السادس عشر',17 => 'القسط السابع عشر',18 => 'القسط الثامن عشر',19 => 'القسط التاسع عشر',
        20 => 'القسط العشرين',21 => 'القسط الواحد والعشرون',22 => 'القسط الثاني والعشرون',23 => 'القسط الثالث والعشرون',24 => 'القسط الرابع والعشرون',25 => 'القسط الخامس والعشرون',26 => 'القسط السادس والعشرون',27 => 'القسط السابع والعشرون',
        28 => 'القسط الثامن والعشرون',29 => 'القسط التاسع والعشرون',30 => 'القسط الثلاثون',31 => 'القسط الواحد والثلاثون',32 => 'القسط الثاني والثلاثون',33 => 'القسط الثالث والثلاثون',34 => 'القسط الرابع والثلاثون',35 => 'القسط الخامس والثلاثون',
        36 => 'القسط السادس والثلاثون',37 => 'القسط السابع والثلاثون',38 => 'القسط الثامن والثلاثون',39 => 'القسط التاسع والثلاثون',40 => 'القسط الأربعون',41 => 'القسط الواحد والأربعون',42 => 'القسط الثاني والأربعون',43 => 'القسط الثالث والأربعون',
        44 => 'القسط الرابع والأربعون',45 => 'القسط الخامس والأربعون',46 => 'القسط السادس والأربعون',47 => 'القسط السابع والأربعون',48 => 'القسط الثامن والأربعون',49 => 'القسط التاسع والأربعون',50 => 'القسط الخمسون',51 => 'القسط الواحد والخمسون',
        52 => 'القسط الثاني والخمسون',53 => 'القسط الثالث والخمسون',54 => 'القسط الرابع والخمسون',55 => 'القسط الخامس والخمسون',56 => 'القسط السادس والخمسون',57 => 'القسط السابع والخمسون',58 => 'القسط الثامن والخمسون',59 => 'القسط التاسع والخمسون',60 => 'القسط الستون'
    };
    
    /*Convertion to Arabic States*/
    public static Map<String, String> convertToArabicStates = new Map<String, String> {
        'Abu Dhabi' => 'أبوظبي', 'Dubai' => 'دبي', 'Sharjah' => 'الشارقة', 'Ajman' => 'عجمان', 'Umm Al Quwain' => 'أم القيوين', 'Ras Al Khaimah' => 'رأس الخيمة', 'Fujairah' => 'الفجيرة'
    };
    
    public SpaJohnRichmondController() {
        Id oppId = ApexPages.currentPage().getParameters().get('oppId');
        
        //try {
            Map<String, Object> objectValues = new Map<String, Object>();

            Opportunity opportunity = [SELECT Id, Name, Booking_Date_Time__c, Registration_Fees__c, Ownership_Share_of_the_Main_Purchaser__c, Offer_layout__c, Unit__r.Project__r.Name,
                Unit__r.Project__r.Project_Name_Arabic__c, Unit__r.Title_Formula__c, Unit__r.Property_Code_Text__c, Unit__r.Building__c, Unit__r.Building_Arabic_Text__c, Unit__r.Number_of_bedrooms__c, Unit__r.Total_Area__c, Unit__r.Community__c, Unit__r.Community_Arabic__c,
                Unit__r.Additional_Area__c, Unit__r.Floor__c, Unit__r.Parking_Space__c, Unit__r.Living_Space__c, Unit__r.Cost_AED__c, Unit__r.Name, Unit__r.Title__c, Unit__r.Type__c, Unit__c, Unit__r.Total_in_Arabic__c, Unit__r.Project_Handover_Date__c, Account.PersonBirthdate,
                Account.Date_of_Birth_Arabic__c, Account.Place_of_Birth__pc, Account.Place_of_Birth_Arabic__pc, Account.Occupation__pc, Account.Occupation_Arabic__pc, Account.Name, Account.Nature_of_Business__pc,
                Account.Nature_of_Business_Arabic__pc, Account.Person_Account_Salutation__pc, Account.Salutation_Arabic__c, Account.Contact_First_Name_Arabic__pc, Account.Contact_Last_Name_Arabic__pc, Account.Contact_Middle_Name_Arabic__pc, Account.Bank_Name__pc,
                Account.Bank_Name_Arabic__pc, Account.Subject_to_Sanction__pc, Account.RecordTypeId, toLabel(Account.Nationality__c), Account.Nationality_Arabic__c, Account.Country_of_Incorporation_Arabic__c,
                Account.Passport_No__c, Account.Passport_Issue_Date__pc, Account.Visa_Number__pc, Account.Visa_Expire_Date__pc, Account.Visa_Place_Issue__pc, Account.Visa_Place_of_Issue_Arabic__pc, Account.Visa_Date_of_Issue__pc,
                Account.Emirates_ID_Card_Number__pc, Account.Emirates_ID_Number__pc, Account.Emirates_ID_Expiry_Date__pc, Account.POA_Holder_Name__pc, Account.POA_Holder_Name_Arabic__pc, Account.POA_Holder_Emirates_ID_Number__pc,
                Account.POA_Holder_Passport_Number__pc, Account.POA_Holder_Passport_Expiry_Date__pc, Account.BillingPostalCode, Account.BillingCity, Account.BillingCountry, Account.BillingStreet, Account.PersonMobilePhone,
                Account.Phone, Account.PersonEmail, Account.Alternative_Email__c, Account.Postal_Code_Arabic__c, Account.Country_Arabic__c, Account.Address__c, Account.City_Arabic__c, toLabel(Account.Source_of_Funds__pc),
                Account.Source_of_Funds_Other__pc, Account.Source_of_Funds_Other_Arabic__pc, Account.Politically_Exposed__pc, Account.Politically_Exposed_Person_Text__pc, Account.Politically_Exposed_Person_Text_Arabic__pc,
                Account.Estimated_duration__pc,Account.Payment_Methods_Other__pc, Account.Payment_Methods_Other_Arabic__pc, Account.Currency_Other__pc, Account.Currency_Other_Arabic__pc, Account.IsPersonAccount,
                Account.Account_Name_Arabic__c, toLabel(Account.Country_of_Incorporation__c), toLabel(Account.Currency__pc), toLabel(Account.Payment_methods__pc), Account.Trade_License_Number__c, Account.Trade_License_Expiry_Date__c,
                Account.P_O_Box_Number__c, Account.License_Copy_All_Pages__c, Account.Certificate_of_Incorporation__c, Account.Certificate_of_Good_Standing__c, Account.Certificate_of_Incumbency__c, Account.TRN_Certificate__c,
                Account.Board_Resolution_or_POA__c, Account.Board_Resolution_Specifying_Signatory__c, Account.Passport_Copy_of_Signatory__c, Account.Passport_Copy_of_all_Shareholders__c, Account.NOC_Issued_by_Authority__c,
                Assisted_by_agent__c, Agency__r.Name, Agency__r.Account_Name_Arabic__c, Agent__r.Name, Agent__r.Contact_First_Name_Arabic__c, Agent__r.Contact_Middle_Name_Arabic__c, Agent__r.Contact_Last_Name_Arabic__c,
                Owner.Name FROM Opportunity WHERE Id = :oppId LIMIT 1];
            
            String bookingDate = Opportunity.Booking_Date_Time__c.format('dd-MMM-yyyy');
            String bookingDateArabic = arabicDate(Opportunity.Booking_Date_Time__c.date());
            objectValues.put('Opportunity', opportunity);
            objectValues.put('bookingDate', bookingDate);
            objectValues.put('bookingDateArabic', bookingDateArabic);
            objectValues.put('arabicUnitType', convertToArabicUnitType);
        	objectValues.put('numberOfBedroomsArabic', arabicNumbers(String.valueOf(opportunity.Unit__r.Number_of_bedrooms__c)));
        	objectValues.put('ownerShipShareArabic', arabicNumbers(String.valueOf(opportunity.Ownership_Share_of_the_Main_Purchaser__c)));
            
            /*Setting up First Installment & Payment Plans*/
            List<Cash_Flow__c> cashFlows = [SELECT Id, Price_Formula__c, Date__c, Name, Percent__c, Handover_Payment__c FROM Cash_Flow__c WHERE Unit__c = :opportunity.Unit__c AND Is_Additional_Payment__c = false AND Name != 'Oqood' AND Name != 'DLD Fee' AND Name != 'Registration Fee' AND Name != 'Purchase Taxes' ORDER BY Date__c ASC LIMIT 31];
      		List<Cash_Flow__c> cashFlowsContinue = [SELECT ID, Price_Formula__c, Date__c, NAme, Percent__c, Handover_Payment__c FROM Cash_Flow__c WHERE Unit__c = :opportunity.Unit__c AND Is_Additional_Payment__c = false AND Name != 'Oqood' AND Name != 'DLD Fee' AND Name != 'Registration Fee' AND Name != 'Purchase Taxes' ORDER BY Date__c ASC Limit 61];
            
            objectValues.put('agentAssistEng', opportunity.Assisted_by_agent__c == true ? 'Yes' : 'No');
            objectValues.put('agentAssistArabic', opportunity.Assisted_by_agent__c == true ? 'نعم' : 'لا');
            List<Map<String,Object>> paymentPlan = new List<Map<String,Object>>();
            List<Map<String,Object>> paymentPlanContinuation = new List<Map<String,Object>>();
            Boolean handOverDateCheck = false;
            String anticipatedCompletionDate = Opportunity.Unit__r.Project_Handover_Date__c != null ? 
                DateTime.newInstance(Opportunity.Unit__r.Project_Handover_Date__c.year(), Opportunity.Unit__r.Project_Handover_Date__c.month(), Opportunity.Unit__r.Project_Handover_Date__c.day()).format('MMMM yyyy') : '';
            String anticipatedCompletionDateArabic = Opportunity.Unit__r.Project_Handover_Date__c != null ? arabicAnticipatedDate(Opportunity.Unit__r.Project_Handover_Date__c) : null;
    
            for (Integer i = 0; i < cashFlows.size(); i++) {
                if (cashFlows[i].Handover_Payment__c == true) {
                    handOverDateCheck = true;
                    anticipatedCompletionDate = DateTime.newInstance(cashFlows[i].Date__c.year(), cashFlows[i].Date__c.month(), cashFlows[i].Date__c.day()).format('MMMM yyyy');
                    anticipatedCompletionDateArabic = arabicAnticipatedDate(cashFlows[i].Date__c);
                }
                String dt;
                    if (i == 0) {
                        dt = bookingDate;
                    } else {
                        dt = DateTime.newInstance(cashFlows[i].Date__c.year(), cashFlows[i].Date__c.month(), cashFlows[i].Date__c.day()).format('dd-MMM-yyyy');
                    }
                    paymentPlan.add(new Map<String,Object> {
                    'numberOfPlan' => String.valueOf(i+1), 
                    'milestone' => cashFlows[i].Name,
                    'percent' => String.valueOf(cashFlows[i].Percent__c),
                    'paymentDate' => String.valueOf(dt),
                    'paymentDateArabic' => arabicDate(cashFlows[i].Date__c),
                    'handoverPayment' => cashFlows[i].Handover_Payment__c,
                    'amount' => formatNumber(cashFlows[i].Price_Formula__c),
                    'amountArabic' => arabicNumbers(formatNumber(cashFlows[i].Price_Formula__c))
                });
            }
        
        	for(Integer i = 0; i < cashFlowsContinue.size(); i++) {
                if (handoverDateCheck == false && cashFlowsContinue[i].Handover_Payment__c == true) {
                    anticipatedCompletionDate = DateTime.newInstance(cashFlowsContinue[i].Date__c.year(), cashFlowsContinue[i].Date__c.month(), cashFlowsContinue[i].Date__c.day()).format('dd-MMM-yyyy');
                    anticipatedCompletionDateArabic = arabicDate(cashFlowsContinue[i].Date__c);
                }
                if (i > 29) {
                    String dt;
                    dt = DateTime.newInstance(cashFlowsContinue[i].Date__c.year(), cashFlowsContinue[i].Date__c.month(), cashFlowsContinue[i].Date__c.day()).format('dd-MMM-yyyy');
                    paymentPlanContinuation.add(new Map<String,Object> {
                        'numberOfPlan' => String.valueOf(i+1), 
                        'milestone' => cashFlowsContinue[i].Name,
                        'percent' => String.valueOf(cashFlowsContinue[i].Percent__c),
                        'paymentDate' => String.valueOf(dt),
                        'paymentDateArabic' => arabicDate(cashFlowsContinue[i].Date__c),
                        'handoverPayment' => cashFlowsContinue[i].Handover_Payment__c,
                        'amount' => formatNumber(cashFlowsContinue[i].Price_Formula__c),
                        'amountArabic' => arabicNumbers(formatNumber(cashFlowsContinue[i].Price_Formula__c))
                    });
                }
            }
            objectValues.put('paymentPlan', paymentPlan);
            objectValues.put('anticipatedDate', anticipatedCompletionDate);
            objectValues.put('anticipatedDateArabic', anticipatedCompletionDateArabic);
            if (paymentPlanContinuation.size() > 0) {
                objectValues.put('paymentPlanContinuation', paymentPlanContinuation);
            } else {
                objectValues.put('paymentPlanContinuation', 'Null');
            }
            objectValues.put('arabicMilestones', convertedToArabicTerms);
            /*END*/
            
            /*Putting all Numbers to format*/
            Map<String, String> numbersToFormat = new Map<String, String>();
        	numbersToFormat.put('unitNumberArabic', arabicNumbers(opportunity.Unit__r.Title__c));
            numbersToFormat.put('formattedTotalArea', formatNumber(opportunity.Unit__r.Total_Area__c));
        	numbersToFormat.put('formattedTotalAreaArabic', arabicNumbers(formatNumber(opportunity.Unit__r.Total_Area__c)));
            numbersToFormat.put('formattedPlotArea', opportunity.Unit__r.Additional_Area__c > 0 ? formatNumber(opportunity.Unit__r.Additional_Area__c) : '');
        	numbersToFormat.put('formattedPlotAreaArabic', opportunity.Unit__r.Additional_Area__c > 0 ? arabicNumbers(formatNumber(opportunity.Unit__r.Additional_Area__c)) : '');
        	numbersToFormat.put('formattedFloorNumber', opportunity.Unit__r.Floor__c > 0 ? String.valueOf(opportunity.Unit__r.Floor__c) : '');
        	numbersToFormat.put('formattedFloorNumberArabic', opportunity.Unit__r.Floor__c > 0 ? arabicNumbers(String.valueOf(opportunity.Unit__r.Floor__c)) : '');
        	numbersToFormat.put('formattedParkingSpace', opportunity.Unit__r.Parking_Space__c > 0 ? String.valueOf(opportunity.Unit__r.Parking_Space__c) : '');
        	numbersToFormat.put('formattedParkingSpaceArabic', opportunity.Unit__r.Parking_Space__c > 0 ? arabicNumbers(String.valueOf(opportunity.Unit__r.Parking_Space__c)) : '');
            //numbersToFormat.put('formattedBuiltupArea', formatNumber(opportunity.Unit__r.Living_Space__c));
        	//numbersToFormat.put('formattedBuiltupAreaArabic', arabicNumbers(formatNumber(opportunity.Unit__r.Living_Space__c)));
            numbersToFormat.put('formattedUnitCost', formatNumber(opportunity.Unit__r.Cost_AED__c));
        	numbersToFormat.put('formattedUnitCostArabic', arabicNumbers(formatNumber(opportunity.Unit__r.Cost_AED__c)));
            numbersToFormat.put('firstInstallment', formatNumber(cashFlows[0].Price_Formula__c));
            objectValues.put('formattedNumbers', numbersToFormat);
            /*END*/
            
            /*Amount In Words Convertion*/
            //AmountInWords amWords = new AmountInWords();
            objectValues.put('amountInWords', AmountInWords.convertNumberToText(opportunity.Unit__r.Cost_AED__c));
            /*END*/
            
            /*Setting up Registration Fee*/
            objectValues.put('registrationFee', RegistrationFeeSetup(opportunity.Registration_Fees__c));
            /*END*/
            
            /*Setting up Arabic Account Name*/
            String arabicAccountName = opportunity.Account.IsPersonAccount ? removeNull(opportunity.Account.Contact_First_Name_Arabic__pc)+' '+removeNull(opportunity.Account.Contact_Middle_Name_Arabic__pc)+' '+removeNull(opportunity.Account.Contact_Last_Name_Arabic__pc) : opportunity.Account.Account_Name_Arabic__c;
            objectValues.put('arabicAccountName', arabicAccountName);
            /*END*/
            
            /*Setting up License & Incorporation Country Values for Single Account & Primary Due Deligence*/
            Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Client').getRecordTypeId();
            String isPerson = opportunity.Account.RecordTypeId <> personAccountRecordTypeId ? 'No' : 'Yes';
            
            Map<String, Object> dueDeligenceMap = new Map<String, Object>();
            Map<String, Object> personInformation = new Map<String, Object>();
        	
        	String personMiddleNameArabic;
            String personFullName;
        	String personFullNameArabic;
        	
            if (opportunity.Account.RecordTypeId == personAccountRecordTypeId) {
                personMiddleNameArabic = opportunity.Account.Contact_Middle_Name_Arabic__pc != null ? opportunity.Account.Contact_Middle_Name_Arabic__pc : '';
                personFullName = opportunity.Account.Person_Account_Salutation__pc+' '+opportunity.Account.Name;
                personFullNameArabic = convertToArabicSalutation.get(opportunity.Account.Person_Account_Salutation__pc)+''+opportunity.Account.Contact_First_Name_Arabic__pc+' '+personMiddleNameArabic+' '+opportunity.Account.Contact_Last_Name_Arabic__pc;
                personInformation.put('personFullName', personFullName);
                personInformation.put('personFullNameArabic', personFullNameArabic);
                personInformation.put('personPhone', opportunity.Account.Phone);
                personInformation.put('personEmail', opportunity.Account.PersonEmail);
                personInformation.put('personMobile', opportunity.Account.PersonMobilePhone);
                personInformation.put('personMobileArabic', arabicNumbers(opportunity.Account.PersonMobilePhone));
                personInformation.put('personVisaNumber', addNotApplicable(opportunity.Account.Visa_Number__pc));
                personInformation.put('personVisaNumberArabic', arabicNumbers(opportunity.Account.Visa_Number__pc));
                personInformation.put('personVisaDateIssue', formatDate(opportunity.Account.Visa_Date_of_Issue__pc));
                personInformation.put('personVisaDateIssueArabic', arabicDate(opportunity.Account.Visa_Date_of_Issue__pc));
                personInformation.put('personVisaPlaceIssue', addNotApplicable(opportunity.Account.Visa_Place_Issue__pc));
                personInformation.put('personVisaPlaceIssueArabic', addNotApplicableArabic(arabicState(opportunity.Account.Visa_Place_Issue__pc)));
                personInformation.put('personVisaExpiryDate', formatDate(opportunity.Account.Visa_Expire_Date__pc));
                personInformation.put('personVisaExpiryDateArabic', arabicDate(opportunity.Account.Visa_Expire_Date__pc));
                if (opportunity.Account.Emirates_Id_Card_Number__pc == null) {
                    personInformation.put('personEmiratesIdCardNumber', 'Not Applicable');
                    personInformation.put('personEmiratesIdCardNumberArabic', 'لا ينطبق');
                } else {
                    personInformation.put('personEmiratesIdCardNumber', opportunity.Account.Emirates_Id_Card_Number__pc);
                    personInformation.put('personEmiratesIdCardNumberArabic', arabicNumbers(String.valueOf(opportunity.Account.Emirates_Id_Card_Number__pc)));
                }
                personInformation.put('personEmiratesIdNumber', addNotApplicable(opportunity.Account.Emirates_ID_Number__pc));
                personInformation.put('personEmiratesIdNumberArabic', arabicNumbers(opportunity.Account.Emirates_ID_Number__pc));
                personInformation.put('personEmiratesIdExpiryDate', addNotApplicable(formatDate(opportunity.Account.Emirates_ID_Expiry_Date__pc)));
                personInformation.put('personEmiratesIdExpiryDateArabic', addNotApplicableArabic(arabicDate(opportunity.Account.Emirates_ID_Expiry_Date__pc)));
                personInformation.put('personPOAHolderName', addNotApplicable(opportunity.Account.POA_Holder_Name__pc));
                personInformation.put('personPOAHolderNameArabic', addNotApplicableArabic(opportunity.Account.POA_Holder_Name_Arabic__pc));
                personInformation.put('personPOAHolderEmiratesIdNumber', addNotApplicable(opportunity.Account.POA_Holder_Emirates_ID_Number__pc));
                personInformation.put('personPOAHolderEmiratesIdNumberArabic', arabicNumbers(opportunity.Account.POA_Holder_Emirates_ID_Number__pc));
                personInformation.put('personPOAHolderPassportNumber', addNotApplicable(opportunity.Account.POA_Holder_Passport_Number__pc));
                personInformation.put('personPOAHolderPassportExpiryDate', addNotApplicable(formatDate(opportunity.Account.POA_Holder_Passport_Expiry_Date__pc)));
                personInformation.put('personPOAHolderPassportExpiryDateArabic', arabicDate(opportunity.Account.POA_Holder_Passport_Expiry_Date__pc));
                
                objectValues.put('licenseNumberValue', 'N/A');
                objectValues.put('licenseNumberValueArabic', 'لا ينطبق');
                objectValues.put('licenseExpiryDate', 'N/A');
                objectValues.put('licenseExpiryDateArabic', 'لا ينطبق');
                objectValues.put('incorporationCountry', 'N/A');
                objectValues.put('incorporationCountryArabic', 'N/A');
                objectValues.put('sourceOfFundArabic', arabicConversionFundSource(opportunity.Account.Source_of_Funds__pc));
            	objectValues.put('paymentMethodsArabic', arabicConversionPaymentMethods(opportunity.Account.Payment_methods__pc));
                
                objectValues.put('sharedContacts', 'Null');
            } else {
                List<Contact> sharedContacts = [SELECT Id, FirstName, MiddleName, LastName, Company_Share__c, Position_in_Company__c, toLabel(Nationality__c), Passport_No__c FROM Contact WHERE AccountId = :opportunity.AccountId];
                Contact relatedContact = [SELECT Id, Salutation, FirstName, LastName, Contact_First_Name_Arabic__c, Contact_Middle_Name_Arabic__c, Contact_Last_Name_Arabic__c, Email, Phone, MobilePhone, Birth_Date__c, Place_of_Birth__c, Place_of_Birth_Arabic__c, Occupation__c,
                    Occupation_Arabic__c, Source_of_Funds__c, Source_of_Funds_Other__c, Source_of_Funds_Other_Arabic__c, Subject_to_Sanction__c, Politically_Exposed__c, Politically_Exposed_Person_Text__c,
                    Politically_Exposed_Person_Text_Arabic__c, Payment_methods__c, Payment_Methods_Other__c, Payment_Methods_Other_Arabic__c, Bank_Name__c, Bank_Name_Arabic__c, Nature_of_Business__c,
                    Nature_of_Business_Arabic__c, Currency__c, Currency_Other__c, Currency_Other_Arabic__c, Passport_Issue_Date__c, Visa_Number__c, Visa_Expire_Date__c, Visa_Place_Issue__c, Visa_Place_of_Issue_Arabic__c, Visa_Date_of_Issue__c,
                	Emirates_ID_Card_Number__c, Emirates_ID_Number__c, Emirates_ID_Expiry_Date__c, POA_Holder_Name__c, POA_Holder_Name_Arabic__c, POA_Holder_Emirates_ID_Number__c,
                	POA_Holder_Passport_Number__c, POA_Holder_Passport_Expiry_Date__c FROM Contact WHERE AccountId = :opportunity.AccountId AND Primary__c = true ORDER BY Id ASC Limit 1
                ];
                
                personMiddleNameArabic = relatedContact.Contact_Middle_Name_Arabic__c != null ? relatedContact.Contact_Middle_Name_Arabic__c : '';
                personFullName = relatedContact.Salutation+' '+relatedContact.FirstName+' '+relatedContact.LastName;
                personFullNameArabic = convertToArabicSalutation.get(relatedContact.Salutation)+''+relatedContact.Contact_First_Name_Arabic__c+' '+personMiddleNameArabic+' '+relatedContact.Contact_Last_Name_Arabic__c;
                personInformation.put('personFullName', personFullName);
                personInformation.put('personFullNameArabic', personFullNameArabic);
                personInformation.put('personPhone', relatedContact.Phone);
                personInformation.put('personEmail', relatedContact.Email);
                personInformation.put('personMobile', relatedContact.MobilePhone);
                personInformation.put('personMobileArabic', arabicNumbers(relatedContact.MobilePhone));
                personInformation.put('personVisaNumber', addNotApplicable(relatedContact.Visa_Number__c));
                personInformation.put('personVisaNumberArabic', arabicNumbers(relatedContact.Visa_Number__c));
                personInformation.put('personVisaDateIssue', formatDate(relatedContact.Visa_Date_of_Issue__c));
                personInformation.put('personVisaDateIssueArabic', arabicDate(relatedContact.Visa_Date_of_Issue__c));
                personInformation.put('personVisaPlaceIssue', addNotApplicable(relatedContact.Visa_Place_Issue__c));
                personInformation.put('personVisaPlaceIssueArabic', addNotApplicableArabic(arabicState(relatedContact.Visa_Place_Issue__c)));
                personInformation.put('personVisaExpiryDate', formatDate(relatedContact.Visa_Expire_Date__c));
                personInformation.put('personVisaExpiryDateArabic', arabicDate(relatedContact.Visa_Expire_Date__c));
                if (relatedContact.Emirates_Id_Card_Number__c == null) {
                    personInformation.put('personEmiratesIdCardNumber', 'Not Applicable');
                    personInformation.put('personEmiratesIdCardNumberArabic', 'لا ينطبق');
                } else {
                    personInformation.put('personEmiratesIdCardNumber', relatedContact.Emirates_Id_Card_Number__c);
                    personInformation.put('personEmiratesIdCardNumberArabic', arabicNumbers(String.valueOf(relatedContact.Emirates_Id_Card_Number__c)));
                }
                personInformation.put('personEmiratesIdNumber', addNotApplicable(relatedContact.Emirates_ID_Number__c));
                personInformation.put('personEmiratesIdNumberArabic', arabicNumbers(relatedContact.Emirates_ID_Number__c));
                personInformation.put('personEmiratesIdExpiryDate', formatDate(opportunity.Account.Emirates_ID_Expiry_Date__pc));
                personInformation.put('personEmiratesIdExpiryDateArabic', arabicDate(opportunity.Account.Emirates_ID_Expiry_Date__pc));
                personInformation.put('personPOAHolderName', addNotApplicable(relatedContact.POA_Holder_Name__c));
                personInformation.put('personPOAHolderNameArabic', addNotApplicableArabic(relatedContact.POA_Holder_Name_Arabic__c));
                personInformation.put('personPOAHolderEmiratesIdNumber', addNotApplicable(relatedContact.POA_Holder_Emirates_ID_Number__c));
                personInformation.put('personPOAHolderEmiratesIdNumberArabic', arabicNumbers(relatedContact.POA_Holder_Emirates_ID_Number__c));
                personInformation.put('personPOAHolderPassportNumber', addNotApplicable(relatedContact.POA_Holder_Passport_Number__c));
                personInformation.put('personPOAHolderPassportExpiryDate', addNotApplicable(formatDate(relatedContact.POA_Holder_Passport_Expiry_Date__c)));
                personInformation.put('personPOAHolderPassportExpiryDateArabic', arabicDate(relatedContact.POA_Holder_Passport_Expiry_Date__c));
                
                objectValues.put('licenseNumberValue', addNotReceived(opportunity.Account.Trade_License_Number__c));
                objectValues.put('licenseNumberValueArabic', arabicNumbers(opportunity.Account.Trade_License_Number__c));
                objectValues.put('licenseExpiryDate', formatDate(opportunity.Account.Trade_License_Expiry_Date__c));
                objectValues.put('licenseExpiryDateArabic', arabicDate(opportunity.Account.Trade_License_Expiry_Date__c));
                objectValues.put('incorporationCountry', addNotReceived(opportunity.Account.Country_of_Incorporation__c));
                objectValues.put('incorporationCountryArabic', addNotReceived(opportunity.Account.Country_of_Incorporation_Arabic__c));
                objectValues.put('sourceOfFundArabic', arabicConversionFundSource(relatedContact.Source_of_Funds__c));
            	objectValues.put('paymentMethodsArabic', arabicConversionPaymentMethods(relatedContact.Payment_methods__c));
                
                objectValues.put('sharedContacts', sharedContacts);
            }
            objectValues.put('personInformation', personInformation);
            objectValues.put('isPerson', isPerson);
            /*END*/
            
            /*Joint Owners Management*/
            List<Joint_Owners__c> jOwners = [SELECT Id, Account__c, Order__c, Ownership_Share__c FROM Joint_Owners__c WHERE Opportunity__c = :opportunity.Id ORDER BY Order__c Asc];

            If (jOwners.size() > 0) {
                Map<String, String> jointOwnerIdToOrder = new Map<String, String>();
                Map<String, String> jointOwnerIdToOwnership = new Map<String, String>();
                Map<String, String> jointOwnerIdToOwnershipArabic = new Map<String, String>();
        
                Set<Id> jointOwnersIds = new Set<Id>();
                for(Joint_Owners__c jointOwner : jOwners){
                    jointOwnersIds.add(jointOwner.Account__c);
                    jointOwnerIdToOrder.put(jointOwner.Account__c.toString(), jointOwner.Order__c != null ? jointOwner.Order__c.toString() : '');
                    jointOwnerIdToOwnership.put(jointOwner.Account__c.toString(), jointOwner.Ownership_Share__c != null ? jointOwner.Ownership_Share__c.toString() : '');
                    jointOwnerIdToOwnershipArabic.put(jointOwner.Account__c.toString(), jointOwner.Ownership_Share__c != null ? arabicNumbers(jointOwner.Ownership_Share__c.toString()) : '');
                }
                objectValues.put('jointOwnersOrder', jointOwnerIdToOrder);
                objectValues.put('jointOwnersOwnership', jointOwnerIdToOwnership);
                objectValues.put('jointOwnersOwnershipArabic', jointOwnerIdToOwnershipArabic);
                
                List<Account> jointOwners = [SELECT Id, RecordTypeId, Trade_License_Number__c, Name, Person_Account_Salutation__pc, toLabel(Nationality__c), Passport_No__c, BillingPostalCode, BillingCity, BillingCountry, 
                        BillingStreet, PersonMobilePhone, Phone, PersonEmail, Contact_First_Name_Arabic__pc, Contact_Middle_Name_Arabic__pc, Contact_Last_Name_Arabic__pc, Country_of_Incorporation_Arabic__c,
                        Nationality_Arabic__c, Postal_Code_Arabic__c, City_Arabic__c, Country_Arabic__c, Address__c, PersonBirthdate, Date_of_Birth_Arabic__c, Occupation__pc, Occupation_Arabic__pc,
                        Place_of_Birth__pc, Place_of_Birth_Arabic__pc, Nature_of_Business__pc, Nature_of_Business_Arabic__pc, toLabel(Source_of_Funds__pc), Source_of_Funds_Other__pc,
                        Source_of_Funds_Other_Arabic__pc, Politically_Exposed__pc, Politically_Exposed_Person_Text__pc, Politically_Exposed_Person_Text_Arabic__pc, Subject_to_Sanction__pc,
                        Bank_Name__pc, Bank_Name_Arabic__pc, Estimated_duration__pc, Payment_Methods_Other__pc, Payment_Methods_Other_Arabic__pc, Currency_Other__pc, Currency_Other_Arabic__pc,
                        IsPersonAccount, Account_Name_Arabic__c, toLabel(Country_of_Incorporation__c), toLabel(Currency__pc), toLabel(Payment_methods__pc), Visa_Number__pc, Visa_Expire_Date__pc,
                    	Visa_Place_Issue__pc, Visa_Place_of_Issue_Arabic__pc, Visa_Date_of_Issue__pc, Emirates_ID_Card_Number__pc, Emirates_ID_Number__pc, Emirates_ID_Expiry_Date__pc,
                    	POA_Holder_Name__pc, POA_Holder_Name_Arabic__pc, POA_Holder_Passport_Number__pc, POA_Holder_Passport_Expiry_Date__pc, POA_Holder_Emirates_ID_Number__pc FROM Account WHERE Id IN:jointOwnersIds 
                ];
        
                objectValues.put('jointOwners', jointOwners);
                
                Map<String, Object> jPersonInformation = new Map<String, Object>();
                Map<String, String> jointOwnerIdToLicenseNumberValue = new Map<String, String>();
                Map<String, String> jointOwnerIdToIncorporationCountry = new Map<String, String>();
                Map<String, String> jointOwnerIdToIncorporationCountryArabic = new Map<String, String>();
                Map<String, String> jointFundSourceArabic = new Map<String, String>();
                Map<String, String> jointPaymentMethodsArabic = new Map<String, String>();
                Map<String, String> jointPurchaserArabicName = new Map<String, String>();
                String jFullName;
                String jFullNameArabic;
                
                Map<String, Map<String, String>> jpInfo = new Map<String, Map<String, String>>();
                
                for (Account account : jointOwners) {
                    jpInfo.put(account.Id, new Map<String, String>());
                    jointFundSourceArabic.put(account.Id, arabicConversionFundSource(account.Source_of_Funds__pc));
                    jointPaymentMethodsArabic.put(account.Id, arabicConversionPaymentMethods(account.Payment_methods__pc));
                    String middleNameArabic = account.Contact_Middle_Name_Arabic__pc != null ? account.Contact_Middle_Name_Arabic__pc : '';
                    if(account.RecordTypeId == personAccountRecordTypeId) {
                    	jFullName = account.Person_Account_Salutation__pc+' '+account.Name;
                		//jFullNameArabic = convertToArabicSalutation.get(account.Person_Account_Salutation__pc)+''+account.Contact_First_Name_Arabic__pc+' '+account.Contact_Middle_Name_Arabic__pc+' '+account.Contact_Last_Name_Arabic__pc;
                        jFullNameArabic = convertToArabicSalutation.get(account.Person_Account_Salutation__pc)+''+account.Contact_First_Name_Arabic__pc+' '+middleNameArabic+' '+account.Contact_Last_Name_Arabic__pc;
                        
                        jpInfo.get(account.Id).put('jpersonFullName', jFullName);
                        jpInfo.get(account.Id).put('jpersonFullNameArabic', jFullNameArabic);
                        jpInfo.get(account.Id).put('jpersonPhone', account.Phone);
                        jpInfo.get(account.Id).put('jpersonEmail', addNotApplicable(account.PersonEmail));
                        jpInfo.get(account.Id).put('jpersonMobile', addNotApplicable(account.PersonMobilePhone));
                        jpInfo.get(account.Id).put('jpersonMobileArabic', arabicNumbers(account.PersonMobilePhone));
                        jpInfo.get(account.Id).put('jpersonVisaNumber', addNotApplicable(account.Visa_Number__pc));
                        jpInfo.get(account.Id).put('jpersonVisaNumberArabic', arabicNumbers(account.Visa_Number__pc));
                        jpInfo.get(account.Id).put('jpersonVisaDateIssue', formatDate(account.Visa_Date_of_Issue__pc));
                        jpInfo.get(account.Id).put('jpersonVisaDateIssueArabic', arabicDate(account.Visa_Date_of_Issue__pc));
                        jpInfo.get(account.Id).put('jpersonVisaPlaceIssue', addNotApplicable(account.Visa_Place_Issue__pc));
                        jpInfo.get(account.Id).put('jpersonVisaPlaceIssueArabic', addNotApplicableArabic(account.Visa_Place_Issue__pc));
                        jpInfo.get(account.Id).put('jpersonVisaExpiryDate', formatDate(account.Visa_Expire_Date__pc));
                        jpInfo.get(account.Id).put('jpersonVisaExpiryDateArabic', arabicDate(account.Visa_Expire_Date__pc));
                        if (account.Emirates_Id_Card_Number__pc == null) {
                            jpInfo.get(account.Id).put('jpersonEmiratesIdCardNumber', 'Not Applicable');
                        	jpInfo.get(account.Id).put('jpersonEmiratesIdCardNumberArabic', 'لا ينطبق');
                        } else {
                            jpInfo.get(account.Id).put('jpersonEmiratesIdCardNumber', account.Emirates_Id_Card_Number__pc.toString());
                        	jpInfo.get(account.Id).put('jpersonEmiratesIdCardNumberArabic', arabicNumbers(String.valueOf(account.Emirates_Id_Card_Number__pc)));
                        }
                        jpInfo.get(account.Id).put('jpersonEmiratesIdNumber', addNotApplicable(account.Emirates_ID_Number__pc));
                        jpInfo.get(account.Id).put('jpersonEmiratesIdNumberArabic', arabicNumbers(account.Emirates_ID_Number__pc));
                        jpInfo.get(account.Id).put('jpersonEmiratesIdExpiryDate', addNotApplicable(formatDate(account.Emirates_ID_Expiry_Date__pc)));
                        jpInfo.get(account.Id).put('jpersonEmiratesIdExpiryDateArabic', addNotApplicableArabic(arabicDate(account.Emirates_ID_Expiry_Date__pc)));
                        jpInfo.get(account.Id).put('jpersonPOAHolderName', addNotApplicable(account.POA_Holder_Name__pc));
                        jpInfo.get(account.Id).put('jpersonPOAHolderNameArabic', addNotApplicableArabic(account.POA_Holder_Name_Arabic__pc));
                        jpInfo.get(account.Id).put('jpersonPOAHolderEmiratesIdNumber', addNotApplicable(account.POA_Holder_Emirates_ID_Number__pc));
                        jpInfo.get(account.Id).put('jpersonPOAHolderEmiratesIdNumberArabic', arabicNumbers(account.POA_Holder_Emirates_ID_Number__pc));
                        jpInfo.get(account.Id).put('jpersonPOAHolderPassportNumber', addNotApplicable(account.POA_Holder_Passport_Number__pc));
                        jpInfo.get(account.Id).put('jpersonPOAHolderPassportExpiryDate', addNotApplicable(formatDate(account.POA_Holder_Passport_Expiry_Date__pc)));
                        jpInfo.get(account.Id).put('jpersonPOAHolderPassportExpiryDateArabic', addNotApplicableArabic(arabicDate(account.POA_Holder_Passport_Expiry_Date__pc)));
                        
                        jointOwnerIdToLicenseNumberValue.put(account.Id, 'N/A');
                        jointOwnerIdToIncorporationCountry.put(account.Id, 'N/A');
                        jointOwnerIdToIncorporationCountryArabic.put(account.Id, 'N/A');
                        jointPurchaserArabicName.put(account.Id, removeNull(account.Contact_First_Name_Arabic__pc)+' '+removeNull(account.Contact_Middle_Name_Arabic__pc)+' '+removeNull(account.Contact_Last_Name_Arabic__pc));
                    } else {
                        jointOwnerIdToLicenseNumberValue.put(account.Id, addNotReceived(account.Trade_License_Number__c));
                        jointOwnerIdToIncorporationCountry.put(account.Id, addNotReceived(account.Country_of_Incorporation__c));
                        jointOwnerIdToIncorporationCountryArabic.put(account.Id, addNotReceived(account.Country_of_Incorporation_Arabic__c));
                        jointPurchaserArabicName.put(account.Id, account.Account_Name_Arabic__c);
                    }
                }
                objectValues.put('jpInfo', jpInfo);                
                
                objectValues.put('jointFundSourceArabic', jointFundSourceArabic);
                objectValues.put('jointPaymentMethodsArabic', jointPaymentMethodsArabic);
                objectValues.put('jointOwnersLicenseValues', jointOwnerIdToLicenseNumberValue);
                objectValues.put('jointOwnersIncorporationValues', jointOwnerIdToIncorporationCountry);
                objectValues.put('jointOwnersIncorporationValuesArabic', jointOwnerIdToIncorporationCountryArabic);
                objectValues.put('jointArabicName', jointPurchaserArabicName);
            } else {
                objectValues.put('jointOwners', 'Null');
            }
            /*END*/
            objectValues.put('arabicNumber', convertToArabicNumber);
            objectValues.put('paymentPlanDescription', paymentPlanDescription);
            objectValues.put('paymentPlanDescriptionArabic', paymentPlanDescriptionArabic);
            
            /*Setting up Floor Plan*/
            Map<Id, File__c> pdfFile = new Map<Id, File__c>([SELECT Id, Description__c FROM File__c WHERE Unit__c = :opportunity.Unit__c AND Type__c = 'Floor Plan' LIMIT 1]);
            
            if (!pdfFile.keySet().isEmpty()) {
                Map<String, String> m = new Map<String, String>();
                List<ContentDocumentLink> cdls = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :pdfFile.keySet()];
                
                Set<Id> cdids = new Set<Id>();
                for(ContentDocumentLink cdl : cdls){
                    cdids.add(cdl.ContentDocumentId);
                    m.put(cdl.ContentDocumentId, pdfFile.get(cdl.LinkedEntityId).Description__c);
                }
                
                List<ContentVersion> cvs = [SELECT Id, ContentDocumentId FROM  ContentVersion WHERE ContentDocumentId IN :cdids ORDER BY Title];
                Map<String,String> imageUrlToStyle = new Map<String,String>();
              	Map<String,String> imageUrlToDesc = new Map<String,String>();
                for (Integer i = 0; i < cvs.size(); i++) {
                    imageUrlToStyle.put('/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + cvs[i].Id, '100%');
                    imageUrlToDesc.put('/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + cvs[i].Id, m.get(cvs[i].ContentDocumentId) != null ? m.get(cvs[i].ContentDocumentId) : '');
                }
                this.imageUrlToStyle = imageUrlToStyle;
                this.imageUrlToStyleKeySet = imageUrlToStyle.keySet();
                this.imageUrlToDesc = imageUrlToDesc;
            }
            /*END*/
            
            oppData = objectValues;
        //} catch (Exception e) {
            //throw new AuraHandledException(e.getMessage());
        //}
    }

    /**
     * Action method to update the SPA_Generated_Date__c field
     * This can be called from a Visualforce page action or command button
     * @return PageReference null to stay on the same page
     */
    public PageReference updateSpaGeneratedDate() {
        try {
            Id oppId = ApexPages.currentPage().getParameters().get('oppId');
            Opportunity oppToUpdate = new Opportunity(Id = oppId);
            oppToUpdate.SPA_Generated_Date__c = Date.today();
            update oppToUpdate;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 
                'SPA Generated Date updated successfully to ' + Date.today()));
            return null; // Stay on the same page
        } catch(Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                'Error updating SPA Generated Date: ' + e.getMessage()));
            return null;
        }
    }
}