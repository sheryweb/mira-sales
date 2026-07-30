public with sharing class InvoicePreviewController {
    @AuraEnabled
    // Read-only: intentionally not gated by the engine switch, so the page renders normally
    // when the engine is off. Only actions are gated (FinancialEngine.requireEnabled).
    public static Financial_Detail__c getFinancialDetail(String financialDetailId) {
        try {
            if (String.isBlank(financialDetailId)) {
                return null;
            }
            
            List<Financial_Detail__c> results = [
                SELECT Id, Name, Account_Name__c, Account_Number__c, 
                       IBAN__c, Swift_Code__c, Branch_Name__c
                FROM Financial_Detail__c
                WHERE Id = :financialDetailId
                LIMIT 1
            ];
            
            return results.isEmpty() ? null : results[0];
            
        } catch (Exception e) {
            return null;
        }
    }
}