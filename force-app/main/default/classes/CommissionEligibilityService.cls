public class CommissionEligibilityService {

    public static List<Commission__c> evaluate(Set<Id> accountIds) {
        return evaluate(accountIds, getActiveConfigs());
    }

    public static List<Commission__c> evaluate(Set<Id> accountIds, List<Commission_Eligibility_Config__mdt> configs) {
        if (accountIds == null || accountIds.isEmpty() || configs == null || configs.isEmpty()) {
            return new List<Commission__c>();
        }

        Map<Id, Account> agencies = new Map<Id, Account>([
            SELECT Id, Status__c, Is_Agency_International__c
            FROM Account
            WHERE Id IN :accountIds
        ]);

        List<Opportunity> opps = [
            SELECT Id, Agency__c, StageName, Amount, Unit__c,
                   Unit__r.Project_Name_F__c, Unit__r.Status__c, Unit__r.Cost_AED__c,
                   Unit__r.Commission_Status__c
            FROM Opportunity
            WHERE Agency__c IN :accountIds
            AND StageName = 'Sold'
            AND SPA_Signed__c = true
            AND Is_20_Paid__c = true
            AND Is_DLD_Registration_Paid__c = true
            AND Unit__r.Commission_Status__c != 'Paid'
            AND Unit__r.Commission_Status__c != 'Unpaid'
            AND Unit__r.Commission_Status__c != 'Partially Paid'
        ];

        return evaluateOpps(opps, agencies, configs);
    }

    public static List<Commission__c> evaluateOpps(
        List<Opportunity> opps,
        Map<Id, Account> agencies,
        List<Commission_Eligibility_Config__mdt> configs
    ) {
        List<Commission__c> drafts = new List<Commission__c>();
        DateTime runDate = System.now();

        for (Opportunity opp : opps) {
            if (opp.Agency__c == null) continue;
            Account agency = agencies.get(opp.Agency__c);
            if (agency == null) continue;

            for (Commission_Eligibility_Config__mdt config : configs) {
                if (config.Active__c != true) continue;
                if (matches(opp, agency, config)) {
                    Decimal baseAmount = (opp.Unit__r != null && opp.Unit__r.Cost_AED__c != null)
                        ? opp.Unit__r.Cost_AED__c
                        : opp.Amount;

                    drafts.add(new Commission__c(
                        Opportunity__c = opp.Id,
                        Agency__c = opp.Agency__c,
                        Unit__c = opp.Unit__c,
                        Project_Name__c = (opp.Unit__r != null) ? opp.Unit__r.Project_Name_F__c : null,
                        Base_Amount__c = baseAmount,
                        Commission_Rate__c = config.Commission_Rate__c,
                        Eligibility_Run_Date__c = runDate,
                        Eligibility_Reason__c = 'Matched rule: ' + config.MasterLabel,
                        Description__c = config.Description__c
                    ));
                    break;
                }
            }
        }
        return drafts;
    }

    private static List<Commission_Eligibility_Config__mdt> getActiveConfigs() {
        return [
            SELECT MasterLabel, Project_Name__c, Required_Opportunity_Stage__c,
                   Required_Unit_Status__c, Required_Agency_Status__c,
                   Exclude_International__c, Min_Paid_Percentage__c,
                   Commission_Rate__c, Active__c, Priority__c, Description__c
            FROM Commission_Eligibility_Config__mdt
            WHERE Active__c = true
            ORDER BY Priority__c ASC NULLS LAST
        ];
    }

    private static Boolean matches(Opportunity opp, Account agency, Commission_Eligibility_Config__mdt config) {
        if (String.isNotBlank(config.Project_Name__c) && config.Project_Name__c != '*') {
            String projectName = (opp.Unit__r != null) ? opp.Unit__r.Project_Name_F__c : null;
            if (projectName != config.Project_Name__c) return false;
        }
        if (String.isNotBlank(config.Required_Opportunity_Stage__c)) {
            if (opp.StageName != config.Required_Opportunity_Stage__c) return false;
        }
        if (String.isNotBlank(config.Required_Unit_Status__c)) {
            String unitStatus = (opp.Unit__r != null) ? opp.Unit__r.Status__c : null;
            if (unitStatus != config.Required_Unit_Status__c) return false;
        }
        if (String.isNotBlank(config.Required_Agency_Status__c)) {
            if (agency.Status__c != config.Required_Agency_Status__c) return false;
        }
        if (config.Exclude_International__c == true && isAgencyInternational(agency)) {
            return false;
        }
        return true;
    }

    private static Boolean isAgencyInternational(Account agency) {
        String val = agency.Is_Agency_International__c;
        if (String.isBlank(val)) return false;
        return val.equalsIgnoreCase('Yes')
            || val.equalsIgnoreCase('true')
            || val.equalsIgnoreCase('International');
    }
}