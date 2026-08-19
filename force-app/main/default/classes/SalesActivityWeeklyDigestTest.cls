/**
 * Tests for SalesActivityWeeklyDigest. Asserts on the PREPARED messages (lastPrepared) —
 * actual delivery is swallowed because sandbox deliverability may be off.
 */
@IsTest
private class SalesActivityWeeklyDigestTest {

    @IsTest
    static void digestGroupsTeamUnderManagerAndFlagsZeroLoggers() {
        Profile rmProfile = [SELECT Id FROM Profile WHERE Name = 'Sales Manager MIRA' LIMIT 1];
        Long stamp = System.currentTimeMillis();
        User manager = new User(
            Alias = 'digm', Email = 'digest.manager@miradevelopments.ae.test',
            EmailEncodingKey = 'UTF-8', LastName = 'DigestManager', LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', ProfileId = rmProfile.Id, TimeZoneSidKey = 'Asia/Dubai',
            Username = 'digest.manager.' + stamp + '@miradevelopments.ae.test'
        );
        User activeRm;
        User quietRm;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert manager;
            activeRm = new User(
                Alias = 'diga', Email = 'digest.active@miradevelopments.ae.test',
                EmailEncodingKey = 'UTF-8', LastName = 'DigestActive', LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US', ProfileId = rmProfile.Id, TimeZoneSidKey = 'Asia/Dubai',
                Username = 'digest.active.' + stamp + '@miradevelopments.ae.test',
                ManagerId = manager.Id
            );
            quietRm = new User(
                Alias = 'digq', Email = 'digest.quiet@miradevelopments.ae.test',
                EmailEncodingKey = 'UTF-8', LastName = 'DigestQuiet', LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US', ProfileId = rmProfile.Id, TimeZoneSidKey = 'Asia/Dubai',
                Username = 'digest.quiet.' + stamp + '@miradevelopments.ae.test',
                ManagerId = manager.Id
            );
            insert new List<User>{ activeRm, quietRm };
        }

        // one 2h briefing last week, owned by the active RM
        Datetime lastWeek = Datetime.newInstance(
            Date.today().toStartOfWeek().addDays(-6), Time.newInstance(10, 0, 0, 0));
        insert new Sales_Activity_Tracker__c(
            OwnerId = activeRm.Id,
            Activity__c = 'Agency Briefing', Type__c = 'Inbound',
            Description__c = 'Digest test briefing', Outcome__c = 'Strong Interest',
            Start_Date_Time__c = lastWeek, End_Date_Time__c = lastWeek.addHours(2),
            Number_of_Agents__c = 4
        );

        Test.startTest();
        Integer prepared = SalesActivityWeeklyDigest.sendDigests();
        Test.stopTest();

        System.assert(prepared >= 1, 'At least our manager gets a digest');
        Messaging.SingleEmailMessage ours;
        for (Messaging.SingleEmailMessage m : SalesActivityWeeklyDigest.lastPrepared) {
            if (m.getToAddresses()[0] == 'digest.manager@miradevelopments.ae.test') ours = m;
        }
        System.assertNotEquals(null, ours, 'Digest addressed to the line manager');
        String body = ours.getHtmlBody();
        System.assert(body.contains('DigestActive'), 'Active RM row present');
        System.assert(body.contains('2.0'), 'Two hours of field time shown');
        System.assert(body.contains('Strong Interest: 1'), 'Outcome totals shown');
        System.assert(body.contains('Logged nothing last week'), 'Zero-logger section present');
        System.assert(body.contains('DigestQuiet'), 'Quiet RM named');
    }

    @IsTest
    static void schedulableRunsEndToEnd() {
        Test.startTest();
        String jobId = System.schedule('Digest test run ' + System.currentTimeMillis(),
            '0 0 7 ? * MON', new SalesActivityWeeklyDigest());
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'Job scheduled');
    }
}
