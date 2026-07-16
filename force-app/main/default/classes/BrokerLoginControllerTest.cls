@isTest
private class BrokerLoginControllerTest {

    // ---- helpers ----
    private static Broker_User__c makeBroker() {
        String uniq = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Account acc = new Account(Name = 'Test Brokerage ' + uniq, Skip_Trigger__c = true);
        insert acc;

        Broker_User__c bu = new Broker_User__c(
            Account__c = acc.Id,
            Email__c = 'broker' + uniq + '@example.com',
            Active__c = true
        );
        insert bu;
        return bu;
    }

    // ---- Step 1: sendOtp (redirects to the code step) ----
    @isTest
    static void sendOtp_existingUser_generatesCodeAndRedirects() {
        Broker_User__c bu = makeBroker();
        Test.setCurrentPage(Page.BrokerLogin);
        BrokerLoginController ctrl = new BrokerLoginController();
        ctrl.email = bu.Email__c;

        Test.startTest();
        PageReference pr = ctrl.sendOtp();
        Test.stopTest();

        System.assertNotEquals(null, pr, 'Should redirect (PRG)');
        System.assert(pr.getUrl().contains('step=otp'), 'Should redirect to the code step: ' + pr.getUrl());
        System.assertNotEquals(null, ctrl.generatedCodeForTest, 'A code should be generated for a known broker');
        System.assertEquals(8, ctrl.generatedCodeForTest.length());
    }

    @isTest
    static void sendOtp_unknownEmail_neutralRedirectNoCode() {
        Test.setCurrentPage(Page.BrokerLogin);
        BrokerLoginController ctrl = new BrokerLoginController();
        ctrl.email = 'nobody-here@example.com';

        Test.startTest();
        PageReference pr = ctrl.sendOtp();
        Test.stopTest();

        // Anti-enumeration: identical redirect to a successful send, but no code/email behind it.
        System.assertNotEquals(null, pr, 'Unknown email redirects like a successful send');
        System.assert(pr.getUrl().contains('step=otp'), 'Same step redirect as a registered email');
        System.assertEquals(null, ctrl.generatedCodeForTest, 'No code generated for an unknown email');
    }

    @isTest
    static void sendOtp_inactiveUser_neutralRedirectNoCode() {
        String uniq = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        Account acc = new Account(Name = 'Inactive Brokerage ' + uniq, Skip_Trigger__c = true);
        insert acc;
        Broker_User__c bu = new Broker_User__c(
            Account__c = acc.Id, Email__c = 'inactive' + uniq + '@example.com', Active__c = false
        );
        insert bu;

        Test.setCurrentPage(Page.BrokerLogin);
        BrokerLoginController ctrl = new BrokerLoginController();
        ctrl.email = bu.Email__c;

        Test.startTest();
        PageReference pr = ctrl.sendOtp();
        Test.stopTest();

        System.assertNotEquals(null, pr, 'Inactive broker gets the same neutral redirect');
        System.assert(pr.getUrl().contains('step=otp'), 'Indistinguishable from a registered email');
        System.assertEquals(null, ctrl.generatedCodeForTest, 'No code generated for an inactive broker');
    }

    @isTest
    static void sendOtp_cooldown_suppressesResend() {
        Broker_User__c bu = makeBroker();
        bu.Last_OTP_Sent__c = System.now();   // a code was just sent
        update bu;

        Test.setCurrentPage(Page.BrokerLogin);
        BrokerLoginController ctrl = new BrokerLoginController();
        ctrl.email = bu.Email__c;

        Test.startTest();
        PageReference pr = ctrl.sendOtp();
        Test.stopTest();

        System.assertNotEquals(null, pr, 'Cooldown still redirects neutrally');
        System.assert(pr.getUrl().contains('step=otp'));
        System.assertEquals(null, ctrl.generatedCodeForTest, 'No new code/email inside the cooldown window');
    }

    @isTest
    static void sendOtp_blankEmail_staysWithMessage() {
        Test.setCurrentPage(Page.BrokerLogin);
        BrokerLoginController ctrl = new BrokerLoginController();
        ctrl.email = '';
        PageReference pr = ctrl.sendOtp();
        System.assertEquals(null, pr, 'Blank email stays on the page');
        System.assertNotEquals(null, ctrl.message);
    }

    // ---- Step 2: verifyOtp (validates the signed OTP cookie) ----
    @isTest
    static void verifyOtp_correctCode_redirectsToPortal() {
        Broker_User__c bu = makeBroker();
        Test.setCurrentPage(Page.BrokerLogin);
        // Simulate the OTP cookie that sendOtp would have set for code '654321'
        ApexPages.currentPage().getCookies().put('brokerOtp',
            new Cookie('brokerOtp', BrokerLoginController.buildOtpCookieValue(bu.Id, '654321'), '/', 600, true));

        BrokerLoginController ctrl = new BrokerLoginController();
        ctrl.otp = '654321';
        PageReference pr = ctrl.verifyOtp();

        System.assertNotEquals(null, pr);
        System.assert(pr.getUrl().toLowerCase().contains('brokerportalhome'),
            'Correct code should redirect to the portal: ' + pr.getUrl());
    }

    @isTest
    static void verifyOtp_wrongCode_redirectsBackWithError() {
        Broker_User__c bu = makeBroker();
        Test.setCurrentPage(Page.BrokerLogin);
        ApexPages.currentPage().getCookies().put('brokerOtp',
            new Cookie('brokerOtp', BrokerLoginController.buildOtpCookieValue(bu.Id, '654321'), '/', 600, true));

        BrokerLoginController ctrl = new BrokerLoginController();
        ctrl.otp = '000000';
        PageReference pr = ctrl.verifyOtp();

        System.assert(pr.getUrl().contains('step=otp'), 'Wrong code returns to the code step');
        System.assert(pr.getUrl().contains('e=1'), 'Wrong code flags an error');
    }

    @isTest
    static void verifyOtp_noCookie_redirectsBackWithError() {
        Test.setCurrentPage(Page.BrokerLogin);
        BrokerLoginController ctrl = new BrokerLoginController();
        ctrl.otp = '123456';
        PageReference pr = ctrl.verifyOtp();
        System.assert(pr.getUrl().contains('e=1'), 'No OTP cookie => error');
    }

    @isTest
    static void verifyOtp_tooManyAttempts_blockedEvenWithCorrectCode() {
        Broker_User__c bu = makeBroker();
        bu.OTP_Attempts__c = 10;              // server-side counter at the cap
        update bu;

        Test.setCurrentPage(Page.BrokerLogin);
        ApexPages.currentPage().getCookies().put('brokerOtp',
            new Cookie('brokerOtp', BrokerLoginController.buildOtpCookieValue(bu.Id, '654321'), '/', 600, true));

        BrokerLoginController ctrl = new BrokerLoginController();
        ctrl.otp = '654321';                  // CORRECT code — must still be blocked
        PageReference pr = ctrl.verifyOtp();

        System.assert(pr.getUrl().contains('e=2'), 'Attempt cap blocks login until a new code: ' + pr.getUrl());
    }

    @isTest
    static void verifyOtp_failedAttempt_isCountedServerSide() {
        Broker_User__c bu = makeBroker();
        Test.setCurrentPage(Page.BrokerLogin);
        ApexPages.currentPage().getCookies().put('brokerOtp',
            new Cookie('brokerOtp', BrokerLoginController.buildOtpCookieValue(bu.Id, '654321'), '/', 600, true));

        BrokerLoginController ctrl = new BrokerLoginController();
        ctrl.otp = '000000';

        Test.startTest();
        ctrl.verifyOtp();
        Test.getEventBus().deliver();         // deliver the OTP_FAIL event to the handler
        Test.stopTest();

        Broker_User__c after = [SELECT OTP_Attempts__c FROM Broker_User__c WHERE Id = :bu.Id];
        System.assertEquals(1, after.OTP_Attempts__c, 'Failed attempt recorded on the record');
    }

    @isTest
    static void logout_revokesAllSessionsViaEpoch() {
        Broker_User__c bu = makeBroker();
        String token = BrokerLoginController.buildSessionToken(bu.Id);

        Test.setCurrentPage(Page.BrokerPortalHome);
        ApexPages.currentPage().getCookies().put('brokerSession',
            new Cookie('brokerSession', token, '/', 3600, true));
        System.assertEquals(bu.Id, BrokerLoginController.validateToken(token), 'Token valid before logout');

        BrokerLoginController ctrl = new BrokerLoginController();
        Test.startTest();
        ctrl.logout();
        Test.getEventBus().deliver();         // deliver the LOGOUT event (epoch bump)
        Test.stopTest();

        System.assertEquals(null, BrokerLoginController.validateToken(token),
            'Old token is dead everywhere after logout, not just in this browser');
    }

    // ---- OTP cookie validation ----
    @isTest
    static void otpCookie_valid_wrong_tampered() {
        Broker_User__c bu = makeBroker();
        String cookieVal = BrokerLoginController.buildOtpCookieValue(bu.Id, '424242');

        System.assertEquals(bu.Id, BrokerLoginController.validateOtpCookie(cookieVal, '424242'), 'Correct code validates');
        System.assertEquals(null, BrokerLoginController.validateOtpCookie(cookieVal, '999999'), 'Wrong code rejected');

        String tampered = cookieVal.substring(0, cookieVal.length() - 1) + (cookieVal.endsWith('a') ? 'b' : 'a');
        System.assertEquals(null, BrokerLoginController.validateOtpCookie(tampered, '424242'), 'Tampered cookie rejected');
    }

    // ---- Stateless session token ----
    @isTest
    static void sessionToken_roundTrips_andValidates() {
        Broker_User__c bu = makeBroker();
        String token = BrokerLoginController.buildSessionToken(bu.Id);
        System.assertEquals(bu.Id, BrokerLoginController.validateToken(token));
    }

    @isTest
    static void sessionToken_tampered_isRejected() {
        Broker_User__c bu = makeBroker();
        String token = BrokerLoginController.buildSessionToken(bu.Id);
        String tampered = token.substring(0, token.length() - 1) + (token.endsWith('a') ? 'b' : 'a');
        System.assertEquals(null, BrokerLoginController.validateToken(tampered));
    }

    @isTest
    static void session_valid_then_logout() {
        Broker_User__c bu = makeBroker();
        Test.setCurrentPage(Page.BrokerPortalHome);
        ApexPages.currentPage().getCookies().put('brokerSession',
            new Cookie('brokerSession', BrokerLoginController.buildSessionToken(bu.Id), '/', 3600, true));

        System.assertEquals(true, BrokerLoginController.isValidSession());
        System.assertEquals(bu.Id, BrokerLoginController.getCurrentBrokerUserId());
        System.assertEquals(bu.Account__c, BrokerLoginController.getCurrentAccountId());

        BrokerLoginController ctrl = new BrokerLoginController();
        System.assertEquals(null, ctrl.checkLogin(), 'Valid session should not redirect');
        System.assertNotEquals(null, ctrl.getBrokerCompanyName());

        PageReference pr = ctrl.logout();
        System.assert(pr.getUrl().toLowerCase().contains('brokerlogin'), 'Logout returns to login');
    }

    @isTest
    static void checkLogin_noSession_redirects() {
        Test.setCurrentPage(Page.BrokerPortalHome);
        BrokerLoginController ctrl = new BrokerLoginController();
        PageReference pr = ctrl.checkLogin();
        System.assert(pr.getUrl().toLowerCase().contains('brokerlogin'));
        System.assertEquals(false, BrokerLoginController.isValidSession());
    }

    // ---- constructor reads URL params ----
    @isTest
    static void constructor_readsStepAndError() {
        PageReference pg = Page.BrokerLogin;
        pg.getParameters().put('step', 'otp');
        pg.getParameters().put('e', '1');
        pg.getParameters().put('email', 'someone@example.com');
        Test.setCurrentPage(pg);

        BrokerLoginController ctrl = new BrokerLoginController();
        System.assertEquals('OTP', ctrl.phase);
        System.assertEquals('someone@example.com', ctrl.email);
        System.assertNotEquals(null, ctrl.message, 'e=1 should show an error message');
    }
}