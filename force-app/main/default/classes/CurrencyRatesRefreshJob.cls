/**
 * Daily refresh of the market FX rates behind CurrencyService.
 *
 * Schedule once (e.g. 06:00 every day):
 *   System.schedule('Daily Currency Rates Refresh', '0 0 6 * * ?', new CurrencyRatesRefreshJob());
 *
 * The schedulable hop enqueues a queueable because scheduled Apex cannot make
 * callouts directly. On API failure the job logs and leaves the previous
 * rates in place — consumers keep converting at the last good rates.
 */
public with sharing class CurrencyRatesRefreshJob implements Schedulable {

    public void execute(SchedulableContext context) {
        System.enqueueJob(new RefreshQueueable());
    }

    /** Separate class because Apex forbids Schedulable+Queueable on one class. */
    public class RefreshQueueable implements Queueable, Database.AllowsCallouts {
        public void execute(QueueableContext context) {
            try {
                Integer refreshed = CurrencyService.refreshRates();
                System.debug(LoggingLevel.INFO, 'CurrencyRatesRefreshJob: refreshed ' + refreshed + ' currencies');
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'CurrencyRatesRefreshJob failed, keeping previous rates: ' + e.getMessage());
            }
        }
    }
}
