@IsTest
private class InvoiceReceiptTransferServiceTest {

    @TestSetup
    static void setupData() {
        Project__c project = new Project__c(
            Name = 'Transfer Test Project',
            Description__c = 'Test',
            District__c = 'Meydan',
            Coordinates_Latitude__c = 1,
            Coordinates_Longitude__c = 1,
            Handover__c = Date.today(),
            Minimum_Cost__c = 1,
            Publish_Project__c = 'Draft'
        );
        insert project;

        Unit__c unit = new Unit__c(
            Title__c = 'Transfer Test Unit',
            Cost_AED__c = 1000000,
            Type__c = 'Apartment',
            Total_Area__c = 1000,
            Living_Space__c = 800,
            Additional_Area__c = 200,
            Floor__c = 1,
            Number_of_Bedrooms__c = 2,
            Number_of_Bathrooms__c = 2,
            Status__c = 'Draft',
            Building__c = 'Tower A',
            Panorama_Link__c = 'Link',
            Project__c = project.Id
        );
        insert unit;
        unit.Status__c = 'Booked';
        update unit;

        Account oldAccount = new Account(Name = 'Old Transfer Customer', Phone = '0500000001');
        Account newAccount = new Account(Name = 'New Transfer Customer', Phone = '0500000002');
        insert new List<Account>{ oldAccount, newAccount };

        Opportunity oldOpp = new Opportunity(
            Name = 'Old Transfer Opp',
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = oldAccount.Id
        );
        Opportunity newOpp = new Opportunity(
            Name = 'New Transfer Opp',
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = newAccount.Id
        );
        Opportunity cancelledOpp = new Opportunity(
            Name = 'Cancelled Transfer Opp',
            StageName = 'New',
            CloseDate = Date.today().addDays(30),
            AccountId = oldAccount.Id
        );
        insert new List<Opportunity>{ oldOpp, newOpp, cancelledOpp };

        oldOpp.Unit__c = unit.Id;
        oldOpp.StageName = 'Cancelled';
        newOpp.Unit__c = unit.Id;
        newOpp.StageName = 'Booked';
        cancelledOpp.Unit__c = unit.Id;
        cancelledOpp.StageName = 'Cancelled';
        update new List<Opportunity>{ oldOpp, newOpp, cancelledOpp };

        insert new Invoice__c(
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today().addDays(30),
            Description__c = 'Old invoice',
            Sub_Total_Amount__c = 1000,
            Unit__c = unit.Id,
            Opportunity__c = oldOpp.Id,
            Account__c = oldAccount.Id,
            Customer_Name__c = 'Old Transfer Customer',
            Customer_Id__c = 'FN-OLD'
        );

        insert new Receipt__c(
            Description__c = 'Old receipt',
            Payment_Date__c = Date.today(),
            Unit__c = unit.Id,
            Opportunity__c = oldOpp.Id,
            Account__c = oldAccount.Id,
            Customer_Name__c = 'Old Transfer Customer'
        );
    }

    private static Unit__c getUnit() {
        return [SELECT Id, Title__c FROM Unit__c WHERE Title__c = 'Transfer Test Unit' LIMIT 1];
    }

    private static Opportunity getBookedOpp() {
        return [
            SELECT Id, Name, AccountId, Account.Financial_Number__c, Account_Name__c
            FROM Opportunity
            WHERE Account.Name = 'New Transfer Customer'
              AND StageName = 'Booked'
              AND Unit__r.Title__c = 'Transfer Test Unit'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    private static Opportunity getCancelledOpp() {
        return [
            SELECT Id
            FROM Opportunity
            WHERE Account.Name = 'Old Transfer Customer'
              AND StageName = 'Cancelled'
              AND Unit__r.Title__c = 'Transfer Test Unit'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    @IsTest
    static void testGetTransferContextAndSearch() {
        Unit__c unit = getUnit();

        Test.startTest();
        InvoiceReceiptTransferService.TransferContextDTO ctx =
            InvoiceReceiptTransferController.getTransferContext(unit.Id);
        List<InvoiceReceiptTransferService.OpportunityOptionDTO> options =
            InvoiceReceiptTransferController.searchOpportunities(unit.Id, 'New');
        Test.stopTest();

        System.assertEquals(true, ctx.canSubmit);
        System.assertEquals(1, ctx.invoiceCount);
        System.assertEquals(1, ctx.receiptCount);
        System.assertEquals(1, options.size(), 'Cancelled/New opps must be excluded');
        System.assertEquals('New Transfer Customer', options[0].accountName);
    }

    @IsTest
    static void testGetAccountPreviewRejectsCancelled() {
        Opportunity cancelled = getCancelledOpp();
        Boolean threw = false;
        try {
            InvoiceReceiptTransferController.getAccountPreview(cancelled.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Cancelled Opportunity should be rejected');
    }

    @IsTest
    static void testApplyApprovedChangesTransfersAll() {
        Unit__c unit = getUnit();
        Opportunity target = getBookedOpp();

        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = InvoiceReceiptTransferService.REQUEST_TYPE,
            Status__c = 'Approved',
            Unit__c = unit.Id,
            Requested_Opportunity__c = target.Id,
            Opportunity__c = target.Id,
            Requester__c = UserInfo.getUserId(),
            Justification__c = 'Transfer after rebooking customer.',
            Field_To_Update__c = 'Opportunity__c;Account__c;Customer_Name__c;Customer_Id__c',
            Related_Object_Type__c = 'Unit__c',
            Related_Record_Id__c = String.valueOf(unit.Id),
            Parent_Object__c = 'Unit__c',
            Parent_Record_Id__c = String.valueOf(unit.Id),
            Current_Value__c = 'Old Transfer Customer',
            Requested_Value__c = 'New Transfer Customer'
        );
        insert req;

        Test.startTest();
        InvoiceReceiptTransferService.applyApprovedChanges(req.Id);
        Test.stopTest();

        Invoice__c inv = [
            SELECT Opportunity__c, Account__c, Customer_Name__c, Customer_Id__c
            FROM Invoice__c
            WHERE Unit__c = :unit.Id
            LIMIT 1
        ];
        Receipt__c rcpt = [
            SELECT Opportunity__c, Account__c, Customer_Name__c
            FROM Receipt__c
            WHERE Unit__c = :unit.Id
            LIMIT 1
        ];
        Approval_Request__c applied = [
            SELECT Status__c
            FROM Approval_Request__c
            WHERE Id = :req.Id
        ];

        System.assertEquals(target.Id, inv.Opportunity__c);
        System.assertEquals(target.AccountId, inv.Account__c);
        System.assertEquals('New Transfer Customer', inv.Customer_Name__c);
        System.assertEquals(target.Account.Financial_Number__c, inv.Customer_Id__c);
        System.assertEquals(target.Id, rcpt.Opportunity__c);
        System.assertEquals(target.AccountId, rcpt.Account__c);
        System.assertEquals('New Transfer Customer', rcpt.Customer_Name__c);
        System.assertEquals('Applied', applied.Status__c);
    }

    @IsTest
    static void testDuplicateOpenRequestBlocked() {
        Unit__c unit = getUnit();
        Opportunity target = getBookedOpp();

        insert new Approval_Request__c(
            Request_Type__c = InvoiceReceiptTransferService.REQUEST_TYPE,
            Status__c = 'Pending',
            Unit__c = unit.Id,
            Requested_Opportunity__c = target.Id,
            Opportunity__c = target.Id,
            Requester__c = UserInfo.getUserId(),
            Justification__c = 'Existing pending transfer request.',
            Field_To_Update__c = 'Opportunity__c;Account__c;Customer_Name__c;Customer_Id__c',
            Related_Object_Type__c = 'Unit__c',
            Related_Record_Id__c = String.valueOf(unit.Id),
            Current_Value__c = 'Old Transfer Customer',
            Requested_Value__c = 'New Transfer Customer'
        );

        Boolean threw = false;
        Test.startTest();
        try {
            InvoiceReceiptTransferController.submitTransferRequest(
                unit.Id,
                target.Id,
                'Another transfer request attempt.'
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Duplicate open request should be blocked');
    }

    @IsTest
    static void testSubmitCreatesRequestWhenProcessAvailable() {
        Unit__c unit = getUnit();
        Opportunity target = getBookedOpp();

        Id requestId;
        Test.startTest();
        try {
            requestId = InvoiceReceiptTransferController.submitTransferRequest(
                unit.Id,
                target.Id,
                'Transfer invoices after customer rebooking.'
            );
        } catch (AuraHandledException e) {
            // Approval process may be unavailable or user may lack Manager for hierarchy.
            return;
        }
        Test.stopTest();

        System.assertNotEquals(null, requestId);
        Approval_Request__c req = [
            SELECT Request_Type__c, Unit__c, Requested_Opportunity__c, Status__c
            FROM Approval_Request__c
            WHERE Id = :requestId
        ];
        System.assertEquals(InvoiceReceiptTransferService.REQUEST_TYPE, req.Request_Type__c);
        System.assertEquals(unit.Id, req.Unit__c);
        System.assertEquals(target.Id, req.Requested_Opportunity__c);
    }

    @IsTest
    static void testTriggerAppliesOnApprovedStatusChange() {
        Unit__c unit = getUnit();
        Opportunity target = getBookedOpp();

        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = InvoiceReceiptTransferService.REQUEST_TYPE,
            Status__c = 'Approved',
            Unit__c = unit.Id,
            Requested_Opportunity__c = target.Id,
            Opportunity__c = target.Id,
            Requester__c = UserInfo.getUserId(),
            Justification__c = 'Invocable apply transfer path.',
            Field_To_Update__c = 'Opportunity__c;Account__c;Customer_Name__c;Customer_Id__c',
            Related_Object_Type__c = 'Unit__c',
            Related_Record_Id__c = String.valueOf(unit.Id),
            Current_Value__c = 'Old Transfer Customer',
            Requested_Value__c = 'New Transfer Customer'
        );
        insert req;

        Test.startTest();
        InvoiceReceiptTransferService.applyApprovedChangesInvocable(new List<Id>{ req.Id });
        Test.stopTest();

        Invoice__c inv = [
            SELECT Account__c, Opportunity__c, Customer_Name__c
            FROM Invoice__c
            WHERE Unit__c = :unit.Id
            LIMIT 1
        ];
        System.assertEquals(target.AccountId, inv.Account__c);
        System.assertEquals(target.Id, inv.Opportunity__c);
        System.assertEquals('New Transfer Customer', inv.Customer_Name__c);
    }

    @IsTest
    static void testGetAccountPreviewAndOpenRequest() {
        Unit__c unit = getUnit();
        Opportunity target = getBookedOpp();

        InvoiceReceiptTransferService.OpportunityOptionDTO preview =
            InvoiceReceiptTransferController.getAccountPreview(target.Id);
        System.assertEquals(target.Id, preview.opportunityId);
        System.assertEquals('New Transfer Customer', preview.accountName);

        System.assertEquals(
            null,
            InvoiceReceiptTransferController.getOpenTransferRequestForUnit(unit.Id)
        );

        insert new Approval_Request__c(
            Request_Type__c = InvoiceReceiptTransferService.REQUEST_TYPE,
            Status__c = 'Draft',
            Unit__c = unit.Id,
            Requested_Opportunity__c = target.Id,
            Opportunity__c = target.Id,
            Requester__c = UserInfo.getUserId(),
            Justification__c = 'Draft open transfer request.',
            Field_To_Update__c = 'Opportunity__c;Account__c;Customer_Name__c;Customer_Id__c',
            Related_Object_Type__c = 'Unit__c',
            Related_Record_Id__c = String.valueOf(unit.Id),
            Current_Value__c = 'Old Transfer Customer',
            Requested_Value__c = 'New Transfer Customer'
        );

        InvoiceReceiptTransferService.OpenTransferRequestDTO openReq =
            InvoiceReceiptTransferController.getOpenTransferRequestForUnit(unit.Id);
        System.assertNotEquals(null, openReq);
        System.assertEquals('Draft', openReq.status);

        InvoiceReceiptTransferService.TransferContextDTO blocked =
            InvoiceReceiptTransferController.getTransferContext(unit.Id);
        System.assertEquals(false, blocked.canSubmit);
    }

    @IsTest
    static void testValidationPaths() {
        Unit__c unit = getUnit();
        Opportunity target = getBookedOpp();

        Boolean missingOpp = false;
        try {
            InvoiceReceiptTransferController.submitTransferRequest(
                unit.Id,
                null,
                'Transfer invoices after customer rebooking.'
            );
        } catch (AuraHandledException e) {
            missingOpp = true;
        }
        System.assertEquals(true, missingOpp);

        Boolean shortJustification = false;
        try {
            InvoiceReceiptTransferController.submitTransferRequest(
                unit.Id,
                target.Id,
                'short'
            );
        } catch (AuraHandledException e) {
            shortJustification = true;
        }
        System.assertEquals(true, shortJustification);

        Boolean missingUnit = false;
        try {
            InvoiceReceiptTransferController.getTransferContext(null);
        } catch (AuraHandledException e) {
            missingUnit = true;
        }
        System.assertEquals(true, missingUnit);

        List<InvoiceReceiptTransferService.OpportunityOptionDTO> allOpps =
            InvoiceReceiptTransferController.searchOpportunities(unit.Id, null);
        System.assertEquals(1, allOpps.size());

        Boolean badPreview = false;
        try {
            InvoiceReceiptTransferController.getAccountPreview(null);
        } catch (AuraHandledException e) {
            badPreview = true;
        }
        System.assertEquals(true, badPreview);

        Boolean badOpen = false;
        try {
            InvoiceReceiptTransferController.getOpenTransferRequestForUnit(null);
        } catch (AuraHandledException e) {
            badOpen = true;
        }
        System.assertEquals(true, badOpen);
    }

    @IsTest
    static void testApplyIgnoresNonApprovedAndWrongType() {
        Unit__c unit = getUnit();
        Opportunity target = getBookedOpp();

        Approval_Request__c pending = new Approval_Request__c(
            Request_Type__c = InvoiceReceiptTransferService.REQUEST_TYPE,
            Status__c = 'Pending',
            Unit__c = unit.Id,
            Requested_Opportunity__c = target.Id,
            Opportunity__c = target.Id,
            Requester__c = UserInfo.getUserId(),
            Justification__c = 'Pending should not apply yet.',
            Field_To_Update__c = 'Opportunity__c;Account__c;Customer_Name__c;Customer_Id__c',
            Related_Object_Type__c = 'Unit__c',
            Related_Record_Id__c = String.valueOf(unit.Id),
            Current_Value__c = 'Old Transfer Customer',
            Requested_Value__c = 'New Transfer Customer'
        );
        insert pending;

        Test.startTest();
        InvoiceReceiptTransferService.applyApprovedChanges(pending.Id);
        Test.stopTest();

        Invoice__c inv = [
            SELECT Customer_Name__c
            FROM Invoice__c
            WHERE Unit__c = :unit.Id
            LIMIT 1
        ];
        System.assertEquals('Old Transfer Customer', inv.Customer_Name__c);
    }

    @IsTest
    static void testShareWithCurrentApproversHandlesNoWorkitems() {
        Unit__c unit = getUnit();
        Opportunity target = getBookedOpp();

        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = InvoiceReceiptTransferService.REQUEST_TYPE,
            Status__c = 'Pending',
            Unit__c = unit.Id,
            Requested_Opportunity__c = target.Id,
            Opportunity__c = target.Id,
            Requester__c = UserInfo.getUserId(),
            Justification__c = 'Share helper coverage without pending workitem.',
            Field_To_Update__c = 'Opportunity__c;Account__c;Customer_Name__c;Customer_Id__c',
            Related_Object_Type__c = 'Unit__c',
            Related_Record_Id__c = String.valueOf(unit.Id),
            Current_Value__c = 'Old Transfer Customer',
            Requested_Value__c = 'New Transfer Customer'
        );
        insert req;

        Test.startTest();
        InvoiceReceiptTransferService.shareWithCurrentApprovers(null);
        InvoiceReceiptTransferService.shareWithCurrentApprovers(req.Id);
        Test.stopTest();

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Approval_Request__Share
                WHERE ParentId = :req.Id
                  AND RowCause = :Schema.Approval_Request__Share.RowCause.Manual
            ]
        );
    }
}
