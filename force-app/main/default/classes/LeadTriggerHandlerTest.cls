@isTest
public class LeadTriggerHandlerTest {
    
    // Helper method to get the correct Record Type ID based on environment
    private static String getDatabaseRecordTypeId() {
        String sandboxId = '012U9000001VJQnIAO';
        String productionId = '012Rg000004MLB8IAO';
        
        // Try to get the sandbox ID first
        List<RecordType> rtList = [SELECT Id FROM RecordType WHERE Id = :sandboxId LIMIT 1];
        if (!rtList.isEmpty()) {
            return sandboxId;
        }
        return productionId;
    }
    
    private static String getMasterRecordTypeId() {
        String sandboxId = '012U9000001VCnVIAW';
        String productionId = '012Rg000004MNYLIA4';
        
        // Try to get the sandbox ID first
        List<RecordType> rtList = [SELECT Id FROM RecordType WHERE Id = :sandboxId LIMIT 1];
        if (!rtList.isEmpty()) {
            return sandboxId;
        }
        return productionId;
    }
    
    @isTest
    static void testInsertLeadWithDatabaseFunnelType() {
        // Create test data
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Funnel_Type__c = 'Database'
        );
        
        // Perform test
        Test.startTest();
        LeadTriggerHandler.assignRecordTypes(new List<Lead>{testLead}, null);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(getDatabaseRecordTypeId(), testLead.RecordTypeId, 
            'Lead should be assigned Database Record Type');
    }
    
    @isTest
    static void testInsertLeadWithOtherFunnelType() {
        // Create test data
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Funnel_Type__c = 'Other'
        );
        
        // Perform test
        Test.startTest();
        LeadTriggerHandler.assignRecordTypes(new List<Lead>{testLead}, null);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(getMasterRecordTypeId(), testLead.RecordTypeId, 
            'Lead should be assigned Master Record Type');
    }
    
    @isTest
    static void testUpdateLeadChangeFunnelType() {
        // Create test data with initial Funnel Type
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Funnel_Type__c = 'Other'
        );
        
        // Assign initial record type
        LeadTriggerHandler.assignRecordTypes(new List<Lead>{testLead}, null);
        insert testLead;
        
        // Create the old version of the lead
        Lead oldLead = new Lead(
            Id = testLead.Id,
            LastName = 'Test Lead',
            Company = 'Test Company',
            Funnel_Type__c = 'Other',
            RecordTypeId = getMasterRecordTypeId()
        );
        Map<Id, Lead> oldLeadsMap = new Map<Id, Lead>{testLead.Id => oldLead};
        
        // Update the lead's Funnel Type
        testLead.Funnel_Type__c = 'Database';
        
        // Perform test
        Test.startTest();
        LeadTriggerHandler.assignRecordTypes(new List<Lead>{testLead}, oldLeadsMap);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(getDatabaseRecordTypeId(), testLead.RecordTypeId, 
            'Lead should be updated to Database Record Type');
    }
    
    @isTest
    static void testUpdateLeadNoFunnelTypeChange() {
        // Create test data
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Funnel_Type__c = 'Database'
        );
        
        // Assign initial record type
        LeadTriggerHandler.assignRecordTypes(new List<Lead>{testLead}, null);
        insert testLead;
        
        // Create old version of the lead (same Funnel Type)
        Lead oldLead = new Lead(
            Id = testLead.Id,
            LastName = 'Test Lead',
            Company = 'Test Company',
            Funnel_Type__c = 'Database',
            RecordTypeId = getDatabaseRecordTypeId()
        );
        Map<Id, Lead> oldLeadsMap = new Map<Id, Lead>{testLead.Id => oldLead};
        
        // Update something else but keep Funnel Type the same
        testLead.Company = 'Updated Company';
        
        // Perform test
        Test.startTest();
        LeadTriggerHandler.assignRecordTypes(new List<Lead>{testLead}, oldLeadsMap);
        Test.stopTest();
        
        // Verify results - RecordTypeId should remain unchanged
        System.assertEquals(getDatabaseRecordTypeId(), testLead.RecordTypeId, 
            'Record Type should remain unchanged when Funnel Type does not change');
    }
}