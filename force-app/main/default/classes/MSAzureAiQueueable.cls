public without sharing class MSAzureAiQueueable implements Queueable, Database.AllowsCallouts {
    public Map<String, Map<Id,Set<String>>> recordsToProcess;
    public MSAzureAiQueueable (Map<String, Map<Id,Set<String>>> rtp) {
        this.recordsToProcess = rtp;
    }

    public class RequestElement {
        public String text;

        public RequestElement (String s) {
            this.text = s;
        }
    }

    public class TransliterateResponseElement {
        public String text;
        public String script;
    }

    public class TranslateResponseElement {
        public DetectedLanguage detectedLanguage;
        public List<Translation> translations;
    }

    public class DetectedLanguage {
        public String language;
        public Decimal score;
    }

    public class Translation {
        public String text;
        public String to;
    }

    public void execute(QueueableContext context) {
        MS_Azure_Configuration__mdt endpointDefinition = MS_Azure_Configuration__mdt.getInstance('Default');
        if (endpointDefinition == null || endpointDefinition.Translate_Endpoint__c == null || endpointDefinition.Transliterate_Endpoint__c == null){
            system.debug('MS Azure endpoints are not defined');
            return;   
        }

        if (endpointDefinition.Subscription_Key__c == null || endpointDefinition.Subscription_Region__c == null){
            system.debug('MS Azure credentials are not defined');
            return;   
        }
        String translateEndpoint = endpointDefinition.Translate_Endpoint__c;
        String transliterateEndpoint = endpointDefinition.Transliterate_Endpoint__c;

        Set<String> stringsToTranslate = new Set<String>();
        Set<String> stringsToTransliterate = new Set<String>();

        List<SObject> recordsToUpdate = new List<SObject>();

        if (recordsToProcess.isEmpty()){
            return;
        }

        Map<String, Map<Id,Set<String>>> recordsToProcessCopy = (Map<String, Map<Id,Set<String>>>) JSON.deserialize(JSON.serialize(recordsToProcess),Map<String, Map<Id,Set<String>>>.class);

        //Transliterate
        if (recordsToProcess.containsKey('transliterate')){
            Map<Id,Set<String>> recordsToTransliterate = recordsToProcess.get('transliterate');
            List<Id> idsToProcess = new List<Id>(recordsToTransliterate.keySet());
            String sObjectType = String.valueOf(idsToProcess[0].getSObjectType());
            if (!MSAzureAiTriggerHandler.transliterateTypeFieldMap.containsKey(sObjectType)){
                return;
            }

            Map<String,String> transliterateFieldMap = MSAzureAiTriggerHandler.transliterateTypeFieldMap.get(sObjectType);
            Set<String> queryFields = transliterateFieldMap.keySet();

            String queryString = 'SELECT '+string.join(queryFields,',') + ' FROM '+sObjectType+' WHERE Id IN :idsToProcess';
            list <SObject> records = Database.query(queryString);
            
            for (SObject record : records) {
                Id recordId = (Id)record.get('Id');
                Set<String> changedFields = recordsToTransliterate.get(recordId);
                system.debug(changedFields);
                for (String fieldName : changedFields){
                    system.debug(fieldName);
                    if (stringsToTransliterate.size()<200) {
                        if (String.isNotBlank((String)record.get(fieldName))){
                            stringsToTransliterate.add((String)record.get(fieldName));
                        }
                        record.put(transliterateFieldMap.get(fieldName),null);
                    }else{
                        break;
                    }
                }
            }
            system.debug(stringsToTransliterate);
            if (stringsToTransliterate.isEmpty()){
                return;
            }
            List<RequestElement> requestBody = new List<RequestElement>();
            for (String s: stringsToTransliterate){
                requestBody.add(new RequestElement(s));
            }

            Http h = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(transliterateEndpoint);
            req.setMethod('POST');

            req.setHeader('content-type', 'application/json');
            req.setHeader('Ocp-Apim-Subscription-Key', endpointDefinition.Subscription_Key__c);
            req.setHeader('Ocp-Apim-Subscription-Region', endpointDefinition.Subscription_Region__c);


            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(100000);
            
            HttpResponse res = h.send(req);
            String response = res.getBody();
            system.debug(response);
            List<TransliterateResponseElement> responseArray = (List<TransliterateResponseElement>)JSON.deserialize(response, List<TransliterateResponseElement>.class);
            Map<String,String> responseMap = new Map<String,String>();
            integer order = 0;
            for (String s: stringsToTransliterate){
                responseMap.put(s, responseArray[order].text);
                order++;
            }

            //update records;
            for (SObject record : records) {
                SObject recordToUpdate = (SObject) Type.forName('Schema', sObjectType).newInstance();
                Id recordId = (Id)record.get('Id');
                recordToUpdate.put('Id',recordId);
                Set<String> changedFields = recordsToTransliterate.get(recordId);
                for (String fieldName : changedFields){
                    String fieldValue = (String)record.get(fieldName);
                    system.debug(fieldName);
                    system.debug(fieldValue);
                    if (String.isNotBlank(fieldValue)){
                        if (responseMap.containsKey(fieldValue)){
                            recordToUpdate.put(transliterateFieldMap.get(fieldName),responseMap.get(fieldValue));
                            recordsToProcessCopy.get('transliterate').get(recordId).remove(fieldName);
                            if (recordsToProcessCopy.get('transliterate').get(recordId).isEmpty()){
                                recordsToProcessCopy.get('transliterate').remove(recordId);
                            }
                        }
                    }
                }
                recordsToUpdate.add(recordToUpdate);
            }
            update recordsToUpdate;
            
        }else{
            Map<Id,Set<String>> recordsToTranslate = recordsToProcess.get('translate');
            List<Id> idsToProcess = new List<Id>(recordsToTranslate.keySet());
            String sObjectType = String.valueOf(idsToProcess[0].getSObjectType());
            if (!MSAzureAiTriggerHandler.translateTypeFieldMap.containsKey(sObjectType)){
                return;
            }

            Map<String,String> translateFieldMap = MSAzureAiTriggerHandler.translateTypeFieldMap.get(sObjectType);
            Set<String> queryFields = translateFieldMap.keySet();

            String queryString = 'SELECT '+string.join(queryFields,',') + ' FROM '+sObjectType+' WHERE Id IN :idsToProcess';
            list <SObject> records = Database.query(queryString);
            
            for (SObject record : records) {
                Id recordId = (Id)record.get('Id');
                Set<String> changedFields = recordsToTranslate.get(recordId);
                for (String fieldName : changedFields){
                    if (stringsToTranslate.size()<200) {
                        if (String.isNotBlank((String)record.get(fieldName))){
                            stringsToTranslate.add((String)record.get(fieldName));
                        }
                        record.put(translateFieldMap.get(fieldName),null);
                    }else{
                        break;
                    }
                }
            }
            system.debug(stringsToTranslate);
            if (stringsToTranslate.isEmpty()){
                return;
            }
            List<RequestElement> requestBody = new List<RequestElement>();
            for (String s: stringsToTranslate){
                requestBody.add(new RequestElement(s));
            }

            Http h = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(translateEndpoint);
            req.setMethod('POST');

            req.setHeader('content-type', 'application/json');
            req.setHeader('Ocp-Apim-Subscription-Key', endpointDefinition.Subscription_Key__c);
            req.setHeader('Ocp-Apim-Subscription-Region', endpointDefinition.Subscription_Region__c);


            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(100000);

            HttpResponse res = h.send(req);
            String response = res.getBody();
            system.debug(response);
            List<TranslateResponseElement> responseArray = (List<TranslateResponseElement>)JSON.deserialize(response, List<TranslateResponseElement>.class);
            Map<String,String> responseMap = new Map<String,String>();
            integer order = 0;
            for (String s: stringsToTranslate){
                responseMap.put(s, responseArray[order].translations[0].text);
                order++;
            }

            //update records;
            for (SObject record : records) {
                SObject recordToUpdate = (SObject) Type.forName('Schema', sObjectType).newInstance();
                Id recordId = (Id)record.get('Id');
                recordToUpdate.put('Id', recordId);
                Set<String> changedFields = recordsToTranslate.get(recordId);
                for (String fieldName : changedFields){
                    String fieldValue = (String)record.get(fieldName);
                    system.debug(fieldName);
                    system.debug(fieldValue);
                    if (String.isNotBlank(fieldValue)){
                        system.debug('contains? '+responseMap.containsKey(fieldValue));
                        if (responseMap.containsKey(fieldValue)){
                            recordToUpdate.put(translateFieldMap.get(fieldName),responseMap.get(fieldValue));
                            recordsToProcessCopy.get('translate').get(recordId).remove(fieldName);
                            if (recordsToProcessCopy.get('translate').get(recordId).isEmpty()){
                                recordsToProcessCopy.get('translate').remove(recordId);
                            }
                        }
                    }
                }
                recordsToUpdate.add(recordToUpdate);
            }
            update recordsToUpdate;
        }
        system.debug(recordsToProcessCopy);
        if (recordsToProcessCopy.containsKey('transliterate')){
            if (recordsToProcessCopy.get('transliterate').isEmpty()){
                recordsToProcessCopy.remove('transliterate');
            }
        }

        if (recordsToProcessCopy.containsKey('translate')){
            if (recordsToProcessCopy.get('translate').isEmpty()){
                recordsToProcessCopy.remove('translate');
            }
        }
        system.debug(recordsToProcessCopy);
        if (!Test.isRunningTest()){
            if (!recordsToProcessCopy.isEmpty()){
                System.enqueueJob(new MSAzureAiQueueable(recordsToProcessCopy));
            }
        }
    }
}