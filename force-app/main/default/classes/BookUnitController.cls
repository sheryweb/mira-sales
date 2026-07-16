public with sharing class BookUnitController {
    // Record Type IDs for filtering
    private static final Set<Id> CLIENT_RECORD_TYPE_IDS = new Set<Id>{
        '012Hp000001yUTFIA2',
        '012Hp000001yiSEIAY'
    };
    private static final Id AGENCY_RECORD_TYPE_ID = '012Hp000001yUTAIA2';

    @AuraEnabled(cacheable=true)
    public static List<Account> searchClientAccounts(String searchKey) {
        try {
            if (!Schema.sObjectType.Account.isAccessible()) {
                throw new AuraHandledException('Insufficient access rights to Account');
            }
            if (String.isBlank(searchKey) || searchKey.length() < 2) {
                return [
                    SELECT Id, Name
                    FROM Account
                    WHERE RecordTypeId IN :CLIENT_RECORD_TYPE_IDS
                    WITH SECURITY_ENFORCED
                    ORDER BY Name
                    LIMIT 10
                ];
            }
            String key = '%' + String.escapeSingleQuotes(searchKey) + '%';
            return [
                SELECT Id, Name
                FROM Account
                WHERE RecordTypeId IN :CLIENT_RECORD_TYPE_IDS
                AND Name LIKE :key
                WITH SECURITY_ENFORCED
                LIMIT 10
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error searching client accounts: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Account> searchAgencyAccounts(String searchKey) {
        try {
            if (!Schema.sObjectType.Account.isAccessible()) {
                throw new AuraHandledException('Insufficient access rights to Account');
            }
            if (String.isBlank(searchKey) || searchKey.length() < 2) {
                return [
                    SELECT Id, Name
                    FROM Account
                    WHERE RecordTypeId = :AGENCY_RECORD_TYPE_ID
                    AND Status__c = 'Completed'
                    WITH SECURITY_ENFORCED
                    ORDER BY Name
                    LIMIT 10
                ];
            }
            String key = '%' + String.escapeSingleQuotes(searchKey) + '%';
            return [
                SELECT Id, Name
                FROM Account
                WHERE RecordTypeId = :AGENCY_RECORD_TYPE_ID
                AND Status__c = 'Completed'
                AND Name LIKE :key
                WITH SECURITY_ENFORCED
                LIMIT 10
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error searching agency accounts: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> searchContactsByAccount(String searchKey, Id accountId) {
        try {
            if (!Schema.sObjectType.Contact.isAccessible()) {
                throw new AuraHandledException('Insufficient access rights to Contact');
            }
            if (accountId == null) {
                return new List<Contact>();
            }
            if (String.isBlank(searchKey) || searchKey.length() < 2) {
                return [
                    SELECT Id, Name
                    FROM Contact
                    WHERE AccountId = :accountId
                    WITH SECURITY_ENFORCED
                    LIMIT 10
                ];
            }
            String key = '%' + String.escapeSingleQuotes(searchKey) + '%';
            return [
                SELECT Id, Name
                FROM Contact
                WHERE AccountId = :accountId
                AND (LastName LIKE :key OR FirstName LIKE :key)
                WITH SECURITY_ENFORCED
                LIMIT 10
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error searching contacts: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Id createBookingOpportunity(Id accountId, Id unitId, Id agencyId, Id agentId, Boolean assistedByAgent) {
        try {
            if (!Schema.sObjectType.Opportunity.isCreateable() || !Schema.sObjectType.Opportunity.isUpdateable()) {
                throw new AuraHandledException('Insufficient access rights to Opportunity');
            }
            if (accountId == null || unitId == null) {
                throw new AuraHandledException('Account and Unit are required');
            }

            Opportunity newOpp = new Opportunity();
            newOpp.AccountId = accountId;
            newOpp.Unit__c = unitId;
            newOpp.StageName = 'New';
            newOpp.CloseDate = Date.today();
            if (Schema.sObjectType.Opportunity.fields.Name.isCreateable()) {
                Account clientAccount = [SELECT Id, Name FROM Account WHERE Id = :accountId WITH SECURITY_ENFORCED LIMIT 1];
                Unit__c unitRecord = [SELECT Id, Title__c FROM Unit__c WHERE Id = :unitId WITH SECURITY_ENFORCED LIMIT 1];
                String unitTitle = unitRecord.Title__c != null ? unitRecord.Title__c : '';
                newOpp.Name = clientAccount.Name + ' - ' + Datetime.now().format('yyyy-MM-dd') + ' - ' + unitTitle;
            }
            newOpp.Assisted_by_Agent__c = assistedByAgent == true;
            if (agencyId != null) {
                newOpp.Agency__c = agencyId;
            }
            if (agentId != null) {
                newOpp.Agent__c = agentId;
            }

            insert newOpp;

            Opportunity oppToBooked = new Opportunity(Id = newOpp.Id, StageName = 'Booked');
            update oppToBooked;

            return newOpp.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating booking: ' + e.getMessage());
        }
    }
}