@isTest
public class JSONCollectionSerializerTest {

    @isTest
    static void testMultipleCollections() {
        // Create test data for Receipt_Amount__c records
        List<SObject> receipts = new List<SObject>();
        receipts.add(new Receipt_Amount__c(Amount__c = 100.50));
        receipts.add(new Receipt_Amount__c(Amount__c = null));

        // Create test data for another SObject type
        List<SObject> otherObjects = new List<SObject>();
        otherObjects.add(new Account(Name = 'Test Account 1'));
        otherObjects.add(new Account(Name = 'Test Account 2'));

        // Input with multiple collections
        List<List<SObject>> inputCollections = new List<List<SObject>>();
        inputCollections.add(receipts);
        inputCollections.add(otherObjects);

        Test.startTest();
        List<String> jsonOutput = JSONCollectionSerializer.serializeCollection(inputCollections);
        Test.stopTest();

        // Validate results for the first collection (Receipt_Amount__c)
        System.assertEquals(2, jsonOutput.size(), 'There should be two JSON strings in the output list.');
        String receiptsJson = jsonOutput[0];
        System.assert(receiptsJson.contains('Amount__c'), 'JSON should include the Amount__c field.');
        System.assert(receiptsJson.contains('100.50'), 'JSON should include the correct Amount__c value.');

        // Validate results for the second collection (Account)
        String accountsJson = jsonOutput[1];
        System.assert(accountsJson.contains('Name'), 'JSON should include the Name field.');
        System.assert(accountsJson.contains('Test Account 1'), 'JSON should include the first Account name.');
    }

    @isTest
    static void testEmptyCollection() {
        // Empty collection
        List<List<SObject>> inputCollections = new List<List<SObject>>();
        inputCollections.add(new List<SObject>());

        Test.startTest();
        List<String> emptyJsonOutput = JSONCollectionSerializer.serializeCollection(inputCollections);
        Test.stopTest();

        System.assertEquals(1, emptyJsonOutput.size(), 'Empty collection should serialize to a single JSON array.');
        System.assertEquals('[]', emptyJsonOutput[0], 'Empty collection should serialize to an empty JSON array.');
    }

    @isTest
    static void testNullCollection() {
        // Null collection
        List<List<SObject>> inputCollections = new List<List<SObject>>();
        inputCollections.add(null);

        Test.startTest();
        List<String> nullJsonOutput = JSONCollectionSerializer.serializeCollection(inputCollections);
        Test.stopTest();

        System.assertEquals(1, nullJsonOutput.size(), 'Null collection should serialize to a single JSON array.');
        System.assertEquals('[]', nullJsonOutput[0], 'Null collection should serialize to an empty JSON array.');
    }
}