public class ProjectTriggerHandler {
    
    public static void handleProjecsAfterUpdate(List<Project__c> projects, Map<Id,Project__c> oldProjectsMap) {
        List<Project__c> projectsToProcess = new List<Project__c>();
        for (Project__c project : projects) {
            if (project.Publish_Project__c == 'Published' && oldProjectsMap.get(project.Id).Publish_Project__c != 'Published' && project.Old_Project__c <> false) {
                projectsToProcess.add(project);
            }
        }
        if (!projectsToProcess.isEmpty()) {
            Map<Id,Unit__c> units = new Map<Id,Unit__c>([SELECT Id, Project__c FROM Unit__c WHERE Project__c IN :projectsToProcess AND (Status__c = 'Draft' OR Status__c = 'Published')]);
            List<Cash_Flow_Sum__c> cashFlowSums = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c IN :units.keyset()];
            delete cashFlowSums;
            List<Payment_Plan__c> paymentPlans = [SELECT Id, Project__c, Date__c, Name, Percent__c FROM Payment_Plan__c WHERE Project__c IN :projectsToProcess ORDER BY Date__c ASC];
            List<Additional_Payment__c> additionalPlans = [SELECT Id, Project__c, Name, Percent__c, Constant__c FROM Additional_Payment__c WHERE Project__c IN :projectsToProcess];
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
            for(Id unitId : units.keyset()){
                Set<String> years = projectToYears.get(units.get(unitId).Project__c);
                for(String year : years){
                    cashFlowSumsToInsert.add(new Cash_Flow_Sum__c(
                        Unit__c = unitId,
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
    
            for(Id unitId : units.keyset()){
                for(Payment_Plan__c paymentPlan : projectIdToPaymentPlans.get(units.get(unitId).Project__c)){
                    cashFlowsToInsert.add(new Cash_Flow__c(
                        Date__c = paymentPlan.Date__c,
                        Name = paymentPlan.Name,
                        Percent__c = paymentPlan.Percent__c,
                        Unit__c = unitId,
                        Cash_Flow_Sum__c = unitToYearToCashFlowSumMap.get(unitId).get(paymentPlan.Date__c.year().toString())
                    ));
                }
                if(projectIdToAdditonalPayments.containsKey(units.get(unitId).Project__c)){
                    for(Additional_Payment__c additionalPlan : projectIdToAdditonalPayments.get(units.get(unitId).Project__c)){
                        cashFlowsToInsert.add(new Cash_Flow__c(
                            Date__c = projectIdToPaymentPlans.get(units.get(unitId).Project__c)[0].Date__c,
                            Name = additionalPlan.Name,
                            Percent__c = additionalPlan.Percent__c,
                            Constant__c = additionalPlan.Constant__c,
                            Unit__c = unitId,
                            Is_Additional_Payment__c = true,
                            Cash_Flow_Sum__c = unitToYearToCashFlowSumMap.get(unitId).get(projectIdToPaymentPlans.get(units.get(unitId).Project__c)[0].Date__c.year().toString())
                        ));
                    }
                }
            }
            insert cashFlowsToInsert;
        }
    }
}