/**
 * Tests for CurrencyService and CurrencyRatesRefreshJob.
 * Custom-setting rates use round numbers (CHF 0.2/AED = x5, USD 0.25/AED = x4)
 * so conversion expectations are exact; org-table fallback expectations are
 * computed from the org's own CurrencyType so they hold in any org.
 */
@IsTest
private class CurrencyServiceTest {

    private static final String GOOD_BODY =
        '{"result":"success","rates":{"AED":1,"CHF":0.21,"USD":0.2723,"EUR":0.2338,' +
        '"GBP":0.2015,"RUB":20.88,"GEL":0.74}}';

    private class FxMock implements HttpCalloutMock {
        private final Integer status;
        private final String body;
        private FxMock(Integer status, String body) {
            this.status = status;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals(CurrencyService.ENDPOINT, request.getEndpoint());
            HttpResponse response = new HttpResponse();
            response.setStatusCode(status);
            response.setBody(body);
            return response;
        }
    }

    private static void seedSettings() {
        insert new List<Currency_Exchange_Rate__c>{
            new Currency_Exchange_Rate__c(
                Name = 'CHF', Rate_Per_AED__c = 0.2,
                Last_Refreshed__c = Datetime.now(), Source__c = 'test'),
            new Currency_Exchange_Rate__c(
                Name = 'USD', Rate_Per_AED__c = 0.25,
                Last_Refreshed__c = Datetime.now().addHours(-1), Source__c = 'test')
        };
    }

    @IsTest
    static void convertsUsingStoredMarketRates() {
        seedSettings();

        System.assertEquals(7500000, CurrencyService.convertToAed(1500000, 'CHF'), 'CHF at 0.2/AED = x5');
        System.assertEquals(2000000, CurrencyService.convertToAed(500000, 'usd'), 'ISO is case-insensitive');
        System.assertEquals(100, CurrencyService.convertToAed(100, null), 'Blank currency counts as AED');
        System.assertEquals(100, CurrencyService.convertToAed(100, 'AED'), 'AED needs no conversion');
        System.assertEquals(0, CurrencyService.convert(null, 'CHF', 'USD'), 'Null amount reads as zero');

        // cross conversion through AED: 100 CHF = 500 AED = 125 USD
        System.assertEquals(125, CurrencyService.convert(100, 'CHF', 'USD'));

        System.assertNotEquals(null, CurrencyService.lastRefreshed(), 'Newest refresh stamp must surface');
    }

    @IsTest
    static void fallsBackToOrgCurrencyTable() {
        // no custom setting rows at all: known org currencies still convert
        List<CurrencyType> orgCurrencies = [
            SELECT IsoCode, ConversionRate FROM CurrencyType
            WHERE IsActive = true AND IsCorporate = false
            LIMIT 1
        ];
        if (orgCurrencies.isEmpty()) {
            return; // single-currency org: nothing to assert
        }
        CurrencyType fallback = orgCurrencies[0];
        Decimal expected = Decimal.valueOf(100000)
            .divide(fallback.ConversionRate, 8)
            .setScale(2, System.RoundingMode.HALF_UP);
        System.assertEquals(expected, CurrencyService.convertToAed(100000, fallback.IsoCode));
        System.assertEquals(null, CurrencyService.lastRefreshed(), 'No API refresh has happened');
    }

    @IsTest
    static void unknownCurrencyPassesAmountThrough() {
        System.assertEquals(500, CurrencyService.convertToAed(500, 'XXX'));
        System.assertEquals(null, CurrencyService.ratePerAed('XXX'));
    }

    @IsTest
    static void refreshUpsertsRatesFromApi() {
        // stale pre-existing row must be updated in place, missing ones inserted
        insert new Currency_Exchange_Rate__c(Name = 'CHF', Rate_Per_AED__c = 9, Source__c = 'manual');
        Test.setMock(HttpCalloutMock.class, new FxMock(200, GOOD_BODY));

        Test.startTest();
        Integer refreshed = CurrencyService.refreshRates();
        Test.stopTest();

        System.assert(refreshed > 0, 'At least the org currencies must refresh');
        Map<String, Currency_Exchange_Rate__c> rows = new Map<String, Currency_Exchange_Rate__c>();
        for (Currency_Exchange_Rate__c row : Currency_Exchange_Rate__c.getAll().values()) {
            rows.put(row.Name.toUpperCase(), row);
        }
        System.assertEquals(0.21, rows.get('CHF').Rate_Per_AED__c, 'Stale manual rate must be replaced');
        System.assertEquals('open.er-api.com', rows.get('CHF').Source__c);
        System.assert(rows.containsKey('GEL'), 'Extra non-org currencies must be stored too');
        System.assertEquals(1, [SELECT COUNT() FROM Currency_Exchange_Rate__c WHERE Name = 'CHF'],
            'Refresh must update, not duplicate');

        // conversions immediately reflect the refreshed rate: 100 / 0.21
        System.assertEquals(476.19, CurrencyService.convertToAed(100, 'CHF'));
    }

    @IsTest
    static void apiFailureThrowsAndKeepsExistingRates() {
        seedSettings();
        Test.setMock(HttpCalloutMock.class, new FxMock(500, 'boom'));
        Test.startTest(); // fresh context so the seeding DML doesn't block the callout
        try {
            CurrencyService.refreshRates();
            System.assert(false, 'Expected CurrencyServiceException');
        } catch (CurrencyService.CurrencyServiceException e) {
            System.assert(e.getMessage().contains('500'), 'Got: ' + e.getMessage());
        }
        Test.stopTest();
        System.assertEquals(7500000, CurrencyService.convertToAed(1500000, 'CHF'),
            'Previous rates must survive a failed refresh');
    }

    @IsTest
    static void queueableRefreshesRates() {
        Test.setMock(HttpCalloutMock.class, new FxMock(200, GOOD_BODY));
        Test.startTest();
        System.enqueueJob(new CurrencyRatesRefreshJob.RefreshQueueable());
        Test.stopTest();
        System.assert(!Currency_Exchange_Rate__c.getAll().isEmpty(), 'Queueable run must store rates');
    }

    @IsTest
    static void queueableSwallowsApiFailure() {
        Test.setMock(HttpCalloutMock.class, new FxMock(503, 'down'));
        Test.startTest();
        System.enqueueJob(new CurrencyRatesRefreshJob.RefreshQueueable()); // must not throw
        Test.stopTest();
        System.assert(Currency_Exchange_Rate__c.getAll().isEmpty(), 'Nothing stored on failure');
    }

    @IsTest
    static void schedulableRegisters() {
        Test.startTest();
        String jobId = System.schedule('CurrencyRatesRefreshJob test', '0 0 6 * * ?', new CurrencyRatesRefreshJob());
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }
}
