/**
 * Tests for MultiSalesOfferWizardController. Project name matches a real routing branch
 * ('Trussardi Residences 2') so getPageReferenceForMultipleSalesOffer is exercised, and
 * generation runs in test mode (Blob 'TEST') because getContentAsPDF is a callout.
 */
@IsTest
private class MultiSalesOfferWizardControllerTest {

    @TestSetup
    static void setup() {
        Project__c p = new Project__c(
            Name = 'Trussardi Residences 2', Description__c = 'Test', District__c = 'Meydan',
            Coordinates_Latitude__c = 1, Coordinates_Longitude__c = 1, Handover__c = Date.today()
        );
        insert p;

        // Validation rule: new units must be created as Draft, then the status may change.
        Unit__c published = new Unit__c(
            Title__c = 'MSO-PUB', Project__c = p.Id, Status__c = 'Draft',
            Cost_AED__c = 1000000, Building__c = 'Tower A'
        );
        Unit__c draft = new Unit__c(
            Title__c = 'MSO-DRAFT', Project__c = p.Id, Status__c = 'Draft',
            Cost_AED__c = 2000000, Building__c = 'Tower B'
        );
        insert new List<Unit__c>{ published, draft };
        published.Status__c = 'Published';
        update published;
    }

    @IsTest
    static void initDataListsProjectsAndCurrencies() {
        MultiSalesOfferWizardController.InitData d = MultiSalesOfferWizardController.getInitData();
        System.assertEquals(8, d.projectNames.size(), 'Same eight projects as the flow');
        System.assertEquals('Trussardi Residences', d.projectNames[0], 'Flow default first');
        System.assertEquals(MultiSalesOfferWizardController.MAX_UNITS, d.maxUnits);
        System.assertNotEquals(null, d.currencies);
        System.assertEquals(false, d.accessDenied, 'Test admin is not a denied profile');
    }

    @IsTest
    static void adminSeesDraftAsBlocked() {
        // The running test user is a System Administrator, who sees Draft units too.
        List<MultiSalesOfferWizardController.UnitRow> rows =
            MultiSalesOfferWizardController.getUnits('Trussardi Residences 2');
        System.assertEquals(2, rows.size(), 'Admin sees Published + Draft');
        Map<String, String> statusByTitle = new Map<String, String>();
        for (MultiSalesOfferWizardController.UnitRow r : rows) statusByTitle.put(r.title, r.status);
        System.assertEquals('Available', statusByTitle.get('MSO-PUB'));
        System.assertEquals('Blocked', statusByTitle.get('MSO-DRAFT'));
    }

    @IsTest
    static void standardUserSeesOnlyPublished() {
        // A real sales profile: has Unit__c read, and is not in BLOCKED_VISIBLE_PROFILES.
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Sales Manager MIRA' LIMIT 1];
        if (profiles.isEmpty()) return; // profile not present in this org — nothing to verify
        Profile std = profiles[0];
        User u = new User(
            Alias = 'msot', Email = 'mso.test@miradevelopments.ae.test',
            EmailEncodingKey = 'UTF-8', LastName = 'MSO', LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', ProfileId = std.Id, TimeZoneSidKey = 'Asia/Dubai',
            Username = 'mso.test.' + System.currentTimeMillis() + '@miradevelopments.ae.test'
        );
        insert u;
        // Unit__c OWD is Private; real sales users see units via sharing rules. The test
        // user owns the records instead, so only the status filter is being verified here.
        List<Unit__c> units = [SELECT Id FROM Unit__c];
        for (Unit__c un : units) un.OwnerId = u.Id;
        update units;
        System.runAs(u) {
            List<MultiSalesOfferWizardController.UnitRow> rows =
                MultiSalesOfferWizardController.getUnits('Trussardi Residences 2');
            System.assertEquals(1, rows.size(), 'Standard profile sees Published only');
            System.assertEquals('MSO-PUB', rows[0].title);
        }
    }

    @IsTest
    static void generateCreatesFileAndCleanupRemovesIt() {
        Id unitId = [SELECT Id FROM Unit__c WHERE Title__c = 'MSO-PUB'].Id;
        List<String> ids = new List<String>{ unitId };

        Test.startTest();
        String docId = MultiSalesOfferWizardController.generateOffers(
            ids, 'USD', 'Trussardi Residences 2');
        Test.stopTest();

        System.assertNotEquals(null, docId, 'A ContentDocument was produced');
        List<ContentDocumentLink> links = [
            SELECT ContentDocument.Title FROM ContentDocumentLink
            WHERE LinkedEntityId = :unitId AND ContentDocumentId = :docId
        ];
        System.assertEquals(1, links.size(), 'File linked to the first unit');
        System.assert(links[0].ContentDocument.Title.toUpperCase().startsWith('SALES OFFER'),
            'File named like the invocable named it');

        // Second run's cleanup deletes the previous offer, matching the flow's behaviour.
        MultiSalesOfferWizardController.cleanupExistingOffers(ids);
        System.assertEquals(0, [
            SELECT COUNT() FROM ContentDocument WHERE Id = :docId
        ], 'Previous sales offer removed');
    }

    @IsTest
    static void selectionValidationEnforced() {
        try {
            MultiSalesOfferWizardController.generateOffers(
                new List<String>(), null, 'Trussardi Residences 2');
            System.assert(false, 'Empty selection must throw');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        List<String> tooMany = new List<String>();
        Id unitId = [SELECT Id FROM Unit__c WHERE Title__c = 'MSO-PUB'].Id;
        for (Integer i = 0; i <= MultiSalesOfferWizardController.MAX_UNITS; i++) {
            tooMany.add(unitId);
        }
        try {
            MultiSalesOfferWizardController.generateOffers(
                tooMany, null, 'Trussardi Residences 2');
            System.assert(false, 'Over-limit selection must throw');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void deniedProfileIsBlocked() {
        List<Profile> denied = [SELECT Id FROM Profile WHERE Name = 'Finance Limited' LIMIT 1];
        if (denied.isEmpty()) return; // profile not present in this org — nothing to verify
        User u = new User(
            Alias = 'msod', Email = 'mso.denied@miradevelopments.ae.test',
            EmailEncodingKey = 'UTF-8', LastName = 'MSOD', LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', ProfileId = denied[0].Id, TimeZoneSidKey = 'Asia/Dubai',
            Username = 'mso.denied.' + System.currentTimeMillis() + '@miradevelopments.ae.test'
        );
        System.runAs(u) {
            System.assertEquals(true, MultiSalesOfferWizardController.getInitData().accessDenied);
            try {
                MultiSalesOfferWizardController.getUnits('Trussardi Residences 2');
                System.assert(false, 'Denied profile must not query units');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
    }
}
