/**
 * NGeniusInvoiceService — creates an N-Genius Pay-by-Link invoice.
 *
 * API contract verified against docs.ngenius-payments.com on 2026-08-20:
 *   POST /invoices/outlets/{outletRef}/invoice
 *   Content-Type/Accept: application/vnd.ni-invoice.v1+json, Authorization: Bearer {token}.
 * The customer-facing link is _links.payment.href; the invoice reference is `reference`.
 *
 * Callout only — no DML in this class, so callers can safely insert audit records after.
 */
public with sharing class NGeniusInvoiceService {
  private static final Integer TIMEOUT_MS = 60000; // Apex ceiling is 120s — stay well under
  @TestVisible
  private static final Decimal MAX_AMOUNT = 50000000; // sane cap, major units
  private static final Integer LOG_MAX_CHARS = 30000;

  public class InvoiceRequest {
    public String firstName;
    public String lastName;
    public String email;
    public String countryCode; // e.g. +971
    public String mobileNumber; // national digits only, or blank
    public Decimal amount; // major units
    public String currencyCode;
    public String description;
    public String referenceNote;
    public Date expiryDate;
    public String message;
  }

  public class InvoiceResult {
    public String paymentUrl;
    public String invoiceReference;
    public String orderReference;
    public Integer statusCode;
    public String rawRequest; // redacted
    public String rawResponse; // redacted
  }

  public static InvoiceResult createInvoice(InvoiceRequest input) {
    validate(input);

    String body = JSON.serialize(buildPayload(input));
    HttpResponse res = send(body, NGeniusAuthService.getToken());

    // A rotated key surfaces as a 401 on the transaction call, not the token call.
    // Invalidate the cached token and retry exactly once — never in a loop.
    if (res.getStatusCode() == 401) {
      NGeniusAuthService.invalidate();
      res = send(body, NGeniusAuthService.getToken());
    }

    if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
      throw NGeniusException.forResponse(
        'N-Genius could not create the payment link (HTTP ' +
          res.getStatusCode() +
          ').',
        res.getStatusCode(),
        res.getBody()
      );
    }

    return parse(res, body, toMinorUnits(input.amount));
  }

  // ---- validation ------------------------------------------------------------------

  /** Collects every problem and throws once, rather than failing on the first. */
  private static void validate(InvoiceRequest input) {
    List<String> problems = new List<String>();
    if (input == null) {
      throw new NGeniusException('Nothing to send.');
    }
    if (String.isBlank(input.firstName)) {
      problems.add('First name is required.');
    }
    if (String.isBlank(input.lastName)) {
      problems.add('Last name is required.');
    }
    if (!isValidEmail(input.email)) {
      problems.add(
        'A valid email address is required — N-Genius sends the link there.'
      );
    }
    if (String.isBlank(input.description)) {
      problems.add('Description is required — the payer sees it.');
    }
    if (input.amount == null || input.amount <= 0) {
      problems.add('Amount is required.');
    } else if (
      NGeniusConfig.minimumAmount() > 0 &&
      input.amount < NGeniusConfig.minimumAmount()
    ) {
      problems.add(
        'Amount must be at least ' +
          NGeniusConfig.minimumAmount().format() +
          ' (business rule).'
      );
    } else if (input.amount > MAX_AMOUNT) {
      problems.add(
        'Amount exceeds the maximum of ' + MAX_AMOUNT.format() + '.'
      );
    }
    if (input.expiryDate == null) {
      problems.add('Expiry date is required.');
    } else if (input.expiryDate < Date.today()) {
      problems.add('Expiry date must not be in the past.');
    }
    if (
      String.isNotBlank(input.mobileNumber) &&
      !Pattern.matches('[0-9]{6,15}', input.mobileNumber)
    ) {
      problems.add(
        'Mobile number must be 6-15 digits (national number, no country code).'
      );
    }
    if (!problems.isEmpty()) {
      throw new NGeniusException(String.join(problems, ' '));
    }
  }

  @TestVisible
  private static Boolean isValidEmail(String email) {
    return String.isNotBlank(email) &&
      Pattern.matches('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$', email.trim());
  }

  // ---- payload ---------------------------------------------------------------------

  private static Map<String, Object> buildPayload(InvoiceRequest input) {
    Integer minorUnits = toMinorUnits(input.amount);
    Map<String, Object> totalAmount = new Map<String, Object>{
      'currencyCode' => input.currencyCode,
      'value' => minorUnits
    };

    Map<String, Object> payload = new Map<String, Object>{
      'transactionType' => NGeniusConfig.transactionType(),
      'firstName' => input.firstName.trim(),
      'lastName' => input.lastName.trim(),
      'email' => input.email.trim(),
      'invoiceExpiryDate' => formatDate(input.expiryDate),
      'paymentAttempts' => NGeniusConfig.paymentAttempts(),
      'emailSubject' => NGeniusConfig.emailSubjectPrefix() +
      input.description.trim(),
      // N-Genius sending the payer email is the whole point of Pay-by-Link.
      'skipInvoiceCreatedEmailNotification' => false,
      'items' => new List<Object>{
        new Map<String, Object>{
          'description' => input.description.trim(),
          'quantity' => 1,
          'totalPrice' => totalAmount
        }
      },
      'total' => totalAmount
    };
    // Supplying a mobile makes N-Genius send an SMS as well as the email.
    if (String.isNotBlank(input.mobileNumber)) {
      payload.put(
        'countryCode',
        String.isBlank(input.countryCode) ? '+971' : input.countryCode
      );
      payload.put('mobileNumber', input.mobileNumber);
    }
    if (String.isNotBlank(input.message)) {
      payload.put('message', input.message.trim());
    }
    if (String.isNotBlank(NGeniusConfig.redirectUrl())) {
      payload.put('redirectUrl', NGeniusConfig.redirectUrl());
    }
    // NOTE deliberately absent: a merchant-side reference field. The invoice payload's
    // field for one is not documented — Network International must confirm which field
    // to use before Salesforce, the portal and the settlement file can share one key.
    // input.referenceNote is stored on Payment_Link__c only.
    return payload;
  }

  private static HttpResponse send(String body, String token) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(
      'callout:' +
        NGeniusConfig.apiNamedCredential() +
        '/invoices/outlets/' +
        EncodingUtil.urlEncode(NGeniusConfig.outletReference(), 'UTF-8') +
        '/invoice'
    );
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/vnd.ni-invoice.v1+json');
    req.setHeader('Accept', 'application/vnd.ni-invoice.v1+json');
    req.setHeader('Authorization', 'Bearer ' + token);
    req.setBody(body);
    req.setTimeout(TIMEOUT_MS);
    try {
      return new Http().send(req);
    } catch (System.CalloutException e) {
      throw NGeniusException.forResponse(
        'Could not reach the N-Genius gateway — check the Named Credential and Trusted URLs. (' +
          e.getMessage() +
          ')',
        null,
        null
      );
    }
  }

  // ---- response --------------------------------------------------------------------

  private static InvoiceResult parse(
    HttpResponse res,
    String rawRequest,
    Integer sentMinorUnits
  ) {
    Map<String, Object> body;
    try {
      body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    } catch (Exception e) {
      throw NGeniusException.forResponse(
        'N-Genius returned a response that could not be parsed.',
        res.getStatusCode(),
        res.getBody()
      );
    }

    InvoiceResult result = new InvoiceResult();
    result.statusCode = res.getStatusCode();
    result.rawRequest = redact(rawRequest);
    result.rawResponse = redact(res.getBody());
    result.invoiceReference = (String) body.get('reference');
    result.paymentUrl = paymentHref(body);
    result.orderReference = findOrderReference(body);

    // A 2xx with no customer-facing link is a failure, not a success.
    if (String.isBlank(result.paymentUrl)) {
      throw NGeniusException.forResponse(
        'N-Genius accepted the invoice but returned no payment link (_links.payment.href was empty).',
        res.getStatusCode(),
        res.getBody()
      );
    }

    // If the gateway echoes a different amount than we sent, something is badly wrong.
    Object echoedTotal = body.get('total');
    if (echoedTotal instanceof Map<String, Object>) {
      Object echoedValue = ((Map<String, Object>) echoedTotal).get('value');
      if (
        echoedValue != null &&
        Decimal.valueOf(String.valueOf(echoedValue)) != sentMinorUnits
      ) {
        throw NGeniusException.forResponse(
          'N-Genius echoed a different amount (' +
            String.valueOf(echoedValue) +
            ' minor units) than was sent (' +
            sentMinorUnits +
            '). Check the N-Genius portal and cancel this link before retrying.',
          res.getStatusCode(),
          res.getBody()
        );
      }
    }
    return result;
  }

  private static String paymentHref(Map<String, Object> body) {
    Object links = body.get('_links');
    if (!(links instanceof Map<String, Object>)) {
      return null;
    }
    Object payment = ((Map<String, Object>) links).get('payment');
    if (!(payment instanceof Map<String, Object>)) {
      return null;
    }
    return (String) ((Map<String, Object>) payment).get('href');
  }

  /**
   * The order reference (the key webhooks and the order-status API use) is not
   * consistently documented on the invoice response — parse defensively and accept null.
   * TODO: confirm the actual location against real N-Genius sandbox traffic.
   */
  private static String findOrderReference(Map<String, Object> body) {
    Object direct = body.get('orderReference');
    if (direct instanceof String && String.isNotBlank((String) direct)) {
      return (String) direct;
    }
    Object embedded = body.get('_embedded');
    if (!(embedded instanceof Map<String, Object>)) {
      return null;
    }
    Object orderNode = ((Map<String, Object>) embedded).get('order');
    if (orderNode instanceof List<Object>) {
      List<Object> orders = (List<Object>) orderNode;
      if (!orders.isEmpty() && orders[0] instanceof Map<String, Object>) {
        return (String) ((Map<String, Object>) orders[0]).get('reference');
      }
      return null;
    }
    if (orderNode instanceof Map<String, Object>) {
      return (String) ((Map<String, Object>) orderNode).get('reference');
    }
    return null;
  }

  // ---- helpers ----------------------------------------------------------------------

  /** AED 25,000.00 -> 2500000. Decimal only, never Double. */
  @TestVisible
  private static Integer toMinorUnits(Decimal amount) {
    return (amount.setScale(2, System.RoundingMode.HALF_UP) * 100).intValue();
  }

  private static String formatDate(Date d) {
    return Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0))
      .format('yyyy-MM-dd');
  }

  /** Public seam for callers that persist bodies (e.g. the controller's error logging). */
  public static String redactForLog(String text) {
    return redact(text);
  }

  /** Strips everything that must never land in a log field. */
  @TestVisible
  private static String redact(String text) {
    if (text == null) {
      return null;
    }
    String out = text;
    out = out.replaceAll(
      '(?i)("access_token"\\s*:\\s*")[^"]*(")',
      '$1[REDACTED]$2'
    );
    out = out.replaceAll(
      '(?i)("refresh_token"\\s*:\\s*")[^"]*(")',
      '$1[REDACTED]$2'
    );
    out = out.replaceAll('(?i)(Bearer\\s+)[A-Za-z0-9._\\-]+', '$1[REDACTED]');
    out = out.replaceAll('(?i)(Basic\\s+)[A-Za-z0-9+/=]+', '$1[REDACTED]');
    out = out.replaceAll('\\b[0-9]{13,19}\\b', '[REDACTED-PAN]');
    return out.length() > LOG_MAX_CHARS
      ? out.substring(0, LOG_MAX_CHARS) + '...[truncated]'
      : out;
  }
}
