@isTest
private class UnitFileServiceControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create test Unit__c record
        Unit__c testUnit = new Unit__c();
        insert testUnit;

        // Create test File__c records for both types
        File__c testFloorPlan = new File__c(
            Type__c = 'Floor Plan',
            Unit__c = testUnit.Id
        );
        File__c testUnitLayout = new File__c(
            Type__c = 'Unit Layout Preview',
            Unit__c = testUnit.Id
        );
        insert new List<File__c>{testFloorPlan, testUnitLayout};

        // Create ContentVersions for Floor Plan
        ContentVersion cvFloorPlan = new ContentVersion(
            Title = 'Test Floor Plan.pdf',
            PathOnClient = 'TestFloorPlan.pdf',
            VersionData = Blob.valueOf('Test PDF Content for Floor Plan')
        );
        insert cvFloorPlan;

        // Create ContentVersions for Unit Layout
        ContentVersion cvUnitLayout = new ContentVersion(
            Title = 'Test Unit Layout.pdf',
            PathOnClient = 'TestUnitLayout.pdf',
            VersionData = Blob.valueOf('Test PDF Content for Unit Layout')
        );
        insert cvUnitLayout;

        // Re-query ContentVersions to get the populated ContentDocumentIds
        cvFloorPlan = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cvFloorPlan.Id LIMIT 1];
        cvUnitLayout = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cvUnitLayout.Id LIMIT 1];

        // Create ContentDocumentLinks to link ContentDocuments with File__c records
        ContentDocumentLink cdlFloorPlan = new ContentDocumentLink(
            ContentDocumentId = cvFloorPlan.ContentDocumentId,
            LinkedEntityId = testFloorPlan.Id,
            ShareType = 'I',
            Visibility = 'AllUsers'
        );
        ContentDocumentLink cdlUnitLayout = new ContentDocumentLink(
            ContentDocumentId = cvUnitLayout.ContentDocumentId,
            LinkedEntityId = testUnitLayout.Id,
            ShareType = 'I',
            Visibility = 'AllUsers'
        );
        insert new List<ContentDocumentLink>{cdlFloorPlan, cdlUnitLayout};
    }

    @isTest
    static void testGetFileContent_SuccessPath() {
        // Get test data
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];

        // Create a working REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitFile/';
        req.httpMethod = 'GET';
        req.params.put('unitId', testUnit.Id);
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitFileServiceController.FileResponseWrapper response = UnitFileServiceController.getFileContent();
        Test.stopTest();

        // Comprehensive assertions for success path
        System.assertEquals(true, response.success, 'Response should be successful');
        System.assertEquals('Files retrieved successfully', response.message);
        System.assertNotEquals(null, response.files, 'Files wrapper should not be null');
        System.assertEquals(1, response.files.floorPlans.size(), 'Should return 1 floor plan');
        System.assertEquals(1, response.files.unitLayouts.size(), 'Should return 1 unit layout');
        
        // Verify floor plan
        UnitFileServiceController.FileData floorPlanData = response.files.floorPlans[0];
        System.assertEquals('Floor Plan', floorPlanData.type);
        System.assertEquals('Test Floor Plan.pdf', floorPlanData.fileName);
        System.assertNotEquals(null, floorPlanData.fileContent, 'File content should not be null');
        System.assert(floorPlanData.contentSize > 0, 'Content size should be greater than 0');
        
        // Verify unit layout
        UnitFileServiceController.FileData unitLayoutData = response.files.unitLayouts[0];
        System.assertEquals('Unit Layout Preview', unitLayoutData.type);
        System.assertEquals('Test Unit Layout.pdf', unitLayoutData.fileName);
        System.assertNotEquals(null, unitLayoutData.fileContent, 'File content should not be null');
        System.assert(unitLayoutData.contentSize > 0, 'Content size should be greater than 0');
    }

    @isTest
    static void testGetFileContent_MissingParameter() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitFile/';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitFileServiceController.FileResponseWrapper response = UnitFileServiceController.getFileContent();
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('UnitId parameter is required', response.message);
    }

    @isTest
    static void testGetFileContent_BlankParameter() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitFile/';
        req.httpMethod = 'GET';
        req.params.put('unitId', '');
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitFileServiceController.FileResponseWrapper response = UnitFileServiceController.getFileContent();
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('UnitId parameter is required', response.message);
    }

    @isTest
    static void testGetFileContent_UnitNotFound() {
        // Create a properly formatted but non-existent Unit ID
        Unit__c realUnit = [SELECT Id FROM Unit__c LIMIT 1];
        String nonExistentId = String.valueOf(realUnit.Id).substring(0, 12) + '999';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitFile/';
        req.httpMethod = 'GET';
        req.params.put('unitId', nonExistentId);
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitFileServiceController.FileResponseWrapper response = UnitFileServiceController.getFileContent();
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('No files found for the specified unit and types', response.message);
    }

    @isTest
    static void testGetFileContent_NoContentDocumentLink() {
        // Create a Unit__c and File__c record without ContentDocumentLink
        Unit__c testUnit = new Unit__c();
        insert testUnit;
        
        File__c testFileWithoutLink = new File__c(
            Type__c = 'Floor Plan',
            Unit__c = testUnit.Id
        );
        insert testFileWithoutLink;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitFile/';
        req.httpMethod = 'GET';
        req.params.put('unitId', testUnit.Id);
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitFileServiceController.FileResponseWrapper response = UnitFileServiceController.getFileContent();
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('No content documents linked to these files', response.message);
    }

    @isTest
    static void testGetFileContent_InvalidIdFormat() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitFile/';
        req.httpMethod = 'GET';
        req.params.put('unitId', 'invalid_id_format');
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitFileServiceController.FileResponseWrapper response = UnitFileServiceController.getFileContent();
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('No files found for the specified unit and types', response.message);
    }

    @isTest
    static void testGetFileContent_ExceptionHandling() {
        RestContext.request = null;

        Test.startTest();
        UnitFileServiceController.FileResponseWrapper response = UnitFileServiceController.getFileContent();
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assert(response.message.startsWith('Error:'));
    }

    @isTest
    static void testFileResponseWrapper_Constructor() {
        Test.startTest();
        UnitFileServiceController.FileResponseWrapper response = new UnitFileServiceController.FileResponseWrapper();
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('', response.message);
        System.assertNotEquals(null, response.files, 'Files wrapper should not be null');
        System.assertEquals(0, response.files.floorPlans.size());
        System.assertEquals(0, response.files.unitLayouts.size());
    }

    @isTest
    static void testFileResponseWrapper_AllProperties() {
        UnitFileServiceController.FileResponseWrapper response = new UnitFileServiceController.FileResponseWrapper();
        
        // Test all properties can be set and retrieved
        response.success = true;
        response.message = 'Test message';
        
        // Create FileData objects for floor plans
        UnitFileServiceController.FileData floorPlan1 = new UnitFileServiceController.FileData();
        floorPlan1.fileId = 'testId1';
        floorPlan1.fileName = 'testFloorPlan1.pdf';
        floorPlan1.fileType = 'PDF';
        floorPlan1.fileExtension = 'pdf';
        floorPlan1.contentSize = 1000;
        floorPlan1.fileContent = 'testContent1';
        floorPlan1.type = 'Floor Plan';
        
        UnitFileServiceController.FileData floorPlan2 = new UnitFileServiceController.FileData();
        floorPlan2.fileId = 'testId2';
        floorPlan2.fileName = 'testFloorPlan2.pdf';
        floorPlan2.fileType = 'PDF';
        floorPlan2.fileExtension = 'pdf';
        floorPlan2.contentSize = 2000;
        floorPlan2.fileContent = 'testContent2';
        floorPlan2.type = 'Floor Plan';
        
        // Create FileData objects for unit layouts
        UnitFileServiceController.FileData unitLayout1 = new UnitFileServiceController.FileData();
        unitLayout1.fileId = 'testId3';
        unitLayout1.fileName = 'testUnitLayout1.pdf';
        unitLayout1.fileType = 'PDF';
        unitLayout1.fileExtension = 'pdf';
        unitLayout1.contentSize = 1500;
        unitLayout1.fileContent = 'testContent3';
        unitLayout1.type = 'Unit Layout Preview';
        
        // Set the files using the new structure
        response.files.floorPlans = new List<UnitFileServiceController.FileData>{floorPlan1, floorPlan2};
        response.files.unitLayouts = new List<UnitFileServiceController.FileData>{unitLayout1};

        // Verify all properties
        System.assertEquals(true, response.success);
        System.assertEquals('Test message', response.message);
        System.assertEquals(2, response.files.floorPlans.size());
        System.assertEquals(1, response.files.unitLayouts.size());
        
        // Verify first floor plan
        System.assertEquals('testId1', response.files.floorPlans[0].fileId);
        System.assertEquals('testFloorPlan1.pdf', response.files.floorPlans[0].fileName);
        System.assertEquals('PDF', response.files.floorPlans[0].fileType);
        System.assertEquals('pdf', response.files.floorPlans[0].fileExtension);
        System.assertEquals(1000, response.files.floorPlans[0].contentSize);
        System.assertEquals('testContent1', response.files.floorPlans[0].fileContent);
        System.assertEquals('Floor Plan', response.files.floorPlans[0].type);
        
        // Verify second floor plan
        System.assertEquals('testId2', response.files.floorPlans[1].fileId);
        System.assertEquals('testFloorPlan2.pdf', response.files.floorPlans[1].fileName);
        System.assertEquals('PDF', response.files.floorPlans[1].fileType);
        System.assertEquals('pdf', response.files.floorPlans[1].fileExtension);
        System.assertEquals(2000, response.files.floorPlans[1].contentSize);
        System.assertEquals('testContent2', response.files.floorPlans[1].fileContent);
        System.assertEquals('Floor Plan', response.files.floorPlans[1].type);
        
        // Verify unit layout
        System.assertEquals('testId3', response.files.unitLayouts[0].fileId);
        System.assertEquals('testUnitLayout1.pdf', response.files.unitLayouts[0].fileName);
        System.assertEquals('PDF', response.files.unitLayouts[0].fileType);
        System.assertEquals('pdf', response.files.unitLayouts[0].fileExtension);
        System.assertEquals(1500, response.files.unitLayouts[0].contentSize);
        System.assertEquals('testContent3', response.files.unitLayouts[0].fileContent);
        System.assertEquals('Unit Layout Preview', response.files.unitLayouts[0].type);
    }

    @isTest
    static void testGetFileContent_NullParameterValue() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitFile/';
        req.httpMethod = 'GET';
        req.params.put('unitId', null);
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitFileServiceController.FileResponseWrapper response = UnitFileServiceController.getFileContent();
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('UnitId parameter is required', response.message);
    }

    @isTest
    static void testGetFileContent_WhitespaceParameter() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitFile/';
        req.httpMethod = 'GET';
        req.params.put('unitId', '   ');
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitFileServiceController.FileResponseWrapper response = UnitFileServiceController.getFileContent();
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('UnitId parameter is required', response.message);
    }

    @isTest
    static void testGetFileContent_MultipleFiles() {
        // Get test data
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];

        // Create an additional File__c record for the same unit
        File__c testFloorPlan2 = new File__c(
            Type__c = 'Floor Plan',
            Unit__c = testUnit.Id
        );
        insert testFloorPlan2;

        // Create ContentVersion for the new File__c
        ContentVersion cv2 = new ContentVersion(
            Title = 'Test Floor Plan 2.pdf',
            PathOnClient = 'TestFloorPlan2.pdf',
            VersionData = Blob.valueOf('Test PDF Content for Floor Plan 2')
        );
        insert cv2;

        // Re-query ContentVersion to get the populated ContentDocumentId
        cv2 = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv2.Id LIMIT 1];

        // Create ContentDocumentLink to link ContentDocument with the new File__c
        ContentDocumentLink cdl2 = new ContentDocumentLink(
            ContentDocumentId = cv2.ContentDocumentId,
            LinkedEntityId = testFloorPlan2.Id,
            ShareType = 'I',
            Visibility = 'AllUsers'
        );
        insert cdl2;

        // Create a working REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitFile/';
        req.httpMethod = 'GET';
        req.params.put('unitId', testUnit.Id);
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitFileServiceController.FileResponseWrapper response = UnitFileServiceController.getFileContent();
        Test.stopTest();

        // Assertions for multiple files
        System.assertEquals(true, response.success, 'Response should be successful');
        System.assertEquals('Files retrieved successfully', response.message);
        System.assertEquals(2, response.files.floorPlans.size(), 'Should return 2 floor plans');
        System.assertEquals(1, response.files.unitLayouts.size(), 'Should return 1 unit layout');
        
        // Verify floor plans are present (order may vary)
        Set<String> floorPlanNames = new Set<String>();
        for (UnitFileServiceController.FileData fileData : response.files.floorPlans) {
            System.assertEquals('Floor Plan', fileData.type);
            System.assertNotEquals(null, fileData.fileContent, 'File content should not be null');
            System.assert(fileData.contentSize > 0, 'Content size should be greater than 0');
            floorPlanNames.add(fileData.fileName);
        }
        
        System.assert(floorPlanNames.contains('Test Floor Plan.pdf'), 'Should contain first floor plan');
        System.assert(floorPlanNames.contains('Test Floor Plan 2.pdf'), 'Should contain second floor plan');
        
        // Verify unit layout
        System.assertEquals(1, response.files.unitLayouts.size(), 'Should have 1 unit layout');
        System.assertEquals('Unit Layout Preview', response.files.unitLayouts[0].type);
    }

    @isTest
    static void testFilesWrapper_Constructor() {
        Test.startTest();
        UnitFileServiceController.FilesWrapper filesWrapper = new UnitFileServiceController.FilesWrapper();
        Test.stopTest();

        System.assertNotEquals(null, filesWrapper.floorPlans, 'Floor plans list should not be null');
        System.assertNotEquals(null, filesWrapper.unitLayouts, 'Unit layouts list should not be null');
        System.assertEquals(0, filesWrapper.floorPlans.size(), 'Floor plans list should be empty');
        System.assertEquals(0, filesWrapper.unitLayouts.size(), 'Unit layouts list should be empty');
    }

    @isTest
    static void testFilesWrapper_Properties() {
        UnitFileServiceController.FilesWrapper filesWrapper = new UnitFileServiceController.FilesWrapper();
        
        // Create test data
        UnitFileServiceController.FileData floorPlan = new UnitFileServiceController.FileData();
        floorPlan.fileId = 'floorPlanId';
        floorPlan.fileName = 'Floor Plan.pdf';
        floorPlan.type = 'Floor Plan';
        
        UnitFileServiceController.FileData unitLayout = new UnitFileServiceController.FileData();
        unitLayout.fileId = 'unitLayoutId';
        unitLayout.fileName = 'Unit Layout.pdf';
        unitLayout.type = 'Unit Layout Preview';
        
        // Set properties
        filesWrapper.floorPlans = new List<UnitFileServiceController.FileData>{floorPlan};
        filesWrapper.unitLayouts = new List<UnitFileServiceController.FileData>{unitLayout};
        
        // Verify properties
        System.assertEquals(1, filesWrapper.floorPlans.size());
        System.assertEquals(1, filesWrapper.unitLayouts.size());
        System.assertEquals('Floor Plan', filesWrapper.floorPlans[0].type);
        System.assertEquals('Unit Layout Preview', filesWrapper.unitLayouts[0].type);
    }

    @isTest
    static void testGetFileContent_OnlyFloorPlans() {
        // Create a unit with only floor plans
        Unit__c testUnit = new Unit__c();
        insert testUnit;
        
        File__c testFloorPlan1 = new File__c(
            Type__c = 'Floor Plan',
            Unit__c = testUnit.Id
        );
        File__c testFloorPlan2 = new File__c(
            Type__c = 'Floor Plan',
            Unit__c = testUnit.Id
        );
        insert new List<File__c>{testFloorPlan1, testFloorPlan2};

        // Create ContentVersions
        ContentVersion cv1 = new ContentVersion(
            Title = 'Floor Plan 1.pdf',
            PathOnClient = 'FloorPlan1.pdf',
            VersionData = Blob.valueOf('Floor Plan 1 Content')
        );
        ContentVersion cv2 = new ContentVersion(
            Title = 'Floor Plan 2.pdf',
            PathOnClient = 'FloorPlan2.pdf',
            VersionData = Blob.valueOf('Floor Plan 2 Content')
        );
        insert new List<ContentVersion>{cv1, cv2};

        // Re-query to get ContentDocumentIds
        cv1 = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv1.Id LIMIT 1];
        cv2 = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv2.Id LIMIT 1];

        // Create ContentDocumentLinks
        ContentDocumentLink cdl1 = new ContentDocumentLink(
            ContentDocumentId = cv1.ContentDocumentId,
            LinkedEntityId = testFloorPlan1.Id,
            ShareType = 'I',
            Visibility = 'AllUsers'
        );
        ContentDocumentLink cdl2 = new ContentDocumentLink(
            ContentDocumentId = cv2.ContentDocumentId,
            LinkedEntityId = testFloorPlan2.Id,
            ShareType = 'I',
            Visibility = 'AllUsers'
        );
        insert new List<ContentDocumentLink>{cdl1, cdl2};

        // Test the API
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitFile/';
        req.httpMethod = 'GET';
        req.params.put('unitId', testUnit.Id);
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitFileServiceController.FileResponseWrapper response = UnitFileServiceController.getFileContent();
        Test.stopTest();

        // Verify response
        System.assertEquals(true, response.success);
        System.assertEquals(2, response.files.floorPlans.size());
        System.assertEquals(0, response.files.unitLayouts.size());
        
        // Verify both floor plans are present
        Set<String> fileNames = new Set<String>();
        for (UnitFileServiceController.FileData fileData : response.files.floorPlans) {
            System.assertEquals('Floor Plan', fileData.type);
            fileNames.add(fileData.fileName);
        }
        System.assert(fileNames.contains('Floor Plan 1.pdf'));
        System.assert(fileNames.contains('Floor Plan 2.pdf'));
    }

    @isTest
    static void testGetFileContent_OnlyUnitLayouts() {
        // Create a unit with only unit layouts
        Unit__c testUnit = new Unit__c();
        insert testUnit;
        
        File__c testUnitLayout1 = new File__c(
            Type__c = 'Unit Layout Preview',
            Unit__c = testUnit.Id
        );
        File__c testUnitLayout2 = new File__c(
            Type__c = 'Unit Layout Preview',
            Unit__c = testUnit.Id
        );
        insert new List<File__c>{testUnitLayout1, testUnitLayout2};

        // Create ContentVersions
        ContentVersion cv1 = new ContentVersion(
            Title = 'Unit Layout 1.pdf',
            PathOnClient = 'UnitLayout1.pdf',
            VersionData = Blob.valueOf('Unit Layout 1 Content')
        );
        ContentVersion cv2 = new ContentVersion(
            Title = 'Unit Layout 2.pdf',
            PathOnClient = 'UnitLayout2.pdf',
            VersionData = Blob.valueOf('Unit Layout 2 Content')
        );
        insert new List<ContentVersion>{cv1, cv2};

        // Re-query to get ContentDocumentIds
        cv1 = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv1.Id LIMIT 1];
        cv2 = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv2.Id LIMIT 1];

        // Create ContentDocumentLinks
        ContentDocumentLink cdl1 = new ContentDocumentLink(
            ContentDocumentId = cv1.ContentDocumentId,
            LinkedEntityId = testUnitLayout1.Id,
            ShareType = 'I',
            Visibility = 'AllUsers'
        );
        ContentDocumentLink cdl2 = new ContentDocumentLink(
            ContentDocumentId = cv2.ContentDocumentId,
            LinkedEntityId = testUnitLayout2.Id,
            ShareType = 'I',
            Visibility = 'AllUsers'
        );
        insert new List<ContentDocumentLink>{cdl1, cdl2};

        // Test the API
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitFile/';
        req.httpMethod = 'GET';
        req.params.put('unitId', testUnit.Id);
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitFileServiceController.FileResponseWrapper response = UnitFileServiceController.getFileContent();
        Test.stopTest();

        // Verify response
        System.assertEquals(true, response.success);
        System.assertEquals(0, response.files.floorPlans.size());
        System.assertEquals(2, response.files.unitLayouts.size());
        
        // Verify both unit layouts are present
        Set<String> fileNames = new Set<String>();
        for (UnitFileServiceController.FileData fileData : response.files.unitLayouts) {
            System.assertEquals('Unit Layout Preview', fileData.type);
            fileNames.add(fileData.fileName);
        }
        System.assert(fileNames.contains('Unit Layout 1.pdf'));
        System.assert(fileNames.contains('Unit Layout 2.pdf'));
    }

    @isTest
    static void testGetFileContent_NoFilesForUnit() {
        // Create a unit with no files
        Unit__c testUnit = new Unit__c();
        insert testUnit;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/UnitFile/';
        req.httpMethod = 'GET';
        req.params.put('unitId', testUnit.Id);
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        UnitFileServiceController.FileResponseWrapper response = UnitFileServiceController.getFileContent();
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('No files found for the specified unit and types', response.message);
    }
}