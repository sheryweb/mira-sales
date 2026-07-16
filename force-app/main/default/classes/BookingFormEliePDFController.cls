public without sharing class BookingFormEliePDFController {

    public String getBookingElieFormPDF() {
        return null;
    }


    public String getTodayDate() {
        return null;
    }

    public Map<String, Object> oppData {get; set;}
    public Set<String> imageUrlToStyleKeySet {get; set;}
    public Map<String, String> imageUrlToStyle{get; set;}
    public Map<String, String> imageUrlToDesc{get; set;}
    public List<PaymentPlanWrapper> paymentPlan {get; set;}
    public Id personAccountRecordTypeId {get; private set;}
    public Map<String, Object> objectValues {get; set;}
    
    
    /* Format decimal numbers*/
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
    
    public static String removeNull(String textPassed) {
        if (textPassed == null) {
            return '';
        } else {
            return textPassed;
        }
    }
    
    public static Date removeNullFromDate(Date datePassed) {
        if (datePassed == null) {
            return Date.today();
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
    
    public class PaymentPlanWrapper {
        public String milestone {get; set;}
        public String description {get; set;}
        public String paymentDate {get; set;}
        public String amount {get; set;}
        
        public PaymentPlanWrapper(String milestone, String description, String paymentDate, String amount) {
            this.milestone = milestone;
            this.description = description;
            this.paymentDate = paymentDate;
            this.amount = amount;
        }
    }
    
    private List<PaymentPlanWrapper> getPaymentPlan(Id unitId) {
        List<PaymentPlanWrapper> paymentPlan = new List<PaymentPlanWrapper>();
        
        List<Cash_Flow__c> cashFlows = [
            SELECT Id, Name, Date__c, Price_CHF__c, Percent__c 
            FROM Cash_Flow__c 
            WHERE Unit__c = :unitId 
            AND Is_Additional_Payment__c = false 
            AND Name != 'Oqood' 
            AND Name != 'DLD Fee' 
            ORDER BY Date__c ASC
        ];
        
        for(Cash_Flow__c cf : cashFlows) {
            String description = '';
            String dateStr = '';
            
            if(cf.Name == 'Booking / Reservation' || cf.Name == 'Booking/Reservation' || cf.Name == 'Booking/ Reservation') {
                description = 'upon signature of Reservation Form';
            } else if(cf.Name == 'Public Deed') {
                description = 'upon signature of the Public Deed';
            } else if(cf.Name.containsIgnoreCase('Handover')) {
                description = 'Upon the Handover';
            } else if(cf.Name.containsIgnoreCase('Payment')) {
                description = 'within ' + (cf.Name.containsIgnoreCase('First') ? '4' : '6') + ' months after the ' + 
                    (cf.Name.containsIgnoreCase('First') ? 'Public Deed' : 'Last Payment');
            }
            
            if(cf.Date__c != null) {
                dateStr = cf.Date__c.day() + '-' + cf.Date__c.month().format().substring(0,3) + '-' + cf.Date__c.year();
            }
            
            String formattedAmount = cf.Price_CHF__c != null ? formatNumber(cf.Price_CHF__c) : '';
            
            paymentPlan.add(new PaymentPlanWrapper(
                cf.Name,
                description,
                dateStr,
                formattedAmount
            ));
        }
        
        return paymentPlan;
    }
    
    public static String formatDate(Date dateToFormat) {
        if (dateToFormat == null) {
            return '';
        }
        return dateToFormat.day() + ' / ' + dateToFormat.month() + ' / ' + dateToFormat.year();
    }

    public static String getPicklistLabel(String objectName, String fieldName, String value) {
        if (value == null) {
            return '';
        }
        Schema.DescribeFieldResult fieldResult = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().get(fieldName).getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for(Schema.PicklistEntry p : ple) {
            if(p.getValue() == value) {
                return p.getLabel();
            }
        }
        return value;
    }

    public static String modeOfPuchaseFirstColumn(String modeOfPurchase) {
        if (modeOfPurchase == 'Booking / Reservation Installment') {
            return 'Reservation Fee: 10%';
        } else if (modeOfPurchase == 'Public Deed') {
            return 'Public Deed: 10%';
        } else if (modeOfPurchase == '1st Installment') {
            return 'First Payment: 10%';
        } else if (modeOfPurchase == '2nd Installment') {
            return 'Second Payment: 10%';
        } else if (modeOfPurchase == '3rd Installment') {
            return 'Third Payment: 10%';
        } else if (modeOfPurchase == '4th Installment') {
            return 'Fourth Payment: 10%';
        } else if (modeOfPurchase == '5th Installment') {
            return 'Fifth Payment: 10%';
        } else if (modeOfPurchase == '100% of Construction') {
            return 'Last Payment: 50%';
        }
        return '';
    }

    public static String modeOfPuchaseSecondColumn(String modeOfPurchase) {
        if (modeOfPurchase == 'Booking / Reservation Installment') {
            return 'upon signature of Reservation Form';
        } else if (modeOfPurchase == 'Public Deed') {
            return 'upon signature of the Public Deed';
        } else if (modeOfPurchase == '1st Installment') {
            return 'within 9 months after the Public Deed';
        } else if (modeOfPurchase == '2nd Installment') {
            return 'within 6 months after the Last Payment';
        } else if (modeOfPurchase == '3rd Installment') {
            return 'within 6 months after the Last Payment';
        } else if (modeOfPurchase == '4th Installment') {
            return 'within 6 months after the Last Payment';
        } else if (modeOfPurchase == '5th Installment') {
            return 'within 6 months after the Last Payment';
        } else if (modeOfPurchase == '100% of Construction') {
            return 'Upon the Handover';
        }
        return '';
    }

    public static String floorText(Integer floor) {
        if (floor == 9) {
            return 'Ground';
        } else if (floor == 1) {
            return 'First';
        } else if (floor == 2) {
            return 'Second';
        } else if (floor == 3) {
            return 'Third';
        } else if (floor == 91) {
            return 'Ground / First';
        } else if (floor == 12) {
            return 'First / Second';
        } else if (floor == 23) {
            return 'Second / Third';
        } else if (floor == 34) {
            return 'Third / Fourth';
        } else if (floor == 123) {
            return 'First / Second / Third';
        }  else {
            return '';
        }
    }
    
    public static String arabicConversionFundSource(String fundSource) {
        if (fundSource == null) {
            return '';
        }
        
        Map<String, String> fundSourceTranslations = new Map<String, String>{
            'Inheritance' => 'الميراث',
            'Income/Savings' => 'الدخل / الادخار',
            'Investment' => 'الاستثمار',
            'Sale of Assets' => 'بيع الأصول',
            'Gift' => 'هدية',
            'Loan' => 'قرض',
            'Company Funds' => 'أموال الشركة',
            'Other' => 'آخر'
        };
        
        return fundSourceTranslations.containsKey(fundSource) ? fundSourceTranslations.get(fundSource) : '';
    }
    
    public static String arabicConversionPaymentMethods(String paymentMethod) {
        if (paymentMethod == null) {
            return '';
        }
        
        Map<String, String> paymentMethodTranslations = new Map<String, String>{
            'Bank Transfer' => 'تحويل مصرفي',
            'Cheque' => 'شيك',
            'Credit Card' => 'بطاقة الائتمان',
            'Cash' => 'نقدا',
            'Direct Debit' => 'خصم مباشر',
            'Other' => 'آخر'
        };
        
        return paymentMethodTranslations.containsKey(paymentMethod) ? paymentMethodTranslations.get(paymentMethod) : '';
    }
    
    public BookingFormEliePDFController() {
        // Initialize all properties
        oppData = new Map<String, Object>();
        imageUrlToStyleKeySet = new Set<String>();
        imageUrlToStyle = new Map<String, String>();
        imageUrlToDesc = new Map<String, String>();
        paymentPlan = new List<PaymentPlanWrapper>();
        objectValues = new Map<String, Object>();
        
        // Initialize standard maps to ensure they always exist
        Map<String, String> personInformation = new Map<String, String>{
            'firstName' => '',
            'lastName' => '',
            'personPhone' => '',
            'personEmail' => ''
        };
        
        Map<String, Object> dueDeligence = new Map<String, Object>{
            'contactBirthDate' => Date.today(), // Default value to avoid null date issues
            'contactBirthPlace' => '',
            'contactOccupation' => '',
            'contactOccupationArabic' => '',
            'contactBusinessNature' => '',
            'contactBusinessNatureArabic' => '',
            'contactFundSource' => '',
            'contactExposedPolitically' => '',
            'contactSubjectSanction' => '',
            'contactPaymentMethods' => '',
            'contactBankName' => '',
            'contactBankNameArabic' => '',
            'contactCurrency' => '',
            'contactCurrencyOther' => '',
            'contactCurrencyOtherArabic' => ''
        };
        
        Map<String, Object> jointOwner = new Map<String, Object>{
            'firstName' => '',
            'lastName' => '',
            'PersonBirthdate' => Date.today(), // Default value to avoid null date issues
            'Place_of_Birth__pc' => '',
            'Nationality__c' => '',
            'Passport_No__c' => '',
            'BillingStreet' => '',
            'BillingPostalCode' => '',
            'BillingCity' => '',
            'Phone' => '',
            'PersonEmail' => ''
        };
        
        Map<String, String> formattedNumbers = new Map<String, String>{
            'formattedTotalArea' => '',
            'formattedPlotArea' => '',
            'formattedUnitCost' => '',
            'formattedNumberOfBathrooms' => '',
            'formattedTotalAreaSquareMeter' => '',
            'formattedUnitCostCHF' => ''
        };
        
        // Add these to the main oppData map
        oppData.put('personInformation', personInformation);
        oppData.put('DueDeligence', dueDeligence);
        oppData.put('jointOwner', jointOwner);
        oppData.put('formattedNumbers', formattedNumbers);
        oppData.put('paymentPlan', paymentPlan);
        
        try {
            Id oppId = ApexPages.currentPage().getParameters().get('oppId');
            if (oppId == null) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Opportunity ID is required'));
                return;
            }
            
            System.debug('Loading opportunity data for ID: ' + oppId);
            
            Opportunity opportunity = [
                SELECT Id, Name, CreatedDate, Booking_Date_Time__c,
                    Registration_Fees__c, Ownership_Share_of_the_Main_Purchaser__c,
                    Offer_layout__c, Unit__r.Project__r.Name,
                    Unit__r.Project__r.Project_Name_Arabic__c,
                    Unit__r.Project_Name_Text__c,
                    Unit__r.Project_Name_Text_Arabic__c,
                    Unit__r.Title_Formula__c,
                    Unit__r.Building__c,
                    Unit__r.Building_Arabic_Text__c,
                    Unit__r.Number_of_bedrooms__c,
                    Unit__r.Number_of_Bathrooms__c,
                    Unit__r.Total_Area_Square_Meter__c,
                    Unit__r.Total_Area__c,
                    Unit__r.Additional_Area__c,
                    Unit__r.Cost_CHF__c,
                    Unit__r.Cost_AED__c,
                    Unit__r.Name,
                    Unit__r.Title__c,
                    Unit__r.Type__c,
                    Unit__r.Property_Code_Text__c,
                    Unit__r.Floor__c,
                    Unit__c,
                    Account.PersonBirthdate,
                    Account.Date_of_Birth_Arabic__c,
                    Account.Place_of_Birth__pc,
                    Account.Place_of_Birth_Arabic__pc,
                    Account.Occupation__pc,
                    Account.Occupation_Arabic__pc,
                    Account.Name,
                    Account.Nature_of_Business__pc,
                    Account.Nature_of_Business_Arabic__pc,
                    Account.Contact_First_Name_Arabic__pc,
                    Account.Contact_Last_Name_Arabic__pc,
                    Account.Contact_Middle_Name_Arabic__pc,
                    Account.Bank_Name__pc,
                    Account.Bank_Name_Arabic__pc,
                    Account.Subject_to_Sanction__pc,
                    Account.RecordTypeId,
                    Account.Nationality__c,
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
                    Account.Source_of_Funds__pc,
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
                    Account.Currency__pc,
                    Account.Payment_methods__pc,
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
                WHERE Id = :oppId 
                LIMIT 1
            ];
            
            if (opportunity == null) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Opportunity not found'));
                return;
            }
            
            System.debug('Opportunity loaded successfully');
            
            // Now populate the pre-initialized maps with actual data
            
            // Update personInformation map with real values
            Map<String, String> personInformationMap = (Map<String, String>)oppData.get('personInformation');
            Map<String, Object> dueDeligenceMap = (Map<String, Object>)oppData.get('DueDeligence');
            String fullName = opportunity.Account.Name;
            if (opportunity.Account.IsPersonAccount) {
                if (fullName != null && fullName.contains(' ')) {
                    personInformationMap.put('firstName', fullName.substringBefore(' '));
                    personInformationMap.put('lastName', fullName.substringAfter(' '));
                } else {
                    personInformationMap.put('firstName', fullName != null ? fullName : '');
                    personInformationMap.put('lastName', '');
                }
            } else {
                // For business accounts, get the primary contact's information
                List<Contact> primaryContacts = [
                    SELECT FirstName, LastName, Email, Phone, MobilePhone, Birth_Date__c
                    FROM Contact 
                    WHERE AccountId = :opportunity.AccountId 
                    AND Primary__c = true 
                    ORDER BY Id ASC 
                    LIMIT 1
                ];
                
                if (!primaryContacts.isEmpty()) {
                    Contact primaryContact = primaryContacts[0];
                    personInformationMap.put('firstName', fullName.substringBefore(' ') != null ? fullName.substringBefore(' ') : '');
                    personInformationMap.put('lastName', fullName.substringAfter(' ') != null ? fullName.substringAfter(' ') : '');
                    personInformationMap.put('personPhone', primaryContact.Phone != null ? primaryContact.Phone : '');
                    personInformationMap.put('personEmail', primaryContact.Email != null ? primaryContact.Email : '');
                    personInformationMap.put('personMobile', primaryContact.MobilePhone != null ? primaryContact.MobilePhone : '');
                    dueDeligenceMap.put('contactBirthDate', formatDate(primaryContact.Birth_Date__c));
                }
            }
            
            // Set email and phone from account if not already set
            if (!personInformationMap.containsKey('personEmail') || String.isBlank(personInformationMap.get('personEmail'))) {
                personInformationMap.put('personEmail', opportunity.Account.PersonEmail != null ? opportunity.Account.PersonEmail : '');
            }
            
            String phone = opportunity.Account.PersonMobilePhone;
            if (phone == null) {
                phone = opportunity.Account.Phone;
            }
            if (!personInformationMap.containsKey('personPhone') || String.isBlank(personInformationMap.get('personPhone'))) {
                personInformationMap.put('personPhone', phone != null ? phone : '');
            }
            
            System.debug('personInformation map updated with keys: ' + personInformationMap.keySet());
            System.debug('personEmail value: ' + personInformationMap.get('personEmail'));
            
            // Get Joint Owner information and update the pre-initialized jointOwner map
            List<Joint_Owners__c> jointOwners = [
                SELECT Id, Account__c, Order__c, Ownership_Share__c,
                    Account__r.FirstName,
                    Account__r.LastName,
                    Account__r.PersonBirthdate,
                    Account__r.Place_of_Birth__pc,
                    Account__r.Place_of_Birth_Arabic__pc,
                    Account__r.Nationality__c,
                    Account__r.Passport_No__c,
                    Account__r.BillingStreet,
                    Account__r.BillingPostalCode,
                    Account__r.BillingCity,
                    Account__r.Phone,
                    Account__r.PersonEmail
                FROM Joint_Owners__c 
                WHERE Opportunity__c = :opportunity.Id 
                ORDER BY Order__c ASC
                LIMIT 1
            ];
            
            // Update jointOwner map with real values if available
            Map<String, Object> jointOwnerMap = (Map<String, Object>)oppData.get('jointOwner');
            if (!jointOwners.isEmpty()) {
                Joint_Owners__c firstJointOwner = jointOwners[0];
                System.debug('Joint Owner Place of Birth: ' + firstJointOwner.Account__r.Place_of_Birth__pc);
                jointOwnerMap.put('firstName', firstJointOwner.Account__r.FirstName != null ? firstJointOwner.Account__r.FirstName : '');
                jointOwnerMap.put('lastName', firstJointOwner.Account__r.LastName != null ? firstJointOwner.Account__r.LastName : '');
                jointOwnerMap.put('PersonBirthdate', formatDate(firstJointOwner.Account__r.PersonBirthdate));
                jointOwnerMap.put('Place_of_Birth__pc', firstJointOwner.Account__r.Place_of_Birth__pc != null ? firstJointOwner.Account__r.Place_of_Birth__pc : '');
                System.debug('Joint Owner Map Place of Birth: ' + jointOwnerMap.get('Place_of_Birth__pc'));
                jointOwnerMap.put('Nationality__c', getPicklistLabel('Account', 'Nationality__c', firstJointOwner.Account__r.Nationality__c));
                jointOwnerMap.put('Passport_No__c', firstJointOwner.Account__r.Passport_No__c != null ? firstJointOwner.Account__r.Passport_No__c : '');
                jointOwnerMap.put('BillingStreet', firstJointOwner.Account__r.BillingStreet != null ? firstJointOwner.Account__r.BillingStreet : '');
                jointOwnerMap.put('BillingPostalCode', firstJointOwner.Account__r.BillingPostalCode != null ? firstJointOwner.Account__r.BillingPostalCode : '');
                jointOwnerMap.put('BillingCity', firstJointOwner.Account__r.BillingCity != null ? firstJointOwner.Account__r.BillingCity : '');
                jointOwnerMap.put('Phone', firstJointOwner.Account__r.Phone != null ? firstJointOwner.Account__r.Phone : '');
                jointOwnerMap.put('PersonEmail', firstJointOwner.Account__r.PersonEmail != null ? firstJointOwner.Account__r.PersonEmail : '');
            }
            
            // Debug to verify jointOwner fields are present
            System.debug('Joint Owner map keys: ' + jointOwnerMap.keySet());
            System.debug('Place_of_Birth__pc in joint owner: ' + jointOwnerMap.get('Place_of_Birth__pc'));
            System.debug('PersonEmail in joint owner: ' + jointOwnerMap.get('PersonEmail'));
            
            // Format the date and get picklist label for Nationality
            String formattedBirthDate = formatDate(opportunity.Account.PersonBirthdate);
            String nationalityLabel = getPicklistLabel('Account', 'Nationality__c', opportunity.Account.Nationality__c);

            // Update the maps with formatted values
            if (opportunity.Account.IsPersonAccount) {
                dueDeligenceMap.put('contactBirthDate', formattedBirthDate);
                dueDeligenceMap.put('contactBirthPlace', opportunity.Account.Place_of_Birth__pc != null ? opportunity.Account.Place_of_Birth__pc : '');
            } else {
                // For business accounts, get the primary contact's birth date and place
                List<Contact> primaryContacts = [
                    SELECT Birth_Date__c, Place_of_Birth__c
                    FROM Contact 
                    WHERE AccountId = :opportunity.AccountId 
                    AND Primary__c = true 
                    ORDER BY Id ASC 
                    LIMIT 1
                ];
                
                if (!primaryContacts.isEmpty()) {
                    Contact primaryContact = primaryContacts[0];
                    if (primaryContact.Birth_Date__c != null) {
                        dueDeligenceMap.put('contactBirthDate', formatDate(primaryContact.Birth_Date__c));
                    }
                    if (primaryContact.Place_of_Birth__c != null) {
                        dueDeligenceMap.put('contactBirthPlace', primaryContact.Place_of_Birth__c);
                    }
                }
                
                // Fallback to account values if contact values are not available
                if (!dueDeligenceMap.containsKey('contactBirthDate')) {
                    dueDeligenceMap.put('contactBirthDate', formattedBirthDate);
                }
                if (!dueDeligenceMap.containsKey('contactBirthPlace')) {
                    dueDeligenceMap.put('contactBirthPlace', opportunity.Account.Place_of_Birth__pc != null ? opportunity.Account.Place_of_Birth__pc : '');
                }
            }

            /*Start of Purchase Mode*/
            List<Map<String,Object>> paymentPlans = new List<Map<String,Object>>();
            List<Map<String,Object>> paymentPlansContinuation = new List<Map<String,Object>>();
            
            String bookingDate = Opportunity.Booking_Date_Time__c <> null ? Opportunity.Booking_Date_Time__c.format('dd-MMM-yyyy') : Opportunity.CreatedDate.format('dd-MMM-yyyy');

            // Add the floor text to the oppData map
            String floorTextValue = '';
            if (opportunity.Unit__r.Floor__c != null) {
                Integer floorNum = Integer.valueOf(opportunity.Unit__r.Floor__c);
                floorTextValue = floorText(floorNum);
            }
            objectValues.put('floorText', floorTextValue);

            List<Cash_Flow__c> cashFlows = [SELECT Id, Price_CHF__c, Date__c, Name, Percent__c FROM Cash_Flow__c WHERE Unit__c = :opportunity.Unit__c AND Name != 'Oqood' AND Name != 'DLD Fee' ORDER BY Date__c ASC LIMIT 30];
            for (Integer i = 0; i < cashFlows.size(); i++) {
                String dt;
                    if(i == 0){
                        dt = bookingDate;
                    } else {
                        dt = DateTime.newInstance(cashFlows[i].Date__c.year(),cashFlows[i].Date__c.month(),cashFlows[i].Date__c.day()).format('dd-MMM-yyyy');
                    }
                    paymentPlans.add(new Map<String,Object>{
                    'modeOfPaymentFirstColumn'=> cashFlows[i].Percent__c == 100 ? 'Reservation Fee: 100%' : modeOfPuchaseFirstColumn(cashFlows[i].Name), 
                    'modeOfPaymentSecondColumn'=> modeOfPuchaseSecondColumn(cashFlows[i].Name),
                    'paymentDate' => String.valueOf(dt),
                    'amount' => formatNumber(cashFlows[i].Price_CHF__c)
                });
            }
            objectValues.put('paymentPlans', paymentPlans);
            
            // Format numbers
            formattedNumbers.put('formattedNumberOfBathrooms', opportunity.Unit__r.Number_of_Bathrooms__c != null ? String.valueOf(opportunity.Unit__r.Number_of_Bathrooms__c.intValue()) : '0');
            formattedNumbers.put('formattedTotalAreaSquareMeter', opportunity.Unit__r.Total_Area_Square_Meter__c != null ? String.valueOf(opportunity.Unit__r.Total_Area_Square_Meter__c.intValue()) : '0');
            formattedNumbers.put('formattedUnitCostCHF', opportunity.Unit__r.Cost_CHF__c != null ? formatNumber(opportunity.Unit__r.Cost_CHF__c) : '0.00');
            
            objectValues.put('formattedNationality', nationalityLabel);
            objectValues.put('licenseNumberValue', opportunity.Account.Trade_License_Number__c != null ? opportunity.Account.Trade_License_Number__c : '');
            objectValues.put('incorporationCountry', opportunity.Account.Country_of_Incorporation__c != null ? opportunity.Account.Country_of_Incorporation__c : '');
            
            objectValues.put('Opportunity', opportunity);
            objectValues.put('BookingDate', opportunity.Booking_Date_Time__c != null ? 
                opportunity.Booking_Date_Time__c.format('dd-MMM-yyyy') : 
                opportunity.CreatedDate.format('dd-MMM-yyyy'));
            objectValues.put('formattedNumbers', formattedNumbers);
            objectValues.put('paymentPlan', paymentPlan);
            objectValues.put('personInformation', personInformationMap);
            objectValues.put('jointOwner', jointOwnerMap);
            objectValues.put('DueDeligence', dueDeligenceMap);
            
            // Ensure paymentPlans is also accessible through paymentPlan key for backward compatibility
            if (!objectValues.containsKey('paymentPlans') && objectValues.containsKey('paymentPlan')) {
                objectValues.put('paymentPlans', objectValues.get('paymentPlan'));
            }
            
            oppData = objectValues;
            
            System.debug('Controller initialization completed successfully');
            
            /*Setting up License & Incorporation Country Values for Single Account & Primary Due Deligence*/
            personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Client').getRecordTypeId();
            
            if(opportunity.Account.RecordTypeId == personAccountRecordTypeId) {
                // ... existing code ...
            }
            
        } catch (Exception e) {
            System.debug('Error in constructor: ' + e.getMessage() + '\n' + e.getStackTraceString());
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error initializing page: ' + e.getMessage()));
        }
    }
}