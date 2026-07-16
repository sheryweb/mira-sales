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

        // Skip trigger for initial invoices
        InvoiceTriggerHelper.skipTrigger = true;
        
        // Create initial invoices with numbers
        List<Invoice__c> initialInvoices = new List<Invoice__c>{
            new Invoice__c(
                Unit__c = units[0].Id,
                Invoice_Number_To_Process_Bentley__c = 7,
                Invoice_Number__c = 'INV-BTL-7'
            ),
            new Invoice__c(
                Unit__c = units[1].Id,
                Invoice_Number_To_Process_Trussardi__c = 5,
                Invoice_Number__c = 'INV-TRD-5'
            ),
            new Invoice__c(
                Unit__c = units[2].Id,
                Invoice_Number_To_Process_Trussardi2__c = 3,
                Invoice_Number__c = 'INV-TRD2-3'
            ),
            new Invoice__c(
                Unit__c = units[3].Id,
                Invoice_Number_To_Process_POST__c = 4,
                Invoice_Number__c = 'INV-POST-4'
            ),
            new Invoice__c(
                Unit__c = units[4].Id,
                Invoice_Number_To_Process_Gianfranco__c = 2,
                Invoice_Number__c = 'INV-GFF-2'
            ),
            new Invoice__c(
                Unit__c = units[5].Id,
                Invoice_Number_To_Process_T2_Offices__c = 10,
                Invoice_Number__c = 'INV-TR2-Retail-10'
            ),
            new Invoice__c(
                Unit__c = units[7].Id,
                Invoice_Number_To_Process_MIRA_VERDE__c = 5,
                Invoice_Number__c = 'INV-MIRA-VERDE-5'
            )
        };
        insert initialInvoices;
        
        // Re-enable trigger for subsequent tests
        InvoiceTriggerHelper.skipTrigger = false;
    }

    @IsTest
    static void testBentleyInvoiceNumbering() {
        // Get the test unit
        Unit__c bentleyUnit = [
            SELECT Id, Project_Name_F__c 
            FROM Unit__c 
            WHERE Project_Name_F__c = 'MIRA Villas Designed by Bentley Home' 
            LIMIT 1
        ];

        // Create new invoice
        Invoice__c newInvoice = new Invoice__c(
            Unit__c = bentleyUnit.Id
        );
        
        Test.startTest();
        insert newInvoice;
        Test.stopTest();

        // Query for the updated invoice
        Invoice__c updatedInvoice = [
            SELECT Id, Invoice_Number_To_Process_Bentley__c, Invoice_Number__c
            FROM Invoice__c 
            WHERE Id = :newInvoice.Id
        ];

        // Verify the invoice numbering
        System.assertNotEquals(null, updatedInvoice.Invoice_Number_To_Process_Bentley__c, 
            'Bentley invoice number should not be null');
        System.assertEquals(8, updatedInvoice.Invoice_Number_To_Process_Bentley__c, 
            'Bentley invoice number should be incremented to 8');
        System.assertEquals('INV-BTL-8', updatedInvoice.Invoice_Number__c, 
            'Invoice number format should match Bentley pattern');
    }

    @IsTest
    static void testTrussardiInvoiceNumbering() {
        // Get the test unit
        Unit__c trussardiUnit = [
            SELECT Id, Project_Name_F__c 
            FROM Unit__c 
            WHERE Project_Name_F__c = 'Trussardi Residences' 
            LIMIT 1
        ];

        // Create new invoice
        Invoice__c newInvoice = new Invoice__c(
            Unit__c = trussardiUnit.Id
        );
        
        Test.startTest();
        insert newInvoice;
        Test.stopTest();

        // Query for the updated invoice
        Invoice__c updatedInvoice = [
            SELECT Id, Invoice_Number_To_Process_Trussardi__c, Invoice_Number__c
            FROM Invoice__c 
            WHERE Id = :newInvoice.Id
        ];

        // Verify the invoice numbering
        System.assertNotEquals(null, updatedInvoice.Invoice_Number_To_Process_Trussardi__c, 
            'Trussardi invoice number should not be null');
        System.assertEquals(6, updatedInvoice.Invoice_Number_To_Process_Trussardi__c, 
            'Trussardi invoice number should be incremented to 6');
        System.assertEquals('INV-TRD-6', updatedInvoice.Invoice_Number__c, 
            'Invoice number format should match Trussardi pattern');
    }

    @IsTest
    static void testTrussardi2InvoiceNumbering() {
        // Get the test unit
        Unit__c trussardi2Unit = [
            SELECT Id, Project_Name_F__c 
            FROM Unit__c 
            WHERE Project_Name_F__c = 'Trussardi Residences 2' 
            LIMIT 1
        ];

        // Create new invoice
        Invoice__c newInvoice = new Invoice__c(
            Unit__c = trussardi2Unit.Id
        );
        
        Test.startTest();
        insert newInvoice;
        Test.stopTest();

        // Query for the updated invoice
        Invoice__c updatedInvoice = [
            SELECT Id, Invoice_Number_To_Process_Trussardi2__c, Invoice_Number__c
            FROM Invoice__c 
            WHERE Id = :newInvoice.Id
        ];

        // Verify the invoice numbering
        System.assertNotEquals(null, updatedInvoice.Invoice_Number_To_Process_Trussardi2__c, 
            'Trussardi 2 invoice number should not be null');
        System.assertEquals(4, updatedInvoice.Invoice_Number_To_Process_Trussardi2__c, 
            'Trussardi 2 invoice number should be incremented to 4');
        System.assertEquals('INV-TRD2-4', updatedInvoice.Invoice_Number__c, 
            'Invoice number format should match Trussardi 2 pattern');
    }

    @IsTest
    static void testPOSTInvoiceNumbering() {
        // Get the test unit
        Unit__c postUnit = [
            SELECT Id, Project_Name_F__c 
            FROM Unit__c 
            WHERE Project_Name_F__c = 'POST HOTEL & RESIDENCES By ELIE SAAB' 
            LIMIT 1
        ];

        // Create new invoice
        Invoice__c newInvoice = new Invoice__c(
            Unit__c = postUnit.Id
        );
        
        Test.startTest();
        insert newInvoice;
        Test.stopTest();

        // Query for the updated invoice
        Invoice__c updatedInvoice = [
            SELECT Id, Invoice_Number_To_Process_POST__c, Invoice_Number__c
            FROM Invoice__c 
            WHERE Id = :newInvoice.Id
        ];

        // Verify the invoice numbering
        System.assertNotEquals(null, updatedInvoice.Invoice_Number_To_Process_POST__c, 
            'POST invoice number should not be null');
        System.assertEquals(5, updatedInvoice.Invoice_Number_To_Process_POST__c, 
            'POST invoice number should be incremented to 5');
        System.assertEquals('INV-POST-5', updatedInvoice.Invoice_Number__c, 
            'Invoice number format should match POST pattern');
    }

    @IsTest
    static void testGianfrancoInvoiceNumbering() {
        // Get the test unit
        Unit__c gianfrancoUnit = [
            SELECT Id, Project_Name_F__c 
            FROM Unit__c 
            WHERE Project_Name_F__c = 'GIANFRANCO FERRE RESIDENCES' 
            LIMIT 1
        ];

        // Create new invoice
        Invoice__c newInvoice = new Invoice__c(
            Unit__c = gianfrancoUnit.Id
        );
        
        Test.startTest();
        insert newInvoice;
        Test.stopTest();

        // Query for the updated invoice
        Invoice__c updatedInvoice = [
            SELECT Id, Invoice_Number_To_Process_Gianfranco__c, Invoice_Number__c
            FROM Invoice__c 
            WHERE Id = :newInvoice.Id
        ];

        // Verify the invoice numbering
        System.assertNotEquals(null, updatedInvoice.Invoice_Number_To_Process_Gianfranco__c, 
            'Gianfranco invoice number should not be null');
        System.assertEquals(3, updatedInvoice.Invoice_Number_To_Process_Gianfranco__c, 
            'Gianfranco invoice number should be incremented to 3');
        System.assertEquals('INV-GFF-3', updatedInvoice.Invoice_Number__c, 
            'Invoice number format should match Gianfranco pattern');
    }

    @IsTest
    static void testInvalidUnit() {
        // Create new invoice without a unit
        Invoice__c newInvoice = new Invoice__c();
        
        Test.startTest();
        insert newInvoice;
        Test.stopTest();

        // Query for the updated invoice
        Invoice__c updatedInvoice = [
            SELECT Id, Invoice_Number_To_Process_Trussardi__c, Invoice_Number_To_Process_Trussardi2__c,
                   Invoice_Number_To_Process_Bentley__c, Invoice_Number_To_Process_POST__c, Invoice_Number_To_Process_Gianfranco__c, Invoice_Number__c
            FROM Invoice__c 
            WHERE Id = :newInvoice.Id
        ];

        // Debug logging to see what values are actually set
        System.debug('Updated Invoice Values:');
        System.debug('Trussardi: ' + updatedInvoice.Invoice_Number_To_Process_Trussardi__c);
        System.debug('Trussardi2: ' + updatedInvoice.Invoice_Number_To_Process_Trussardi2__c);
        System.debug('Bentley: ' + updatedInvoice.Invoice_Number_To_Process_Bentley__c);
        System.debug('POST: ' + updatedInvoice.Invoice_Number_To_Process_POST__c);
        System.debug('Gianfranco: ' + updatedInvoice.Invoice_Number_To_Process_Gianfranco__c);
        System.debug('Invoice Number: ' + updatedInvoice.Invoice_Number__c);

        // Verify no numbers were assigned - accept either null or 0 as valid states
        System.assert(updatedInvoice.Invoice_Number_To_Process_Trussardi__c == null || 
                     updatedInvoice.Invoice_Number_To_Process_Trussardi__c == 0, 
            'Trussardi number should be null or zero for invalid unit');
        System.assert(updatedInvoice.Invoice_Number_To_Process_Trussardi2__c == null || 
                     updatedInvoice.Invoice_Number_To_Process_Trussardi2__c == 0, 
            'Trussardi2 number should be null or zero for invalid unit');
        System.assert(updatedInvoice.Invoice_Number_To_Process_Bentley__c == null || 
                     updatedInvoice.Invoice_Number_To_Process_Bentley__c == 0, 
            'Bentley number should be null or zero for invalid unit');
        System.assert(updatedInvoice.Invoice_Number_To_Process_POST__c == null || 
                     updatedInvoice.Invoice_Number_To_Process_POST__c == 0, 
            'POST number should be null or zero for invalid unit');
        System.assert(updatedInvoice.Invoice_Number_To_Process_Gianfranco__c == null || 
                     updatedInvoice.Invoice_Number_To_Process_Gianfranco__c == 0, 
            'Gianfranco number should be null or zero for invalid unit');
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

        Invoice__c inserted = [SELECT Invoice_Number__c, Invoice_Number_To_Process_Bentley__c FROM Invoice__c WHERE Id = :newInvoice.Id];
        System.assertEquals(null, inserted.Invoice_Number__c, 'Invoice number should be null when skipTrigger is true');
        System.assertEquals(null, inserted.Invoice_Number_To_Process_Bentley__c, 'Bentley number should be null when skipTrigger is true');
    }

    @IsTest
    static void testTrussardi2OfficesRetailInvoiceNumbering() {
        Unit__c t2Unit = [SELECT Id FROM Unit__c WHERE Property_Code_Text__c = 'TEST-T2-RETAIL' LIMIT 1];
        Invoice__c newInvoice = new Invoice__c(Unit__c = t2Unit.Id);
        insert newInvoice;

        Invoice__c updated = [SELECT Invoice_Number_To_Process_T2_Offices__c, Invoice_Number__c FROM Invoice__c WHERE Id = :newInvoice.Id];
        System.assertEquals(11, updated.Invoice_Number_To_Process_T2_Offices__c, 'T2 Offices number should increment to 11');
        System.assert(updated.Invoice_Number__c != null && updated.Invoice_Number__c.startsWith('INV-TR2-'), 'Invoice should use T2 Offices pattern');
    }

    @IsTest
    static void testTrussardi2OfficesOfficeInvoiceNumbering() {
        Unit__c t2Unit = [SELECT Id FROM Unit__c WHERE Property_Code_Text__c = 'TEST-T2-OFFICE' LIMIT 1];
        Invoice__c newInvoice = new Invoice__c(Unit__c = t2Unit.Id);
        insert newInvoice;

        Invoice__c updated = [SELECT Invoice_Number_To_Process_T2_Offices__c, Invoice_Number__c FROM Invoice__c WHERE Id = :newInvoice.Id];
        System.assertEquals(11, updated.Invoice_Number_To_Process_T2_Offices__c, 'T2 Offices number should increment to 11');
        System.assertEquals('INV-TR2-Office-11', updated.Invoice_Number__c, 'Invoice should use Office pattern when Type is not Retail');
    }

    @IsTest
    static void testMiraVerdeInvoiceNumbering() {
        Unit__c miraUnit = [SELECT Id FROM Unit__c WHERE Property_Code_Text__c = 'TEST-MIRA-001' LIMIT 1];
        Invoice__c newInvoice = new Invoice__c(Unit__c = miraUnit.Id);
        insert newInvoice;

        Invoice__c updated = [SELECT Invoice_Number_To_Process_MIRA_VERDE__c, Invoice_Number__c FROM Invoice__c WHERE Id = :newInvoice.Id];
        System.assertEquals(6, updated.Invoice_Number_To_Process_MIRA_VERDE__c, 'MIRA VERDE number should increment to 6');
        System.assertEquals('INV-MIRA-VERDE-6', updated.Invoice_Number__c, 'Invoice number should match MIRA VERDE pattern');
    }

    @IsTest
    static void testUnknownProjectName() {
        Unit__c unknownUnit = [SELECT Id FROM Unit__c WHERE Property_Code_Text__c = 'TEST-UNKNOWN' LIMIT 1];
        Invoice__c newInvoice = new Invoice__c(Unit__c = unknownUnit.Id);
        insert newInvoice;

        Invoice__c updated = [SELECT Invoice_Number__c FROM Invoice__c WHERE Id = :newInvoice.Id];
        System.assertEquals(null, updated.Invoice_Number__c, 'Invoice number should be null for unknown project');
    }
}