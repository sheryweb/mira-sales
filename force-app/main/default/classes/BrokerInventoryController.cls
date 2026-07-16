public without sharing class BrokerInventoryController extends BrokerLoginController {

    // Bound to the project filter dropdown ('' = All)
    public String selectedProjectId { get; set; }

    public class UnitRow {
        public Id unitId { get; set; }
        public String title { get; set; }
        public String location { get; set; }
        public String price { get; set; }
        public String specs { get; set; }
    }

    // Dropdown: "All Projects" + every published project
    public List<SelectOption> getProjectOptions() {
        List<SelectOption> opts = new List<SelectOption>();
        opts.add(new SelectOption('', 'All Projects'));
        if (isValidSession()) {
            for (Project__c p : [
                SELECT Id, Name FROM Project__c WHERE Publish_Project__c = 'Published' ORDER BY Name
            ]) {
                opts.add(new SelectOption(p.Id, p.Name));
            }
        }
        return opts;
    }

    private List<Unit__c> queryUnits() {
        if (!isValidSession()) return new List<Unit__c>();
        // Available units in published projects, optionally filtered to one project
        if (String.isBlank(selectedProjectId)) {
            return [
                SELECT Name, Title__c, Building__c, Cost_AED__c, Project__r.Name,
                       Number_of_Bedrooms__c, Number_of_Bathrooms__c, Total_Area__c
                FROM Unit__c
                WHERE Status__c = 'Published' AND Project__r.Publish_Project__c = 'Published'
                ORDER BY Project__r.Name, CreatedDate DESC
            ];
        }
        return [
            SELECT Name, Title__c, Building__c, Cost_AED__c, Project__r.Name,
                   Number_of_Bedrooms__c, Number_of_Bathrooms__c, Total_Area__c
            FROM Unit__c
            WHERE Status__c = 'Published' AND Project__r.Publish_Project__c = 'Published'
              AND Project__c = :selectedProjectId
            ORDER BY CreatedDate DESC
        ];
    }

    public List<UnitRow> getUnits() {
        List<UnitRow> rows = new List<UnitRow>();
        for (Unit__c u : queryUnits()) {
            UnitRow r = new UnitRow();
            r.unitId = u.Id;
            r.title = String.isBlank(u.Title__c) ? u.Name : u.Title__c;
            r.location = buildLocation((u.Project__r != null ? u.Project__r.Name : null), u.Building__c);
            r.price = (u.Cost_AED__c == null) ? '' : 'AED ' + u.Cost_AED__c.setScale(0).format();
            r.specs = buildSpecs(u.Number_of_Bedrooms__c, u.Number_of_Bathrooms__c, u.Total_Area__c);
            rows.add(r);
        }
        return rows;
    }

    // ---- Sales Offer: server fetches an access token; the BROWSER calls the PDF endpoint ----
    // Server-side Apex cannot call our own org's render endpoint (Salesforce "callout loop"), so the
    // controller only mints the token (password flow, integration user) and the page's browser fetches
    // the PDF with it. The token is for a dedicated integration user (treat it as low-privilege).

    public String offerUnitId { get; set; }            // unit whose offer is requested
    public String offerCurrency { get; set; }          // optional secondary currency (blank = none)
    public transient String offerToken  { get; private set; }   // bearer token handed to the browser
    public transient String offerApiUrl { get; private set; }   // full endpoint URL the browser calls
    public transient String offerError  { get; private set; }   // non-blank => something went wrong
    @TestVisible private static Sales_Offer_Auth__mdt configOverride;   // test seam (no CMT DML in tests)

    public void prepareOffer() {
        offerToken = null; offerApiUrl = null; offerError = null;
        Id unitId = validatedOfferUnitId();
        if (unitId == null) { offerError = 'This unit is not available.'; return; }

        Sales_Offer_Auth__mdt cfg = loadAuthConfig();
        if (cfg == null || String.isBlank(cfg.Token_Url__c)) {
            offerError = 'Sales Offer generation is not configured yet. Please contact MIRA.';
            return;
        }
        String token;
        try { token = fetchAccessToken(cfg); } catch (Exception e) { token = null; }
        if (String.isBlank(token)) {
            offerError = 'Could not authenticate to generate the offer. Please try again or contact MIRA.';
            return;
        }
        offerToken = token;
        offerApiUrl = cfg.Token_Url__c.substringBefore('/services')
            + '/services/apexrest/generateSalesOfferPdf?unitId=' + unitId;
        if (String.isNotBlank(offerCurrency)) {
            offerApiUrl += '&sCurrency=' + EncodingUtil.urlEncode(offerCurrency, 'UTF-8');
        }
    }

    // OAuth password flow -> access token for the integration user that renders the offer.
    private String fetchAccessToken(Sales_Offer_Auth__mdt cfg) {
        HttpRequest tok = new HttpRequest();
        tok.setEndpoint(cfg.Token_Url__c);
        tok.setMethod('POST');
        tok.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        tok.setTimeout(120000);
        tok.setBody('grant_type=password'
            + '&client_id='     + EncodingUtil.urlEncode(nz(cfg.Client_Id__c), 'UTF-8')
            + '&client_secret=' + EncodingUtil.urlEncode(nz(cfg.Client_Secret__c), 'UTF-8')
            + '&username='      + EncodingUtil.urlEncode(nz(cfg.Username__c), 'UTF-8')
            + '&password='      + EncodingUtil.urlEncode(nz(cfg.Password__c), 'UTF-8'));
        HttpResponse res = new Http().send(tok);
        if (res.getStatusCode() != 200) return null;
        Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) m.get('access_token');
    }

    private Sales_Offer_Auth__mdt loadAuthConfig() {
        if (configOverride != null) return configOverride;
        List<Sales_Offer_Auth__mdt> cfgs = [
            SELECT Client_Id__c, Client_Secret__c, Username__c, Password__c, Token_Url__c
            FROM Sales_Offer_Auth__mdt LIMIT 1
        ];
        return cfgs.isEmpty() ? null : cfgs[0];
    }

    private static String nz(String s) { return s == null ? '' : s; }

    // The unit must belong to the available (Published) inventory the broker is allowed to see.
    private Id validatedOfferUnitId() {
        if (!isValidSession() || String.isBlank(offerUnitId)) return null;
        Id unitId;
        try { unitId = Id.valueOf(offerUnitId); } catch (Exception e) { return null; }
        Boolean ok = ![
            SELECT Id FROM Unit__c
            WHERE Id = :unitId AND Status__c = 'Published' AND Project__r.Publish_Project__c = 'Published'
            LIMIT 1
        ].isEmpty();
        return ok ? unitId : null;
    }

    public Boolean getHasUnits() { return !queryUnits().isEmpty(); }

    private String buildLocation(String project, String building) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(project)) parts.add(project);
        if (String.isNotBlank(building)) parts.add(building);
        return String.join(parts, ' • ');
    }

    private String buildSpecs(Decimal beds, Decimal baths, Decimal area) {
        List<String> parts = new List<String>();
        if (beds != null)  parts.add(beds == 0 ? 'Studio' : beds.stripTrailingZeros().toPlainString() + ' Bed');
        if (baths != null) parts.add(baths.stripTrailingZeros().toPlainString() + ' Bath');
        if (area != null)  parts.add(area.setScale(0).format() + ' sqft');
        return String.join(parts, '  •  ');
    }
}