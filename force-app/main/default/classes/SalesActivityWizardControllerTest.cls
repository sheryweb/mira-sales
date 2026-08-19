/**
 * Tests for SalesActivityWizardController. An Agency account (Type/Status matching the
 * Agency__c lookup filter) and a person Account with the Client record type back the
 * search and save paths.
 */
@IsTest
private class SalesActivityWizardControllerTest {

    @TestSetup
    static void setup() {
        insert new Account(Name = 'Wizard Test Agency', Type = 'Agency', Status__c = 'Completed');
        Id clientRt = [SELECT Id FROM RecordType
                       WHERE SobjectType = 'Account' AND DeveloperName = 'Client' LIMIT 1].Id;
        insert new Account(LastName = 'WizardTestClient', RecordTypeId = clientRt);
    }

    private static SalesActivityWizardController.ActivityInput validInput() {
        SalesActivityWizardController.ActivityInput i = new SalesActivityWizardController.ActivityInput();
        i.activity = 'Agency Briefing';
        i.activityType = 'Inbound';
        i.agencyId = [SELECT Id FROM Account WHERE Name = 'Wizard Test Agency'].Id;
        i.description = 'Briefed the team on the new MIRA Verde launch and payment plans.';
        Datetime start = Datetime.newInstance(2026, 8, 19, 10, 0, 0);
        i.startDateTime = start.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        i.endDateTime = start.addMinutes(90).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        i.numberOfAgents = 8;
        i.rmsAttended = new List<String>();
        i.outcome = 'Strong Interest';
        i.projectsDiscussed = new List<String>();
        return i;
    }

    @IsTest
    static void initDataReturnsPicklistsAndWeekCount() {
        SalesActivityWizardController.InitData d = SalesActivityWizardController.getInitData();
        System.assert(d.activities.contains('Agency Briefing'), 'Activity values from the value set');
        System.assert(d.types.contains('Inbound'), 'Type values from the value set');
        System.assertNotEquals(0, d.rmNames.size(), 'RM names loaded from RMs_Attended__c');
        System.assertEquals(0, d.weekCount, 'No activities logged yet this week');
    }

    @IsTest
    static void searchesFilterByKindOfAccount() {
        List<SalesActivityWizardController.AccountOption> agencies =
            SalesActivityWizardController.searchAgencies('Wizard Test');
        System.assertEquals(1, agencies.size(), 'Only the agency matches');
        System.assertEquals('Wizard Test Agency', agencies[0].name);

        List<SalesActivityWizardController.AccountOption> clients =
            SalesActivityWizardController.searchClients('WizardTestClient');
        System.assertEquals(1, clients.size(), 'Only the client record type matches');

        System.assertEquals(0, SalesActivityWizardController.searchAgencies('WizardTestClient').size(),
            'Client account never appears in the agency search');
    }

    @IsTest
    static void saveCreatesRecordWithAllValues() {
        SalesActivityWizardController.ActivityInput i = validInput();
        i.clientId = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Client' LIMIT 1].Id;
        i.rmsAttended = new List<String>{ 'Abid Gull', 'Ahmad Suleiman' };
        i.projectsDiscussed = new List<String>{
            'Trussardi Residences 2', SalesActivityWizardController.OTHER_PROJECT };
        i.otherProject = 'Marina Launch 2027';

        SalesActivityWizardController.SaveResult r = SalesActivityWizardController.saveActivity(i);

        System.assertNotEquals(null, r.recordId);
        System.assertEquals(1, r.weekCount, 'Week counter includes the new record');
        Sales_Activity_Tracker__c rec = [
            SELECT Activity__c, Type__c, Agency__c, Client__c, Description__c,
                   Start_Date_Time__c, End_Date_Time__c, Number_of_Agents__c, RMs_Attended__c,
                   Outcome__c, Projects_Discussed__c, Other_Project_Discussed__c
            FROM Sales_Activity_Tracker__c WHERE Id = :r.recordId
        ];
        System.assertEquals('Strong Interest', rec.Outcome__c);
        System.assertEquals('Trussardi Residences 2;' + SalesActivityWizardController.OTHER_PROJECT,
            rec.Projects_Discussed__c);
        System.assertEquals('Marina Launch 2027', rec.Other_Project_Discussed__c);
        System.assertEquals('Agency Briefing', rec.Activity__c);
        System.assertEquals('Inbound', rec.Type__c);
        System.assertEquals((Id) i.agencyId, rec.Agency__c);
        System.assertEquals((Id) i.clientId, rec.Client__c);
        System.assertEquals(8, rec.Number_of_Agents__c);
        System.assertEquals('Abid Gull;Ahmad Suleiman', rec.RMs_Attended__c);
        System.assertEquals(90, (rec.End_Date_Time__c.getTime() - rec.Start_Date_Time__c.getTime()) / 60000,
            'Duration preserved');
    }

    @IsTest
    static void clientMeetingNeedsNoAgentCount() {
        SalesActivityWizardController.ActivityInput i = validInput();
        i.activity = 'Client Meeting';
        i.numberOfAgents = null;
        SalesActivityWizardController.SaveResult r = SalesActivityWizardController.saveActivity(i);
        System.assertNotEquals(null, r.recordId, 'Client meeting saves without an agent count');
    }

    @IsTest
    static void followUpDateCreatesTaskOnTheActivity() {
        SalesActivityWizardController.ActivityInput i = validInput();
        i.followUpDate = String.valueOf(Date.today().addDays(3));
        i.followUpNote = 'Send the price list';

        SalesActivityWizardController.SaveResult r = SalesActivityWizardController.saveActivity(i);

        System.assertNotEquals(null, r.followUpDate, 'Follow-up date echoed back');
        List<Task> tasks = [SELECT Subject, ActivityDate, Status, WhatId, Description
                            FROM Task WHERE WhatId = :r.recordId];
        System.assertEquals(1, tasks.size(), 'One follow-up task on the activity');
        System.assertEquals('Follow-up: Wizard Test Agency', tasks[0].Subject);
        System.assertEquals(Date.today().addDays(3), tasks[0].ActivityDate);
        System.assertEquals('Not Started', tasks[0].Status);
        System.assertEquals('Send the price list', tasks[0].Description);
    }

    @IsTest
    static void noFollowUpMeansNoTask() {
        SalesActivityWizardController.SaveResult r =
            SalesActivityWizardController.saveActivity(validInput());
        System.assertEquals(null, r.followUpDate);
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :r.recordId]);
    }

    @IsTest
    static void validationRejectsBadInput() {
        // agency always required — even for client meetings
        SalesActivityWizardController.ActivityInput i = validInput();
        i.activity = 'Client Meeting';
        i.agencyId = null;
        expectError(i, 'agency');

        // description required and must not be trivially short
        i = validInput();
        i.description = 'ok';
        expectError(i, 'describe');

        // end must be after start
        i = validInput();
        i.endDateTime = i.startDateTime;
        expectError(i, 'end time');

        // duration cap
        i = validInput();
        Datetime start = Datetime.newInstance(2026, 8, 19, 10, 0, 0);
        i.endDateTime = start.addHours(SalesActivityWizardController.MAX_DURATION_HOURS + 1)
            .formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        expectError(i, 'longer than');

        // briefing needs an agent count
        i = validInput();
        i.numberOfAgents = 0;
        expectError(i, 'agents');

        // outcome is required
        i = validInput();
        i.outcome = null;
        expectError(i, 'outcome');

        // picking Other / Upcoming Project requires naming it
        i = validInput();
        i.projectsDiscussed = new List<String>{ SalesActivityWizardController.OTHER_PROJECT };
        i.otherProject = '';
        expectError(i, 'name the project');

        // follow-up date cannot be in the past
        i = validInput();
        i.followUpDate = String.valueOf(Date.today().addDays(-1));
        expectError(i, 'past');
    }

    private static void expectError(SalesActivityWizardController.ActivityInput i, String messagePart) {
        try {
            SalesActivityWizardController.saveActivity(i);
            System.assert(false, 'Expected a validation error mentioning "' + messagePart + '"');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().toLowerCase().contains(messagePart.toLowerCase()),
                'Error should mention "' + messagePart + '" but was: ' + e.getMessage());
        }
    }
}
