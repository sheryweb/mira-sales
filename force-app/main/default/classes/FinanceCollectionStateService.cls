/**
 * FinanceCollectionStateService — derives and stamps per-unit collection state onto Unit__c:
 * the Due / Not-Yet-Due split, overdue age, missed-instalment count, and Collection_Health__c.
 *
 * READ-ONLY over the FinancialEngine's outputs: it consumes Cash_Flow__c.Remaining_Amount__c
 * (Price_Formula + VAT − engine-owned Received_Amount) and writes ONLY the Finance Center
 * fields it owns: Unit__c.Due_Amount__c, Not_Yet_Due_Amount__c, Overdue_Days_Max__c,
 * Missed_Instalments__c, Collection_Health__c, Collection_State_As_Of__c. It never touches
 * an engine-owned or DLRS-managed field.
 *
 * Freshness model (two layers — see the Finance Center plan):
 *  - Intraday: FinancialEngineTriggerHandler and CashFlowTriggerHandler call enqueueStamp()
 *    for the affected units after every finance transaction / payment-plan edit, so the
 *    stamped state follows a receipt within seconds (Queueable; falls back to synchronous
 *    when the context can't take another queueable).
 *  - Nightly: FinanceCollectionStateBatch full sweep handles what only time changes
 *    (instalments crossing their due date at midnight) and self-heals anything missed.
 *
 * "Due" mirrors the SOA exactly (SOAPDFController "Current Amounts Due Summary"): the unpaid
 * Remaining_Amount__c of every cash flow with Date__c <= TODAY, both money pools (instalments
 * AND registration). Missed_Instalments__c / Overdue_Days_Max__c count INSTALMENT items only
 * (registration Oqood / DLD Fee / Registration Fee excluded) because they feed the
 * defaulted/termination view. Amounts are in the unit's project currency, like every other
 * Unit__c money field; AED conversion happens where portfolio numbers are aggregated.
 */
public without sharing class FinanceCollectionStateService {

    /** Same tolerance the engine uses, so a rounding leftover never reads as "due". */
    @TestVisible static final Decimal TOLERANCE = 0.005;

    /** Defaulted = overdue at least this long AND more than this many missed instalments. */
    @TestVisible static final Integer DEFAULT_DAYS_OVERDUE = 90;
    @TestVisible static final Integer DEFAULT_MISSED_INSTALMENTS = 2;

    public static final String HEALTH_FULLY_PAID = 'Fully Paid';
    public static final String HEALTH_ON_TRACK   = 'On Track';
    public static final String HEALTH_OVERDUE    = 'Overdue';
    public static final String HEALTH_DEFAULTED  = 'Defaulted';

    /** Derived collection state for one unit. Amounts in the unit's project currency. */
    public class UnitState {
        public Decimal dueAmount = 0;
        public Decimal notYetDueAmount = 0;
        public Integer overdueDaysMax = 0;
        public Integer missedInstalments = 0;
        public String  health;                     // null when the unit has no priced plan
        public Boolean hasPricedPlan = false;
        public Decimal dueNotInvoicedAmount = 0;   // due remaining on Is_Invoiced__c = false rows
        public Integer negativeRemainingCount = 0; // data quality: over-allocated cash flows
        public Decimal plannedTotal = 0;           // Σ Price_Formula of non-registration rows
        /** Unpaid remaining by calendar month (YYYY-MM), current month forward — feeds the forecast. */
        public Map<String, Decimal> futureByMonth = new Map<String, Decimal>();
    }

    /** Pure derivation — one Cash_Flow__c query, no DML. */
    public static Map<Id, UnitState> deriveForUnits(Set<Id> unitIds) {
        Map<Id, UnitState> states = new Map<Id, UnitState>();
        if (unitIds == null || unitIds.isEmpty()) return states;
        for (Id uId : unitIds) {
            if (uId != null) states.put(uId, new UnitState());
        }
        Date today = Date.today();
        Date monthStart = today.toStartOfMonth();

        for (Cash_Flow__c cf : [
            SELECT Unit__c, Date__c, Price_Formula__c, Remaining_Amount__c,
                   Payment_Plan_Name__c, Is_Invoiced__c
            FROM Cash_Flow__c
            WHERE Unit__c IN :states.keySet()
        ]) {
            UnitState st = states.get(cf.Unit__c);
            Boolean isReg = isRegistrationCashFlow(cf.Payment_Plan_Name__c);
            Decimal price = nz(cf.Price_Formula__c);
            Decimal remaining = nz(cf.Remaining_Amount__c);

            if (price > 0) st.hasPricedPlan = true;
            if (!isReg) st.plannedTotal += price;
            if (remaining < -TOLERANCE) st.negativeRemainingCount++;
            if (remaining <= TOLERANCE) continue; // paid (or over-paid) — nothing outstanding

            if (cf.Date__c != null && cf.Date__c <= today) {
                st.dueAmount += remaining;
                if (cf.Is_Invoiced__c == false) st.dueNotInvoicedAmount += remaining;
                if (!isReg) {
                    st.missedInstalments++;
                    Integer daysOver = cf.Date__c.daysBetween(today);
                    if (daysOver > st.overdueDaysMax) st.overdueDaysMax = daysOver;
                }
            } else {
                // A null date sorts last in the engine's chronology → treat as not yet due.
                st.notYetDueAmount += remaining;
            }

            // Forecast: months from the start of the current month forward (a row already due
            // inside the current month still counts as expected in this month).
            if (cf.Date__c != null && cf.Date__c >= monthStart) {
                String k = monthKey(cf.Date__c);
                Decimal cur = st.futureByMonth.get(k);
                st.futureByMonth.put(k, (cur == null ? 0 : cur) + remaining);
            }
        }

        for (UnitState st : states.values()) {
            st.health = healthFor(st);
        }
        return states;
    }

    /** Derive + write the stamped fields for the given units (only rows whose values changed). */
    public static void stampUnits(Set<Id> unitIds) {
        stampDerived(deriveForUnits(unitIds));
    }

    /** Write side for callers (the nightly batch) that already derived the states. */
    public static void stampDerived(Map<Id, UnitState> states) {
        if (states == null || states.isEmpty()) return;
        List<Unit__c> updates = new List<Unit__c>();
        for (Unit__c u : [
            SELECT Id, Due_Amount__c, Not_Yet_Due_Amount__c, Overdue_Days_Max__c,
                   Missed_Instalments__c, Collection_Health__c
            FROM Unit__c
            WHERE Id IN :states.keySet()
        ]) {
            UnitState st = states.get(u.Id);
            if (eq(u.Due_Amount__c, st.dueAmount)
                && eq(u.Not_Yet_Due_Amount__c, st.notYetDueAmount)
                && nzi(u.Overdue_Days_Max__c) == st.overdueDaysMax
                && nzi(u.Missed_Instalments__c) == st.missedInstalments
                && u.Collection_Health__c == st.health) {
                continue;
            }
            updates.add(new Unit__c(
                Id = u.Id,
                Due_Amount__c = st.dueAmount,
                Not_Yet_Due_Amount__c = st.notYetDueAmount,
                Overdue_Days_Max__c = st.overdueDaysMax,
                Missed_Instalments__c = st.missedInstalments,
                Collection_Health__c = st.health,
                Collection_State_As_Of__c = System.now()
            ));
        }
        if (!updates.isEmpty()) update updates;
    }

    // ---- intraday enqueue ------------------------------------------------------

    /** Units already queued (or stamped) this transaction, so repeated trigger events don't
     *  spawn duplicate jobs for the same unit. */
    @TestVisible static Set<Id> stampedThisTransaction = new Set<Id>();

    /**
     * Queue a re-stamp for the given units. Prefers a Queueable so the user's save is never
     * slowed; falls back to a synchronous stamp when the context can't take another queueable
     * (already inside a chained queueable, queue full). Safe to call repeatedly in one
     * transaction — each unit is processed once.
     */
    public static void enqueueStamp(Set<Id> unitIds) {
        if (unitIds == null || unitIds.isEmpty()) return;
        Set<Id> fresh = new Set<Id>();
        for (Id uId : unitIds) {
            if (uId != null && !stampedThisTransaction.contains(uId)) fresh.add(uId);
        }
        if (fresh.isEmpty()) return;
        stampedThisTransaction.addAll(fresh);

        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            try {
                System.enqueueJob(new StampJob(fresh));
                return;
            } catch (Exception e) {
                // fall through to the synchronous stamp
            }
        }
        stampUnits(fresh);
    }

    public class StampJob implements Queueable {
        private Set<Id> unitIds;
        public StampJob(Set<Id> unitIds) { this.unitIds = unitIds; }
        public void execute(QueueableContext ctx) {
            stampUnits(unitIds);
        }
    }

    // ---- rules & helpers -------------------------------------------------------

    /**
     * Registration-pool rule — mirrors FinancialEngine.isRegistrationCashFlow (Oqood / DLD Fee)
     * plus the SOA's '%Registration Fee%' exclusion, so instalment counts reconcile 1:1 with
     * the SOA's instalment tables.
     */
    @TestVisible
    static Boolean isRegistrationCashFlow(String paymentPlanName) {
        if (String.isBlank(paymentPlanName)) return false;
        return paymentPlanName.contains('Oqood')
            || paymentPlanName.contains('DLD Fee')
            || paymentPlanName.contains('Registration Fee');
    }

    private static String healthFor(UnitState st) {
        if (!st.hasPricedPlan) return null;
        if (st.dueAmount <= TOLERANCE && st.notYetDueAmount <= TOLERANCE) return HEALTH_FULLY_PAID;
        if (st.overdueDaysMax >= DEFAULT_DAYS_OVERDUE
            && st.missedInstalments > DEFAULT_MISSED_INSTALMENTS) return HEALTH_DEFAULTED;
        if (st.dueAmount > TOLERANCE) return HEALTH_OVERDUE;
        return HEALTH_ON_TRACK;
    }

    /** YYYY-MM, zero-padded — string-sortable chronologically (Executive dashboard convention). */
    public static String monthKey(Date d) {
        return d.year() + '-' + (d.month() < 10 ? '0' : '') + d.month();
    }

    private static Boolean eq(Decimal a, Decimal b) {
        return Math.abs(nz(a) - nz(b)) <= TOLERANCE;
    }

    private static Decimal nz(Decimal d) { return d == null ? 0 : d; }

    private static Integer nzi(Decimal d) { return d == null ? 0 : d.intValue(); }
}
