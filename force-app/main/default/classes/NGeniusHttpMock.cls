/**
 * NGeniusHttpMock — routes on the endpoint (/identity/ vs /invoices/) and serves a queued
 * sequence of responses per endpoint, so the 401-then-retry path is testable. When a queue
 * runs dry the last response repeats.
 */
@IsTest
public class NGeniusHttpMock implements HttpCalloutMock {
  public Integer identityCalls = 0;
  public Integer invoiceCalls = 0;
  public List<String> invoiceRequestBodies = new List<String>();

  private List<Integer> identityStatuses = new List<Integer>();
  private List<String> identityBodies = new List<String>();
  private List<Integer> invoiceStatuses = new List<Integer>();
  private List<String> invoiceBodies = new List<String>();

  public static final String TOKEN_BODY = '{"access_token":"test-access-token-value","expires_in":300,"refresh_token":"test-refresh-token-value","token_type":"bearer"}';

  public static String invoiceBody(Integer minorUnits) {
    return '{"reference":"inv-ref-123","orderReference":"ord-ref-456",' +
      '"_links":{"payment":{"href":"https://paypage.sandbox.ngenius-payments.com/?code=abc123"}},' +
      '"total":{"currencyCode":"AED","value":' +
      minorUnits +
      '}}';
  }

  /** Happy path on both endpoints: token 200, invoice 201 echoing the given amount. */
  public static NGeniusHttpMock happy(Integer minorUnits) {
    NGeniusHttpMock mock = new NGeniusHttpMock();
    mock.queueIdentity(200, TOKEN_BODY);
    mock.queueInvoice(201, invoiceBody(minorUnits));
    return mock;
  }

  public NGeniusHttpMock queueIdentity(Integer status, String body) {
    identityStatuses.add(status);
    identityBodies.add(body);
    return this;
  }

  public NGeniusHttpMock queueInvoice(Integer status, String body) {
    invoiceStatuses.add(status);
    invoiceBodies.add(body);
    return this;
  }

  /** Simulate an unreachable host (surfaces as System.CalloutException). */
  public Boolean throwOnIdentity = false;
  public Boolean throwOnInvoice = false;

  public HttpResponse respond(HttpRequest req) {
    HttpResponse res = new HttpResponse();
    res.setHeader('Content-Type', 'application/json');
    if (req.getEndpoint().contains('/identity/')) {
      if (throwOnIdentity) {
        throw new System.CalloutException('Unable to reach host');
      }
      identityCalls++;
      Integer i = Math.min(identityCalls - 1, identityStatuses.size() - 1);
      res.setStatusCode(identityStatuses[i]);
      res.setBody(identityBodies[i]);
    } else {
      if (throwOnInvoice) {
        throw new System.CalloutException('Unable to reach host');
      }
      invoiceCalls++;
      invoiceRequestBodies.add(req.getBody());
      Integer i = Math.min(invoiceCalls - 1, invoiceStatuses.size() - 1);
      res.setStatusCode(invoiceStatuses[i]);
      res.setBody(invoiceBodies[i]);
    }
    return res;
  }
}
