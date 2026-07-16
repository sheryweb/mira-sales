public with sharing class CustomLookupController {
    @AuraEnabled(cacheable=true)
    public static List<SObject> findRecords(
        String searchKey,
        String objectName,
        String searchField,
        String filterField,
        String filterValue
    ) {
        return queryRecords(searchKey, objectName, searchField, filterField, filterValue);
    }

    public static List<SObject> findRecords(String searchKey, String objectName, String searchField) {
        return queryRecords(searchKey, objectName, searchField, null, null);
    }

    private static List<SObject> queryRecords(
        String searchKey,
        String objectName,
        String searchField,
        String filterField,
        String filterValue
    ) {
        try {
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
            if (objectType == null || !objectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('Insufficient access rights to ' + objectName);
            }

            Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
            String resolvedSearchField = resolveFieldApiName(fieldMap, searchField);
            if (resolvedSearchField == null) {
                throw new AuraHandledException('Invalid search field: ' + searchField);
            }

            String key = '%' + (searchKey == null ? '' : searchKey) + '%';
            String query =
                'SELECT Id, ' +
                resolvedSearchField +
                ' FROM ' +
                objectName +
                ' WHERE ' +
                resolvedSearchField +
                ' LIKE :key';

            Id filterId;
            if (String.isNotBlank(filterField) && String.isNotBlank(filterValue)) {
                String resolvedFilterField = resolveFieldApiName(fieldMap, filterField);
                if (resolvedFilterField == null) {
                    throw new AuraHandledException('Invalid filter field: ' + filterField);
                }
                filterId = (Id) filterValue;
                query += ' AND ' + resolvedFilterField + ' = :filterId';
            }

            query += ' ORDER BY ' + resolvedSearchField + ' ASC LIMIT 10';
            return Database.query(query);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error searching records: ' + e.getMessage());
        }
    }

    private static String resolveFieldApiName(
        Map<String, Schema.SObjectField> fieldMap,
        String fieldName
    ) {
        if (String.isBlank(fieldName) || fieldMap == null || fieldMap.isEmpty()) {
            return null;
        }

        Schema.SObjectField fieldToken = fieldMap.get(fieldName.toLowerCase());
        if (fieldToken == null) {
            fieldToken = fieldMap.get(fieldName);
        }
        return fieldToken == null ? null : fieldToken.getDescribe().getName();
    }
}