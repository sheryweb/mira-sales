/**
 * Tests for UnitStatusWizardController — block (Published→Draft) and release (Draft→Published)
 * flows, admin gate, and the published-projects choice list.
 */
@IsTest
private class UnitStatusWizardControllerTest {

    @TestSetup
    static void setup() {
        Project__c p = new Project__c(
            Name = 'USW Project', Description__c = 'Test', District__c = 'Meydan',
            Coordinates_Latitude__c = 1, Coordinates_Longitude__c = 1, Handover__c = Date.today(),
            Publish_Project__c = 'Published'
        );
        insert p;

        // Validation rule: new units must be created as Draft, then the status may change.
        Unit__c avail = new Unit__c(
            Title__c = 'USW-AVAIL', Project__c = p.Id, Status__c = 'Draft',
            Cost_AED__c = 1000000, Building__c = 'A'
        );
        Unit__c blocked = new Unit__c(
            Title__c = 'USW-BLOCKED', Project__c = p.Id, Status__c = 'Draft',
            Cost_AED__c = 2000000, Building__c = 'B'
        );
        insert new List<Unit__c>{ avail, blocked };
        avail.Status__c = 'Published';
        update avail;
    }

    @IsTest
    static void initListsPublishedProjects() {
        UnitStatusWizardController.InitData d = UnitStatusWizardController.getInitData();
        System.assertEquals(false, d.accessDenied, 'Test admin passes the gate');
        Boolean found = false;
        for (UnitStatusWizardController.ProjectOption o : d.projects) {
            if (o.name == 'USW Project') found = true;
        }
        System.assert(found, 'Published project offered');
    }

    @IsTest
    static void blockModeListsAvailableAndBlocksThem() {
        Id projId = [SELECT Id FROM Project__c WHERE Name = 'USW Project'].Id;
        List<UnitStatusWizardController.UnitRow> rows =
            UnitStatusWizardController.getUnits(projId, 'block');
        System.assertEquals(1, rows.size(), 'Block mode offers Published units only');
        System.assertEquals('USW-AVAIL', rows[0].title);
        System.assertEquals('Available', rows[0].status);

        Integer n = UnitStatusWizardController.updateStatuses(
            new List<String>{ rows[0].id }, 'block');
        System.assertEquals(1, n);
        System.assertEquals('Draft',
            [SELECT Status__c FROM Unit__c WHERE Title__c = 'USW-AVAIL'].Status__c,
            'Blocked = back to Draft');
    }

    @IsTest
    static void releaseModeListsBlockedAndReleasesThem() {
        Id projId = [SELECT Id FROM Project__c WHERE Name = 'USW Project'].Id;
        List<UnitStatusWizardController.UnitRow> rows =
            UnitStatusWizardController.getUnits(projId, 'release');
        System.assertEquals(1, rows.size(), 'Release mode offers Draft units only');
        System.assertEquals('USW-BLOCKED', rows[0].title);
        System.assertEquals('Blocked', rows[0].status);

        Integer n = UnitStatusWizardController.updateStatuses(
            new List<String>{ rows[0].id }, 'release');
        System.assertEquals(1, n);
        System.assertEquals('Published',
            [SELECT Status__c FROM Unit__c WHERE Title__c = 'USW-BLOCKED'].Status__c,
            'Released = Published');
    }

    @IsTest
    static void validationAndModeErrors() {
        Id projId = [SELECT Id FROM Project__c WHERE Name = 'USW Project'].Id;
        try {
            UnitStatusWizardController.updateStatuses(new List<String>(), 'block');
            System.assert(false, 'Empty selection must throw');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        try {
            UnitStatusWizardController.getUnits(projId, 'demolish');
            System.assert(false, 'Unknown mode must throw');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void nonAdminIsDenied() {
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Sales Manager MIRA' LIMIT 1];
        if (profiles.isEmpty()) return; // profile not present in this org — nothing to verify
        User u = new User(
            Alias = 'uswt', Email = 'usw.test@miradevelopments.ae.test',
            EmailEncodingKey = 'UTF-8', LastName = 'USW', LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', ProfileId = profiles[0].Id, TimeZoneSidKey = 'Asia/Dubai',
            Username = 'usw.test.' + System.currentTimeMillis() + '@miradevelopments.ae.test'
        );
        System.runAs(u) {
            System.assertEquals(true, UnitStatusWizardController.getInitData().accessDenied);
            try {
                UnitStatusWizardController.updateStatuses(new List<String>{ 'x' }, 'block');
                System.assert(false, 'Non-admin must not update statuses');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
    }
}
