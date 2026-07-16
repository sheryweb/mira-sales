public class CommissionTriggerHandler {
    public static void handleBeforeInsertOrUpdate(List<Commission__c> commissions) {
        handleBeforeInsertOrUpdate(commissions, null);
    }

    public static void handleBeforeInsertOrUpdate(List<Commission__c> commissions, Map<Id, Commission__c> oldMap) {
        Boolean isInsert = (oldMap == null);
        for (Commission__c c : commissions) {
            Commission__c oldRecord = (!isInsert) ? oldMap.get(c.Id) : null;
            calculateCommissionAmount(c, isInsert, oldRecord);
            computeStatus(c);
        }
    }

    private static void calculateCommissionAmount(Commission__c c, Boolean isInsert, Commission__c oldRecord) {
        if (isInsert) {
            if (c.Commission_Amount__c == null && c.Base_Amount__c != null && c.Commission_Rate__c != null) {
                c.Commission_Amount__c = (c.Base_Amount__c * c.Commission_Rate__c / 100).setScale(2);
            }
            return;
        }
        if (oldRecord == null) return;
        if (c.Commission_Rate__c != oldRecord.Commission_Rate__c
            && c.Base_Amount__c != null
            && c.Commission_Rate__c != null) {
            c.Commission_Amount__c = (c.Base_Amount__c * c.Commission_Rate__c / 100).setScale(2);
        }
    }

    public static void handleAfterInsert(List<Commission__c> commissions) {
        syncUnitStatuses(commissions, null);
    }

    public static void handleAfterUpdate(List<Commission__c> commissions, Map<Id, Commission__c> oldMap) {
        syncUnitStatuses(commissions, oldMap);
    }

    private static void syncUnitStatuses(List<Commission__c> commissions, Map<Id, Commission__c> oldMap) {
        Map<Id, String> unitToNewStatus = new Map<Id, String>();
        for (Commission__c c : commissions) {
            if (c.Unit__c == null) continue;
            if (oldMap != null) {
                Commission__c old = oldMap.get(c.Id);
                if (old != null && old.Status__c == c.Status__c && old.Unit__c == c.Unit__c) continue;
            }
            String mapped = mapToUnitStatus(c.Status__c);
            if (mapped == null) continue;
            unitToNewStatus.put(c.Unit__c, mapped);
        }
        if (unitToNewStatus.isEmpty()) return;
        List<Unit__c> updates = new List<Unit__c>();
        for (Id unitId : unitToNewStatus.keySet()) {
            updates.add(new Unit__c(Id = unitId, Commission_Status__c = unitToNewStatus.get(unitId)));
        }
        update updates;
    }

    private static String mapToUnitStatus(String commissionStatus) {
        if (commissionStatus == 'Fully Paid') return 'Paid';
        if (commissionStatus == 'Partially Paid') return 'Partially Paid';
        if (commissionStatus == 'Eligible' || commissionStatus == 'Invoiced' || commissionStatus == 'On Hold') return 'Unpaid';
        return null;
    }

    private static void computeStatus(Commission__c c) {
        if (c.Manual_Override__c == 'Cancelled') {
            c.Status__c = 'Cancelled';
        } else if (c.Manual_Override__c == 'On Hold') {
            c.Status__c = 'On Hold';
        } else if (c.Paid_Amount__c != null && c.Total_Commission_Amount__c != null
                   && c.Total_Commission_Amount__c > 0 && c.Paid_Amount__c >= c.Total_Commission_Amount__c) {
            c.Status__c = 'Fully Paid';
        } else if (c.Paid_Amount__c != null && c.Paid_Amount__c > 0) {
            c.Status__c = 'Partially Paid';
        } else if (c.Invoice__c != null) {
            c.Status__c = 'Invoiced';
        } else {
            c.Status__c = 'Eligible';
        }
    }
}