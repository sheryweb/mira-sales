@isTest
private class CommissionEligibilitySchedulerTest {

    @isTest
    static void testSchedulerSchedules() {
        String cron = '0 0 2 * * ?';
        String jobName = 'Test Commission Eligibility ' + String.valueOf(Crypto.getRandomLong());

        Test.startTest();
        String jobId = System.schedule(jobName, cron, new CommissionEligibilityScheduler());
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Scheduler should produce a job Id');

        CronTrigger ct = [SELECT Id, CronExpression, NextFireTime FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cron, ct.CronExpression);
    }
}