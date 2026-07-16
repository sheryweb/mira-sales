@IsTest
private class ReceiptTriggerHelperTest {
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
                Name = 'John Richmond Residences',
                Description__c = 'Test Project John Richmond',
                District__c = 'Meydan',
                Coordinates_Latitude__c = 8.0,
                Coordinates_Longitude__c = 8.0,
                Handover__c = Date.today(),
                Minimum_Cost__c = 8000000,
                Publish_Project__c = 'Published',
                Project_Code__c = 'TEST-PROJ-008'
            ),
            new Project__c(
                Name = 'Unknown Project XYZ',
                Description__c = 'Test Unknown Project',
                District__c = 'Meydan',
                Coordinates_Latitude__c = 9.0,
                Coordinates_Longitude__c = 9.0,
                Handover__c = Date.today(),
                Minimum_Cost__c = 9000000,
                Publish_Project__c = 'Published',
                Project_Code__c = 'TEST-PROJ-009'
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
                Building__c = 'Test Building T2',
                Title__c = 'Test Property T2',
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
                Building__c = 'Test Building John Richmond',
                Title__c = 'Test Property John Richmond',
                Property_Code_Text__c = 'TEST-RICHMOND-001'
            ),
            new Unit__c(
                Project__c = projects[8].Id,
                Building__c = 'Test Building Unknown',
                Title__c = 'Test Property Unknown',
                Property_Code_Text__c = 'TEST-UNKNOWN'
            )
        };
        insert units;

        // Skip trigger for initial receipts - store original value to restore later
        Boolean originalSkipValue = ReceiptTriggerHelper.skipTrigger;
        ReceiptTriggerHelper.skipTrigger = true;
        
        // Create initial receipts with numbers
        List<Receipt__c> initialReceipts = new List<Receipt__c>{
            new Receipt__c(
                Unit__c = units[0].Id,
                Voucher_Number_To_Process_Bentley__c = 7,
                Description__c = 'Test Receipt 1',
                Payment_Date__c = Date.today(),
                Payable_Amount__c = 1000,
                Status__c = 'Reconciled'
            ),
            new Receipt__c(
                Unit__c = units[1].Id,
                Voucher_Number_To_Process_Trussardi__c = 5,
                Description__c = 'Test Receipt 2',
                Payment_Date__c = Date.today(),
                Payable_Amount__c = 2000,
                Status__c = 'Reconciled'
            ),
            new Receipt__c(
                Unit__c = units[2].Id,
                Voucher_Number_To_Process_Trussardi2__c = 3,
                Description__c = 'Test Receipt 3',
                Payment_Date__c = Date.today(),
                Payable_Amount__c = 3000,
                Status__c = 'Reconciled'
            ),
            new Receipt__c(
                Unit__c = units[3].Id,
                Voucher_Number_To_Process_POST__c = 4,
                Description__c = 'Test Receipt 4',
                Payment_Date__c = Date.today(),
                Payable_Amount__c = 4000,
                Status__c = 'Reconciled'
            ),
            new Receipt__c(
                Unit__c = units[4].Id,
                Voucher_Number_To_Process_Gianfranco__c = 2,
                Description__c = 'Test Receipt 5',
                Payment_Date__c = Date.today(),
                Payable_Amount__c = 5000,
                Status__c = 'Reconciled'
            ),
            new Receipt__c(
                Unit__c = units[5].Id,
                Voucher_Number_To_Process_T2_Offices__c = 10,
                Description__c = 'Test Receipt T2',
                Payment_Date__c = Date.today(),
                Payable_Amount__c = 6000,
                Status__c = 'Reconciled'
            ),
            new Receipt__c(
                Unit__c = units[6].Id,
                Voucher_Number_To_Process_MIRA_VERDE__c = 5,
                Description__c = 'Test Receipt MIRA',
                Payment_Date__c = Date.today(),
                Payable_Amount__c = 7000,
                Status__c = 'Reconciled'
            ),
            new Receipt__c(
                Unit__c = units[7].Id,
                Voucher_Number_To_Process_Richmond__c = 3,
                Description__c = 'Test Receipt John Richmond',
                Payment_Date__c = Date.today(),
                Payable_Amount__c = 8000,
                Status__c = 'Reconciled'
            )
        };
        insert initialReceipts;
        
        // Restore original skipTrigger value
        ReceiptTriggerHelper.skipTrigger = originalSkipValue;
    }

    @IsTest
    static void testBentleyReceiptNumbering() {
        // Get the test unit
        Unit__c bentleyUnit = [
            SELECT Id, Project_Name_F__c 
            FROM Unit__c 
            WHERE Project_Name_F__c = 'MIRA Villas Designed by Bentley Home' 
            LIMIT 1
        ];

        // Create new receipt
        Receipt__c newReceipt = new Receipt__c(
            Unit__c = bentleyUnit.Id,
            Description__c = 'New Bentley Receipt',
            Payment_Date__c = Date.today(),
            Payable_Amount__c = 1000,
            Status__c = 'Reconciled'
        );
        
        Test.startTest();
        insert newReceipt;
        Test.stopTest();

        // Query for the updated receipt
        Receipt__c updatedReceipt = [
            SELECT Id, Voucher_Number_To_Process_Bentley__c
            FROM Receipt__c 
            WHERE Id = :newReceipt.Id
        ];

        // Verify the receipt numbering
        System.assertNotEquals(null, updatedReceipt.Voucher_Number_To_Process_Bentley__c, 
            'Bentley receipt number should not be null');
        System.assertEquals(8, updatedReceipt.Voucher_Number_To_Process_Bentley__c, 
            'Bentley receipt number should be incremented to 8');
    }

    @IsTest
    static void testTrussardiReceiptNumbering() {
        // Get the test unit
        Unit__c trussardiUnit = [
            SELECT Id, Project_Name_F__c 
            FROM Unit__c 
            WHERE Project_Name_F__c = 'Trussardi Residences' 
            LIMIT 1
        ];

        // Create new receipt
        Receipt__c newReceipt = new Receipt__c(
            Unit__c = trussardiUnit.Id,
            Description__c = 'New Trussardi Receipt',
            Payment_Date__c = Date.today(),
            Payable_Amount__c = 1000,
            Status__c = 'Reconciled'
        );
        
        Test.startTest();
        insert newReceipt;
        Test.stopTest();

        // Query for the updated receipt
        Receipt__c updatedReceipt = [
            SELECT Id, Voucher_Number_To_Process_Trussardi__c
            FROM Receipt__c 
            WHERE Id = :newReceipt.Id
        ];

        // Verify the receipt numbering
        System.assertNotEquals(null, updatedReceipt.Voucher_Number_To_Process_Trussardi__c, 
            'Trussardi receipt number should not be null');
        System.assertEquals(6, updatedReceipt.Voucher_Number_To_Process_Trussardi__c, 
            'Trussardi receipt number should be incremented to 6');
    }

    @IsTest
    static void testTrussardi2ReceiptNumbering() {
        // Get the test unit
        Unit__c trussardi2Unit = [
            SELECT Id, Project_Name_F__c 
            FROM Unit__c 
            WHERE Project_Name_F__c = 'Trussardi Residences 2' 
            LIMIT 1
        ];

        // Create new receipt
        Receipt__c newReceipt = new Receipt__c(
            Unit__c = trussardi2Unit.Id,
            Description__c = 'New Trussardi 2 Receipt',
            Payment_Date__c = Date.today(),
            Payable_Amount__c = 1000,
            Status__c = 'Reconciled'
        );
        
        Test.startTest();
        insert newReceipt;
        Test.stopTest();

        // Query for the updated receipt
        Receipt__c updatedReceipt = [
            SELECT Id, Voucher_Number_To_Process_Trussardi2__c
            FROM Receipt__c 
            WHERE Id = :newReceipt.Id
        ];

        // Verify the receipt numbering
        System.assertNotEquals(null, updatedReceipt.Voucher_Number_To_Process_Trussardi2__c, 
            'Trussardi 2 receipt number should not be null');
        System.assertEquals(4, updatedReceipt.Voucher_Number_To_Process_Trussardi2__c, 
            'Trussardi 2 receipt number should be incremented to 4');
    }

    @IsTest
    static void testPOSTReceiptNumbering() {
        // Get the test unit
        Unit__c postUnit = [
            SELECT Id, Project_Name_F__c 
            FROM Unit__c 
            WHERE Project_Name_F__c = 'POST HOTEL & RESIDENCES By ELIE SAAB' 
            LIMIT 1
        ];

        // Create new receipt
        Receipt__c newReceipt = new Receipt__c(
            Unit__c = postUnit.Id,
            Description__c = 'New POST Receipt',
            Payment_Date__c = Date.today(),
            Payable_Amount__c = 1000,
            Status__c = 'Reconciled'
        );
        
        Test.startTest();
        insert newReceipt;
        Test.stopTest();

        // Query for the updated receipt
        Receipt__c updatedReceipt = [
            SELECT Id, Voucher_Number_To_Process_POST__c
            FROM Receipt__c 
            WHERE Id = :newReceipt.Id
        ];

        // Verify the receipt numbering
        System.assertNotEquals(null, updatedReceipt.Voucher_Number_To_Process_POST__c, 
            'POST receipt number should not be null');
        System.assertEquals(5, updatedReceipt.Voucher_Number_To_Process_POST__c, 
            'POST receipt number should be incremented to 5');
    }

    @IsTest
    static void testGianfrancoReceiptNumbering() {
        // Get the test unit
        Unit__c gianfrancoUnit = [
            SELECT Id, Project_Name_F__c 
            FROM Unit__c 
            WHERE Project_Name_F__c = 'GIANFRANCO FERRE RESIDENCES' 
            LIMIT 1
        ];

        // Create new receipt
        Receipt__c newReceipt = new Receipt__c(
            Unit__c = gianfrancoUnit.Id,
            Description__c = 'New Gianfranco Receipt',
            Payment_Date__c = Date.today(),
            Payable_Amount__c = 1000,
            Status__c = 'Reconciled'
        );
        
        Test.startTest();
        insert newReceipt;
        Test.stopTest();

        // Query for the updated receipt
        Receipt__c updatedReceipt = [
            SELECT Id, Voucher_Number_To_Process_Gianfranco__c
            FROM Receipt__c 
            WHERE Id = :newReceipt.Id
        ];

        // Verify the receipt numbering
        System.assertNotEquals(null, updatedReceipt.Voucher_Number_To_Process_Gianfranco__c, 
            'Gianfranco receipt number should not be null');
        System.assertEquals(3, updatedReceipt.Voucher_Number_To_Process_Gianfranco__c, 
            'Gianfranco receipt number should be incremented to 3');
    }

    @IsTest
    static void testInvalidUnit() {
        // We need to write this as a completely independent test
        // to avoid any shared state with other tests
        
        // Create new receipt without a unit
        Receipt__c newReceipt = new Receipt__c(
            Description__c = 'Invalid Receipt',
            Payment_Date__c = Date.today(),
            Payable_Amount__c = 1000,
            Status__c = 'Reconciled',
            Unit__c = null, // Explicitly set to null
            Voucher_Number_To_Process_Trussardi__c = null,
            Voucher_Number_To_Process_Trussardi2__c = null,
            Voucher_Number_To_Process_Bentley__c = null,
            Voucher_Number_To_Process_POST__c = null,
            Voucher_Number_To_Process_Gianfranco__c = null // Explicitly set to null
        );
        
        // Reset skipTrigger to make sure trigger runs
        ReceiptTriggerHelper.skipTrigger = false;
        
        Test.startTest();
        System.debug('Before insert: ReceiptTriggerHelper.skipTrigger = ' + ReceiptTriggerHelper.skipTrigger);
        insert newReceipt;
        Test.stopTest();

        // Query for the updated receipt
        List<Receipt__c> updatedReceipts = [
            SELECT Id, Voucher_Number_To_Process_Trussardi__c, Voucher_Number_To_Process_Trussardi2__c,
                   Voucher_Number_To_Process_Bentley__c, Voucher_Number_To_Process_POST__c,
                   Voucher_Number_To_Process_Gianfranco__c
            FROM Receipt__c 
            WHERE Id = :newReceipt.Id
        ];

        System.assert(!updatedReceipts.isEmpty(), 'Receipt should be found after insert');
        Receipt__c updatedReceipt = updatedReceipts[0];
        
        // Debug logging to see what values are actually set
        System.debug('Updated Receipt Values:');
        System.debug('Trussardi: ' + updatedReceipt.Voucher_Number_To_Process_Trussardi__c);
        System.debug('Trussardi2: ' + updatedReceipt.Voucher_Number_To_Process_Trussardi2__c);
        System.debug('Bentley: ' + updatedReceipt.Voucher_Number_To_Process_Bentley__c);
        System.debug('POST: ' + updatedReceipt.Voucher_Number_To_Process_POST__c);
        System.debug('Gianfranco: ' + updatedReceipt.Voucher_Number_To_Process_Gianfranco__c);
        
        // Verify no numbers were assigned - accept either null or 0 as valid states
        System.assert(updatedReceipt.Voucher_Number_To_Process_Trussardi__c == null || 
                     updatedReceipt.Voucher_Number_To_Process_Trussardi__c == 0, 
            'Trussardi number should be null or zero for invalid unit');
        System.assert(updatedReceipt.Voucher_Number_To_Process_Trussardi2__c == null || 
                     updatedReceipt.Voucher_Number_To_Process_Trussardi2__c == 0, 
            'Trussardi2 number should be null or zero for invalid unit');
        System.assert(updatedReceipt.Voucher_Number_To_Process_Bentley__c == null || 
                     updatedReceipt.Voucher_Number_To_Process_Bentley__c == 0, 
            'Bentley number should be null or zero for invalid unit');
        System.assert(updatedReceipt.Voucher_Number_To_Process_POST__c == null || 
                     updatedReceipt.Voucher_Number_To_Process_POST__c == 0, 
            'POST number should be null or zero for invalid unit');
        System.assert(updatedReceipt.Voucher_Number_To_Process_Gianfranco__c == null || 
                     updatedReceipt.Voucher_Number_To_Process_Gianfranco__c == 0, 
            'Gianfranco number should be null or zero for invalid unit');
    }

    @IsTest
    static void testSkipTrigger() {
        ReceiptTriggerHelper.skipTrigger = true;
        Unit__c bentleyUnit = [
            SELECT Id
            FROM Unit__c
            WHERE Project_Name_F__c = 'MIRA Villas Designed by Bentley Home'
            LIMIT 1
        ];
        Receipt__c newReceipt = new Receipt__c(
            Unit__c = bentleyUnit.Id,
            Description__c = 'Skipped Receipt',
            Payment_Date__c = Date.today(),
            Payable_Amount__c = 1000,
            Status__c = 'Reconciled'
        );

        Test.startTest();
        insert newReceipt;
        Test.stopTest();

        ReceiptTriggerHelper.skipTrigger = false;

        Receipt__c inserted = [
            SELECT Voucher_Number_To_Process_Bentley__c
            FROM Receipt__c
            WHERE Id = :newReceipt.Id
        ];
        System.assertEquals(null, inserted.Voucher_Number_To_Process_Bentley__c,
            'Bentley voucher number should be null when skipTrigger is true');
    }

    @IsTest
    static void testT2OfficesReceiptNumbering() {
        Unit__c t2Unit = [SELECT Id FROM Unit__c WHERE Property_Code_Text__c = 'TEST-T2-OFFICE' LIMIT 1];
        Receipt__c newReceipt = new Receipt__c(
            Unit__c = t2Unit.Id,
            Description__c = 'New T2 Offices Receipt',
            Payment_Date__c = Date.today(),
            Payable_Amount__c = 1000,
            Status__c = 'Reconciled'
        );

        Test.startTest();
        insert newReceipt;
        Test.stopTest();

        Receipt__c updated = [
            SELECT Voucher_Number_To_Process_T2_Offices__c
            FROM Receipt__c
            WHERE Id = :newReceipt.Id
        ];
        System.assertEquals(11, updated.Voucher_Number_To_Process_T2_Offices__c,
            'T2 Offices voucher number should increment to 11');
    }

    @IsTest
    static void testMiraVerdeReceiptNumbering() {
        Unit__c miraUnit = [SELECT Id FROM Unit__c WHERE Property_Code_Text__c = 'TEST-MIRA-001' LIMIT 1];
        Receipt__c newReceipt = new Receipt__c(
            Unit__c = miraUnit.Id,
            Description__c = 'New MIRA VERDE Receipt',
            Payment_Date__c = Date.today(),
            Payable_Amount__c = 1000,
            Status__c = 'Reconciled'
        );

        Test.startTest();
        insert newReceipt;
        Test.stopTest();

        Receipt__c updated = [
            SELECT Voucher_Number_To_Process_MIRA_VERDE__c
            FROM Receipt__c
            WHERE Id = :newReceipt.Id
        ];
        System.assertEquals(6, updated.Voucher_Number_To_Process_MIRA_VERDE__c,
            'MIRA VERDE voucher number should increment to 6');
    }

    @IsTest
    static void testRichmondReceiptNumbering() {
        Unit__c richmondUnit = [SELECT Id FROM Unit__c WHERE Property_Code_Text__c = 'TEST-RICHMOND-001' LIMIT 1];
        Receipt__c newReceipt = new Receipt__c(
            Unit__c = richmondUnit.Id,
            Description__c = 'New John Richmond Receipt',
            Payment_Date__c = Date.today(),
            Payable_Amount__c = 1000,
            Status__c = 'Reconciled'
        );

        Test.startTest();
        insert newReceipt;
        Test.stopTest();

        Receipt__c updated = [
            SELECT Voucher_Number_To_Process_Richmond__c
            FROM Receipt__c
            WHERE Id = :newReceipt.Id
        ];
        System.assertEquals(4, updated.Voucher_Number_To_Process_Richmond__c,
            'John Richmond voucher number should increment to 4');
    }

    @IsTest
    static void testUnknownProjectName() {
        Unit__c unknownUnit = [
            SELECT Id, Project_Name_F__c
            FROM Unit__c
            WHERE Property_Code_Text__c = 'TEST-UNKNOWN'
            LIMIT 1
        ];
        System.assertEquals('Unknown Project XYZ', unknownUnit.Project_Name_F__c,
            'Test unit should have an unrecognized project name');

        Receipt__c newReceipt = new Receipt__c(
            Unit__c = unknownUnit.Id,
            Description__c = 'Unknown Project Receipt',
            Payment_Date__c = Date.today(),
            Payable_Amount__c = 1000,
            Status__c = 'Reconciled'
        );

        Test.startTest();
        ReceiptTriggerHelper.handleVoucherNumberAssignment(new List<Receipt__c>{ newReceipt });
        Test.stopTest();

        System.assertEquals(null, newReceipt.Voucher_Number_To_Process_Trussardi__c,
            'Trussardi voucher should not be assigned for unknown project');
        System.assertEquals(null, newReceipt.Voucher_Number_To_Process_Trussardi2__c,
            'Trussardi2 voucher should not be assigned for unknown project');
        System.assertEquals(null, newReceipt.Voucher_Number_To_Process_Bentley__c,
            'Bentley voucher should not be assigned for unknown project');
        System.assertEquals(null, newReceipt.Voucher_Number_To_Process_POST__c,
            'POST voucher should not be assigned for unknown project');
        System.assertEquals(null, newReceipt.Voucher_Number_To_Process_Gianfranco__c,
            'Gianfranco voucher should not be assigned for unknown project');
        System.assertEquals(null, newReceipt.Voucher_Number_To_Process_T2_Offices__c,
            'T2 Offices voucher should not be assigned for unknown project');
        System.assertEquals(null, newReceipt.Voucher_Number_To_Process_MIRA_VERDE__c,
            'MIRA VERDE voucher should not be assigned for unknown project');
        System.assertEquals(null, newReceipt.Voucher_Number_To_Process_Richmond__c,
            'John Richmond voucher should not be assigned for unknown project');
    }
}