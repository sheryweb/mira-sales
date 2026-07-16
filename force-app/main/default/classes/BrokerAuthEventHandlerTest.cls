@isTest
private class BrokerAuthEventHandlerTest {

    private static Broker_User__c makeBroker() {
        String uniq = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Account acc = new Account(Name = 'Auth Agency ' + uniq, Skip_Trigger__c = true);
        insert acc;
        Broker_User__c bu = new Broker_User__c(
            Account__c = acc.Id, Email__c = 'auth' + uniq + '@example.com', Active__c = true);
        insert bu;
        return bu;
    }

    private static Broker_Auth_Event__e evt(Id buId, String action) {
        return new Broker_Auth_Event__e(Broker_User_Id__c = buId, Action__c = action);
    }

    @isTest
    static void otpSent_stampsCooldownAndResetsAttempts() {
        Broker_User__c bu = makeBroker();
        bu.OTP_Attempts__c = 7;
        update bu;

        BrokerAuthEventHandler.handle(new List<Broker_Auth_Event__e>{
            evt(bu.Id, BrokerAuthEventHandler.ACTION_OTP_SENT) });

        Broker_User__c after = [SELECT Last_OTP_Sent__c, OTP_Attempts__c FROM Broker_User__c WHERE Id = :bu.Id];
        System.assertNotEquals(null, after.Last_OTP_Sent__c, 'Cooldown timestamp set');
        System.assertEquals(0, after.OTP_Attempts__c, 'New code resets the attempt counter');
    }

    @isTest
    static void otpFail_increments_otpOk_resetsAndStampsLogin() {
        Broker_User__c bu = makeBroker();

        BrokerAuthEventHandler.handle(new List<Broker_Auth_Event__e>{
            evt(bu.Id, BrokerAuthEventHandler.ACTION_OTP_FAIL),
            evt(bu.Id, BrokerAuthEventHandler.ACTION_OTP_FAIL) });
        Broker_User__c after = [SELECT OTP_Attempts__c FROM Broker_User__c WHERE Id = :bu.Id];
        System.assertEquals(2, after.OTP_Attempts__c, 'Each failure counted');

        BrokerAuthEventHandler.handle(new List<Broker_Auth_Event__e>{
            evt(bu.Id, BrokerAuthEventHandler.ACTION_OTP_OK) });
        after = [SELECT OTP_Attempts__c, Last_Login__c FROM Broker_User__c WHERE Id = :bu.Id];
        System.assertEquals(0, after.OTP_Attempts__c, 'Success resets the counter');
        System.assertNotEquals(null, after.Last_Login__c, 'Successful login stamped');
    }

    @isTest
    static void logout_bumpsSessionEpoch() {
        Broker_User__c bu = makeBroker();

        BrokerAuthEventHandler.handle(new List<Broker_Auth_Event__e>{
            evt(bu.Id, BrokerAuthEventHandler.ACTION_LOGOUT) });

        Broker_User__c after = [SELECT Session_Epoch__c FROM Broker_User__c WHERE Id = :bu.Id];
        System.assertEquals(1, after.Session_Epoch__c, 'Epoch bumped, all session tokens invalid');
    }

    @isTest
    static void badIds_andUnknownActions_areIgnored() {
        Broker_User__c bu = makeBroker();
        BrokerAuthEventHandler.handle(new List<Broker_Auth_Event__e>{
            new Broker_Auth_Event__e(Broker_User_Id__c = 'not-an-id', Action__c = 'OTP_FAIL'),
            evt(bu.Id, 'SOMETHING_ELSE') });

        Broker_User__c after = [SELECT OTP_Attempts__c, Session_Epoch__c FROM Broker_User__c WHERE Id = :bu.Id];
        System.assert(after.OTP_Attempts__c == null || after.OTP_Attempts__c == 0, 'Unknown action changed nothing');
    }

    // Publish for real so the trigger itself gets covered.
    @isTest
    static void trigger_coversPublishedEvent() {
        Broker_User__c bu = makeBroker();
        Test.startTest();
        EventBus.publish(evt(bu.Id, BrokerAuthEventHandler.ACTION_LOGOUT));
        Test.getEventBus().deliver();
        Test.stopTest();

        Broker_User__c after = [SELECT Session_Epoch__c FROM Broker_User__c WHERE Id = :bu.Id];
        System.assertEquals(1, after.Session_Epoch__c, 'Published event processed by the trigger');
    }
}