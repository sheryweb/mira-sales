@isTest
private class NoticeOfCompletionTest {
    
    @testSetup
    static void setup() {
        // Create test account (Business Account)
        Account testAccount = new Account(
            Name = 'John Doe',
            BillingStreet = '123 Main Street',
            BillingCity = 'Dubai',
            BillingState = 'Dubai',
            BillingPostalCode = '12345',
            BillingCountry = 'UAE'
        );
        insert testAccount;
        
        // Create test Project
        Project__c testProject = new Project__c(
            Name = 'Trussardi Residences',
            Description__c = 'Test Project Description',
            District__c = 'Meydan',
            Coordinates_Latitude__c = 25.0,
            Coordinates_Longitude__c = 55.0,
            Handover__c = Date.today().addMonths(12),
            Minimum_Cost__c = 1000000,
            Publish_Project__c = 'Published',
            Project_Code__c = 'TRUSS'
        );
        insert testProject;
        
        // Create test unit - must start with Draft status due to validation rule
        Unit__c testUnit = new Unit__c(
            Title__c = 'A-1102',
            Account__c = testAccount.Id,
            Status__c = 'Draft',
            Project__c = testProject.Id,
            Cost_AED__c = 1000000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Floor__c = 5,
            Number_of_Bedrooms__c = 2,
            Number_of_Bathrooms__c = 2,
            Building__c = 'Building A'
        );
        insert testUnit;
        
        // Update to Sold status after creation
        testUnit.Status__c = 'Sold';
        update testUnit;
        
        // Create test Opportunity with Sold status
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Sold',
            CloseDate = Date.today(),
            Unit__c = testUnit.Id
        );
        insert testOpp;
    }
    
    @isTest
    static void testConstructorWithValidUnitId() {
        // Get the test unit
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];
        
        // Set up page parameters
        PageReference pageRef = Page.CompletionDateUpdateTrussardi;
        pageRef.getParameters().put('unitId', testUnit.Id);
        Test.setCurrentPage(pageRef);
        
        // Test
        Test.startTest();
        NoticeOfCompletion controller = new NoticeOfCompletion();
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, controller.unit, 'Unit should not be null');
        System.assertEquals('A-1102', controller.unitTitle, 'Unit title should match');
        System.assertNotEquals(null, controller.projectName, 'Project name should be set');
        System.assertEquals('John Doe', controller.clientName, 'Client name should match');
        System.assertNotEquals(null, controller.clientEmail, 'Client email should be set');
        System.assertNotEquals(null, controller.todayDate, 'Today date should not be null');
    }
    
    @isTest
    static void testConstructorWithInvalidUnitId() {
        // Set up page parameters with invalid ID
        PageReference pageRef = Page.CompletionDateUpdateTrussardi;
        pageRef.getParameters().put('unitId', 'invalid-id');
        Test.setCurrentPage(pageRef);
        
        // Test
        Test.startTest();
        NoticeOfCompletion controller = new NoticeOfCompletion();
        Test.stopTest();
        
        // Assert - should have error message
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assert(messages.size() > 0, 'Should have error message');
    }
    
    @isTest
    static void testConstructorWithWrongObjectTypeId() {
        // Get an Account ID (different object type)
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Set up page parameters with Account ID instead of Unit ID
        PageReference pageRef = Page.CompletionDateUpdateTrussardi;
        pageRef.getParameters().put('unitId', testAccount.Id);
        Test.setCurrentPage(pageRef);
        
        // Test
        Test.startTest();
        NoticeOfCompletion controller = new NoticeOfCompletion();
        Test.stopTest();
        
        // Assert - should have error message about wrong object type
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assert(messages.size() > 0, 'Should have error message for wrong object type');
    }
    
    @isTest
    static void testConstructorWithNoUnitId() {
        // Set up page parameters without ID
        PageReference pageRef = Page.CompletionDateUpdateTrussardi;
        Test.setCurrentPage(pageRef);
        
        // Test
        Test.startTest();
        NoticeOfCompletion controller = new NoticeOfCompletion();
        Test.stopTest();
        
        // Assert - should have error message
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assert(messages.size() > 0, 'Should have error message');
    }
    
    @isTest
    static void testConstructorWithNonExistentUnitId() {
        // Create a fake unit ID
        String fakeUnitId = 'a0A000000000000AAA';
        
        // Set up page parameters
        PageReference pageRef = Page.CompletionDateUpdateTrussardi;
        pageRef.getParameters().put('unitId', fakeUnitId);
        Test.setCurrentPage(pageRef);
        
        // Test
        Test.startTest();
        NoticeOfCompletion controller = new NoticeOfCompletion();
        Test.stopTest();
        
        // Assert - should have error message
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assert(messages.size() > 0, 'Should have error message for non-existent unit');
    }
    
    @isTest
    static void testWithUnitWithoutAccount() {
        // Get test project
        Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
        
        // Create unit without account - start with Draft status
        Unit__c testUnit = new Unit__c(
            Title__c = 'B-2201',
            Status__c = 'Draft',
            Project__c = testProject.Id,
            Cost_AED__c = 1000000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Floor__c = 5,
            Number_of_Bedrooms__c = 2,
            Number_of_Bathrooms__c = 2,
            Building__c = 'Building B'
        );
        insert testUnit;
        
        // Update to Sold status
        testUnit.Status__c = 'Sold';
        update testUnit;
        
        // Set up page parameters
        PageReference pageRef = Page.CompletionDateUpdateTrussardi;
        pageRef.getParameters().put('unitId', testUnit.Id);
        Test.setCurrentPage(pageRef);
        
        // Test
        Test.startTest();
        NoticeOfCompletion controller = new NoticeOfCompletion();
        Test.stopTest();
        
        // Assert
        System.assertEquals('', controller.clientName, 'Client name should be empty');
        System.assertEquals('', controller.clientEmail, 'Client email should be empty');
        System.assertEquals('', controller.clientAddress, 'Client address should be empty');
        System.assertEquals('B-2201', controller.unitTitle, 'Unit title should match');
        System.assertNotEquals(null, controller.projectName, 'Project name should be initialized');
    }
    
    @isTest
    static void testConstructorWithNonSoldUnit() {
        // Get test project
        Project__c testProject = [SELECT Id FROM Project__c LIMIT 1];
        
        // Create unit with Draft status first
        Unit__c testUnit = new Unit__c(
            Title__c = 'C-3301',
            Status__c = 'Draft',
            Project__c = testProject.Id,
            Cost_AED__c = 1000000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Floor__c = 5,
            Number_of_Bedrooms__c = 2,
            Number_of_Bathrooms__c = 2,
            Building__c = 'Building C'
        );
        insert testUnit;
        
        // Update to Available status (non-Sold)
        testUnit.Status__c = 'Published';
        update testUnit;
        
        // Set up page parameters
        PageReference pageRef = Page.CompletionDateUpdateTrussardi;
        pageRef.getParameters().put('unitId', testUnit.Id);
        Test.setCurrentPage(pageRef);
        
        // Test
        Test.startTest();
        NoticeOfCompletion controller = new NoticeOfCompletion();
        Test.stopTest();
        
        // Assert - should have error message about unit not being sold
        List<ApexPages.Message> messages = ApexPages.getMessages();
        System.assert(messages.size() > 0, 'Should have error message for non-Sold unit');
    }
    
    @isTest
    static void testConstructorWithJointOwners() {
        // Get test data
        Unit__c testUnit = [SELECT Id FROM Unit__c WHERE Title__c = 'A-1102' LIMIT 1];
        Opportunity testOpp = [SELECT Id, AccountId FROM Opportunity WHERE Unit__c = :testUnit.Id LIMIT 1];
        
        // Create joint owner accounts (Business Accounts)
        Account jointOwner1 = new Account(
            Name = 'Jane Smith'
        );
        insert jointOwner1;
        
        Account jointOwner2 = new Account(
            Name = 'Bob Johnson'
        );
        insert jointOwner2;
        
        // Create joint owner records
        List<Joint_Owners__c> jointOwners = new List<Joint_Owners__c>();
        jointOwners.add(new Joint_Owners__c(
            Opportunity__c = testOpp.Id,
            Account__c = jointOwner1.Id,
            Order__c = 1,
            Ownership_Share__c = 50
        ));
        jointOwners.add(new Joint_Owners__c(
            Opportunity__c = testOpp.Id,
            Account__c = jointOwner2.Id,
            Order__c = 2,
            Ownership_Share__c = 50
        ));
        insert jointOwners;
        
        // Set up page parameters
        PageReference pageRef = Page.CompletionDateUpdateTrussardi;
        pageRef.getParameters().put('unitId', testUnit.Id);
        Test.setCurrentPage(pageRef);
        
        // Test
        Test.startTest();
        NoticeOfCompletion controller = new NoticeOfCompletion();
        Test.stopTest();
        
        // Assert - client name should include all owners joined with &
        System.assertNotEquals(null, controller.clientName, 'Client name should not be null');
        System.assert(controller.clientName.contains('John Doe'), 'Client name should contain primary account name');
        System.assert(controller.clientName.contains('Jane Smith'), 'Client name should contain first joint owner');
        System.assert(controller.clientName.contains('Bob Johnson'), 'Client name should contain second joint owner');
        System.assert(controller.clientName.contains(' & '), 'Client name should contain & separator');
    }
}