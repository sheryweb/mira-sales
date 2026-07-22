@IsTest
private class InvoiceTriggerHelperTest {
    @TestSetup
    static void setupTestData() {
        // Create test projects first
        List<Project__c> projects = new List<Project__c>{
            new Project__c(
                Name = 'MIRA Villas Designed by Bentley Home',
                Description__c = 'Test Project 1',
                District__c = 'Meydan',
                Coordinates_Latitude__c = 1.0,
                Coordinates_Longitude__c = 1.0,
                Handover__c = Date.today(),
                Minimum_Cost__c = 1000000,
                Publish_Project__c = 'Published',
                Project_Code__c = 'TEST-PROJ-001'
            ),
            new Project__c(
                Name = 'Trussardi Residences',
                Description__c = 'Test Project 2',
                District__c = 'Meydan',
                Coordinates_Latitude__c = 2.0,
                Coordinates_Longitude__c = 2.0,
                Handover__c = Date.today(),
                Minimum_Cost__c = 2000000,
                Publish_Project__c = 'Published',
                Project_Code__c = 'TEST-PROJ-002'
            ),
            new Project__c(
                Name = 'Trussardi Residences 2',
                Description__c = 'Test Project 3',
                District__c = 'Meydan',
                Coordinates_Latitude__c = 3.0,
                Coordinates_Longitude__c = 3.0,
                Handover__c = Date.today(),
                Minimum_Cost__c = 3000000,
                Publish_Project__c = 'Published',
                Project_Code__c = 'TEST-PROJ-003'
            ),
            new Project__c(
                Name = 'POST HOTEL & RESIDENCES By ELIE SAAB',
                Description__c = 'Test Project 4',
                District__c = 'Meydan',
                Coordinates_Latitude__c = 4.0,
                Coordinates_Longitude__c = 4.0,
                Handover__c = Date.today(),
                Minimum_Cost__c = 4000000,
                Publish_Project__c = 'Published',
                Project_Code__c = 'TEST-PROJ-004'
            ),
            new Project__c(
                Name = 'GIANFRANCO FERRE RESIDENCES',
                Description__c = 'Test Project 5',
                District__c = 'Meydan',
                Coordinates_Latitude__c = 5.0,
                Coordinates_Longitude__c = 5.0,
                Handover__c = Date.today(),
                Minimum_Cost__c = 5000000,
                Publish_Project__c = 'Published',
                Project_Code__c = 'TEST-PROJ-005'
            ),
            new Project__c(
                Name = 'Trussardi Residences 2 Offices',
                Description__c = 'Test Project T2 Offices',
                District__c = 'Meydan',
                Coordinates_Latitude__c = 6.0,
                Coordinates_Longitude__c = 6.0,
                Handover__c = Date.today(),
                Minimum_Cost__c = 6000000,
                Publish_Project__c = 'Published',
                Project_Code__c = 'TEST-PROJ-006'
            ),
            new Project__c(
                Name = 'Trussardi Residences MIRA VERDE',
                Description__c = 'Test Project MIRA VERDE',
                District__c = 'Meydan',
                Coordinates_Latitude__c = 7.0,
                Coordinates_Longitude__c = 7.0,
                Handover__c = Date.today(),
                Minimum_Cost__c = 7000000,
                Publish_Project__c = 'Published',
                Project_Code__c = 'TEST-PROJ-007'
            ),
            new Project__c(
                Name = 'Unknown Project XYZ',
                Description__c = 'Test Unknown Project',
                District__c = 'Meydan',
                Coordinates_Latitude__c = 8.0,
                Coordinates_Longitude__c = 8.0,
                Handover__c = Date.today(),
                Minimum_Cost__c = 8000000,
                Publish_Project__c = 'Published',
                Project_Code__c = 'TEST-PROJ-008'
            )
        };
        insert projects;

        // Create test units for all projects
        List<Unit__c> units = new List<Unit__c>{
            new Unit__c(
                Project__c = projects[0].Id,
                Building__c = 'Test Building 1',
                Title__c = 'Test Property 1',
                Property_Code_Text__c = 'TEST-001'
            ),
            new Unit__c(
                Project__c = projects[1].Id,
                Building__c = 'Test Building 2',
                Title__c = 'Test Property 2',
                Property_Code_Text__c = 'TEST-002'
            ),
            new Unit__c(
                Project__c = projects[2].Id,
                Building__c = 'Test Building 3',
                Title__c = 'Test Property 3',
                Property_Code_Text__c = 'TEST-003'
            ),
            new Unit__c(
                Project__c = projects[3].Id,
                Building__c = 'Test Building 4',
                Title__c = 'Test Property 4',
                Property_Code_Text__c = 'TEST-004'
            ),
            new Unit__c(
                Project__c = projects[4].Id,
                Building__c = 'Test Building 5',
                Title__c = 'Test Property 5',
                Property_Code_Text__c = 'TEST-005'
            ),
            new Unit__c(
                Project__c = projects[5].Id,
                Building__c = 'Test Building T2 Retail',
                Title__c = 'Test Property T2 Retail',
                Type__c = 'Retail',
                Property_Code_Text__c = 'TEST-T2-RETAIL'
            ),
            new Unit__c(
                Project__c = projects[5].Id,
                Building__c = 'Test Building T2 Office',
                Title__c = 'Test Property T2 Office',
                Property_Code_Text__c = 'TEST-T2-OFFICE'
            ),
            new Unit__c(
                Project__c = projects[6].Id,
                Building__c = 'Test Building MIRA',
                Title__c = 'Test Property MIRA VERDE',
                Property_Code_Text__c = 'TEST-MIRA-001'
            ),
            new Unit__c(
                Project__c = projects[7].Id,
                Building__c = 'Test Building Unknown',
                Title__c = 'Test Property Unknown',
                Property_Code_Text__c = 'TEST-UNKNOWN'
            )
        };
        insert units;

        // Skip trigger for initial invoices so we can seed known sequences.
        InvoiceTriggerHelper.skipTrigger = true;

        // Create initial invoices seeding the per-project sequence (Invoice_Seq__c).
        List<Invoice__c> initialInvoices = new List<Invoice__c>{
            new Invoice__c(Unit__c = units[0].Id, Invoice_Seq__c = 7,  Invoice_Number__c = 'INV-BTL-7'),
            new Invoice__c(Unit__c = units[1].Id, Invoice_Seq__c = 5,  Invoice_Number__c = 'INV-TRD-5'),
            new Invoice__c(Unit__c = units[2].Id, Invoice_Seq__c = 3,  Invoice_Number__c = 'INV-TRD2-3'),
            new Invoice__c(Unit__c = units[3].Id, Invoice_Seq__c = 4,  Invoice_Number__c = 'INV-POST-4'),
            new Invoice__c(Unit__c = units[4].Id, Invoice_Seq__c = 2,  Invoice_Number__c = 'INV-GFF-2'),
            new Invoice__c(Unit__c = units[5].Id, Invoice_Seq__c = 10, Invoice_Number__c = 'INV-TR2-Office-10'),
            new Invoice__c(Unit__c = units[7].Id, Invoice_Seq__c = 5,  Invoice_Number__c = 'INV-MIRA-VERDE-5')
        };
        insert initialInvoices;

        // Re-enable trigger for subsequent tests
        InvoiceTriggerHelper.skipTrigger = false;
    }

    @IsTest
    static void testBentleyInvoiceNumbering() {
        Unit__c bentleyUnit = [
            SELECT Id FROM Unit__c
            WHERE Project_Name_F__c = 'MIRA Villas Designed by Bentley Home'
            LIMIT 1
        ];

        Invoice__c newInvoice = new Invoice__c(Unit__c = bentleyUnit.Id);

        Test.startTest();
        insert newInvoice;
        Test.stopTest();

        Invoice__c updatedInvoice = [
            SELECT Invoice_Seq__c, Invoice_Number__c
            FROM Invoice__c WHERE Id = :newInvoice.Id
        ];

        System.assertEquals(8, updatedInvoice.Invoice_Seq__c,
            'Bentley invoice sequence should increment to 8');
        System.assertEquals('INV-BTL-8', updatedInvoice.Invoice_Number__c,
            'Invoice number format should match Bentley pattern');
    }

    @IsTest
    static void testTrussardiInvoiceNumbering() {
        Unit__c trussardiUnit = [
            SELECT Id FROM Unit__c
            WHERE Project_Name_F__c = 'Trussardi Residences'
            LIMIT 1
        ];

        Invoice__c newInvoice = new Invoice__c(Unit__c = trussardiUnit.Id);

        Test.startTest();
        insert newInvoice;
        Test.stopTest();

        Invoice__c updatedInvoice = [
            SELECT Invoice_Seq__c, Invoice_Number__c
            FROM Invoice__c WHERE Id = :newInvoice.Id
        ];

        System.assertEquals(6, updatedInvoice.Invoice_Seq__c,
            'Trussardi invoice sequence should increment to 6');
        System.assertEquals('INV-TRD-6', updatedInvoice.Invoice_Number__c,
            'Invoice number format should match Trussardi pattern');
    }

    @IsTest
    static void testTrussardi2InvoiceNumbering() {
        Unit__c trussardi2Unit = [
            SELECT Id FROM Unit__c
            WHERE Project_Name_F__c = 'Trussardi Residences 2'
            LIMIT 1
        ];

        Invoice__c newInvoice = new Invoice__c(Unit__c = trussardi2Unit.Id);

        Test.startTest();
        insert newInvoice;
        Test.stopTest();

        Invoice__c updatedInvoice = [
            SELECT Invoice_Seq__c, Invoice_Number__c
            FROM Invoice__c WHERE Id = :newInvoice.Id
        ];

        System.assertEquals(4, updatedInvoice.Invoice_Seq__c,
            'Trussardi 2 invoice sequence should increment to 4');
        System.assertEquals('INV-TRD2-4', updatedInvoice.Invoice_Number__c,
            'Invoice number format should match Trussardi 2 pattern');
    }

    @IsTest
    static void testPOSTInvoiceNumbering() {
        Unit__c postUnit = [
            SELECT Id FROM Unit__c
            WHERE Project_Name_F__c = 'POST HOTEL & RESIDENCES By ELIE SAAB'
            LIMIT 1
        ];

        Invoice__c newInvoice = new Invoice__c(Unit__c = postUnit.Id);

        Test.startTest();
        insert newInvoice;
        Test.stopTest();

        Invoice__c updatedInvoice = [
            SELECT Invoice_Seq__c, Invoice_Number__c
            FROM Invoice__c WHERE Id = :newInvoice.Id
        ];

        System.assertEquals(5, updatedInvoice.Invoice_Seq__c,
            'POST invoice sequence should increment to 5');
        System.assertEquals('INV-POST-5', updatedInvoice.Invoice_Number__c,
            'Invoice number format should match POST pattern');
    }

    @IsTest
    static void testGianfrancoInvoiceNumbering() {
        Unit__c gianfrancoUnit = [
            SELECT Id FROM Unit__c
            WHERE Project_Name_F__c = 'GIANFRANCO FERRE RESIDENCES'
            LIMIT 1
        ];

        Invoice__c newInvoice = new Invoice__c(Unit__c = gianfrancoUnit.Id);

        Test.startTest();
        insert newInvoice;
        Test.stopTest();

        Invoice__c updatedInvoice = [
            SELECT Invoice_Seq__c, Invoice_Number__c
            FROM Invoice__c WHERE Id = :newInvoice.Id
        ];

        System.assertEquals(3, updatedInvoice.Invoice_Seq__c,
            'Gianfranco invoice sequence should increment to 3');
        System.assertEquals('INV-GFF-3', updatedInvoice.Invoice_Number__c,
            'Invoice number format should match Gianfranco pattern');
    }

    @IsTest
    static void testInvalidUnit() {
        Invoice__c newInvoice = new Invoice__c();

        Test.startTest();
        insert newInvoice;
        Test.stopTest();

        Invoice__c updatedInvoice = [
            SELECT Invoice_Seq__c, Invoice_Number__c
            FROM Invoice__c WHERE Id = :newInvoice.Id
        ];

        System.assertEquals(null, updatedInvoice.Invoice_Seq__c,
            'Invoice sequence should be null for invalid unit');
        System.assertEquals(null, updatedInvoice.Invoice_Number__c,
            'Invoice number should be null for invalid unit');
    }

    @IsTest
    static void testSkipTrigger() {
        InvoiceTriggerHelper.skipTrigger = true;
        Unit__c bentleyUnit = [SELECT Id FROM Unit__c WHERE Project_Name_F__c = 'MIRA Villas Designed by Bentley Home' LIMIT 1];
        Invoice__c newInvoice = new Invoice__c(Unit__c = bentleyUnit.Id);
        insert newInvoice;
        InvoiceTriggerHelper.skipTrigger = false;

        Invoice__c inserted = [SELECT Invoice_Number__c, Invoice_Seq__c FROM Invoice__c WHERE Id = :newInvoice.Id];
        System.assertEquals(null, inserted.Invoice_Number__c, 'Invoice number should be null when skipTrigger is true');
        System.assertEquals(null, inserted.Invoice_Seq__c, 'Invoice sequence should be null when skipTrigger is true');
    }

    @IsTest
    static void testTrussardi2OfficesRetailInvoiceNumbering() {
        // Parity check: retail-type T2 units keep the Office prefix, because the
        // T2 CMDT row has no Invoice_Prefix_Retail__c set (matches legacy behavior).
        Unit__c t2Unit = [SELECT Id FROM Unit__c WHERE Property_Code_Text__c = 'TEST-T2-RETAIL' LIMIT 1];
        Invoice__c newInvoice = new Invoice__c(Unit__c = t2Unit.Id);
        insert newInvoice;

        Invoice__c updated = [SELECT Invoice_Seq__c, Invoice_Number__c FROM Invoice__c WHERE Id = :newInvoice.Id];
        System.assertEquals(11, updated.Invoice_Seq__c, 'T2 Offices sequence should increment to 11');
        System.assertEquals('INV-TR2-Office-11', updated.Invoice_Number__c,
            'Retail T2 invoices keep the Office prefix under current parity configuration');
    }

    @IsTest
    static void testTrussardi2OfficesOfficeInvoiceNumbering() {
        Unit__c t2Unit = [SELECT Id FROM Unit__c WHERE Property_Code_Text__c = 'TEST-T2-OFFICE' LIMIT 1];
        Invoice__c newInvoice = new Invoice__c(Unit__c = t2Unit.Id);
        insert newInvoice;

        Invoice__c updated = [SELECT Invoice_Seq__c, Invoice_Number__c FROM Invoice__c WHERE Id = :newInvoice.Id];
        System.assertEquals(11, updated.Invoice_Seq__c, 'T2 Offices sequence should increment to 11');
        System.assertEquals('INV-TR2-Office-11', updated.Invoice_Number__c, 'Invoice should use Office pattern when Type is not Retail');
    }

    @IsTest
    static void testMiraVerdeInvoiceNumbering() {
        Unit__c miraUnit = [SELECT Id FROM Unit__c WHERE Property_Code_Text__c = 'TEST-MIRA-001' LIMIT 1];
        Invoice__c newInvoice = new Invoice__c(Unit__c = miraUnit.Id);
        insert newInvoice;

        Invoice__c updated = [SELECT Invoice_Seq__c, Invoice_Number__c FROM Invoice__c WHERE Id = :newInvoice.Id];
        System.assertEquals(6, updated.Invoice_Seq__c, 'MIRA VERDE sequence should increment to 6');
        System.assertEquals('INV-MIRA-VERDE-6', updated.Invoice_Number__c, 'Invoice number should match MIRA VERDE pattern');
    }

    @IsTest
    static void testUnknownProjectName() {
        Unit__c unknownUnit = [SELECT Id FROM Unit__c WHERE Property_Code_Text__c = 'TEST-UNKNOWN' LIMIT 1];
        Invoice__c newInvoice = new Invoice__c(Unit__c = unknownUnit.Id);
        insert newInvoice;

        Invoice__c updated = [SELECT Invoice_Seq__c, Invoice_Number__c FROM Invoice__c WHERE Id = :newInvoice.Id];
        System.assertEquals(null, updated.Invoice_Seq__c, 'Invoice sequence should be null for unknown project');
        System.assertEquals(null, updated.Invoice_Number__c, 'Invoice number should be null for unknown project');
    }

    @IsTest
    static void deleteBlockedWhenInvoicePaid() {
        Unit__c u = [SELECT Id FROM Unit__c WHERE Property_Code_Text__c = 'TEST-001' LIMIT 1];
        Invoice__c inv = new Invoice__c(Unit__c = u.Id, Sub_Total_Amount__c = 1000,
            Paid_Amount__c = 500, Status__c = 'Partially Paid');
        insert inv;

        Boolean blocked = false;
        Test.startTest();
        try {
            delete inv;
        } catch (DmlException e) {
            blocked = true;
            System.assert(e.getMessage().contains('cannot be deleted'),
                'Expected the guard message, got: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(blocked, 'Deleting a paid invoice must be blocked');
        System.assertEquals(1, [SELECT COUNT() FROM Invoice__c WHERE Id = :inv.Id], 'Invoice should still exist');
    }

    @IsTest
    static void deleteAllowedWhenUnpaidFreesInstallments() {
        Unit__c u = [SELECT Id FROM Unit__c WHERE Property_Code_Text__c = 'TEST-001' LIMIT 1];
        Cash_Flow_Sum__c s = new Cash_Flow_Sum__c(Name = 'CFS', Unit__c = u.Id);
        insert s;
        Cash_Flow__c cf = new Cash_Flow__c(Name = 'M1', Unit__c = u.Id, Cash_Flow_Sum__c = s.Id,
            Date__c = Date.today(), Constant__c = 1000, Received_Amount__c = 0, Is_Invoiced__c = true);
        insert cf;
        Invoice__c inv = new Invoice__c(Unit__c = u.Id, Sub_Total_Amount__c = 1000,
            Paid_Amount__c = 0, Status__c = 'Pending');
        insert inv;
        Milestone_Invoice__c mi = new Milestone_Invoice__c(Invoice__c = inv.Id, Cash_Flow__c = cf.Id);
        insert mi;

        Test.startTest();
        delete inv;
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Invoice__c WHERE Id = :inv.Id], 'Unpaid invoice should be deleted');
        System.assertEquals(0, [SELECT COUNT() FROM Milestone_Invoice__c WHERE Id = :mi.Id], 'Milestone link should be removed');
        System.assertEquals(false,
            [SELECT Is_Invoiced__c FROM Cash_Flow__c WHERE Id = :cf.Id].Is_Invoiced__c,
            'The covered installment should be freed (Is_Invoiced reset)');
    }
}
