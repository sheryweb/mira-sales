public with sharing class ContentDocumentLinkTriggerController {
    public static void handleContentDocumentLinkBeforeInsert(List<ContentDocumentLink> contentDocumentLinks) {
        shareContentDocumentLinksBasedOnCustomMetadata(contentDocumentLinks);   
    }

    public static void shareContentDocumentLinksBasedOnCustomMetadata(List<ContentDocumentLink> contentDocumentLinks){
        Map<Id, ContentDocumentLink> fileToContentDocumentLink = new Map<Id, ContentDocumentLink>();
        Map<Id, ContentDocumentLink> contentDocumentLinkMap = new Map<Id,ContentDocumentLink>();
        Map<SObjectType, List<Id>> objectTypeToContentDocmentLinks= new Map<SObjectType, List<Id>>();

        for(ContentDocumentLink contentDocumentLink : contentDocumentLinks){
            if(objectTypeToContentDocmentLinks.containsKey(contentDocumentLink.LinkedEntityId.getSObjectType())){
                List<Id> idList = objectTypeToContentDocmentLinks.get(contentDocumentLink.LinkedEntityId.getSObjectType());
                idList.add(contentDocumentLink.LinkedEntityId);
                objectTypeToContentDocmentLinks.put(contentDocumentLink.LinkedEntityId.getSObjectType(), idList);
            } else {
                objectTypeToContentDocmentLinks.put(contentDocumentLink.LinkedEntityId.getSObjectType(), new List<Id>{contentDocumentLink.LinkedEntityId});
            }
            contentDocumentLinkMap.put(contentDocumentLink.Id, contentDocumentLink);
            fileToContentDocumentLink.put(contentDocumentLink.LinkedEntityId,contentDocumentLink);

        }

        List<Content_Document_Link_Sharing_Setting__mdt> sharingSettings = [
            SELECT Id, Field_Value__c, Field_Api_Name__c, sObject_Api_Name__c 
            FROM Content_Document_Link_Sharing_Setting__mdt
        ];
        
        for(Content_Document_Link_Sharing_Setting__mdt sharingSetting : sharingSettings){
            SObjectType sObjType = ((SObject) Type.forName(sharingSetting.sObject_Api_Name__c).newInstance()).getSObjectType();
            Set<String> fieldValuesSet;
            if(sharingSetting.Field_Value__c != null){
                List<String> fieldValues = (sharingSetting.Field_Value__c).split(';');
                fieldValuesSet = new Set<String>(fieldValues);
            }
            if(objectTypeToContentDocmentLinks.get(sObjType) != null){
                List<Id> ids = objectTypeToContentDocmentLinks.get(sObjType);
                String mainQuery = 'SELECT Id';
                if(sharingSetting.Field_Api_Name__c != null){
                    mainQuery += ', ' + sharingSetting.Field_Api_Name__c;
                }
                mainQuery += ' FROM ' + sharingSetting.sObject_Api_Name__c + ' WHERE Id IN :ids';
                List<sObject> sObjectList = Database.query(mainQuery);
                
                for(sObject queriedObject : sObjectList){
                    if(sharingSetting.Field_Value__c == null){
                        ContentDocumentLink contentDocumentLink = fileToContentDocumentLink.get(queriedObject.Id);
                        contentDocumentLink.Visibility = 'AllUsers'; 
                        contentDocumentLinkMap.put(contentDocumentLink.Id, contentDocumentLink);
                    } else if(!fieldValuesSet.isEmpty() && fieldValuesSet.contains((String)queriedObject.get(sharingSetting.Field_Api_Name__c))){
                        ContentDocumentLink contentDocumentLink = fileToContentDocumentLink.get(queriedObject.Id);
                        contentDocumentLink.Visibility = 'AllUsers'; 
                        contentDocumentLinkMap.put(contentDocumentLink.Id, contentDocumentLink); 
                    }
                }
            }
        }
    }
}