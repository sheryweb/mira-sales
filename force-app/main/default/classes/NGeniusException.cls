/**
 * NGeniusException — carries the HTTP status and raw body of a failed N-Genius call.
 *
 * Apex exception subclasses inherit their constructors implicitly, so this class declares
 * NO constructor and never chains with this(...). Build instances through forResponse().
 *
 * The raw body may contain access tokens — it must never reach the UI. userMessage() is
 * the only thing shown to users.
 */
public class NGeniusException extends Exception {
  public Integer statusCode;
  public String responseBody;
  /** Specific reason extracted from the gateway's errors[] — safe text only, never the raw body. */
  public String gatewayDetail;

  public static NGeniusException forResponse(
    String message,
    Integer statusCode,
    String body
  ) {
    NGeniusException e = new NGeniusException(message); // implicit constructor
    e.statusCode = statusCode;
    e.responseBody = body;
    e.gatewayDetail = extractDetail(body);
    return e;
  }

  /** Pulls only errors[].message / message out of the gateway's error body. */
  private static String extractDetail(String body) {
    if (String.isBlank(body)) {
      return null;
    }
    try {
      Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(
        body
      );
      List<String> details = new List<String>();
      Object errorList = parsed.get('errors');
      if (errorList instanceof List<Object>) {
        for (Object entry : (List<Object>) errorList) {
          if (entry instanceof Map<String, Object>) {
            String detail = (String) ((Map<String, Object>) entry)
              .get('message');
            if (String.isNotBlank(detail)) {
              details.add(detail);
            }
          }
        }
      }
      if (details.isEmpty() && parsed.get('message') instanceof String) {
        details.add((String) parsed.get('message'));
      }
      return details.isEmpty()
        ? null
        : String.join(details, ' ').abbreviate(300);
    } catch (Exception ignored) {
      return null; // not JSON, or an unexpected shape — the generic text stands
    }
  }

  /** Short, user-safe text. The raw response body never leaks into this. */
  public String userMessage() {
    if (statusCode == null) {
      return getMessage();
    }
    if (statusCode >= 200 && statusCode < 300) {
      return getMessage(); // 2xx failures carry a specific message already
    }
    if (statusCode == 401) {
      return 'N-Genius rejected the credentials (HTTP 401) — the API key may have been rotated or revoked. Ask an admin to check the NGenius External Credential.';
    }
    if (statusCode == 403) {
      return 'N-Genius refused the request (HTTP 403) — Pay-by-Link may not be enabled on this outlet, or the outlet reference is wrong.';
    }
    if (statusCode == 400 || statusCode == 422) {
      // Show the gateway's own reason when one was extracted — a generic hint
      // sent people chasing the wrong fields (e.g. the SMS-feature-disabled 422).
      return String.isNotBlank(gatewayDetail)
        ? 'N-Genius rejected the request (HTTP ' +
          statusCode +
          '): ' +
          gatewayDetail
        : 'N-Genius rejected the request (HTTP ' +
          statusCode +
          ') — check the email address, amount and expiry date.';
    }
    if (statusCode == 404) {
      return 'N-Genius endpoint or outlet not found (HTTP 404) — check the outlet reference and Named Credential URL.';
    }
    return 'N-Genius returned an unexpected error (HTTP ' +
      statusCode +
      '), details logged.';
  }
}
