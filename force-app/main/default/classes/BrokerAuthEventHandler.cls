/**
 * Handles Broker_Auth_Event__e platform events. Runs in the Automated Process (system)
 * context — NOT the site guest — so it can write the auth-tracking fields on Broker_User__c
 * that the guest is only allowed to read. This is what makes the portal's rate limiting and
 * session revocation SERVER-SIDE state an attacker can't strip (unlike cookies).
 *
 * Actions:
 *   OTP_SENT -> stamp Last_OTP_Sent__c (resend cooldown), reset OTP_Attempts__c
 *   OTP_FAIL -> increment OTP_Attempts__c (login blocked at the cap until a new code)
 *   OTP_OK   -> reset OTP_Attempts__c, stamp Last_Login__c
 *   LOGOUT   -> increment Session_Epoch__c (invalidates ALL of the broker's session tokens)
 */
public without sharing class BrokerAuthEventHandler {

    public static final String ACTION_OTP_SENT = 'OTP_SENT';
    public static final String ACTION_OTP_FAIL = 'OTP_FAIL';
    public static final String ACTION_OTP_OK   = 'OTP_OK';
    public static final String ACTION_LOGOUT   = 'LOGOUT';

    public static void handle(List<Broker_Auth_Event__e> events) {
        Set<Id> ids = new Set<Id>();
        for (Broker_Auth_Event__e e : events) {
            if (String.isNotBlank(e.Broker_User_Id__c)) {
                try { ids.add(Id.valueOf(e.Broker_User_Id__c)); } catch (Exception ignored) {}
            }
        }
        if (ids.isEmpty()) return;

        Map<Id, Broker_User__c> users = new Map<Id, Broker_User__c>([
            SELECT Id, OTP_Attempts__c, Session_Epoch__c FROM Broker_User__c WHERE Id IN :ids
        ]);
        if (users.isEmpty()) return;

        Set<Id> touched = new Set<Id>();
        for (Broker_Auth_Event__e e : events) {
            Broker_User__c u;
            try { u = users.get(Id.valueOf(e.Broker_User_Id__c)); } catch (Exception ignored) { continue; }
            if (u == null) continue;

            if (e.Action__c == ACTION_OTP_SENT) {
                u.Last_OTP_Sent__c = System.now();
                u.OTP_Attempts__c = 0;
            } else if (e.Action__c == ACTION_OTP_FAIL) {
                u.OTP_Attempts__c = nvl(u.OTP_Attempts__c) + 1;
            } else if (e.Action__c == ACTION_OTP_OK) {
                u.OTP_Attempts__c = 0;
                u.Last_Login__c = System.now();
            } else if (e.Action__c == ACTION_LOGOUT) {
                u.Session_Epoch__c = nvl(u.Session_Epoch__c) + 1;
            } else {
                continue;
            }
            touched.add(u.Id);
        }
        if (touched.isEmpty()) return;

        List<Broker_User__c> toUpdate = new List<Broker_User__c>();
        for (Id i : touched) toUpdate.add(users.get(i));
        // Partial success on purpose: one bad row must never suspend the event subscription.
        Database.update(toUpdate, false);
    }

    private static Decimal nvl(Decimal d) { return d == null ? 0 : d; }
}