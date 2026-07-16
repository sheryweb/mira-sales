public class PlanCollectorTriggerHandler {
    private static String getOrdinalSuffix(Integer inputNumber) {
        if (inputNumber >= 11 && inputNumber <= 13) {
            return 'th';
        }
        switch on Math.mod(inputNumber, 10) {
            when 1 {
                return 'st';
            }
            when 2 {
                return 'nd';
            }
            when 3 {
                return 'rd';
            }
            when else {
                return 'th';
            }
        }
    }

    public static void handlePlanCollectorAfterUpdate(List<Payment_Plans_Collector__c> planCollectors, Map<Id,Payment_Plans_Collector__c> oldPlanCollectorMap) {
        List<Payment_Plans_Collector__c> plansToProcess = new List<Payment_Plans_Collector__c>();
        for (Payment_Plans_Collector__c planCollector : planCollectors) {
            if (planCollector.Status__c == 'Published' && oldPlanCollectorMap.get(planCollector.Id).Status__c != 'Published') {
                plansToProcess.add(planCollector);
            }
        }
        
        Map<Id,Unit__c> units = new Map<Id,Unit__c>([SELECT Id, Payment_Plans_Collector__c FROM Unit__c WHERE Payment_Plans_Collector__c IN :plansToProcess AND (Status__c = 'Draft' OR Status__c = 'Published')]);
        List<Cash_Flow_Sum__c> cashFlowSums = [SELECT Id FROM Cash_Flow_Sum__c WHERE Unit__c IN :units.keyset()];
        delete cashFlowSums;
        
        List<Payment_Plan__c> paymentPlans = [SELECT Id, Project__c, Date__c, Name, Percent__c, Payment_Plans_Collector__c FROM Payment_Plan__c WHERE Payment_Plans_Collector__c IN :plansToProcess ORDER BY Date__c ASC];
        Map<Id,Set<String>> projectToYears = new Map<Id,Set<String>>();
        for(Payment_Plan__c paymentPlan : paymentPlans){
            String paymentPlanYear = paymentPlan.Date__c.year().toString();
            if(projectToYears.containsKey(paymentPlan.Payment_Plans_Collector__c)){
                Set<String> years = projectToYears.get(paymentPlan.Payment_Plans_Collector__c);
                years.add(paymentPlanYear);
                projectToYears.put(paymentPlan.Payment_Plans_Collector__c, years);
            } else {
                projectToYears.put(paymentPlan.Payment_Plans_Collector__c, new Set<String>{paymentPlanYear});
            }
        }

        Map<Id,List<Payment_Plan__c>> collectorIdToPaymentPlans = new Map<Id,List<Payment_Plan__c>>();
        for(Payment_Plan__c paymentPlan : paymentPlans){
            if(collectorIdToPaymentPlans.containsKey(paymentPlan.Payment_Plans_Collector__c)){
                List<Payment_Plan__c> collectorPaymentPlans = collectorIdToPaymentPlans.get(paymentPlan.Payment_Plans_Collector__c);
                collectorPaymentPlans.add(paymentPlan);
                collectorIdToPaymentPlans.put(paymentPlan.Payment_Plans_Collector__c, collectorPaymentPlans);
            } else {
                collectorIdToPaymentPlans.put(paymentPlan.Payment_Plans_Collector__c, new List<Payment_Plan__c>{paymentPlan});
            }
        }

        List<Cash_Flow_Sum__c> cashFlowSumsToInsert = new List<Cash_Flow_Sum__c>();
        List<Cash_Flow__c> cashFlowsToInsert = new List<Cash_Flow__c>();
        for(Id unitId : units.keyset()){
            Set<String> years = projectToYears.get(units.get(unitId).Payment_Plans_Collector__c);
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
            Id collectorId = units.get(unitId).Payment_Plans_Collector__c;
            Integer installmentCounter = 1;
            for(Payment_Plan__c paymentPlan : collectorIdToPaymentPlans.get(collectorId)){
                String installmentMilestone;
                if(paymentPlan.Name == 'Booking / Reservation') {
                    installmentMilestone = 'Booking / Reservation';
                } else if(paymentPlan.Name == 'Oqood') {
                    installmentMilestone = 'Oqood';
                } else if(paymentPlan.Name == 'DLD Fee') {
                    installmentMilestone = 'DLD Fee';
                } else {
                    installmentMilestone = installmentCounter + getOrdinalSuffix(installmentCounter) + ' Installment';
                    installmentCounter++;
                }
                
                cashFlowsToInsert.add(new Cash_Flow__c(
                    Date__c = paymentPlan.Date__c,
                    Name = paymentPlan.Name,
                    Percent__c = paymentPlan.Percent__c,
                    Unit__c = unitId,
                    Installment_Milestone__c = installmentMilestone,
                    Cash_Flow_Sum__c = unitToYearToCashFlowSumMap.get(unitId).get(paymentPlan.Date__c.year().toString())
                ));
            }
        }

        insert cashFlowsToInsert;
    }
}