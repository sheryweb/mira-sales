public class AgencyAgreementController {
    public Map<String, Object> accData {get; set;}
    public AgencyAgreementController() {
        Id actId = ApexPages.currentPage().getParameters().get('actId');
        Map<String, Object> objVal = new Map<String, Object>();
        Account acct = [SELECT Id, Name, BillingStreet, BillingPostalCode, Trade_License_Number__c, ORN_Number__c, Phone, Company_Email__c, Signatory_Name__c, Registered_In__c, Issuing_Authority__c FROM Account WHERE Id= :actId];
        
        objVal.put('agencyAccount', acct);
        
        accData = objVal;
    }
}