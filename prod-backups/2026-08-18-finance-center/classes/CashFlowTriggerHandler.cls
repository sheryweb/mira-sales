public without sharing class CashFlowTriggerHandler {
    public static void handleCashFlowsAfterInsert(Set<Id> cashFlowIds) {
        CashFlowPriceQueueable queueJob = new CashFlowPriceQueueable(cashFlowIds);
        System.enqueueJob(queueJob); 
    }

    public static void handleCashFlowsAfterUpdate(Map<Id,Cash_Flow__c> newMap, Map<Id,Cash_Flow__c> oldMap) {
        Set<Id> cashFlowIds = new Set<Id>();
        for (Id cfId : newMap.keySet()) {
            if ((newMap.get(cfId).Percent__c != oldMap.get(cfId).Percent__c) || (newMap.get(cfId).Constant__c != oldMap.get(cfId).Constant__c)){
                cashFlowIds.add(cfId);
            }
        }
        if (!cashFlowIds.isEmpty()) {
            CashFlowPriceQueueable queueJob = new CashFlowPriceQueueable(cashFlowIds);
            System.enqueueJob(queueJob); 
        }
    }
    
    private static final Set<String> ELIGIBLE_UNIT_STATUSES = new Set<String>{
        'Draft',
        'Published',
        'Booked'
    };

    // Static variable to prevent recursion
    private static Boolean isTriggerExecuted = false;

    public static void updateInstallmentMilestoneOnDateChange(
        Map<Id, Cash_Flow__c> newMap,
        Map<Id, Cash_Flow__c> oldMap
    ) {
        List<Cash_Flow__c> dateChangedRecords = new List<Cash_Flow__c>();
        for (Cash_Flow__c newRecord : newMap.values()) {
            Cash_Flow__c oldRecord = oldMap.get(newRecord.Id);
            if (oldRecord != null && newRecord.Date__c != oldRecord.Date__c) {
                dateChangedRecords.add(newRecord);
            }
        }
        if (!dateChangedRecords.isEmpty()) {
            updateInstallmentMilestone(dateChangedRecords);
        }
    }
    
    public static void updateInstallmentMilestone(List<Cash_Flow__c> triggerRecords) {
        if (isTriggerExecuted) return;
        isTriggerExecuted = true;

        try {
            // Collect Unit Ids from trigger records
            Set<Id> unitIds = new Set<Id>();
            for (Cash_Flow__c cf : triggerRecords) {
                if (cf.Unit__c != null) {
                    unitIds.add(cf.Unit__c);
                }
            }

            // Query Units to check their Status
            Map<Id, Unit__c> unitsMap = new Map<Id, Unit__c>([
                SELECT Id, Status__c 
                FROM Unit__c 
                WHERE Id IN :unitIds
            ]);

            Set<Id> eligibleUnitIds = new Set<Id>();
            for (Unit__c unit : unitsMap.values()) {
                if (ELIGIBLE_UNIT_STATUSES.contains(unit.Status__c)) {
                    eligibleUnitIds.add(unit.Id);
                }
            }

            // If no eligible units, return early
            if (eligibleUnitIds.isEmpty()) {
                return;
            }

            // Query ALL cash flows for the eligible units to reorder them
            List<Cash_Flow__c> allCashFlows = [SELECT Id, Unit__c, Name, Date__c, Installment_Milestone__c 
                                              FROM Cash_Flow__c 
                                              WHERE Unit__c IN :eligibleUnitIds];

            // Group by Unit
            Map<Id, List<Cash_Flow__c>> unitToCashFlows = new Map<Id, List<Cash_Flow__c>>();
            for (Cash_Flow__c cf : allCashFlows) {
                if (!unitToCashFlows.containsKey(cf.Unit__c)) {
                    unitToCashFlows.put(cf.Unit__c, new List<Cash_Flow__c>());
                }
                unitToCashFlows.get(cf.Unit__c).add(cf);
            }

            List<Cash_Flow__c> cashFlowsToUpdate = new List<Cash_Flow__c>();
            for (List<Cash_Flow__c> cashFlows : unitToCashFlows.values()) {
                Map<Id, String> priorMilestones = new Map<Id, String>();
                for (Cash_Flow__c cashFlow : cashFlows) {
                    priorMilestones.put(cashFlow.Id, cashFlow.Installment_Milestone__c);
                }

                processInstallmentMilestones(cashFlows);

                for (Cash_Flow__c cashFlow : cashFlows) {
                    if (cashFlow.Installment_Milestone__c != priorMilestones.get(cashFlow.Id)) {
                        cashFlowsToUpdate.add(cashFlow);
                    }
                }
            }

            // Update all affected records
            if (!cashFlowsToUpdate.isEmpty()) {
                update cashFlowsToUpdate;
            }
        } finally {
            isTriggerExecuted = false;
        }
    }

    private static void processInstallmentMilestones(List<Cash_Flow__c> cashFlows) {
        // Sort cash flows by date
        List<CashFlowWrapper> wrappers = new List<CashFlowWrapper>();
        for (Cash_Flow__c cf : cashFlows) {
            wrappers.add(new CashFlowWrapper(cf));
        }
        wrappers.sort();

        Integer installmentCount = 2;
        
        for (CashFlowWrapper wrapper : wrappers) {
            Cash_Flow__c cf = wrapper.cashFlow;
            // Handle special cases first
            if (cf.Name != null) {
                String normalizedName = cf.Name.toLowerCase().trim();
                
                if (normalizedName.contains('booking') && normalizedName.contains('reservation')) {
                    cf.Installment_Milestone__c = 'Booking / Reservation';
                    continue;
                }
                if (normalizedName.contains('oqood')) {
                    cf.Installment_Milestone__c = 'Oqood';
                    continue;
                }
                if (normalizedName.contains('dld fee')) {
                    cf.Installment_Milestone__c = 'DLD Fee';
                    continue;
                }
            }
            
            // For regular installments
            String suffix = getOrdinalSuffix(installmentCount);
            cf.Installment_Milestone__c = installmentCount + suffix + ' Installment';
            installmentCount++;
        }
    }

    // Helper method to get the ordinal suffix (st, nd, rd, th) for the number
    private static String getOrdinalSuffix(Integer num) {
        if (num >= 11 && num <= 13) return 'th';
        
        Integer lastDigit = Math.mod(num, 10);
        switch on lastDigit {
            when 1 { return 'st'; }
            when 2 { return 'nd'; }
            when 3 { return 'rd'; }
            when else { return 'th'; }
        }
    }

    // Wrapper class to handle sorting of Cash Flow records by Date
    private class CashFlowWrapper implements Comparable {
        public Cash_Flow__c cashFlow;

        public CashFlowWrapper(Cash_Flow__c cf) {
            this.cashFlow = cf;
        }

        public Integer compareTo(Object compareTo) {
            CashFlowWrapper compareToWrapper = (CashFlowWrapper)compareTo;
            
            if (this.cashFlow.Date__c == null && compareToWrapper.cashFlow.Date__c == null) {
                return 0;
            }
            if (this.cashFlow.Date__c == null) {
                return 1;
            }
            if (compareToWrapper.cashFlow.Date__c == null) {
                return -1;
            }
            
            if (this.cashFlow.Date__c > compareToWrapper.cashFlow.Date__c) {
                return 1;
            } else if (this.cashFlow.Date__c < compareToWrapper.cashFlow.Date__c) {
                return -1;
            }
            return 0;
        }
    }
}