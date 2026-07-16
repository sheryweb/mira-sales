public with sharing class OpportunityMonthlyActivityController {
    
    @AuraEnabled(cacheable=true)
    public static List<MonthlyActivityData> getMonthlyActivityData(Integer year) {
        try {
            if (year == null) {
                year = Date.today().year();
            }
            
            // Step 1: Define date range for this year
            Date startDate = Date.newInstance(year, 1, 1);
            Date endDate = Date.newInstance(year, 12, 31);
            
            
            // Step 4: Query Booked Activities to get totals and per month grouping
            Map<Integer, Decimal> bookedValues = new Map<Integer, Decimal>();
            Map<Integer, Integer> bookedCounts = new Map<Integer, Integer>();
            
            AggregateResult[] bookedAggs = [
                SELECT CALENDAR_MONTH(Activity_Date__c) month,
                       SUM(Opportunity__r.Unit__r.Cost_AED__c) totalUnitPrice,
                       COUNT(Opportunity__r.Id) totalOpps
                FROM Opportunity_Monthly_Activity__c
                WHERE Activity_Type__c = 'Booked'
                  AND Activity_Date__c >= :startDate
                  AND Activity_Date__c <= :endDate
                  AND Opportunity__c != null
                  AND Opportunity__r.StageName != 'Cancelled'
                  AND Opportunity__r.StageName != 'New'
                  AND Opportunity__r.Is_it_a_Resell__c = false
                GROUP BY CALENDAR_MONTH(Activity_Date__c)
                ORDER BY CALENDAR_MONTH(Activity_Date__c)
            ];
            
            System.debug('===== Booked Activities Totals by Month =====');
            for (AggregateResult ar : bookedAggs) {
                Integer monthNum = (Integer) ar.get('month');
                Decimal monthTotal = (Decimal) ar.get('totalUnitPrice');
                Integer countOpps = (Integer) ar.get('totalOpps');
                
                bookedValues.put(monthNum, monthTotal != null ? monthTotal : 0);
                bookedCounts.put(monthNum, countOpps != null ? countOpps : 0);
                
                System.debug('Month: ' + monthNum + ' | Total Unit__r.Cost_AED__c: ' + monthTotal + ' | Opportunities: ' + countOpps);
            }
            
            // Step 5: Query Sold Activities to get totals and per month grouping
            Map<Integer, Decimal> soldValues = new Map<Integer, Decimal>();
            Map<Integer, Integer> soldCounts = new Map<Integer, Integer>();
            
            AggregateResult[] soldAggs = [
                SELECT CALENDAR_MONTH(Activity_Date__c) month,
                       SUM(Opportunity__r.Unit__r.Cost_AED__c) totalUnitPrice,
                       COUNT(Opportunity__r.Id) totalOpps
                FROM Opportunity_Monthly_Activity__c
                WHERE Activity_Type__c = 'Sold'
                  AND Activity_Date__c >= :startDate
                  AND Activity_Date__c <= :endDate
                  AND Opportunity__c != null
                  AND Opportunity__r.StageName != 'Cancelled'
                  AND Opportunity__r.StageName != 'New'
                  AND Opportunity__r.Is_it_a_Resell__c = false
                GROUP BY CALENDAR_MONTH(Activity_Date__c)
                ORDER BY CALENDAR_MONTH(Activity_Date__c)
            ];
            
            System.debug('===== Sold Activities Totals by Month =====');
            for (AggregateResult ar : soldAggs) {
                Integer monthNum = (Integer) ar.get('month');
                Decimal monthTotal = (Decimal) ar.get('totalUnitPrice');
                Integer countOpps = (Integer) ar.get('totalOpps');
                
                soldValues.put(monthNum, monthTotal != null ? monthTotal : 0);
                soldCounts.put(monthNum, countOpps != null ? countOpps : 0);
                
                System.debug('Month: ' + monthNum + ' | Total Unit__r.Cost_AED__c: ' + monthTotal + ' | Opportunities: ' + countOpps);
            }
            
            // Step 5a: Query Sold Activities that were also Booked in the same year (for In Progress calculation)
            Map<Integer, Decimal> soldInCurrentYearValues = new Map<Integer, Decimal>();
            Map<Integer, Integer> soldInCurrentYearCounts = new Map<Integer, Integer>();
            
            // Get all opportunities that were booked in the current year
            Set<Id> bookedOppIds = new Set<Id>();
            for (Opportunity_Monthly_Activity__c bookedActivity : [
                SELECT Opportunity__c
                FROM Opportunity_Monthly_Activity__c
                WHERE Activity_Type__c = 'Booked'
                  AND Activity_Date__c >= :startDate
                  AND Activity_Date__c <= :endDate
                  AND Opportunity__c != null
                  AND Opportunity__r.StageName != 'Cancelled'
                  AND Opportunity__r.StageName != 'New'
                  AND Opportunity__r.Is_it_a_Resell__c = false
            ]) {
                bookedOppIds.add(bookedActivity.Opportunity__c);
            }
            
            // Now get sold activities for those same opportunities in the current year
            if (!bookedOppIds.isEmpty()) {
                AggregateResult[] soldInCurrentYearAggs = [
                    SELECT CALENDAR_MONTH(Activity_Date__c) month,
                           SUM(Opportunity__r.Unit__r.Cost_AED__c) totalUnitPrice,
                           COUNT(Opportunity__r.Id) totalOpps
                    FROM Opportunity_Monthly_Activity__c
                    WHERE Activity_Type__c = 'Sold'
                      AND Activity_Date__c >= :startDate
                      AND Activity_Date__c <= :endDate
                      AND Opportunity__c IN :bookedOppIds
                      AND Opportunity__r.StageName != 'Cancelled'
                      AND Opportunity__r.StageName != 'New'
                      AND Opportunity__r.Is_it_a_Resell__c = false
                    GROUP BY CALENDAR_MONTH(Activity_Date__c)
                    ORDER BY CALENDAR_MONTH(Activity_Date__c)
                ];
                
                System.debug('===== Sold Activities (Booked in Current Year) Totals by Month =====');
                for (AggregateResult ar : soldInCurrentYearAggs) {
                    Integer monthNum = (Integer) ar.get('month');
                    Decimal monthTotal = (Decimal) ar.get('totalUnitPrice');
                    Integer countOpps = (Integer) ar.get('totalOpps');
                    
                    soldInCurrentYearValues.put(monthNum, monthTotal != null ? monthTotal : 0);
                    soldInCurrentYearCounts.put(monthNum, countOpps != null ? countOpps : 0);
                    
                    System.debug('Month: ' + monthNum + ' | Total Unit__r.Cost_AED__c: ' + monthTotal + ' | Opportunities: ' + countOpps);
                }
            }
            
            // Step 6: Initialize data structure for all 12 months
            Map<Integer, MonthlyActivityData> monthlyDataMap = new Map<Integer, MonthlyActivityData>();
            for (Integer i = 1; i <= 12; i++) {
                monthlyDataMap.put(i, new MonthlyActivityData(i, year));
            }
            
            // Step 7: Populate monthly data with Opportunity values
            for (Integer month = 1; month <= 12; month++) {
                MonthlyActivityData monthData = monthlyDataMap.get(month);
                if (monthData != null) {
                    monthData.bookedValue = bookedValues.get(month) != null ? bookedValues.get(month) : 0;
                    monthData.bookedCount = bookedCounts.get(month) != null ? bookedCounts.get(month) : 0;
                    monthData.soldValue = soldValues.get(month) != null ? soldValues.get(month) : 0;
                    monthData.soldCount = soldCounts.get(month) != null ? soldCounts.get(month) : 0;
                    monthData.soldInCurrentYearValue = soldInCurrentYearValues.get(month) != null ? soldInCurrentYearValues.get(month) : 0;
                    monthData.soldInCurrentYearCount = soldInCurrentYearCounts.get(month) != null ? soldInCurrentYearCounts.get(month) : 0;
                }
            }
            
            // Step 8: Calculate totals for each month
            for (MonthlyActivityData monthData : monthlyDataMap.values()) {
                monthData.calculateTotals();
            }
            
            // Step 9: Debug final results
            System.debug('=== FINAL RESULTS ===');
            for (MonthlyActivityData monthData : monthlyDataMap.values()) {
                if (monthData.bookedCount > 0 || monthData.soldCount > 0) {
                    System.debug('Month ' + monthData.month + ' (' + monthData.monthName + '): Booked=' + monthData.bookedCount + '/' + monthData.bookedValue + ', Sold=' + monthData.soldCount + '/' + monthData.soldValue + ', Total=' + monthData.totalCount + '/' + monthData.totalValue);
                }
            }
            System.debug('=== END FINAL RESULTS ===');
            
            return monthlyDataMap.values();
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving monthly activity data: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Integer> getAvailableYears() {
        try {
            List<AggregateResult> results = [
                SELECT CALENDAR_YEAR(Activity_Date__c) year
                FROM Opportunity_Monthly_Activity__c
                GROUP BY CALENDAR_YEAR(Activity_Date__c)
                ORDER BY CALENDAR_YEAR(Activity_Date__c) DESC
            ];
            
            List<Integer> years = new List<Integer>();
            for (AggregateResult result : results) {
                years.add((Integer) result.get('year'));
            }
            
            // If no data exists, return current year
            if (years.isEmpty()) {
                years.add(Date.today().year());
            }
            
            return years;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving available years: ' + e.getMessage());
        }
    }
    
    public class MonthlyActivityData {
        @AuraEnabled public Integer month { get; set; }
        @AuraEnabled public Integer year { get; set; }
        @AuraEnabled public String monthName { get; set; }
        @AuraEnabled public Integer bookedCount { get; set; }
        @AuraEnabled public Decimal bookedValue { get; set; }
        @AuraEnabled public Integer soldCount { get; set; }
        @AuraEnabled public Decimal soldValue { get; set; }
        @AuraEnabled public Integer soldInCurrentYearCount { get; set; }
        @AuraEnabled public Decimal soldInCurrentYearValue { get; set; }
        @AuraEnabled public Integer totalCount { get; set; }
        @AuraEnabled public Decimal totalValue { get; set; }
        
        public MonthlyActivityData(Integer month, Integer year) {
            this.month = month;
            this.year = year;
            this.monthName = getMonthName(month);
            this.bookedCount = 0;
            this.bookedValue = 0;
            this.soldCount = 0;
            this.soldValue = 0;
            this.soldInCurrentYearCount = 0;
            this.soldInCurrentYearValue = 0;
            this.totalCount = 0;
            this.totalValue = 0;
        }
        
        public void calculateTotals() {
            this.totalCount = this.bookedCount + this.soldCount;
            this.totalValue = this.bookedValue + this.soldValue;
        }
        
        private String getMonthName(Integer month) {
            Map<Integer, String> monthNames = new Map<Integer, String>{
                1 => 'Jan', 2 => 'Feb', 3 => 'Mar', 4 => 'Apr',
                5 => 'May', 6 => 'Jun', 7 => 'Jul', 8 => 'Aug',
                9 => 'Sep', 10 => 'Oct', 11 => 'Nov', 12 => 'Dec'
            };
            return monthNames.get(month);
        }
    }
}