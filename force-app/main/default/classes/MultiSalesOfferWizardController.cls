/**
 * MultiSalesOfferWizardController — Apex for the multiSalesOfferWizard LWC, the replacement
 * for the Generate_Multiple_Sales_Offers_Screen flow. Mirrors the flow's behaviour exactly:
 *
 *  - Finance Limited / MIRA Collections profiles are denied.
 *  - Everyone sees Published ("Available") units of the chosen project; System Administrator
 *    and Sales Director MIRA also see Draft ("Blocked") ones.
 *  - Generation delegates to MultipleSalesPDFActionController's page routing and file naming,
 *    so the flow (still active for rollback) and the LWC can never drift apart.
 *
 * Cleanup and generation are separate @AuraEnabled methods because getContentAsPDF is a
 * callout: deleting the previous offer documents in the same transaction would throw
 * "uncommitted work pending". The flow got away with one invocable only because its
 * Automatic transaction model committed the screen navigation beforehand.
 */
public with sharing class MultiSalesOfferWizardController {

    @TestVisible private static final Integer MAX_UNITS = 15;
    private static final Set<String> DENIED_PROFILES =
        new Set<String>{ 'Finance Limited', 'MIRA Collections' };
    private static final Set<String> BLOCKED_VISIBLE_PROFILES =
        new Set<String>{ 'System Administrator', 'Sales Director MIRA' };
    /** Same names, order and default (first) as the flow's radio choices. */
    private static final List<String> PROJECT_NAMES = new List<String>{
        'Trussardi Residences',
        'MIRA Villas Designed by Bentley Home',
        'Trussardi Residences 2',
        'POST HOTEL & RESIDENCES By ELIE SAAB',
        'GIANFRANCO FERRE RESIDENCES',
        'Trussardi Residences 2 Offices',
        'Trussardi Residences MIRA VERDE',
        'John Richmond Residences'
    };

    public class InitData {
        @AuraEnabled public Boolean accessDenied;
        @AuraEnabled public Boolean canSeeBlocked;
        @AuraEnabled public List<String> projectNames;
        @AuraEnabled public List<String> currencies;
        @AuraEnabled public Integer maxUnits;
    }

    public class UnitRow {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String tower;
        @AuraEnabled public String status;      // Available / Blocked, the flow's labels
        @AuraEnabled public String unitType;    // Type_Formula__c (Apartment / Duplex / Villa / Office …)
        @AuraEnabled public String unitCost;    // Unit_Cost__c text, e.g. 'USD 1234567' — price in the project currency
        @AuraEnabled public Decimal bedrooms;
        @AuraEnabled public Decimal totalArea;
    }

    @AuraEnabled(cacheable=true)
    public static InitData getInitData() {
        String profileName = currentProfileName();
        InitData d = new InitData();
        d.accessDenied = DENIED_PROFILES.contains(profileName);
        d.canSeeBlocked = BLOCKED_VISIBLE_PROFILES.contains(profileName);
        d.projectNames = PROJECT_NAMES;
        d.currencies = new List<String>();
        for (Schema.PicklistEntry e : Unit__c.Secondary_Currency__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) d.currencies.add(e.getValue());
        }
        d.maxUnits = MAX_UNITS;
        return d;
    }

    @AuraEnabled
    public static List<UnitRow> getUnits(String projectName) {
        assertAllowed();
        if (String.isBlank(projectName)) {
            throw new AuraHandledException('Please select a project first.');
        }
        Set<String> statuses = new Set<String>{ 'Published' };
        if (BLOCKED_VISIBLE_PROFILES.contains(currentProfileName())) {
            statuses.add('Draft');
        }
        // MIRA Verde only sells its Standard layouts (Structure__c 'Standard %') — Sheraz 2026-08-18.
        Boolean standardOnly = projectName == 'Trussardi Residences MIRA VERDE';
        List<Unit__c> units = standardOnly
            ? [SELECT Id, Title__c, Building__c, Status__c, Type_Formula__c, Unit_Cost__c,
                      Number_of_Bedrooms__c, Total_Area__c
               FROM Unit__c
               WHERE Project_Name_F__c = :projectName AND Status__c IN :statuses
                 AND Structure__c LIKE 'Standard%'
               ORDER BY Title__c ASC]
            : [SELECT Id, Title__c, Building__c, Status__c, Type_Formula__c, Unit_Cost__c,
                      Number_of_Bedrooms__c, Total_Area__c
               FROM Unit__c
               WHERE Project_Name_F__c = :projectName AND Status__c IN :statuses
               ORDER BY Title__c ASC];
        List<UnitRow> rows = new List<UnitRow>();
        for (Unit__c u : units) {
            UnitRow r = new UnitRow();
            r.id = u.Id;
            r.title = u.Title__c;
            r.tower = u.Building__c;
            r.status = u.Status__c == 'Draft' ? 'Blocked' : 'Available';
            r.unitType = u.Type_Formula__c;
            r.unitCost = u.Unit_Cost__c;
            r.bedrooms = u.Number_of_Bedrooms__c;
            r.totalArea = u.Total_Area__c;
            rows.add(r);
        }
        return rows;
    }

    /** Step 1 of generation: delete the previous "Sales Offer …" files on the selected units
     *  (same clean-up the invocable performed). DML only — no callout may follow in here. */
    @AuraEnabled
    public static void cleanupExistingOffers(List<String> unitIds) {
        assertAllowed();
        validateSelection(unitIds);
        List<Id> linkedIds = new List<Id>();
        for (String uid : unitIds) linkedIds.add((Id) uid.trim());
        List<ContentDocumentLink> existing =
            MultipleSalesPDFActionController.querySalesOfferDocumentLinks(linkedIds);
        if (existing.isEmpty()) return;
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : existing) docIds.add(l.ContentDocumentId);
        delete existing;
        delete [SELECT Id FROM ContentDocument WHERE Id IN :docIds];
    }

    /** Step 2 of generation: render the project's VF page as PDF (callout), then save the
     *  file and link it to the first unit — identical to the invocable's output. */
    @AuraEnabled
    public static String generateOffers(List<String> unitIds, String selectedCurrency, String projectName) {
        assertAllowed();
        validateSelection(unitIds);
        if (String.isBlank(projectName)) {
            throw new AuraHandledException('Please select a project first.');
        }
        String joinedIds = String.join(unitIds, ',');
        PageReference pdfPage =
            MultipleSalesPDFActionController.getPageReferenceForMultipleSalesOffer(projectName);
        pdfPage.getParameters().put('unitIds', joinedIds);
        pdfPage.getParameters().put('sCurrency', selectedCurrency == null ? '' : selectedCurrency);

        Blob pdfBody = Test.isRunningTest() ? Blob.valueOf('TEST') : pdfPage.getContentAsPDF();

        // Title is set explicitly (the invocable relied on PathOnClient, but a locale date
        // format with slashes truncates the derived title and breaks the 'SALES OFFER'
        // clean-up match) and the filename date is slash-free for the same reason.
        String dateStamp = DateTime.now().format('dd-MM-yyyy');
        ContentVersion file = new ContentVersion();
        file.ContentLocation = 'S';
        file.Title = 'Sales Offer ' + dateStamp;
        file.PathOnClient = 'Sales Offer ' + dateStamp + '.pdf';
        file.VersionData = pdfBody;
        insert file;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :file.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = (Id) unitIds[0],
            ShareType = 'V'
        );
        return docId;
    }

    // ---- helpers -----------------------------------------------------------------

    private static String currentProfileName() {
        return [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()].Name;
    }

    private static void assertAllowed() {
        if (DENIED_PROFILES.contains(currentProfileName())) {
            throw new AuraHandledException('Access denied. Please contact your System Administrator.');
        }
    }

    private static void validateSelection(List<String> unitIds) {
        if (unitIds == null || unitIds.isEmpty()) {
            throw new AuraHandledException('Please select at least 1 unit in order to proceed.');
        }
        if (unitIds.size() > MAX_UNITS) {
            throw new AuraHandledException('A maximum of ' + MAX_UNITS + ' units can be selected in one go.');
        }
    }
}
