/**
 * Resets commission tracking when a Unit sale is cancelled (Status__c moves away
 * from 'Sold', e.g. back to 'Draft'/Blocked), so the unit goes through the
 * commission eligibility process again from the beginning.
 *
 * Existing Commission__c records are intentionally left untouched: they keep
 * whatever status they had at cancellation time (Paid, Eligible, ...). A blank
 * Unit Commission_Status__c is the signal that the unit is in a fresh eligibility
 * cycle, which both hides old commissions from the unit-page cards and lets the
 * nightly eligibility batch evaluate the unit again once it is resold.
 */
public class UnitCommissionResetHandler {

    /**
     * Before update: clear Commission_Status__c on units whose sale was cancelled.
     */
    public static void clearCommissionStatusOnSaleCancellation(List<Unit__c> units, Map<Id, Unit__c> oldMap) {
        for (Unit__c u : units) {
            Unit__c oldUnit = oldMap.get(u.Id);
            if (oldUnit != null && oldUnit.Status__c == 'Sold' && u.Status__c != 'Sold') {
                u.Commission_Status__c = null;
            }
        }
    }
}
