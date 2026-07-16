public class JSONInvoiceSerializer {
    @InvocableMethod(label='JSON Invoice Serializer')
    public static List<String> serializeInvoices(List<List<SObject>> inputCollections) {
        List<String> jsonStrings = new List<String>();

        for (List<SObject> collection : inputCollections) {
            if (collection != null && !collection.isEmpty()) {
                // Iterate through each record in the collection
                for (SObject record : collection) {
                    // Check if the object type is Invoice__c or Milestone_Invoice__c
                    if (record.getSObjectType() == Invoice__c.SObjectType) {
                        // Debug logging for Invoice__c fields
                        if (record.get('Sub_Total_Amount__c') != null) {
                            System.debug('Sub_Total_Amount__c exists and is: ' + record.get('Sub_Total_Amount__c'));
                        } else {
                            System.debug('Sub_Total_Amount__c is null in this Invoice__c record');
                        }

                        if (record.get('Grand_Total_Amount__c') != null) {
                            System.debug('Grand_Total_Amount__c exists and is: ' + record.get('Grand_Total_Amount__c'));
                        } else {
                            System.debug('Grand_Total_Amount__c is null in this Invoice__c record');
                        }
                    } else if (record.getSObjectType() == Milestone_Invoice__c.SObjectType) {
                        // Debug logging for Milestone_Invoice__c fields
                        if (record.get('Amount__c') != null) {
                            System.debug('Amount__c exists and is: ' + record.get('Amount__c'));
                        } else {
                            System.debug('Amount__c is null in this Milestone_Invoice__c record');
                        }
                    } else {
                        System.debug('Record is not an Invoice__c or Milestone_Invoice__c: ' + record.getSObjectType());
                    }
                }

                // Serialize the collection
                jsonStrings.add(JSON.serialize(collection));
            } else {
                jsonStrings.add('[]');
            }
        }
        System.debug('jsonStrings: ' + jsonStrings);

        return jsonStrings;
    }
}