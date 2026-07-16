public without sharing class MSAzureAiTriggerHandler {
    public static final Map<String,Map<String, String>> transliterateTypeFieldMap = new Map <String,Map<String,String>>{
        'Contact' => new Map<String,String> {
            'LastName' => 'Contact_Last_Name_Arabic__c',
            'FirstName' => 'Contact_First_Name_Arabic__c',
            'MiddleName' => 'Contact_Middle_Name_Arabic__c',
            'Place_of_birth__c' => 'Place_of_birth_arabic__c',
            'Occupation__c'  => 'Occupation_Arabic__c',
            'Source_of_funds_other__c' => 'Source_of_funds_other_arabic__c',
            'Politically_exposed_person_text__c' => 'Politically_exposed_person_text_arabic__c',
            'Payment_methods_other__c' => 'Payment_methods_other_arabic__c',
            'Currency_other__c' => 'currency_other_arabic__c',
            'Bank_Name__c' => 'Bank_Name_Arabic__c',
            'Nature_of_Business__c' => 'Nature_of_Business_Arabic__c',
            'Nationality__c' => 'Nationality_Arabic__c',
            'POA_Holder_Name__c' => 'POA_Holder_Name_Arabic__c',
            'Visa_Place_Issue__c' => 'Visa_Place_of_Issue_Arabic__c'
        },
        'Account' => new Map<String,String> {
            'LastName' => 'Contact_Last_Name_Arabic__pc',
            'FirstName' => 'Contact_First_Name_Arabic__pc',
            'MiddleName' => 'Contact_Middle_Name_Arabic__pc',
            'Name' => 'Account_Name_Arabic__c',
            'BillingStreet' => 'Address__c','Source_of_funds_other__pc' => 'Source_of_funds_other_arabic__pc',
            'Politically_exposed_person_text__pc' => 'Politically_exposed_person_text_arabic__pc',
            'Payment_methods_other__pc' => 'Payment_methods_other_arabic__pc',
            'Bank_Name__pc' => 'Bank_Name_Arabic__pc',
            'Nature_of_Business__pc' => 'Nature_of_Business_Arabic__pc',
            'POA_Holder_Name__pc' => 'POA_Holder_Name_Arabic__pc',
            'Visa_Place_Issue__pc' => 'Visa_Place_of_Issue_Arabic__pc'
        },
        'Project__c' => new Map<String,String> {
            'Name' => 'Project_Name_Arabic__c'
        }
    };

    public static final Map<String,Map<String, String>> translateTypeFieldMap = new Map <String,Map<String,String>>{
        'Contact' => new Map<String,String> {
            'Place_of_birth__c' => 'Place_of_birth_arabic__c',
            'Occupation__c'  => 'Occupation_Arabic__c',
            'Source_of_funds_other__c' => 'Source_of_funds_other_arabic__c',
            'Politically_exposed_person_text__c' => 'Politically_exposed_person_text_arabic__c',
            'Payment_methods_other__c' => 'Payment_methods_other_arabic__c',
            'Currency_other__c' => 'currency_other_arabic__c',
            'Bank_Name__c' => 'Bank_Name_Arabic__c',
            'Nature_of_Business__c' => 'Nature_of_Business_Arabic__c',
            'Nationality__c' => 'Nationality_Arabic__c',
            'POA_Holder_Name__c' => 'POA_Holder_Name_Arabic__c',
            'Visa_Place_Issue__c' => 'Visa_Place_of_Issue_Arabic__c'
        },
        'Account' => new Map<String,String> {
            'BillingCity' => 'City_Arabic__c',
            'BillingCountry' => 'Country_Arabic__c',
            'Place_of_birth__pc' => 'Place_of_birth_arabic__pc',
            'Occupation__pc'  => 'Occupation_Arabic__pc',
            'Source_of_funds_other__pc' => 'Source_of_funds_other_arabic__pc',
            'Politically_exposed_person_text__pc' => 'Politically_exposed_person_text_arabic__pc',
            'Payment_methods_other__pc' => 'Payment_methods_other_arabic__pc',
            'Currency_other__pc' => 'currency_other_arabic__pc',
            'Bank_Name__pc' => 'Bank_Name_Arabic__pc',
            'Nature_of_Business__pc' => 'Nature_of_Business_Arabic__pc',
            'POA_Holder_Name__pc' => 'POA_Holder_Name_Arabic__pc',
            'Visa_Place_Issue__pc' => 'Visa_Place_of_Issue_Arabic__pc'
        }
    };
    public static void handleSObjectTransliteratableFieldsNullify(list<SObject> triggerNew, list<SObject> triggerOld){
        String sObjectType = String.valueOf(triggerNew[0].getSObjectType());
        System.debug('===> Checking Transliteration Fields Handler for SObject '+sObjectType);
        Map<String,Map<Id,Set<String>>> recordsToProcess = new Map<String,Map<Id, Set<String>>>();
        //Map<Id,Set<String>> recordsToProcess = new Map<Id,Set<String>>(); 

        if(!Trigger.isInsert && !Trigger.isUpdate) {
            return;
        }
        if(!Trigger.isBefore) {
            return;
        }

        Map<String,String> transliterateFieldMap = transliterateTypeFieldMap.get(sObjectType);
        Map<String,String> translateFieldMap = translateTypeFieldMap.get(sObjectType);
        if (transliterateFieldMap != null) {
            for (String fieldName : transliterateFieldMap.keySet()){
                for (Integer i=0; i < trigger.new.size(); i++) {
                    if (Trigger.isInsert) {
                        if (triggerNew[i].get(fieldName) == null) {
                            triggerNew[i].put(transliterateFieldMap.get(fieldName),null);
                        }
                    }
                    if (Trigger.isUpdate){
                        if (triggerNew[i].get(fieldName) != triggerOld[i].get(fieldName)) {
                            triggerNew[i].put(transliterateFieldMap.get(fieldName),null);
                        }
                    }
                }
            }
        }

        if (translateFieldMap != null) {
            for (String fieldName : translateFieldMap.keySet()){
                for (Integer i=0; i < trigger.new.size(); i++) {
                    if (Trigger.isInsert){
                        if (triggerNew[i].get(fieldName) == null) {
                            triggerNew[i].put(translateFieldMap.get(fieldName),null);
                        }
                    }
                    if (Trigger.isUpdate){
                        if (triggerNew[i].get(fieldName) != triggerOld[i].get(fieldName)) {
                            triggerNew[i].put(translateFieldMap.get(fieldName),null);
                        }
                    }
                }
            }
        }
    }

    public static void handleSObjectTransliteratableFieldsChange(list<SObject> triggerNew, list<SObject> triggerOld){
        String sObjectType = String.valueOf(triggerNew[0].getSObjectType());
        System.debug('===> Checking Transliteration Fields Handler for SObject '+sObjectType);
        Map<String,Map<Id,Set<String>>> recordsToProcess = new Map<String,Map<Id, Set<String>>>();
        //Map<Id,Set<String>> recordsToProcess = new Map<Id,Set<String>>(); 

        if(!Trigger.isInsert && !Trigger.isUpdate) {
            return;
        }
        if(!Trigger.isAfter) {
            return;
        }

        Map<String,String> transliterateFieldMap = transliterateTypeFieldMap.get(sObjectType);
        Map<String,String> translateFieldMap = translateTypeFieldMap.get(sObjectType);
        if (transliterateFieldMap != null) {
            for (String fieldName : transliterateFieldMap.keySet()){
                for (Integer i=0; i < trigger.new.size(); i++) {
                    if (Trigger.isInsert){
                        if (triggerNew[i].get(fieldName) != null) {
                            if (!recordsToProcess.containsKey('transliterate')){
                                recordsToProcess.put('transliterate', new Map<Id,Set<String>>());
                            }
                            if (!recordsToProcess.get('transliterate').containsKey((String)triggerNew[i].get('Id'))){
                                recordsToProcess.get('transliterate').put((String)triggerNew[i].get('Id'), new Set<String>());
                            }
                            recordsToProcess.get('transliterate').get((String)triggerNew[i].get('Id')).add(fieldName);
                        }
                    }
                    if (Trigger.isUpdate){
                        if (triggerNew[i].get(fieldName) != triggerOld[i].get(fieldName) && triggerNew[i].get(fieldName) != null) {
                            if (!recordsToProcess.containsKey('transliterate')){
                                recordsToProcess.put('transliterate', new Map<Id,Set<String>>());
                            }
                            if (!recordsToProcess.get('transliterate').containsKey((String)triggerNew[i].get('Id'))){
                                recordsToProcess.get('transliterate').put((String)triggerNew[i].get('Id'), new Set<String>());
                            }
                            recordsToProcess.get('transliterate').get((String)triggerNew[i].get('Id')).add(fieldName);
                        }
                    }
                }
            }
        }

        if (translateFieldMap != null) {
            for (String fieldName : translateFieldMap.keySet()){
                for (Integer i=0; i < trigger.new.size(); i++) {
                    if (Trigger.isInsert){
                        if (triggerNew[i].get(fieldName) != null) {
                            if (!recordsToProcess.containsKey('translate')){
                                recordsToProcess.put('translate', new Map<Id,Set<String>>());
                            }
                            if (!recordsToProcess.get('translate').containsKey((String)triggerNew[i].get('Id'))){
                                recordsToProcess.get('translate').put((String)triggerNew[i].get('Id'), new Set<String>());
                            }
                            recordsToProcess.get('translate').get((String)triggerNew[i].get('Id')).add(fieldName);
                        }
                    }
                    if (Trigger.isUpdate){
                        if (triggerNew[i].get(fieldName) != triggerOld[i].get(fieldName) && triggerNew[i].get(fieldName) != null) {
                            if (!recordsToProcess.containsKey('translate')){
                                recordsToProcess.put('translate', new Map<Id,Set<String>>());
                            }
                            if (!recordsToProcess.get('translate').containsKey((String)triggerNew[i].get('Id'))){
                                recordsToProcess.get('translate').put((String)triggerNew[i].get('Id'), new Set<String>());
                            }
                            recordsToProcess.get('translate').get((String)triggerNew[i].get('Id')).add(fieldName);
                        }
                    }
                }
            }
        }
        System.debug('===> Transliteration required for '+recordsToProcess);
        if (!recordsToProcess.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new MSAzureAiQueueable(recordsToProcess));
        }
    }
}