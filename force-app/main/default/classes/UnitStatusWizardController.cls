/**
 * UnitStatusWizardController — Apex for the unitStatusWizard LWC, replacing the
 * Block_Multiple_Units and Release_Multiple_Units screen flows (both kept active as rollback).
 * One controller, two modes:
 *
 *   block   — Published ("Available") units of a project → Status__c 'Draft' ("Blocked")
 *   release — Draft ("Blocked") units of a project → Status__c 'Published' ("Available")
 *
 * System Administrator only, enforced server-side on every method (the flows' profile gate;
 * the list-view buttons themselves cannot be hidden per profile).
 * Projects offered = Project__c with Publish_Project__c = 'Published', same as the flows'
 * dynamic choice set.
 */
public with sharing class UnitStatusWizardController {

    private static final String MODE_BLOCK = 'block';
    private static final String MODE_RELEASE = 'release';

    public class InitData {
        @AuraEnabled public Boolean accessDenied;
        @AuraEnabled public List<ProjectOption> projects;
    }

    public class ProjectOption {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
    }

    public class UnitRow {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String tower;
        @AuraEnabled public String propertyCode;
        @AuraEnabled public String status;      // Available / Blocked
        @AuraEnabled public String unitType;
        @AuraEnabled public Decimal bedrooms;
    }

    @AuraEnabled(cacheable=true)
    public static InitData getInitData() {
        InitData d = new InitData();
        d.accessDenied = !isAdmin();
        d.projects = new List<ProjectOption>();
        if (d.accessDenied) return d;
        for (Project__c p : [
            SELECT Id, Name FROM Project__c
            WHERE Publish_Project__c = 'Published'
            ORDER BY Name ASC
        ]) {
            ProjectOption o = new ProjectOption();
            o.id = p.Id;
            o.name = p.Name;
            d.projects.add(o);
        }
        return d;
    }

    @AuraEnabled
    public static List<UnitRow> getUnits(String projectId, String mode) {
        assertAdmin();
        String status = statusForSelection(mode);
        if (String.isBlank(projectId)) {
            throw new AuraHandledException('Please select a project first.');
        }
        Id projId = (Id) projectId; // String param per LWC↔Apex Id gotcha
        List<UnitRow> rows = new List<UnitRow>();
        for (Unit__c u : [
            SELECT Id, Title__c, Building__c, Property_Code_Text__c, Status__c,
                   Type_Formula__c, Number_of_Bedrooms__c
            FROM Unit__c
            WHERE Project__c = :projId AND Status__c = :status
            ORDER BY Title__c ASC
        ]) {
            UnitRow r = new UnitRow();
            r.id = u.Id;
            r.title = u.Title__c;
            r.tower = u.Building__c;
            r.propertyCode = u.Property_Code_Text__c;
            r.status = u.Status__c == 'Draft' ? 'Blocked' : 'Available';
            r.unitType = u.Type_Formula__c;
            r.bedrooms = u.Number_of_Bedrooms__c;
            rows.add(r);
        }
        return rows;
    }

    /** Flip the selected units' status, exactly as the flows' single recordUpdates did. */
    @AuraEnabled
    public static Integer updateStatuses(List<String> unitIds, String mode) {
        assertAdmin();
        String targetStatus = statusForSelection(mode) == 'Published' ? 'Draft' : 'Published';
        if (unitIds == null || unitIds.isEmpty()) {
            throw new AuraHandledException('Please select at least 1 unit in order to proceed.');
        }
        List<Unit__c> updates = new List<Unit__c>();
        for (String uid : unitIds) {
            updates.add(new Unit__c(Id = (Id) uid.trim(), Status__c = targetStatus));
        }
        update updates;
        return updates.size();
    }

    // ---- helpers -----------------------------------------------------------------

    /** Which current status a mode selects from: block picks Published, release picks Draft. */
    private static String statusForSelection(String mode) {
        if (mode == MODE_BLOCK) return 'Published';
        if (mode == MODE_RELEASE) return 'Draft';
        throw new AuraHandledException('Unknown mode: ' + mode);
    }

    private static Boolean isAdmin() {
        return [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()].Name
            == 'System Administrator';
    }

    private static void assertAdmin() {
        if (!isAdmin()) {
            throw new AuraHandledException('Insufficient privileges for this operation.');
        }
    }
}
