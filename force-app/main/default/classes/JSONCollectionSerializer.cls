public class JSONCollectionSerializer {
    @InvocableMethod(label='JSON Serializer')
    public static List<String> serializeCollection(List<List<SObject>> inputCollections) {
        List<String> jsonStrings = new List<String>();

        for (List<SObject> collection : inputCollections) {
            if (collection != null && !collection.isEmpty()) {
                // Iterate through each record in the collection
                for (SObject record : collection) {
                    // Check if the object type is Receipt_Amount__c, which has Amount__c field
                    if (record.getSObjectType() == Receipt_Amount__c.SObjectType) {
                        if (record.get('Amount__c') != null) {
                            System.debug('Amount__c exists and is: ' + record.get('Amount__c'));
                        } else {
                            System.debug('Amount__c is null in this Receipt_Amount__c record');
                        }
                    } else {
                        System.debug('Record does not have Amount__c field: ' + record.getSObjectType());
                    }
                }

                // Serialize the collection (whether or not Amount__c exists)
                jsonStrings.add(JSON.serialize(collection));
            } else {
                jsonStrings.add('[]');
            }
        }

        return jsonStrings;
    }
}