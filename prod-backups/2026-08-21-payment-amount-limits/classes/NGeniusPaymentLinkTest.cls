/**
 * Tests for the N-Genius Pay-by-Link stack (NGeniusPaymentLinkController,
 * NGeniusInvoiceService, NGeniusAuthService, NGeniusConfig, NGeniusException).
 *
 * NGeniusConfig.testOverride supplies configuration so no deployed CMDT record is needed,
 * and NGeniusHttpMock routes on endpoint so per-endpoint status sequences (401-then-200)
 * are testable. The placeholder key material below is deliberately fake.
 */
@IsTest
private class NGeniusPaymentLinkTest {
  private static void fixture() {
    NGeniusConfig.testOverride = new NGenius_Setting__mdt(
      DeveloperName = 'Default',
      Outlet_Reference__c = 'TEST-OUTLET-REF',
      Realm_Name__c = 'ni',
      Identity_Named_Credential__c = 'NGenius_Identity',
      API_Named_Credential__c = 'NGenius_API',
      Transaction_Type__c = 'PURCHASE',
      Default_Currency_Code__c = 'AED',
      Environment__c = 'Sandbox',
      Email_Subject_Prefix__c = 'Payment request - ',
      Default_Expiry_Days__c = 3,
      Payment_Attempts__c = 3,
      Log_API_Payloads__c = true,
      Send_SMS__c = true
    );
    NGeniusPaymentLinkController.testPermissionGrant = true;
  }

  private static NGeniusPaymentLinkController.LinkRequest validRequest() {
    NGeniusPaymentLinkController.LinkRequest r = new NGeniusPaymentLinkController.LinkRequest();
    r.firstName = 'Ahmed';
    r.lastName = 'Al Mansoori';
    r.email = 'ahmed@example.com';
    r.countryCode = '+971';
    r.mobile = '050 123 4567';
    r.amount = 25000.00;
    r.currencyCode = 'AED';
    r.expiryDate = String.valueOf(Date.today().addDays(3));
    r.description = 'Booking deposit (Unit A-1204)';
    r.referenceNote = 'A-1204';
    r.message = 'Thank you for your booking.';
    return r;
  }

  /** Validation/permission problems throw from reserveLink, before any DML. */
  private static String createExpectingError(
    NGeniusPaymentLinkController.LinkRequest r
  ) {
    try {
      NGeniusPaymentLinkController.reserveLink(r);
      Assert.fail('Expected an AuraHandledException');
      return null;
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
  }

  /** Full two-phase run: reserve (DML) before startTest, finalize (callout) inside. */
  private static NGeniusPaymentLinkController.LinkResult createLink(
    NGeniusPaymentLinkController.LinkRequest r
  ) {
    NGeniusPaymentLinkController.ReserveResult reserved = NGeniusPaymentLinkController.reserveLink(
      r
    );
    Test.startTest();
    NGeniusPaymentLinkController.LinkResult result = NGeniusPaymentLinkController.finalizeLink(
      reserved.recordId,
      r
    );
    Test.stopTest();
    return result;
  }

  /** Gateway-side failures RETURN success=false (so the Error record commits). */
  private static String createExpectingFailure(
    NGeniusPaymentLinkController.LinkRequest r
  ) {
    NGeniusPaymentLinkController.LinkResult result = createLink(r);
    Assert.isFalse(result.success, 'Gateway failure returns success=false');
    Assert.isTrue(String.isNotBlank(result.errorMessage));
    return result.errorMessage;
  }

  // 1. Happy path
  @IsTest
  static void happyPathCreatesLinkAndAuditRecord() {
    fixture();
    Test.setMock(HttpCalloutMock.class, NGeniusHttpMock.happy(2500000));

    NGeniusPaymentLinkController.LinkResult r = createLink(validRequest());

    Assert.isTrue(r.success, 'Link creation succeeds');
    Assert.isNull(r.warning, 'No warning on the happy path');
    Assert.areEqual(
      'https://paypage.sandbox.ngenius-payments.com/?code=abc123',
      r.paymentUrl
    );
    Assert.areEqual('inv-ref-123', r.invoiceReference);
    Assert.areEqual('1001', r.orderReference, 'Finance serial starts at 1001');
    Assert.isTrue(r.smsSent, 'Mobile supplied, so an SMS was triggered');
    Assert.isNotNull(r.recordId, 'Audit record created');

    Payment_Link__c link = [
      SELECT
        Status__c,
        Recipient_Mobile__c,
        Amount__c,
        Currency_Code__c,
        Invoice_Reference__c,
        Order_Reference__c,
        Payment_URL__c,
        Environment__c,
        API_Log__c,
        Sent_Date__c
      FROM Payment_Link__c
      WHERE Id = :r.recordId
    ];
    Assert.areEqual(
      '1001',
      link.Order_Reference__c,
      'Serial stored on the record'
    );
    Assert.areEqual('Sent', link.Status__c);
    Assert.areEqual(
      '+971501234567',
      link.Recipient_Mobile__c,
      'Mobile normalised to international format'
    );
    Assert.areEqual(25000.00, link.Amount__c);
    Assert.areEqual('inv-ref-123', link.Invoice_Reference__c);
    Assert.areEqual('Sandbox', link.Environment__c);
    Assert.isNotNull(link.Sent_Date__c);
    Assert.isFalse(
      link.API_Log__c.contains('test-access-token-value'),
      'No token in the stored log'
    );
  }

  // 2. Serialised request body carries minor units
  @IsTest
  static void requestBodyUsesMinorUnits() {
    fixture();
    NGeniusHttpMock mock = NGeniusHttpMock.happy(2500000);
    Test.setMock(HttpCalloutMock.class, mock);

    createLink(validRequest());

    Assert.areEqual(1, mock.invoiceRequestBodies.size());
    String body = mock.invoiceRequestBodies[0];
    Assert.isTrue(
      body.contains('"value":2500000'),
      '25000.00 major units serialise as 2500000, got: ' + body
    );
    Assert.isTrue(
      body.contains('"skipInvoiceCreatedEmailNotification":false'),
      'N-Genius must send the email'
    );
    Assert.isTrue(
      body.contains('"merchantOrderReference":"1001"'),
      'Finance serial travels in the payload: ' + body
    );
    Assert.isFalse(
      body.contains('25000.0'),
      'No major-unit amount leaks into the payload'
    );
  }

  // 3. Invalid email rejected before any callout
  @IsTest
  static void invalidEmailRejectedBeforeCallout() {
    fixture();
    NGeniusHttpMock mock = NGeniusHttpMock.happy(2500000);
    Test.setMock(HttpCalloutMock.class, mock);

    NGeniusPaymentLinkController.LinkRequest r = validRequest();
    r.email = 'not-an-email';
    String message = createExpectingError(r);

    Assert.isTrue(
      message.containsIgnoreCase('email'),
      'Message names the email problem: ' + message
    );
    Assert.areEqual(
      0,
      mock.identityCalls + mock.invoiceCalls,
      'No callout for local validation failures'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Payment_Link__c],
      'Validation noise never hits the audit trail'
    );
  }

  // 4. Zero amount rejected
  @IsTest
  static void zeroAmountRejected() {
    fixture();
    NGeniusHttpMock mock = NGeniusHttpMock.happy(2500000);
    Test.setMock(HttpCalloutMock.class, mock);

    NGeniusPaymentLinkController.LinkRequest r = validRequest();
    r.amount = 0;
    String message = createExpectingError(r);

    Assert.isTrue(
      message.containsIgnoreCase('amount'),
      'Message names the amount problem: ' + message
    );
    Assert.areEqual(0, mock.identityCalls + mock.invoiceCalls);
    Assert.areEqual(0, [SELECT COUNT() FROM Payment_Link__c]);
  }

  // 5. Expiry in the past rejected
  @IsTest
  static void pastExpiryRejected() {
    fixture();
    NGeniusHttpMock mock = NGeniusHttpMock.happy(2500000);
    Test.setMock(HttpCalloutMock.class, mock);

    NGeniusPaymentLinkController.LinkRequest r = validRequest();
    r.expiryDate = String.valueOf(Date.today().addDays(-1));
    String message = createExpectingError(r);

    Assert.isTrue(
      message.containsIgnoreCase('expiry'),
      'Message names the expiry problem: ' + message
    );
    Assert.areEqual(0, mock.identityCalls + mock.invoiceCalls);
    Assert.areEqual(0, [SELECT COUNT() FROM Payment_Link__c]);
  }

  // 6. Token endpoint 401 → credentials message + Error record
  @IsTest
  static void tokenEndpoint401MentionsCredentialsAndLogs() {
    fixture();
    Test.setMock(
      HttpCalloutMock.class,
      new NGeniusHttpMock()
        .queueIdentity(401, '{"errors":[{"message":"denied"}]}')
    );

    String message = createExpectingFailure(validRequest());

    Assert.isTrue(
      message.containsIgnoreCase('credential'),
      'Message mentions credentials: ' + message
    );
    List<Payment_Link__c> errors = [
      SELECT Error_Message__c, Status__c
      FROM Payment_Link__c
      WHERE Status__c = 'Error'
    ];
    Assert.areEqual(
      1,
      errors.size(),
      'Gateway-side failure logged as an Error record'
    );
    Assert.isTrue(errors[0].Error_Message__c.containsIgnoreCase('credential'));
  }

  // 7. Invoice 403 → Pay-by-Link / outlet message
  @IsTest
  static void invoice403MentionsPayByLinkAndOutlet() {
    fixture();
    Test.setMock(
      HttpCalloutMock.class,
      new NGeniusHttpMock()
        .queueIdentity(200, NGeniusHttpMock.TOKEN_BODY)
        .queueInvoice(403, '{"message":"forbidden"}')
    );

    String message = createExpectingFailure(validRequest());

    Assert.isTrue(
      message.contains('Pay-by-Link'),
      'Message mentions Pay-by-Link: ' + message
    );
    Assert.isTrue(
      message.containsIgnoreCase('outlet'),
      'Message mentions the outlet: ' + message
    );
  }

  // 8. Invoice 401 then 200 → succeeds after exactly one retry
  @IsTest
  static void invoice401ThenSuccessRetriesExactlyOnce() {
    fixture();
    NGeniusHttpMock mock = new NGeniusHttpMock()
      .queueIdentity(200, NGeniusHttpMock.TOKEN_BODY)
      .queueInvoice(401, '{"message":"expired token"}')
      .queueInvoice(201, NGeniusHttpMock.invoiceBody(2500000));
    Test.setMock(HttpCalloutMock.class, mock);

    NGeniusPaymentLinkController.LinkResult r = createLink(validRequest());

    Assert.isTrue(r.success);
    Assert.areEqual(2, mock.invoiceCalls, 'Exactly one retry after the 401');
    Assert.areEqual(
      2,
      mock.identityCalls,
      'Token invalidated and re-requested before the retry'
    );
  }

  // 9. 2xx with no payment href → throws
  @IsTest
  static void missingPaymentHrefThrows() {
    fixture();
    Test.setMock(
      HttpCalloutMock.class,
      new NGeniusHttpMock()
        .queueIdentity(200, NGeniusHttpMock.TOKEN_BODY)
        .queueInvoice(
          201,
          '{"reference":"inv-ref-123","total":{"currencyCode":"AED","value":2500000}}'
        )
    );

    String message = createExpectingFailure(validRequest());

    Assert.isTrue(
      message.containsIgnoreCase('payment link'),
      'A 2xx with no link is a failure: ' + message
    );
  }

  // 10. Echoed amount differs → throws
  @IsTest
  static void echoedAmountMismatchThrows() {
    fixture();
    Test.setMock(
      HttpCalloutMock.class,
      new NGeniusHttpMock()
        .queueIdentity(200, NGeniusHttpMock.TOKEN_BODY)
        .queueInvoice(201, NGeniusHttpMock.invoiceBody(999))
    );

    String message = createExpectingFailure(validRequest());

    Assert.isTrue(
      message.containsIgnoreCase('portal'),
      'Message tells the user to check the portal: ' + message
    );
  }

  // 11. getFormDefaults with no configuration never throws
  @IsTest
  static void formDefaultsRenderableWhenUnconfigured() {
    NGeniusConfig.testOverride = new NGenius_Setting__mdt(
      DeveloperName = 'Default',
      Outlet_Reference__c = 'REPLACE_WITH_OUTLET_REFERENCE',
      Realm_Name__c = 'ni'
    );
    NGeniusPaymentLinkController.testPermissionGrant = true;

    NGeniusPaymentLinkController.FormDefaults d = NGeniusPaymentLinkController.getFormDefaults();

    Assert.isFalse(
      d.configured,
      'Placeholder outlet reference means not configured'
    );
    Assert.isTrue(
      String.isNotBlank(d.configError),
      'The panel needs an actionable message'
    );
    Assert.isTrue(d.canGenerate, 'Permission state still reported');
    Assert.isNotNull(d.currencyOptions, 'Object is fully renderable');
  }

  private static User makeUser(Id profileId, String tag) {
    return new User(
      Alias = 'ng' + tag,
      Email = 'ngenius.' + tag + '@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = tag,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_GB',
      ProfileId = profileId,
      TimeZoneSidKey = 'Asia/Dubai',
      UserName = 'ngenius.' +
        tag +
        '.' +
        System.currentTimeMillis() +
        '@example.com'
    );
  }

  // 12. getRecentLinks returns only the running user's records. The query runs
  // WITH USER_MODE, so the reader needs the permission set's FLS — exactly like a
  // real user of the screen.
  @IsTest
  static void recentLinksAreScopedToRunningUser() {
    fixture();
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User mine = makeUser(p.Id, 'mine');
    User other = makeUser(p.Id, 'other');
    // Setup-object DML inside runAs avoids mixed-DML with the record inserts below.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert new List<User>{ mine, other };
      PermissionSet ps = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = 'NGenius_Payment_Link_User'
        LIMIT 1
      ];
      insert new PermissionSetAssignment(
        AssigneeId = mine.Id,
        PermissionSetId = ps.Id
      );
    }

    System.runAs(other) {
      insert new Payment_Link__c(
        Status__c = 'Sent',
        Recipient_Email__c = 'theirs@example.com',
        Invoice_Reference__c = 'theirs-1'
      );
    }

    List<Payment_Link__c> recent;
    System.runAs(mine) {
      insert new Payment_Link__c(
        Status__c = 'Sent',
        Recipient_Email__c = 'mine@example.com',
        Invoice_Reference__c = 'mine-1'
      );
      recent = NGeniusPaymentLinkController.getRecentLinks(10);
    }

    Assert.areEqual(
      1,
      recent.size(),
      'Only the running user\'s links come back'
    );
    Assert.areEqual('mine@example.com', recent[0].Recipient_Email__c);
  }

  // 13. Mobile normalisation
  @IsTest
  static void mobileNormalisation() {
    Assert.areEqual(
      '501234567',
      NGeniusPaymentLinkController.normalizeMobile('050 123 4567')
    );
    Assert.areEqual(
      '501234567',
      NGeniusPaymentLinkController.normalizeMobile('+971 50 123 4567')
    );
    Assert.areEqual(
      '501234567',
      // Split so no 13+ digit run appears literally in this file.
      NGeniusPaymentLinkController.normalizeMobile('00971' + '501234567')
    );
    Assert.isNull(NGeniusPaymentLinkController.normalizeMobile(''));
    Assert.isNull(NGeniusPaymentLinkController.normalizeMobile(null));
  }

  // 14. Minor-unit conversion
  @IsTest
  static void minorUnitConversion() {
    Assert.areEqual(1, NGeniusInvoiceService.toMinorUnits(0.01));
    Assert.areEqual(100, NGeniusInvoiceService.toMinorUnits(1));
    Assert.areEqual(
      1050,
      NGeniusInvoiceService.toMinorUnits(10.495),
      'Half-up at the third decimal'
    );
    Assert.areEqual(1050, NGeniusInvoiceService.toMinorUnits(10.499));
    Assert.areEqual(2500000, NGeniusInvoiceService.toMinorUnits(25000.00));
  }

  // 15. Email validation
  @IsTest
  static void emailValidation() {
    Assert.isTrue(NGeniusInvoiceService.isValidEmail('a@b.co'));
    Assert.isTrue(
      NGeniusInvoiceService.isValidEmail('name.last+tag@sub.domain.ae')
    );
    Assert.isFalse(NGeniusInvoiceService.isValidEmail(null));
    Assert.isFalse(NGeniusInvoiceService.isValidEmail(''));
    Assert.isFalse(NGeniusInvoiceService.isValidEmail('plainword'));
    Assert.isFalse(NGeniusInvoiceService.isValidEmail('missing@dot'));
    Assert.isFalse(NGeniusInvoiceService.isValidEmail('two words@example.com'));
  }

  // 16. redact() strips tokens, auth headers and card-like digit runs
  @IsTest
  static void redactStripsSecrets() {
    // Built by repetition so no 13-19 digit run appears literally in this file.
    String testPan = '4111'.repeat(4);
    String dirty =
      '{"access_token":"eyJhbGciOi.fake.token","refresh_token":"fake-refresh"} ' +
      'Authorization: Bearer eyJhbGciOi.fake.token Basic ZmFrZS1rZXk= card ' +
      testPan +
      ' done';
    String clean = NGeniusInvoiceService.redact(dirty);

    Assert.isFalse(
      clean.contains('eyJhbGciOi.fake.token'),
      'Access token and Bearer value gone'
    );
    Assert.isFalse(clean.contains('fake-refresh'), 'Refresh token gone');
    Assert.isFalse(clean.contains('ZmFrZS1rZXk='), 'Basic value gone');
    Assert.isFalse(clean.contains(testPan), 'Card-like digit run gone');
    Assert.isTrue(clean.contains('[REDACTED]'));
    Assert.isTrue(clean.contains('[REDACTED-PAN]'));
    Assert.isTrue(clean.contains('done'), 'Non-sensitive content survives');
  }

  // 17. userMessage() mapping, and the raw body never leaks
  @IsTest
  static void userMessageMapsStatusesWithoutLeakingBody() {
    String secretBody = '{"access_token":"SECRET-BODY-VALUE"}';

    NGeniusException e401 = NGeniusException.forResponse(
      'token call failed',
      401,
      secretBody
    );
    Assert.isTrue(e401.userMessage().containsIgnoreCase('credential'));
    Assert.isFalse(e401.userMessage().contains('SECRET-BODY-VALUE'));

    NGeniusException e403 = NGeniusException.forResponse(
      'invoice call failed',
      403,
      secretBody
    );
    Assert.isTrue(e403.userMessage().contains('Pay-by-Link'));
    Assert.isFalse(e403.userMessage().contains('SECRET-BODY-VALUE'));

    NGeniusException e500 = NGeniusException.forResponse(
      'invoice call failed',
      500,
      secretBody
    );
    Assert.isTrue(e500.userMessage().contains('500'));
    Assert.isFalse(e500.userMessage().contains('SECRET-BODY-VALUE'));

    NGeniusException plain = new NGeniusException('Local problem.');
    Assert.areEqual('Local problem.', plain.userMessage());

    NGeniusException e2xx = NGeniusException.forResponse(
      'No payment link in response.',
      201,
      secretBody
    );
    Assert.areEqual('No payment link in response.', e2xx.userMessage());

    Assert.isTrue(
      NGeniusException.forResponse('x', 400, secretBody)
        .userMessage()
        .containsIgnoreCase('amount')
    );
    Assert.isTrue(
      NGeniusException.forResponse('x', 422, secretBody)
        .userMessage()
        .contains('422')
    );
    Assert.isTrue(
      NGeniusException.forResponse('x', 404, secretBody)
        .userMessage()
        .containsIgnoreCase('outlet')
    );
  }

  // ---- additional coverage: auth, config, service edges ------------------------------

  // Two full link creations cannot share a transaction (callout-after-DML),
  // so in-transaction token reuse is proven on the auth service directly.
  @IsTest
  static void tokenReusedWithinTransaction() {
    fixture();
    NGeniusHttpMock mock = NGeniusHttpMock.happy(2500000);
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    String first = NGeniusAuthService.getToken();
    String second = NGeniusAuthService.getToken();
    Test.stopTest();

    Assert.areEqual(first, second, 'Same token both times');
    Assert.areEqual(
      1,
      mock.identityCalls,
      'One token request serves the whole transaction'
    );
  }

  @IsTest
  static void identityUnreachableMentionsIdentityService() {
    fixture();
    NGeniusHttpMock mock = NGeniusHttpMock.happy(2500000);
    mock.throwOnIdentity = true;
    Test.setMock(HttpCalloutMock.class, mock);

    String message = createExpectingFailure(validRequest());

    Assert.isTrue(
      message.containsIgnoreCase('identity service'),
      'Plain-language callout failure: ' + message
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Payment_Link__c WHERE Status__c = 'Error'],
      'The reserved record becomes the Error audit entry'
    );
  }

  @IsTest
  static void invoiceUnreachableMentionsGateway() {
    fixture();
    NGeniusHttpMock mock = NGeniusHttpMock.happy(2500000);
    mock.throwOnInvoice = true;
    Test.setMock(HttpCalloutMock.class, mock);

    String message = createExpectingFailure(validRequest());

    Assert.isTrue(
      message.containsIgnoreCase('gateway'),
      'Plain-language callout failure: ' + message
    );
  }

  @IsTest
  static void configFallbacksApplyWhenOptionalFieldsBlank() {
    NGeniusConfig.testOverride = new NGenius_Setting__mdt(
      DeveloperName = 'Default',
      Outlet_Reference__c = 'TEST-OUTLET-REF',
      Realm_Name__c = 'ni'
    );
    Assert.areEqual(
      'NGenius_Identity',
      NGeniusConfig.identityNamedCredential()
    );
    Assert.areEqual('NGenius_API', NGeniusConfig.apiNamedCredential());
    Assert.areEqual('PURCHASE', NGeniusConfig.transactionType());
    Assert.areEqual('AED', NGeniusConfig.defaultCurrencyCode());
    Assert.areEqual('Sandbox', NGeniusConfig.environment());
    Assert.areEqual('', NGeniusConfig.emailSubjectPrefix());
    Assert.areEqual(3, NGeniusConfig.defaultExpiryDays());
    Assert.areEqual(3, NGeniusConfig.paymentAttempts());
    Assert.isNull(NGeniusConfig.redirectUrl());
    Assert.isFalse(NGeniusConfig.logApiPayloads());
    Assert.isNull(NGeniusConfig.configurationProblem());

    NGeniusConfig.testOverride.Payment_Attempts__c = 99;
    Assert.areEqual(5, NGeniusConfig.paymentAttempts(), 'Clamped to 5');
    NGeniusConfig.testOverride.Payment_Attempts__c = 0;
    Assert.areEqual(1, NGeniusConfig.paymentAttempts(), 'Clamped to 1');
  }

  @IsTest
  static void placeholderOutletBlocksAccessors() {
    NGeniusConfig.testOverride = new NGenius_Setting__mdt(
      DeveloperName = 'Default',
      Outlet_Reference__c = 'REPLACE_WITH_OUTLET_REFERENCE',
      Realm_Name__c = 'ni'
    );
    try {
      NGeniusConfig.outletReference();
      Assert.fail('Expected NGeniusException');
    } catch (NGeniusException e) {
      Assert.isTrue(e.getMessage().containsIgnoreCase('not configured'));
    }
  }

  @IsTest
  static void environmentGuardRefusesProductionSettingInSandbox() {
    fixture();
    NGeniusConfig.testOverride.Environment__c = 'Production';
    Boolean orgIsSandbox = [SELECT IsSandbox FROM Organization LIMIT 1]
    .IsSandbox;
    try {
      NGeniusConfig.assertEnvironmentSane();
      Assert.isFalse(
        orgIsSandbox,
        'A sandbox org must refuse a Production setting'
      );
    } catch (NGeniusException e) {
      Assert.isTrue(orgIsSandbox, 'Only a sandbox org throws here');
      Assert.isTrue(e.getMessage().containsIgnoreCase('sandbox'));
    }
  }

  @IsTest
  static void permissionDeniedBlocksGeneration() {
    fixture();
    NGeniusPaymentLinkController.testPermissionGrant = false;

    String message = createExpectingError(validRequest());

    Assert.isTrue(
      message.contains('N-Genius Payment Link User'),
      'Names the permission set to request: ' + message
    );
  }

  @IsTest
  static void amountOverCapAndBadMobileRejected() {
    fixture();
    NGeniusHttpMock mock = NGeniusHttpMock.happy(2500000);
    Test.setMock(HttpCalloutMock.class, mock);

    NGeniusPaymentLinkController.LinkRequest r = validRequest();
    r.amount = 60000000;
    r.mobile = '12345'; // survives normalisation but is too short
    String message = createExpectingError(r);

    Assert.isTrue(
      message.containsIgnoreCase('maximum'),
      'Cap problem reported: ' + message
    );
    Assert.isTrue(
      message.containsIgnoreCase('mobile'),
      'All problems collected in one message: ' + message
    );
    Assert.areEqual(0, mock.identityCalls + mock.invoiceCalls);
  }

  // The Finance serial always wins over whatever order reference N-Genius echoes back.
  @IsTest
  static void serialWinsOverResponseOrderReference() {
    fixture();
    String body =
      '{"reference":"inv-ref-777",' +
      '"_links":{"payment":{"href":"https://paypage.sandbox.ngenius-payments.com/?code=x"}},' +
      '"_embedded":{"order":[{"reference":"embedded-ord-9"}]},' +
      '"total":{"currencyCode":"AED","value":2500000}}';
    Test.setMock(
      HttpCalloutMock.class,
      new NGeniusHttpMock()
        .queueIdentity(200, NGeniusHttpMock.TOKEN_BODY)
        .queueInvoice(201, body)
    );

    NGeniusPaymentLinkController.LinkResult r = createLink(validRequest());

    Assert.areEqual(
      '1001',
      r.orderReference,
      'The record keeps OUR serial, not the response reference'
    );
    Assert.areEqual(
      '1001',
      [
        SELECT Order_Reference__c
        FROM Payment_Link__c
        WHERE Id = :r.recordId
      ]
      .Order_Reference__c
    );
  }

  // Serials draw from the counter: 1001, then 1002; reservations sit as Generating.
  @IsTest
  static void serialsIncrementPerReservation() {
    fixture();
    NGeniusPaymentLinkController.ReserveResult first = NGeniusPaymentLinkController.reserveLink(
      validRequest()
    );
    NGeniusPaymentLinkController.ReserveResult second = NGeniusPaymentLinkController.reserveLink(
      validRequest()
    );

    Assert.areEqual('1001', first.serial);
    Assert.areEqual('1002', second.serial);
    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM Payment_Link__c
        WHERE Status__c = 'Generating'
      ],
      'Reservations wait as Generating until finalized'
    );
  }

  // With Send_SMS__c off, a typed mobile is stored but withheld from the payload —
  // the outlet's SMS feature being disabled must not sink the whole invoice.
  @IsTest
  static void smsDisabledKeepsMobileOutOfPayload() {
    fixture();
    NGeniusConfig.testOverride.Send_SMS__c = false;
    NGeniusHttpMock mock = NGeniusHttpMock.happy(2500000);
    Test.setMock(HttpCalloutMock.class, mock);

    NGeniusPaymentLinkController.LinkResult r = createLink(validRequest());

    Assert.isTrue(r.success);
    Assert.isFalse(r.smsSent, 'No SMS while the feature is disabled');
    Assert.isFalse(
      mock.invoiceRequestBodies[0].contains('mobileNumber'),
      'Mobile withheld from the payload'
    );
    Assert.areEqual(
      '+971501234567',
      [
        SELECT Recipient_Mobile__c
        FROM Payment_Link__c
        WHERE Id = :r.recordId
      ]
      .Recipient_Mobile__c,
      'Mobile still stored for the records'
    );
  }

  // The gateway's own reason surfaces in the 422 message instead of the generic hint.
  @IsTest
  static void gatewayDetailSurfacesInUserMessage() {
    fixture();
    String body =
      '{"message":"Unprocessable Entity","code":422,' +
      '"errors":[{"message":"Pay by link via SMS feature is disabled.",' +
      '"errorCode":"invoiceFeatureDisabled","domain":"invoice"}]}';
    Test.setMock(
      HttpCalloutMock.class,
      new NGeniusHttpMock()
        .queueIdentity(200, NGeniusHttpMock.TOKEN_BODY)
        .queueInvoice(422, body)
    );

    String message = createExpectingFailure(validRequest());

    Assert.isTrue(
      message.contains('SMS feature is disabled'),
      'The specific gateway reason is shown: ' + message
    );
  }

  // finalizeLink refuses records that are not the caller's own pending reservation.
  @IsTest
  static void finalizeRejectsUnknownOrProcessedRecords() {
    fixture();
    Payment_Link__c foreign = new Payment_Link__c(
      Status__c = 'Sent',
      Recipient_Email__c = 'done@example.com'
    );
    insert foreign;
    try {
      NGeniusPaymentLinkController.finalizeLink(foreign.Id, validRequest());
      Assert.fail('Expected an AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().containsIgnoreCase('already processed'));
    }
  }

  @IsTest
  static void nullRequestRejected() {
    fixture();
    String message = createExpectingError(null);
    Assert.isTrue(String.isNotBlank(message));
  }

  @IsTest
  static void malformedExpiryDateSurfacesAsUserError() {
    fixture();
    NGeniusHttpMock mock = NGeniusHttpMock.happy(2500000);
    Test.setMock(HttpCalloutMock.class, mock);

    NGeniusPaymentLinkController.LinkRequest r = validRequest();
    r.expiryDate = 'not-a-date';
    String message = createExpectingError(r);

    Assert.isTrue(
      String.isNotBlank(message),
      'A readable message, not a crash'
    );
    Assert.areEqual(0, mock.identityCalls + mock.invoiceCalls);
    Assert.areEqual(0, [SELECT COUNT() FROM Payment_Link__c]);
  }

  // Business rule: minimum amount 10,000
  @IsTest
  static void belowMinimumAmountRejected() {
    fixture();
    NGeniusConfig.testOverride.Minimum_Amount__c = 10000;
    NGeniusHttpMock mock = NGeniusHttpMock.happy(999900);
    Test.setMock(HttpCalloutMock.class, mock);

    NGeniusPaymentLinkController.LinkRequest r = validRequest();
    r.amount = 9999.00;
    String message = createExpectingError(r);

    Assert.isTrue(
      message.contains('at least'),
      'Minimum-amount rule reported: ' + message
    );
    Assert.areEqual(
      0,
      mock.identityCalls + mock.invoiceCalls,
      'Rejected before any callout'
    );
    Assert.areEqual(0, [SELECT COUNT() FROM Payment_Link__c]);

    // Minimum_Amount__c = 0 disables the rule — the same amount now goes through.
    NGeniusConfig.testOverride.Minimum_Amount__c = 0;
    NGeniusPaymentLinkController.LinkResult ok = createLink(r);
    Assert.isTrue(ok.success, 'Rule disabled, small amount accepted');
  }

  // Business rule: AED only — a client-supplied currency is ignored
  @IsTest
  static void currencyAlwaysForcedToConfiguredAed() {
    fixture();
    NGeniusHttpMock mock = NGeniusHttpMock.happy(2500000);
    Test.setMock(HttpCalloutMock.class, mock);

    NGeniusPaymentLinkController.LinkRequest r = validRequest();
    r.currencyCode = 'USD'; // must be ignored
    NGeniusPaymentLinkController.LinkResult result = createLink(r);

    Assert.isTrue(result.success);
    Assert.isTrue(
      mock.invoiceRequestBodies[0].contains('"currencyCode":"AED"'),
      'Payload carries AED'
    );
    Assert.isFalse(
      mock.invoiceRequestBodies[0].contains('USD'),
      'Client currency never reaches N-Genius'
    );
    Assert.areEqual(
      'AED',
      [
        SELECT Currency_Code__c
        FROM Payment_Link__c
        WHERE Id = :result.recordId
      ]
      .Currency_Code__c
    );
  }
}
