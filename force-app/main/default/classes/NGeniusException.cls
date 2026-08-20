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

  public static NGeniusException forResponse(
    String message,
    Integer statusCode,
    String body
  ) {
    NGeniusException e = new NGeniusException(message); // implicit constructor
    e.statusCode = statusCode;
    e.responseBody = body;
    return e;
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
      return 'N-Genius rejected the request (HTTP ' +
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
