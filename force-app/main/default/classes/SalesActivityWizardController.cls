/**
 * SalesActivityWizardController — Apex for the salesActivityWizard LWC, the guided
 * "Record Activity" entry for Sales_Activity_Tracker__c (the standard New button stays
 * untouched while the wizard is being trialled).
 *
 * Server-side rules mirror the wizard UI (decided with Sheraz 2026-08-19):
 *  - Agency is ALWAYS required — every activity is agency-facing, even client meetings.
 *  - Client is ALWAYS optional (Account record type 'Client').
 *  - Description and start/end times are required; end must be after start and the
 *    duration is capped at 16 hours — the old free-form pickers produced negative and
 *    >24h "meetings" (41 and 44 records respectively as of 2026-08-19).
 *  - Number of agents: required (≥1) for Agency Briefing, optional for Client Meeting.
 */
public with sharing class SalesActivityWizardController {

    @TestVisible private static final Integer MAX_DURATION_HOURS = 16;
    private static final Integer SEARCH_LIMIT = 12;

    public class InitData {
        @AuraEnabled public List<String> activities;
        @AuraEnabled public List<String> types;
        @AuraEnabled public String defaultActivity;
        @AuraEnabled public String defaultType;
        @AuraEnabled public List<String> rmNames;
        @AuraEnabled public Integer weekCount;
        @AuraEnabled public String userName;
    }

    public class AccountOption {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
    }

    /** All-String on purpose: Id fields in Apex wrappers arrive null from LWC. */
    public class ActivityInput {
        @AuraEnabled public String activity   { get; set; }
        @AuraEnabled public String activityType { get; set; }
        @AuraEnabled public String agencyId   { get; set; }
        @AuraEnabled public String clientId   { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String startDateTime { get; set; } // ISO-8601 from the LWC
        @AuraEnabled public String endDateTime   { get; set; }
        @AuraEnabled public Integer numberOfAgents { get; set; }
        @AuraEnabled public List<String> rmsAttended { get; set; }
    }

    public class SaveResult {
        @AuraEnabled public String recordId;
        @AuraEnabled public String recordName;
        @AuraEnabled public Integer weekCount;
    }

    @AuraEnabled(cacheable=true)
    public static InitData getInitData() {
        InitData d = new InitData();
        d.activities = new List<String>();
        d.types = new List<String>();
        d.rmNames = new List<String>();
        for (Schema.PicklistEntry e : Sales_Activity_Tracker__c.Activity__c.getDescribe().getPicklistValues()) {
            if (!e.isActive()) continue;
            d.activities.add(e.getValue());
            if (e.isDefaultValue()) d.defaultActivity = e.getValue();
        }
        for (Schema.PicklistEntry e : Sales_Activity_Tracker__c.Type__c.getDescribe().getPicklistValues()) {
            if (!e.isActive()) continue;
            d.types.add(e.getValue());
            if (e.isDefaultValue()) d.defaultType = e.getValue();
        }
        for (Schema.PicklistEntry e : Sales_Activity_Tracker__c.RMs_Attended__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) d.rmNames.add(e.getValue());
        }
        d.weekCount = myWeekCount();
        d.userName = UserInfo.getFirstName();
        return d;
    }

    @AuraEnabled(cacheable=true)
    public static List<AccountOption> searchAgencies(String term) {
        return toOptions([
            SELECT Id, Name FROM Account
            WHERE Type = 'Agency' AND Status__c = 'Completed'
              AND Name LIKE :likeTerm(term)
            ORDER BY Name LIMIT :SEARCH_LIMIT
        ]);
    }

    @AuraEnabled(cacheable=true)
    public static List<AccountOption> searchClients(String term) {
        return toOptions([
            SELECT Id, Name FROM Account
            WHERE RecordType.DeveloperName = 'Client'
              AND Name LIKE :likeTerm(term)
            ORDER BY Name LIMIT :SEARCH_LIMIT
        ]);
    }

    @AuraEnabled
    public static SaveResult saveActivity(ActivityInput input) {
        if (input == null) throw err('Nothing to save.');
        if (String.isBlank(input.activity)) {
            throw err('Please choose the activity.');
        }
        if (String.isBlank(input.activityType)) {
            throw err('Please choose Inbound, Outbound or Online.');
        }
        if (String.isBlank(input.agencyId)) {
            throw err('Please select the agency — every activity is held via an agency.');
        }
        if (String.isBlank(input.description) || input.description.trim().length() < 10) {
            throw err('Please describe what was discussed (at least a short sentence).');
        }
        Datetime startDt = parseDt(input.startDateTime, 'start time');
        Datetime endDt = parseDt(input.endDateTime, 'end time');
        if (endDt <= startDt) {
            throw err('The end time must be after the start time.');
        }
        if (startDt.addHours(MAX_DURATION_HOURS) < endDt) {
            throw err('An activity cannot be longer than ' + MAX_DURATION_HOURS + ' hours. Please check the times.');
        }
        if (input.activity == 'Agency Briefing'
                && (input.numberOfAgents == null || input.numberOfAgents < 1)) {
            throw err('Please enter how many agents attended the briefing.');
        }

        Sales_Activity_Tracker__c rec = new Sales_Activity_Tracker__c(
            Activity__c = input.activity,
            Type__c = input.activityType,
            Agency__c = (Id) input.agencyId,
            Client__c = String.isBlank(input.clientId) ? null : (Id) input.clientId,
            Description__c = input.description.trim(),
            Start_Date_Time__c = startDt,
            End_Date_Time__c = endDt,
            Number_of_Agents__c = input.numberOfAgents,
            RMs_Attended__c = (input.rmsAttended == null || input.rmsAttended.isEmpty())
                ? null : String.join(input.rmsAttended, ';')
        );
        try {
            insert rec;
        } catch (Exception e) {
            throw err('The activity could not be saved: ' + e.getMessage());
        }

        SaveResult r = new SaveResult();
        r.recordId = rec.Id;
        r.recordName = [SELECT Name FROM Sales_Activity_Tracker__c WHERE Id = :rec.Id].Name;
        r.weekCount = myWeekCount();
        return r;
    }

    // ---- helpers -----------------------------------------------------------------

    private static Integer myWeekCount() {
        return [
            SELECT COUNT() FROM Sales_Activity_Tracker__c
            WHERE OwnerId = :UserInfo.getUserId() AND CreatedDate = THIS_WEEK
        ];
    }

    private static String likeTerm(String term) {
        return '%' + (term == null ? '' : String.escapeSingleQuotes(term.trim())) + '%';
    }

    private static List<AccountOption> toOptions(List<Account> accounts) {
        List<AccountOption> opts = new List<AccountOption>();
        for (Account a : accounts) {
            AccountOption o = new AccountOption();
            o.id = a.Id;
            o.name = a.Name;
            opts.add(o);
        }
        return opts;
    }

    private static Datetime parseDt(String iso, String label) {
        if (String.isBlank(iso)) {
            throw err('Please set the ' + label + '.');
        }
        try {
            return (Datetime) JSON.deserialize('"' + iso + '"', Datetime.class);
        } catch (Exception e) {
            throw err('The ' + label + ' is not a valid date/time.');
        }
    }

    /** AuraHandledException only carries its message to getMessage() when set explicitly. */
    private static AuraHandledException err(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}
