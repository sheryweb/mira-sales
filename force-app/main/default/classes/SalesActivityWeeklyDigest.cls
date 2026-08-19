/**
 * SalesActivityWeeklyDigest — Monday-morning email to each line manager: their team's
 * last-week tracker activity (counts, hours, briefings/meetings, outcomes) and, just as
 * important, who logged nothing.
 *
 * Schedule (weekly, Monday 07:00 org time):
 *   System.schedule('Sales Activity Weekly Digest', '0 0 7 ? * MON', new SalesActivityWeeklyDigest());
 *
 * "Team" = active users on the tracker profiles grouped by User.ManagerId; the week is
 * last Monday 00:00 → this Monday 00:00, keyed off Start_Date_Time__c. Send failures are
 * swallowed (the working sandbox has deliverability off) — the digest count returned is
 * "prepared", not "delivered".
 */
public without sharing class SalesActivityWeeklyDigest implements Schedulable {

    @TestVisible private static final Set<String> TRACKER_PROFILES = new Set<String>{
        'Sales Manager MIRA', 'Sales Director MIRA', 'Agency Relationship Manager - Limited'
    };
    @TestVisible private static List<Messaging.SingleEmailMessage> lastPrepared;

    public void execute(SchedulableContext sc) {
        sendDigests();
    }

    private class RmStats {
        Integer activities = 0;
        Integer briefings = 0;
        Integer meetings = 0;
        Decimal hours = 0;
        Map<String, Integer> outcomes = new Map<String, Integer>();
    }

    /** Builds and sends one email per line manager. Returns how many were prepared. */
    public static Integer sendDigests() {
        Date thisMonday = Date.today().toStartOfWeek();
        Datetime endDt = Datetime.newInstance(thisMonday, Time.newInstance(0, 0, 0, 0));
        Datetime startDt = endDt.addDays(-7);

        // the RM population, grouped under their line manager
        Map<Id, List<User>> teamByManager = new Map<Id, List<User>>();
        Map<Id, User> managers = new Map<Id, User>();
        for (User u : [
            SELECT Id, Name, ManagerId, Manager.Name, Manager.Email
            FROM User
            WHERE IsActive = true AND Profile.Name IN :TRACKER_PROFILES
              AND ManagerId != null AND Manager.Email != null
        ]) {
            if (!teamByManager.containsKey(u.ManagerId)) {
                teamByManager.put(u.ManagerId, new List<User>());
                managers.put(u.ManagerId, u.Manager);
            }
            teamByManager.get(u.ManagerId).add(u);
        }

        // last week's activity per owner
        Map<Id, RmStats> statsByOwner = new Map<Id, RmStats>();
        for (Sales_Activity_Tracker__c t : [
            SELECT OwnerId, Activity__c, Outcome__c, Start_Date_Time__c, End_Date_Time__c
            FROM Sales_Activity_Tracker__c
            WHERE Start_Date_Time__c >= :startDt AND Start_Date_Time__c < :endDt
            LIMIT 10000
        ]) {
            RmStats s = statsByOwner.get(t.OwnerId);
            if (s == null) {
                s = new RmStats();
                statsByOwner.put(t.OwnerId, s);
            }
            s.activities++;
            if (t.Activity__c == 'Agency Briefing') s.briefings++;
            else s.meetings++;
            if (t.End_Date_Time__c != null && t.End_Date_Time__c > t.Start_Date_Time__c) {
                s.hours += (Decimal) (t.End_Date_Time__c.getTime() - t.Start_Date_Time__c.getTime()) / 3600000;
            }
            if (String.isNotBlank(t.Outcome__c)) {
                Integer c = s.outcomes.get(t.Outcome__c);
                s.outcomes.put(t.Outcome__c, c == null ? 1 : c + 1);
            }
        }

        String range = startDt.date().format() + ' – ' + endDt.date().addDays(-1).format();
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (Id managerId : teamByManager.keySet()) {
            User manager = managers.get(managerId);
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ manager.Email });
            mail.setSubject('Sales activity digest — your team, ' + range);
            mail.setHtmlBody(buildBody(manager.Name, teamByManager.get(managerId), statsByOwner, range));
            mail.setSaveAsActivity(false);
            mails.add(mail);
        }
        lastPrepared = mails;

        if (!mails.isEmpty()) {
            try {
                Messaging.sendEmail(mails, false);
            } catch (Exception e) {
                // deliverability may be off (sandboxes) — the digest must never break the scheduler
                System.debug(LoggingLevel.WARN, 'Digest send failed: ' + e.getMessage());
            }
        }
        return mails.size();
    }

    private static String buildBody(String managerName, List<User> team,
                                    Map<Id, RmStats> statsByOwner, String range) {
        String rows = '';
        String zeroLoggers = '';
        Map<String, Integer> teamOutcomes = new Map<String, Integer>();
        for (User rm : team) {
            RmStats s = statsByOwner.get(rm.Id);
            if (s == null) {
                zeroLoggers += '<li>' + rm.Name.escapeHtml4() + '</li>';
                continue;
            }
            rows += '<tr><td style="padding:6px 10px;border-bottom:1px solid #e2ebee;">' + rm.Name.escapeHtml4() + '</td>'
                + '<td style="padding:6px 10px;border-bottom:1px solid #e2ebee;text-align:right;">' + s.activities + '</td>'
                + '<td style="padding:6px 10px;border-bottom:1px solid #e2ebee;text-align:right;">' + s.briefings + '</td>'
                + '<td style="padding:6px 10px;border-bottom:1px solid #e2ebee;text-align:right;">' + s.meetings + '</td>'
                + '<td style="padding:6px 10px;border-bottom:1px solid #e2ebee;text-align:right;">' + s.hours.setScale(1) + '</td></tr>';
            for (String o : s.outcomes.keySet()) {
                Integer c = teamOutcomes.get(o);
                teamOutcomes.put(o, (c == null ? 0 : c) + s.outcomes.get(o));
            }
        }

        String outcomeLine = '';
        for (String o : teamOutcomes.keySet()) {
            outcomeLine += (outcomeLine == '' ? '' : ' · ') + o.escapeHtml4() + ': ' + teamOutcomes.get(o);
        }

        String body = '<div style="font-family:Arial,sans-serif;color:#114a5a;max-width:620px;">'
            + '<h2 style="margin:0 0 4px;">Sales activity — your team</h2>'
            + '<p style="margin:0 0 16px;color:#51707a;">' + range + '</p>';
        if (rows != '') {
            body += '<table style="border-collapse:collapse;width:100%;font-size:14px;">'
                + '<tr style="background:#f6fafb;"><th style="padding:6px 10px;text-align:left;">RM</th>'
                + '<th style="padding:6px 10px;text-align:right;">Activities</th>'
                + '<th style="padding:6px 10px;text-align:right;">Briefings</th>'
                + '<th style="padding:6px 10px;text-align:right;">Meetings</th>'
                + '<th style="padding:6px 10px;text-align:right;">Hours</th></tr>'
                + rows + '</table>';
            if (outcomeLine != '') {
                body += '<p style="margin:14px 0 0;font-size:13px;"><b>Outcomes:</b> ' + outcomeLine + '</p>';
            }
        } else {
            body += '<p>No activities were logged by your team last week.</p>';
        }
        if (zeroLoggers != '') {
            body += '<p style="margin:16px 0 4px;font-size:13px;color:#b45309;"><b>Logged nothing last week:</b></p>'
                + '<ul style="margin:0;font-size:13px;color:#b45309;">' + zeroLoggers + '</ul>';
        }
        body += '<p style="margin:18px 0 0;font-size:12px;color:#8fa9b1;">Sent automatically every Monday from the Sales Activity Tracker.</p></div>';
        return body;
    }
}
