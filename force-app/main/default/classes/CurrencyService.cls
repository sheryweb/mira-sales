/**
 * Core currency-conversion facility for the whole org (built 2026-08-13).
 * ANY code needing a currency conversion should call this — never hand-roll
 * rates or read rate fields directly.
 *
 * Rate storage: Currency_Exchange_Rate__c list custom setting (Name = ISO code,
 * Rate_Per_AED__c = units of that currency per 1 AED), refreshed daily from a
 * market-rate API by CurrencyRatesRefreshJob. Custom settings are org-cached,
 * so lookups cost no SOQL.
 *
 * Lookup order per currency:
 *   1. Currency_Exchange_Rate__c row (fresh market rate)
 *   2. Org currency table (CurrencyType — AED is the corporate currency, so
 *      ConversionRate is already "units per 1 AED"; same source CURRENCYRATE()
 *      formulas use)
 *   3. Unknown currency: conversions pass the amount through unchanged rather
 *      than guess.
 *
 * All conversions cross through AED. Blank ISO codes count as AED (org
 * business default for blank Project_Currency__c).
 */
public with sharing class CurrencyService {

    public static final String CORPORATE_ISO = 'AED';

    @TestVisible
    private static final String ENDPOINT = 'https://open.er-api.com/v6/latest/' + CORPORATE_ISO;

    /** Non-org currencies the business still converts to (project rate fields). */
    @TestVisible
    private static final Set<String> EXTRA_ISOS = new Set<String>{ 'GEL' };

    private static Map<String, Decimal> ratePerAedCache;
    private static Datetime newestRefresh;

    /** Convenience: convert an amount from the given currency into AED. */
    public static Decimal convertToAed(Decimal amount, String fromIso) {
        return convert(amount, fromIso, CORPORATE_ISO);
    }

    /**
     * Converts between any two known currencies, crossing through AED.
     * Unknown source or target currency returns the amount unchanged (the
     * caller surfaces the raw figure rather than a guessed one).
     */
    public static Decimal convert(Decimal amount, String fromIso, String toIso) {
        if (amount == null) {
            return 0;
        }
        String source = normalize(fromIso);
        String target = normalize(toIso);
        if (amount == 0 || source == target) {
            return amount;
        }
        Decimal sourceRate = ratePerAed(source);
        Decimal targetRate = ratePerAed(target);
        if (sourceRate == null || sourceRate == 0 || targetRate == null || targetRate == 0) {
            return amount;
        }
        Decimal inAed = amount.divide(sourceRate, 8);
        return (inAed * targetRate).setScale(2, System.RoundingMode.HALF_UP);
    }

    /** Units of the given currency per 1 AED, or null when unknown. */
    public static Decimal ratePerAed(String iso) {
        loadRates();
        return ratePerAedCache.get(normalize(iso));
    }

    /** Newest Last_Refreshed__c across the stored market rates (null = API never ran). */
    public static Datetime lastRefreshed() {
        loadRates();
        return newestRefresh;
    }

    /**
     * Pulls current market rates from the FX API and upserts the custom setting
     * rows for every active org currency plus EXTRA_ISOS. Called by
     * CurrencyRatesRefreshJob (daily); safe to run manually. Requires callout
     * context. Throws CurrencyServiceException on API failure — existing rates
     * stay untouched, so consumers keep converting at the last good rates.
     * @return number of currencies refreshed
     */
    public static Integer refreshRates() {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(ENDPOINT);
        request.setMethod('GET');
        request.setTimeout(20000);
        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() != 200) {
            throw new CurrencyServiceException('FX API returned HTTP ' + response.getStatusCode());
        }
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        if ((String) payload.get('result') != 'success') {
            throw new CurrencyServiceException('FX API result was not success: ' + payload.get('result'));
        }
        Map<String, Object> rates = (Map<String, Object>) payload.get('rates');

        Set<String> wanted = new Set<String>(EXTRA_ISOS);
        for (CurrencyType orgCurrency : [SELECT IsoCode FROM CurrencyType WHERE IsActive = true]) {
            wanted.add(orgCurrency.IsoCode);
        }
        wanted.remove(CORPORATE_ISO);

        Map<String, Currency_Exchange_Rate__c> existing = new Map<String, Currency_Exchange_Rate__c>();
        for (Currency_Exchange_Rate__c row : Currency_Exchange_Rate__c.getAll().values()) {
            existing.put(row.Name.toUpperCase(), row);
        }

        List<Currency_Exchange_Rate__c> toUpsert = new List<Currency_Exchange_Rate__c>();
        for (String iso : wanted) {
            Decimal rate = asDecimal(rates.get(iso));
            if (rate == null || rate <= 0) {
                continue; // API doesn't quote this currency; keep whatever we have
            }
            Currency_Exchange_Rate__c row = existing.containsKey(iso)
                ? existing.get(iso)
                : new Currency_Exchange_Rate__c(Name = iso);
            row.Rate_Per_AED__c = rate;
            row.Last_Refreshed__c = Datetime.now();
            row.Source__c = 'open.er-api.com';
            toUpsert.add(row);
        }
        upsert toUpsert;

        // bust the transaction cache so conversions after a refresh use new rates
        ratePerAedCache = null;
        newestRefresh = null;
        return toUpsert.size();
    }

    private static void loadRates() {
        if (ratePerAedCache != null) {
            return;
        }
        ratePerAedCache = new Map<String, Decimal>{ CORPORATE_ISO => 1 };
        for (Currency_Exchange_Rate__c row : Currency_Exchange_Rate__c.getAll().values()) {
            if (row.Rate_Per_AED__c != null && row.Rate_Per_AED__c > 0) {
                ratePerAedCache.put(row.Name.toUpperCase(), row.Rate_Per_AED__c);
                if (row.Last_Refreshed__c != null
                    && (newestRefresh == null || row.Last_Refreshed__c > newestRefresh)) {
                    newestRefresh = row.Last_Refreshed__c;
                }
            }
        }
        for (CurrencyType orgCurrency : [
            SELECT IsoCode, ConversionRate FROM CurrencyType WHERE IsActive = true
        ]) {
            if (!ratePerAedCache.containsKey(orgCurrency.IsoCode)
                && orgCurrency.ConversionRate != null && orgCurrency.ConversionRate > 0) {
                ratePerAedCache.put(orgCurrency.IsoCode, orgCurrency.ConversionRate);
            }
        }
    }

    private static String normalize(String iso) {
        return String.isBlank(iso) ? CORPORATE_ISO : iso.trim().toUpperCase();
    }

    private static Decimal asDecimal(Object raw) {
        if (raw == null) {
            return null;
        }
        if (raw instanceof Decimal) {
            return (Decimal) raw;
        }
        if (raw instanceof Double) {
            return Decimal.valueOf((Double) raw);
        }
        if (raw instanceof Integer) {
            return Decimal.valueOf((Integer) raw);
        }
        return Decimal.valueOf(String.valueOf(raw));
    }

    public class CurrencyServiceException extends Exception {}
}
