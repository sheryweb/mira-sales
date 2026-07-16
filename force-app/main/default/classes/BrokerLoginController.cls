public virtual without sharing class BrokerLoginController {

    // ---- Config ----
    //private static final String ORG_WIDE_EMAIL_ID = '0D2U90000000Y4vKAE'; // Sandbox OWEA (agents@miradevelopments.ae)
    private static final String ORG_WIDE_EMAIL_ID = '0D2Rg0000000LkPKAU'; // Production OWEA (agents@miradevelopments.ae)
    private static final Integer OTP_TTL_MINUTES = 10;
    private static final Integer SESSION_TTL_HOURS = 8;
    private static final Integer OTP_RESEND_COOLDOWN_SECONDS = 60;
    private static final Integer MAX_OTP_ATTEMPTS = 10;
    private static final String COOKIE_NAME = 'brokerSession';
    private static final String OTP_COOKIE_NAME = 'brokerOtp';

    // HMAC key for the OTP and session cookies, read from the protected custom setting
    // (set per environment via anonymous Apex; never in source control).
    // If unset, every signature check fails -> the portal fails CLOSED (no logins, no valid sessions).
    @TestVisible
    private static String signingSecret {
        get {
            if (signingSecret == null) {
                Broker_Portal_Settings__c s = Broker_Portal_Settings__c.getOrgDefaults();
                signingSecret = (s == null || String.isBlank(s.Signing_Secret__c))
                    ? (Test.isRunningTest() ? 'test-only-signing-secret' : null)
                    : s.Signing_Secret__c;
            }
            return signingSecret;
        }
        set;
    }

    private static Boolean isConfigured() { return String.isNotBlank(signingSecret); }

    // ---- Page state ----
    public String email { get; set; }
    public String otp   { get; set; }
    public String message { get; set; }
    public String phase { get; set; }   // 'EMAIL' or 'OTP' (driven by the ?step= URL param)

    @TestVisible private String generatedCodeForTest; // populated only to let tests read the random code

    // Each page load is a fresh GET (PRG), so state comes from the URL, not view state.
    public BrokerLoginController() {
        Map<String, String> p = ApexPages.currentPage().getParameters();
        phase = (p.get('step') == 'otp') ? 'OTP' : 'EMAIL';
        String e = p.get('email');
        if (String.isNotBlank(e)) {
            email = EncodingUtil.urlDecode(e, 'UTF-8');
        }
        if (p.get('e') == '1') {
            message = 'Invalid or expired code. Please try again.';
        } else if (p.get('e') == '2') {
            message = 'Too many incorrect attempts. Please request a new code.';
        }
    }

    // EMAIL step: generate + email a code, drop it in a signed short-lived cookie, then REDIRECT to the code step.
    public PageReference sendOtp() {
        if (!isConfigured()) {
            message = 'Login is temporarily unavailable. Please contact MIRA Developments.';
            return null; // fail closed: no signing secret configured in this org
        }
        if (String.isBlank(email)) {
            message = 'Please enter your email.';
            return null; // stay on the email step (harmless to resubmit - no side effect)
        }
        List<Broker_User__c> users = [
            SELECT Id, Last_OTP_Sent__c FROM Broker_User__c WHERE Email__c = :email AND Active__c = true LIMIT 1
        ];
        if (users.isEmpty()) {
            // Unknown or inactive email: behave EXACTLY like a successful send (same redirect, no
            // email, no cookie) so the response never reveals whether an email is registered.
            return stepRedirect('otp', email, null);
        }
        if (users[0].Last_OTP_Sent__c != null
                && users[0].Last_OTP_Sent__c > System.now().addSeconds(-OTP_RESEND_COOLDOWN_SECONDS)) {
            // Server-side resend cooldown (anti email-bombing): same neutral redirect, no new email.
            // The previously sent code (if any) is still valid in the user's cookie.
            return stepRedirect('otp', email, null);
        }
        String code = generateOtp();
        generatedCodeForTest = code;
        ApexPages.currentPage().setCookies(new Cookie[]{
            new Cookie(OTP_COOKIE_NAME, buildOtpCookieValue(users[0].Id, code), '/', OTP_TTL_MINUTES * 60, true, 'Lax', true)
        });
        sendOtpEmail(email, code);
        publishAuth(users[0].Id, BrokerAuthEventHandler.ACTION_OTP_SENT);
        return stepRedirect('otp', email, null);
    }

    // CODE step: validate the entered code against the signed cookie; on success issue the session and go to the portal.
    public PageReference verifyOtp() {
        if (String.isBlank(otp)) {
            return stepRedirect('otp', email, '1');
        }
        otp = otp.trim().toUpperCase();   // codes are case-insensitive for the user
        Cookie c = ApexPages.currentPage().getCookies().get(OTP_COOKIE_NAME);
        String cookieVal = (c == null) ? null : c.getValue();

        // Server-side attempt cap: blocked until a NEW code is requested (counter is on the
        // Broker_User__c record, written by the event handler - a client can't reset it).
        Id cookieUserId = parseCookieUserId(cookieVal);
        if (cookieUserId != null && attemptsExceeded(cookieUserId)) {
            return stepRedirect('otp', email, '2');
        }

        Id brokerUserId = validateOtpCookie(cookieVal, otp);
        if (brokerUserId == null) {
            if (cookieUserId != null) publishAuth(cookieUserId, BrokerAuthEventHandler.ACTION_OTP_FAIL);
            return stepRedirect('otp', email, '1');
        }
        // Success: set the session cookie, clear the (single-use) OTP cookie, redirect to the portal home.
        publishAuth(brokerUserId, BrokerAuthEventHandler.ACTION_OTP_OK);
        ApexPages.currentPage().setCookies(new Cookie[]{
            new Cookie(COOKIE_NAME, buildSessionToken(brokerUserId), '/', SESSION_TTL_HOURS * 3600, true, 'Lax', true),
            new Cookie(OTP_COOKIE_NAME, '', '/', 0, true, 'Lax', true)
        });
        PageReference home = Page.BrokerPortalHome;
        home.setRedirect(true);
        return home;
    }

    public PageReference resetToEmail() {
        ApexPages.currentPage().setCookies(new Cookie[]{ new Cookie(OTP_COOKIE_NAME, '', '/', 0, true, 'Lax', true) });
        PageReference login = Page.BrokerLogin; // no ?step => email step
        login.setRedirect(true);
        return login;
    }

    private PageReference stepRedirect(String step, String emailVal, String errFlag) {
        PageReference ref = Page.BrokerLogin;
        ref.getParameters().put('step', step);
        if (String.isNotBlank(emailVal)) ref.getParameters().put('email', emailVal);
        if (errFlag != null) ref.getParameters().put('e', errFlag);
        ref.setRedirect(true);
        return ref;
    }

    // ---- OTP cookie (signed, short-lived; no DB write) ----

    @TestVisible
    private static String buildOtpCookieValue(Id brokerUserId, String code) {
        Long exp = System.now().addMinutes(OTP_TTL_MINUTES).getTime();
        String mac = hmacHex(code + '.' + brokerUserId + '.' + exp);
        return brokerUserId + '.' + exp + '.' + mac;
    }

    // Returns the broker user id if the entered code matches the signed cookie and isn't expired; else null.
    @TestVisible
    private static Id validateOtpCookie(String cookieVal, String enteredOtp) {
        if (!isConfigured()) return null;                                // fail closed
        if (String.isBlank(cookieVal) || String.isBlank(enteredOtp)) return null;
        List<String> parts = cookieVal.split('\\.');
        if (parts.size() != 3) return null;
        Id brokerUserId;
        try { brokerUserId = (Id) parts[0]; } catch (Exception e) { return null; }
        Long exp;
        try { exp = Long.valueOf(parts[1]); } catch (Exception e) { return null; }
        if (exp < System.now().getTime()) return null;                  // expired
        if (hmacHex(enteredOtp + '.' + brokerUserId + '.' + exp) != parts[2]) return null; // wrong code / tampered
        return brokerUserId;
    }

    // ---- Stateless session: a signed cookie, validated by signature (no stored token) ----

    // Token = brokerUserId.expiry.epoch.HMAC - the epoch ties the token to the broker's current
    // Session_Epoch__c; bumping that field (logout / admin revocation) invalidates every token.
    @TestVisible
    private static String buildSessionToken(Id brokerUserId) {
        Long exp = System.now().addHours(SESSION_TTL_HOURS).getTime();
        String payload = brokerUserId + '.' + String.valueOf(exp) + '.' + String.valueOf(currentEpoch(brokerUserId));
        return payload + '.' + hmacHex(payload);
    }

    @TestVisible
    private static Id validateToken(String token) {
        if (!isConfigured()) return null;                                // fail closed
        if (String.isBlank(token)) return null;
        List<String> parts = token.split('\\.');
        if (parts.size() != 4) return null;
        String payload = parts[0] + '.' + parts[1] + '.' + parts[2];
        if (hmacHex(payload) != parts[3]) return null;                 // signature mismatch / tampered
        Long exp;
        try { exp = Long.valueOf(parts[1]); } catch (Exception e) { return null; }
        if (exp < System.now().getTime()) return null;                 // expired
        Long tokenEpoch;
        try { tokenEpoch = Long.valueOf(parts[2]); } catch (Exception e) { return null; }
        Id brokerUserId;
        try { brokerUserId = (Id) parts[0]; } catch (Exception e) { return null; }
        List<Broker_User__c> users = [
            SELECT Id, Session_Epoch__c FROM Broker_User__c WHERE Id = :brokerUserId AND Active__c = true LIMIT 1
        ];
        if (users.isEmpty()) return null;
        Long recordEpoch = (users[0].Session_Epoch__c == null) ? 0 : users[0].Session_Epoch__c.longValue();
        return (tokenEpoch == recordEpoch) ? users[0].Id : null;       // revoked (logged out) tokens die here
    }

    private static Long currentEpoch(Id brokerUserId) {
        List<Broker_User__c> users = [SELECT Session_Epoch__c FROM Broker_User__c WHERE Id = :brokerUserId LIMIT 1];
        return (users.isEmpty() || users[0].Session_Epoch__c == null) ? 0 : users[0].Session_Epoch__c.longValue();
    }

    // First segment of a signed cookie value (the broker user id) - readable even when the
    // code/signature doesn't validate, so failed attempts can be attributed and counted.
    private static Id parseCookieUserId(String cookieVal) {
        if (String.isBlank(cookieVal)) return null;
        List<String> parts = cookieVal.split('\\.');
        if (parts.isEmpty()) return null;
        try { return (Id) parts[0]; } catch (Exception e) { return null; }
    }

    private static Boolean attemptsExceeded(Id brokerUserId) {
        List<Broker_User__c> users = [SELECT OTP_Attempts__c FROM Broker_User__c WHERE Id = :brokerUserId LIMIT 1];
        return !users.isEmpty() && users[0].OTP_Attempts__c != null && users[0].OTP_Attempts__c >= MAX_OTP_ATTEMPTS;
    }

    private static void publishAuth(Id brokerUserId, String action) {
        try {
            EventBus.publish(new Broker_Auth_Event__e(
                Broker_User_Id__c = brokerUserId, Action__c = action));
        } catch (Exception e) {
            System.debug('Broker auth event not published: ' + e.getMessage());
        }
    }

    public static Id getCurrentBrokerUserId() {
        Cookie c = ApexPages.currentPage().getCookies().get(COOKIE_NAME);
        return (c == null) ? null : validateToken(c.getValue());
    }

    public static Boolean isValidSession() {
        return getCurrentBrokerUserId() != null;
    }

    public static Id getCurrentAccountId() {
        Id buId = getCurrentBrokerUserId();
        if (buId == null) return null;
        List<Broker_User__c> users = [SELECT Account__c FROM Broker_User__c WHERE Id = :buId LIMIT 1];
        return users.isEmpty() ? null : users[0].Account__c;
    }

    public PageReference checkLogin() {
        if (!isValidSession()) {
            PageReference login = Page.BrokerLogin;
            login.setRedirect(true);
            return login;
        }
        return null;
    }

    public String getBrokerCompanyName() {
        Id accId = getCurrentAccountId();
        if (accId == null) return null;
        List<Account> accs = [SELECT Name FROM Account WHERE Id = :accId LIMIT 1];
        return accs.isEmpty() ? null : accs[0].Name;
    }

    public PageReference logout() {
        // Bump the session epoch so EVERY token for this broker dies server-side,
        // not just the cookie in this browser.
        Id buId = getCurrentBrokerUserId();
        if (buId != null) publishAuth(buId, BrokerAuthEventHandler.ACTION_LOGOUT);
        ApexPages.currentPage().setCookies(new Cookie[]{ new Cookie(COOKIE_NAME, '', '/', 0, true, 'Lax', true) });
        PageReference login = Page.BrokerLogin;
        login.setRedirect(true);
        return login;
    }

    // ---- internals ----
    // 8 chars from an unambiguous alphabet (no 0/O/1/I) -> 32^8 (~1.1e12) combinations.
    private static final String OTP_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    private String generateOtp() {
        String code = '';
        for (Integer i = 0; i < 8; i++) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), OTP_ALPHABET.length());
            code += OTP_ALPHABET.substring(idx, idx + 1);
        }
        return code;
    }

    private static String hmacHex(String data) {
        Blob mac = Crypto.generateMac('hmacSHA256', Blob.valueOf(data), Blob.valueOf(signingSecret));
        return EncodingUtil.convertToHex(mac);
    }

    private void sendOtpEmail(String toAddress, String code) {
        String subject = 'Your MIRA Broker Portal login code';
        String body = 'Your login code is: ' + code + '\n\nThis code expires in ' + OTP_TTL_MINUTES + ' minutes.';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ toAddress });
        mail.setOrgWideEmailAddressId(ORG_WIDE_EMAIL_ID);
        mail.setSubject(subject);
        mail.setPlainTextBody(body);
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        } catch (Exception e) {
            // The Org-Wide Email Address id isn't valid in this org (e.g. prod id used in a sandbox).
            // Fall back to the default sender so login never breaks on an email config issue.
            try {
                Messaging.SingleEmailMessage retry = new Messaging.SingleEmailMessage();
                retry.setToAddresses(new String[]{ toAddress });
                retry.setSubject(subject);
                retry.setPlainTextBody(body);
                Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ retry });
            } catch (Exception e2) {
                System.debug('OTP email could not be sent: ' + e2.getMessage());
            }
        }
    }
}