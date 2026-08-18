public class UnitTriggerHandler {
    
    public static void handleUnitsCashFlowAfterUpdate(List<Unit__c> units, List<Unit__c> oldUnits){
        List<Unit__c> unitsToProcess = new List<Unit__c>();
        for(Unit__c unit : units){
            if (unit.Status__c == 'Draft' && unit.Project_Name_Text__c <> 'Trussardi Residences 2') {
                unitsToProcess.add(unit);
            }
        }
        Id projectId = oldUnits[0].Project__c;
    
        if (!unitsToProcess.isEmpty()) {
            List<Cash_Flow_Sum__c> cashFlowSums = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c IN :unitsToProcess];
            delete cashFlowSums;
    
            List<Payment_Plan__c> paymentPlans = [SELECT Id, Project__c, Date__c, Name, Percent__c FROM Payment_Plan__c WHERE Project__c = :projectId ORDER BY Date__c ASC];
            List<Additional_Payment__c> additionalPlans = [SELECT Id, Project__c, Name, Percent__c, Constant__c FROM Additional_Payment__c WHERE Project__c = :projectId];
            System.debug('add: ' + additionalPlans);
            Map<Id,Set<String>> projectToYears = new Map<Id,Set<String>>();
            for(Payment_Plan__c paymentPlan : paymentPlans){
                String paymentPlanYear = paymentPlan.Date__c.year().toString();
                if(projectToYears.containsKey(paymentPlan.Project__c)){
                    Set<String> years = projectToYears.get(paymentPlan.Project__c);
                    years.add(paymentPlanYear);
                    projectToYears.put(paymentPlan.Project__c, years);
                } else {
                    projectToYears.put(paymentPlan.Project__c, new Set<String>{paymentPlanYear});
                }
            }
    
            Map<Id,List<Payment_Plan__c>> projectIdToPaymentPlans = new Map<Id,List<Payment_Plan__c>>();
            for(Payment_Plan__c paymentPlan : paymentPlans){
                if(projectIdToPaymentPlans.containsKey(paymentPlan.Project__c)){
                    List<Payment_Plan__c> projectPaymentPlans = projectIdToPaymentPlans.get(paymentPlan.Project__c);
                    projectPaymentPlans.add(paymentPlan);
                    projectIdToPaymentPlans.put(paymentPlan.Project__c, projectPaymentPlans);
                } else {
                    projectIdToPaymentPlans.put(paymentPlan.Project__c, new List<Payment_Plan__c>{paymentPlan});
                }
            }
    
            Map<Id,List<Additional_Payment__c>> projectIdToAdditonalPayments = new Map<Id,List<Additional_Payment__c>>();
            for(Additional_Payment__c additionalPlan : additionalPlans){
                if(projectIdToAdditonalPayments.containsKey(additionalPlan.Project__c)){
                    List<Additional_Payment__c> projectAdditionalPlans = projectIdToAdditonalPayments.get(additionalPlan.Project__c);
                    projectAdditionalPlans.add(additionalPlan);
                    projectIdToAdditonalPayments.put(additionalPlan.Project__c, projectAdditionalPlans);
                } else {
                    projectIdToAdditonalPayments.put(additionalPlan.Project__c, new List<Additional_Payment__c>{additionalPlan});
                }
            }
            List<Cash_Flow_Sum__c> cashFlowSumsToInsert = new List<Cash_Flow_Sum__c>();
            List<Cash_Flow__c> cashFlowsToInsert = new List<Cash_Flow__c>();
            for(Unit__c ut : unitsToProcess){
                Set<String> years = projectToYears.get(ut.Project__c);
                for(String year : years){
                    cashFlowSumsToInsert.add(new Cash_Flow_Sum__c(
                        Unit__c = ut.Id,
                        Name = year
                    ));
                }
    
            }
            insert cashFlowSumsToInsert;
    
            Map<Id, Map<String,Id>> unitToYearToCashFlowSumMap = new Map<Id, Map<String,Id>>();
    
            for(Cash_Flow_Sum__c cashFlowSum : cashFlowSumsToInsert){
                if(unitToYearToCashFlowSumMap.containsKey(cashFlowSum.Unit__c)){
                    Map<String,Id> yearToCashFlowSum = unitToYearToCashFlowSumMap.get(cashFlowSum.Unit__c);
                    yearToCashFlowSum.put(cashFlowSum.Name, cashFlowSum.Id);
                    unitToYearToCashFlowSumMap.put(cashFlowSum.Unit__c, yearToCashFlowSum);
                } else {
                    unitToYearToCashFlowSumMap.put(cashFlowSum.Unit__c, new Map<String,Id>{cashFlowSum.Name => cashFlowSum.Id});
    
                }
    
            }
    
            for(Unit__c ut : unitsToProcess){
                for(Payment_Plan__c paymentPlan : projectIdToPaymentPlans.get(ut.Project__c)){
                    cashFlowsToInsert.add(new Cash_Flow__c(
                        Date__c = paymentPlan.Date__c,
                        Name = paymentPlan.Name,
                        Percent__c = paymentPlan.Percent__c,
                        Unit__c = ut.Id,
                        Cash_Flow_Sum__c = unitToYearToCashFlowSumMap.get(ut.Id).get(paymentPlan.Date__c.year().toString())
                    ));
                }
                if(projectIdToAdditonalPayments.containsKey(ut.Project__c)){
                    for(Additional_Payment__c additionalPlan : projectIdToAdditonalPayments.get(ut.Project__c)){
                        cashFlowsToInsert.add(new Cash_Flow__c(
                            Date__c = projectIdToPaymentPlans.get(ut.Project__c)[0].Date__c,
                            Name = additionalPlan.Name,
                            Percent__c = additionalPlan.Percent__c,
                            Constant__c = additionalPlan.Constant__c,
                            Unit__c = ut.Id,
                            Is_Additional_Payment__c = true,
                            Cash_Flow_Sum__c = unitToYearToCashFlowSumMap.get(ut.Id).get(projectIdToPaymentPlans.get(ut.Project__c)[0].Date__c.year().toString())
                        ));
                    }
                }
            }
            insert cashFlowsToInsert;
        }
    }
}