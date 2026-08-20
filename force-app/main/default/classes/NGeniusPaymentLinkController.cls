/**
 * NGeniusPaymentLinkController — @AuraEnabled surface for the nGeniusPaymentLink LWC.
 *
 * Order of operations in createPaymentLink is deliberate and load-bearing:
 * callout FIRST, insert AFTER (Salesforce forbids a callout after DML in one transaction).
 * If the insert fails, the link is already live and already emailed — so the link is still
 * returned to the UI with a visible warning, never reported as a failure.
 */
public with sharing class NGeniusPaymentLinkController {
  private static final Integer DEFAULT_RECENT = 10;
  private static final Integer MAX_RECENT = 50;
  private static final String PERMISSION_NAME = 'Generate_Payment_Links';

  /** Tests force the gate open/closed without assigning permission sets. */
  @TestVisible
  private static Boolean testPermissionGrant;

  // ---- wrappers ----------------------------------------------------------------------
  // Every property that crosses to the LWC needs @AuraEnabled, and the LinkRequest keys
  // must match the LWC object keys exactly — an unknown key makes deserialisation fail.

  public class LinkRequest {
    @AuraEnabled
    public String firstName { get; set; }
    @AuraEnabled
    public String lastName { get; set; }
    @AuraEnabled
    public String email { get; set; }
    @AuraEnabled
    public String countryCode { get; set; }
    @AuraEnabled
    public String mobile { get; set; }
    @AuraEnabled
    public Decimal amount { get; set; }
    @AuraEnabled
    public String currencyCode { get; set; }
    @AuraEnabled
    public String expiryDate { get; set; } // yyyy-MM-dd
    @AuraEnabled
    public String description { get; set; }
    @AuraEnabled
    public String referenceNote { get; set; }
    @AuraEnabled
    public String message { get; set; }
  }

  public class LinkResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String paymentUrl;
    @AuraEnabled
    public String invoiceReference;
    @AuraEnabled
    public String orderReference;
    @AuraEnabled
    public String recordId;
    @AuraEnabled
    public String recordName;
    @AuraEnabled
    public String recipientEmail;
    @AuraEnabled
    public String amountFormatted;
    @AuraEnabled
    public String expiryDate;
    @AuraEnabled
    public Boolean smsSent;
    @AuraEnabled
    public String warning;
    @AuraEnabled
    public String errorMessage; // set when success = false
  }

  public class Option {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;
    public Option(String label, String value) {
      this.label = label;
      this.value = value;
    }
  }

  public class FormDefaults {
    @AuraEnabled
    public String defaultCurrency;
    @AuraEnabled
    public List<Option> currencyOptions;
    @AuraEnabled
    public String defaultCountryCode;
    @AuraEnabled
    public String defaultExpiryDate;
    @AuraEnabled
    public Integer expiryDays;
    @AuraEnabled
    public String environmentName;
    @AuraEnabled
    public Boolean canGenerate;
    @AuraEnabled
    public Boolean configured;
    @AuraEnabled
    public String configError;
  }

  // ---- reads --------------------------------------------------------------------------

  /** Must never throw — a broken config renders a helpful panel, not a blank screen. */
  @AuraEnabled(cacheable=true)
  public static FormDefaults getFormDefaults() {
    FormDefaults d = new FormDefaults();
    try {
      d.canGenerate = hasGeneratePermission();
      d.configError = NGeniusConfig.configurationProblem();
      d.configured = d.configError == null;
      d.environmentName = NGeniusConfig.environment();
      d.defaultCurrency = NGeniusConfig.defaultCurrencyCode();
      d.defaultCountryCode = '+971';
      d.expiryDays = NGeniusConfig.defaultExpiryDays();
      d.defaultExpiryDate = String.valueOf(Date.today().addDays(d.expiryDays));
      d.currencyOptions = new List<Option>{
        new Option('AED — UAE Dirham', 'AED'),
        new Option('USD — US Dollar', 'USD'),
        new Option('EUR — Euro', 'EUR'),
        new Option('GBP — British Pound', 'GBP')
      };
    } catch (Exception e) {
      d.configured = false;
      d.configError = e.getMessage();
      if (d.canGenerate == null) {
        d.canGenerate = false;
      }
    }
    return d;
  }

  @AuraEnabled(cacheable=true)
  public static List<Payment_Link__c> getRecentLinks(Integer recordLimit) {
    Integer capped = recordLimit == null ||
      recordLimit <= 0
      ? DEFAULT_RECENT
      : Math.min(recordLimit, MAX_RECENT);
    return [
      SELECT
        Id,
        Name,
        Recipient_Name__c,
        Recipient_Email__c,
        Amount__c,
        Currency_Code__c,
        Status__c,
        Expiry_Date__c,
        Payment_URL__c,
        CreatedDate
      FROM Payment_Link__c
      WHERE CreatedById = :UserInfo.getUserId()
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT :capped
    ];
  }

  // ---- create ---------------------------------------------------------------------------

  @AuraEnabled
  public static LinkResult createPaymentLink(LinkRequest request) {
    if (!hasGeneratePermission()) {
      throw uiError(
        'You do not have permission to generate payment links. Ask an admin for the "N-Genius Payment Link User" permission set.'
      );
    }
    if (request == null) {
      throw uiError('Nothing to send.');
    }

    NGeniusInvoiceService.InvoiceRequest input = new NGeniusInvoiceService.InvoiceRequest();
    NGeniusInvoiceService.InvoiceResult invoice;
    try {
      NGeniusConfig.assertEnvironmentSane();

      input.firstName = trimmed(request.firstName);
      input.lastName = trimmed(request.lastName);
      input.email = trimmed(request.email);
      input.countryCode = String.isBlank(request.countryCode)
        ? '+971'
        : '+' + digitsOf(request.countryCode);
      input.mobileNumber = normalizeMobile(request.mobile);
      input.amount = request.amount;
      // Business rule (Sheraz 2026-08-20): AED only. The client's currency value is
      // deliberately ignored — the configured currency always wins.
      input.currencyCode = NGeniusConfig.defaultCurrencyCode();
      input.description = trimmed(request.description);
      input.referenceNote = trimmed(request.referenceNote);
      input.message = trimmed(request.message);
      input.expiryDate = String.isBlank(request.expiryDate)
        ? null
        : Date.valueOf(request.expiryDate.trim());

      invoice = NGeniusInvoiceService.createInvoice(input);
    } catch (NGeniusException e) {
      // Gateway-side failures (N-Genius actually responded) RETURN a failure result
      // instead of throwing: a thrown exception rolls back the whole transaction and
      // the Error audit record would silently vanish. Local validation failures are
      // user-input noise — they still throw, and log nothing.
      if (e.statusCode != null) {
        logErrorRecord(input, e);
        LinkResult failed = new LinkResult();
        failed.success = false;
        failed.errorMessage = e.userMessage();
        return failed;
      }
      throw uiError(e.userMessage());
    } catch (Exception e) {
      throw uiError(e.getMessage());
    }

    // The link is live and the email is sent from this point on. The audit insert gets
    // its own try/catch — an insert failure becomes a warning, never a reported failure.
    LinkResult result = new LinkResult();
    result.success = true;
    result.paymentUrl = invoice.paymentUrl;
    result.invoiceReference = invoice.invoiceReference;
    result.orderReference = invoice.orderReference;
    result.recipientEmail = input.email;
    result.amountFormatted =
      input.currencyCode +
      ' ' +
      String.valueOf(input.amount.setScale(2, System.RoundingMode.HALF_UP));
    result.expiryDate = String.valueOf(input.expiryDate);
    result.smsSent = String.isNotBlank(input.mobileNumber);

    try {
      Payment_Link__c link = new Payment_Link__c(
        Recipient_Name__c = input.firstName + ' ' + input.lastName,
        Recipient_Email__c = input.email,
        Recipient_Mobile__c = String.isBlank(input.mobileNumber)
          ? null
          : input.countryCode + input.mobileNumber,
        Amount__c = input.amount,
        Currency_Code__c = input.currencyCode,
        Description__c = input.description,
        Reference_Note__c = input.referenceNote,
        Status__c = 'Sent',
        Expiry_Date__c = input.expiryDate,
        Sent_Date__c = Datetime.now(),
        Invoice_Reference__c = invoice.invoiceReference,
        Order_Reference__c = invoice.orderReference,
        Payment_URL__c = invoice.paymentUrl,
        Environment__c = NGeniusConfig.environment(),
        API_Log__c = NGeniusConfig.logApiPayloads()
          ? ('REQUEST:\n' +
            invoice.rawRequest +
            '\n\nRESPONSE:\n' +
            invoice.rawResponse)
          : null
      );
      insert link;
      result.recordId = link.Id;
      result.recordName = [SELECT Name FROM Payment_Link__c WHERE Id = :link.Id]
      .Name;
    } catch (Exception e) {
      result.warning =
        'The payment link was created and emailed to ' +
        input.email +
        ', but the audit record could not be saved: ' +
        e.getMessage() +
        ' Copy the link now and report this to an admin.';
    }
    return result;
  }

  // ---- helpers -----------------------------------------------------------------------

  private static Boolean hasGeneratePermission() {
    if (testPermissionGrant != null) {
      return testPermissionGrant;
    }
    try {
      return FeatureManagement.checkPermission(PERMISSION_NAME);
    } catch (Exception e) {
      // Permission not deployed yet — do not lock everyone out of a half-deployed org.
      return true;
    }
  }

  /** 050 123 4567, +971 50 123 4567 and the 00971-prefixed form all become 501234567. */
  @TestVisible
  private static String normalizeMobile(String raw) {
    if (String.isBlank(raw)) {
      return null;
    }
    String digits = digitsOf(raw);
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('971')) {
      digits = digits.substring(3);
    }
    digits = digits.replaceFirst('^0+', '');
    return String.isBlank(digits) ? null : digits;
  }

  private static String digitsOf(String raw) {
    return raw == null ? '' : raw.replaceAll('[^0-9]', '');
  }

  private static String trimmed(String raw) {
    return String.isBlank(raw) ? null : raw.trim();
  }

  /** Best-effort audit of a gateway-side failure. Never masks the real error. */
  private static void logErrorRecord(
    NGeniusInvoiceService.InvoiceRequest input,
    NGeniusException e
  ) {
    try {
      insert new Payment_Link__c(
        Recipient_Name__c = String.isBlank(input.firstName)
          ? null
          : (input.firstName + ' ' + input.lastName),
        Recipient_Email__c = input.email,
        Amount__c = input.amount,
        Currency_Code__c = input.currencyCode,
        Description__c = input.description,
        Reference_Note__c = input.referenceNote,
        Expiry_Date__c = input.expiryDate,
        Status__c = 'Error',
        Environment__c = NGeniusConfig.environment(),
        Error_Message__c = e.userMessage().abbreviate(255),
        API_Log__c = NGeniusConfig.logApiPayloads()
          ? NGeniusInvoiceService.redactForLog(e.responseBody)
          : null
      );
    } catch (Exception ignored) {
      // Logging is best-effort only — the real error still surfaces to the user.
    }
  }

  /** Without setMessage the LWC receives "Script-thrown exception" instead of the text. */
  private static AuraHandledException uiError(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
