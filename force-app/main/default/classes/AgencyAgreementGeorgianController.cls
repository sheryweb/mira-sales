public class AgencyAgreementGeorgianController {
    public Map<String, Object> accData {get; set;}
    public AgencyAgreementGeorgianController() {
        Id acctId = ApexPages.currentPage().getParameters().get('acctId');
        Map<String, Object> objVal = new Map<String, Object>();
        Account acct = [SELECT Id, Name, BillingStreet, BillingPostalCode, Trade_License_Number__c, ORN_Number__c, Phone, Company_Email__c, Signatory_Name__c, Registered_In__c, Issuing_Authority__c, Identification_Number__c FROM Account WHERE Id = :acctId];
        objVal.put('agencyAccount', acct);
        accData = objVal;
    }
}