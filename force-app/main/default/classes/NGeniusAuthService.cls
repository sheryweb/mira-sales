/**
 * NGeniusAuthService — obtains and caches the N-Genius access token.
 *
 * Token lookup order: in-transaction static, then Platform Cache (partition local.NGenius,
 * TTL 240s — safely under the 300s token life), then a fresh callout. Every Platform Cache
 * call is wrapped in try/catch: Cache.Org.getPartition throws when the partition does not
 * exist, and this must still work in an org without Platform Cache — it just degrades to
 * one token request per transaction.
 *
 * The Basic auth header on the token call is injected by the NGenius_Identity Named
 * Credential (custom header, Generate Authorization Header OFF). The API key never appears
 * in Apex.
 */
public with sharing class NGeniusAuthService {
  private static final String CACHE_PARTITION = 'local.NGenius';
  private static final String CACHE_KEY = 'accessToken';
  private static final Integer CACHE_TTL_SECONDS = 240;
  private static final Integer TIMEOUT_MS = 60000;

  /** In-transaction reuse — the same transaction never requests two tokens. */
  private static String transactionToken;

  public static String getToken() {
    if (String.isNotBlank(transactionToken)) {
      return transactionToken;
    }

    String cached = cacheGet();
    if (String.isNotBlank(cached)) {
      transactionToken = cached;
      return cached;
    }

    String token = requestToken();
    transactionToken = token;
    cachePut(token);
    return token;
  }

  /** Clears both the static and the Platform Cache entry — used on a 401 before the one retry. */
  public static void invalidate() {
    transactionToken = null;
    try {
      Cache.Org.getPartition(CACHE_PARTITION).remove(CACHE_KEY);
    } catch (Exception ignored) {
      // No Platform Cache partition — nothing to clear.
    }
  }

  private static String requestToken() {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(
      'callout:' +
        NGeniusConfig.identityNamedCredential() +
        '/identity/auth/access-token'
    );
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/vnd.ni-identity.v1+json');
    req.setBody(
      JSON.serialize(
        new Map<String, Object>{ 'realmName' => NGeniusConfig.realmName() }
      )
    );
    req.setTimeout(TIMEOUT_MS);

    HttpResponse res;
    try {
      res = new Http().send(req);
    } catch (System.CalloutException e) {
      throw NGeniusException.forResponse(
        'Could not reach the N-Genius identity service — check the Named Credential and Trusted URLs. (' +
          e.getMessage() +
          ')',
        null,
        null
      );
    }

    if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
      throw NGeniusException.forResponse(
        'The N-Genius token request failed with HTTP ' +
          res.getStatusCode() +
          '.',
        res.getStatusCode(),
        res.getBody()
      );
    }

    String token;
    try {
      Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
        res.getBody()
      );
      token = (String) body.get('access_token');
    } catch (Exception e) {
      token = null;
    }
    if (String.isBlank(token)) {
      throw NGeniusException.forResponse(
        'The N-Genius token response did not contain an access token.',
        res.getStatusCode(),
        res.getBody()
      );
    }
    return token;
  }

  private static String cacheGet() {
    try {
      return (String) Cache.Org.getPartition(CACHE_PARTITION).get(CACHE_KEY);
    } catch (Exception ignored) {
      return null; // No partition / no Platform Cache — degrade gracefully.
    }
  }

  private static void cachePut(String token) {
    try {
      Cache.Org.getPartition(CACHE_PARTITION)
        .put(CACHE_KEY, token, CACHE_TTL_SECONDS);
    } catch (Exception ignored) {
      // No partition / no Platform Cache — degrade gracefully.
    }
  }
}
