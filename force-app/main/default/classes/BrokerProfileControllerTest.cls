@isTest
private class BrokerProfileControllerTest {

    private static Id agencyRtId() {
        Map<String, Schema.RecordTypeInfo> m = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (m.containsKey('Agency') && m.get('Agency').isAvailable()) return m.get('Agency').getRecordTypeId();
        for (Schema.RecordTypeInfo i : m.values()) if (i.isAvailable() && !i.isMaster()) return i.getRecordTypeId();
        return null;
    }

    private static Broker_User__c setupCompany() {
        String u = String.valueOf(Crypto.getRandomLong());
        Account agency = new Account(
            Name = 'Profile Agency ' + u, Skip_Trigger__c = true, Type = 'Agency',
            Company_Email__c = 'info' + u + '@example.com',
            Trade_License_Number__c = 'TL-' + u,
            Signatory_Name__c = 'Jane Signatory',
            Signatory_Email__c = 'jane' + u + '@example.com',
            VAT_TRN__c = 'Yes'
        );
        Id rt = agencyRtId(); if (rt != null) agency.RecordTypeId = rt;
        insert agency;

        insert new List<Bank__c>{
            new Bank__c(Name = 'Emirates NBD', Bank_Account_Name__c = 'Profile Agency',
                Bank_Account_Number__c = '123456', IBAN__c = 'AE000123', Swift_Code__c = 'EBILAEAD',
                Branch_Name__c = 'Main', Account__c = agency.Id),
            new Bank__c(Name = 'ADCB', Bank_Account_Name__c = 'Profile Agency 2',
                Account__c = agency.Id)
        };

        insert new Shareholder__c(Name = 'John Owner', Percent__c = 60, Account__c = agency.Id);

        Broker_User__c bu = new Broker_User__c(Account__c = agency.Id, Email__c = 'prof' + u + '@example.com', Active__c = true);
        insert bu;
        return bu;
    }

    private static void loginAs(Broker_User__c bu) {
        Test.setCurrentPage(Page.BrokerProfile);
        ApexPages.currentPage().getCookies().put('brokerSession',
            new Cookie('brokerSession', BrokerLoginController.buildSessionToken(bu.Id), '/', 3600, true));
    }

    @isTest
    static void loads_company_and_banks() {
        Broker_User__c bu = setupCompany();
        loginAs(bu);
        BrokerProfileController c = new BrokerProfileController();

        System.assertNotEquals(null, c.company, 'company loaded');
        System.assert(c.company.Company_Email__c.startsWith('info'), 'company email');
        System.assertEquals('Jane Signatory', c.company.Signatory_Name__c, 'signatory');
        System.assertEquals('Agency', c.company.Type, 'business type');
        System.assertEquals(true, c.getHasBanks());
        System.assertEquals(2, c.getBanks().size(), 'two bank accounts');
        System.assertEquals(true, c.getHasShareholders());
        System.assertEquals(1, c.getShareholders().size(), 'one shareholder');
    }

    @isTest
    static void empty_without_session() {
        Test.setCurrentPage(Page.BrokerProfile);
        BrokerProfileController c = new BrokerProfileController();
        System.assertEquals(null, c.company);
        System.assertEquals(false, c.getHasBanks());
        System.assertEquals(0, c.getBanks().size());
        System.assertEquals('BR', c.getInitials(), 'default initials when no company');
        System.assertEquals('', c.getLicenseIssueDate(), 'empty date when no company');
        System.assertEquals('', c.getLicenseExpiryDate(), 'empty date when no company');
        System.assertEquals(false, c.getHasPendingRequest(), 'no pending request without session');
        System.assertEquals(false, c.getHasShareholders());
        System.assertEquals(0, c.getShareholders().size());
    }

    @isTest
    static void license_dates_and_initials() {
        Broker_User__c bu = setupCompany();
        update new Account(
            Id = bu.Account__c,
            Skip_Trigger__c = true,
            Trade_License_Issue_Date__c = Date.newInstance(2024, 1, 15),
            Trade_License_Expiry_Date__c = Date.newInstance(2026, 1, 15)
        );
        loginAs(bu);
        BrokerProfileController c = new BrokerProfileController();

        String issue = c.getLicenseIssueDate();
        String expiry = c.getLicenseExpiryDate();
        System.assert(String.isNotBlank(issue) && issue.contains('2024'), 'formatted issue date: ' + issue);
        System.assert(String.isNotBlank(expiry) && expiry.contains('2026'), 'formatted expiry date: ' + expiry);

        // "Profile Agency <n>" -> "PA"
        System.assertEquals('PA', c.getInitials());
    }

    @isTest
    static void pending_request_flag() {
        Broker_User__c bu = setupCompany();
        loginAs(bu);
        BrokerProfileController c = new BrokerProfileController();

        System.assertEquals(false, c.getHasPendingRequest(), 'no request yet');

        insert new Approval_Request__c(
            Request_Type__c = 'Agency Profile Update',
            Related_Object_Type__c = 'Account',
            Related_Record_Id__c = String.valueOf(bu.Account__c),
            Field_To_Update__c = 'Company Profile (multiple)',
            Current_Value__c = 'See Profile Changes',
            Requested_Value__c = 'See Profile Changes',
            Justification__c = 'Company profile update from Broker Portal',
            Status__c = 'Pending'
        );

        System.assertEquals(true, c.getHasPendingRequest(), 'pending request detected');
    }

    // ---- Documents ----
    private static Id addFile(Id accId, String title) {
        ContentVersion cv = new ContentVersion(
            Title = title, PathOnClient = 'doc.pdf',
            VersionData = Blob.valueOf('hello'), FirstPublishLocationId = accId
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
    }

    @isTest
    static void documents_list_all_files_with_reupload_rules() {
        Broker_User__c bu = setupCompany();
        addFile(bu.Account__c, 'Trade License');
        addFile(bu.Account__c, 'Anything At All.pdf');                       // arbitrary file still shows
        addFile(bu.Account__c, 'NOC_Broker Agreement - Fully Executed');    // shown, NOT re-uploadable
        addFile(bu.Account__c, 'Project Notification - Profile Agency 7');  // shown, NOT re-uploadable (contains match)
        loginAs(bu);
        BrokerProfileController c = new BrokerProfileController();

        System.assertEquals(true, c.getHasDocuments());
        List<BrokerProfileController.DocRow> docs = c.getDocuments();
        System.assertEquals(4, docs.size(), 'all files listed regardless of description');

        Map<String, Boolean> reuploadByName = new Map<String, Boolean>();
        for (BrokerProfileController.DocRow d : docs) reuploadByName.put(d.fileName, d.canReupload);
        System.assertEquals(true, reuploadByName.get('Trade License'));
        System.assertEquals(true, reuploadByName.get('Anything At All.pdf'));
        System.assertEquals(false, reuploadByName.get('NOC_Broker Agreement - Fully Executed'), 'NOC not re-uploadable');
        System.assertEquals(false, reuploadByName.get('Project Notification - Profile Agency 7'), 'Project Notification not re-uploadable');
    }

    @isTest
    static void internal_named_file_hidden_from_portal() {
        Broker_User__c bu = setupCompany();
        addFile(bu.Account__c, 'Trade License');
        addFile(bu.Account__c, 'INTERNAL Memo');           // staff-marked internal -> hidden
        addFile(bu.Account__c, 'Internal Audit Report');   // also starts with "internal" -> hidden
        loginAs(bu);
        BrokerProfileController c = new BrokerProfileController();

        List<BrokerProfileController.DocRow> docs = c.getDocuments();
        System.assertEquals(1, docs.size(), 'internal-named files are hidden from the agency');
        System.assertEquals('Trade License', docs[0].fileName);
    }

    @isTest
    static void stage_multiple_then_submit_one_request() {
        Broker_User__c bu = setupCompany();
        Id d1 = addFile(bu.Account__c, 'Trade License');
        Id d2 = addFile(bu.Account__c, 'VAT Certificate');
        loginAs(bu);

        BrokerProfileController c = new BrokerProfileController();
        c.docFileBody = Blob.valueOf('a'); c.docFileName = 'tl.pdf'; c.selectedDocId = String.valueOf(d1);
        PageReference p1 = c.stageDoc();
        System.assert(p1.getUrl().contains('docmsg=staged'), 'PRG redirect after staging: ' + p1.getUrl());

        c.docFileBody = Blob.valueOf('b'); c.docFileName = 'vat.pdf'; c.selectedDocId = String.valueOf(d2);
        PageReference p2 = c.stageDoc();
        System.assert(p2.getUrl().contains('docmsg=staged'), 'second stage redirects');

        List<Approval_Request__c> drafts = [
            SELECT Id, Status__c, Profile_Changes_JSON__c FROM Approval_Request__c
            WHERE Related_Record_Id__c = :String.valueOf(bu.Account__c) AND Request_Type__c = 'Document Re-upload'
        ];
        System.assertEquals(1, drafts.size(), 'a SINGLE request holds both staged documents');
        System.assertEquals('Draft', drafts[0].Status__c);
        System.assert(drafts[0].Profile_Changes_JSON__c.contains('tl.pdf')
            && drafts[0].Profile_Changes_JSON__c.contains('vat.pdf'), 'both files staged');
        System.assertEquals(2, [SELECT COUNT() FROM ContentVersion WHERE Description = 'BROKER_PORTAL_PENDING_REUPLOAD']);

        // Staged docs show the staged badge; the hidden pending files aren't listed.
        BrokerProfileController cView = new BrokerProfileController();
        System.assertEquals(2, cView.getStagedCount());
        System.assertEquals(true, cView.getHasStaged());
        List<BrokerProfileController.DocRow> docs = cView.getDocuments();
        System.assertEquals(2, docs.size(), 'staged uploads themselves are hidden');
        for (BrokerProfileController.DocRow d : docs) System.assertEquals(true, d.staged);

        // Submit all -> single request goes Pending.
        BrokerProfileController cSub = new BrokerProfileController();
        Test.startTest();
        PageReference ps = cSub.submitAllDocs();
        Test.stopTest();
        System.assert(ps.getUrl().contains('docmsg=submitted'), 'redirect after submit');
        System.assertEquals('Pending', [SELECT Status__c FROM Approval_Request__c WHERE Id = :drafts[0].Id].Status__c);

        BrokerProfileController cAfter = new BrokerProfileController();
        for (BrokerProfileController.DocRow d : cAfter.getDocuments()) System.assertEquals(true, d.pending, 'now pending');
    }

    @isTest
    static void stage_blocked_without_file() {
        Broker_User__c bu = setupCompany();
        Id docId = addFile(bu.Account__c, 'Trade License');
        loginAs(bu);
        BrokerProfileController c = new BrokerProfileController();
        c.selectedDocId = String.valueOf(docId);   // no file chosen
        PageReference pr = c.stageDoc();
        System.assert(pr.getUrl().contains('docmsg=nofile'), 'redirects with nofile: ' + pr.getUrl());
        System.assertEquals(0, [SELECT COUNT() FROM Approval_Request__c WHERE Related_Record_Id__c = :String.valueOf(bu.Account__c)]);
    }

    @isTest
    static void discard_staged_draft() {
        Broker_User__c bu = setupCompany();
        Id d1 = addFile(bu.Account__c, 'Trade License');
        loginAs(bu);
        BrokerProfileController c = new BrokerProfileController();
        c.docFileBody = Blob.valueOf('a'); c.docFileName = 'tl.pdf'; c.selectedDocId = String.valueOf(d1);
        c.stageDoc();
        System.assertEquals(1, [SELECT COUNT() FROM Approval_Request__c WHERE Related_Record_Id__c = :String.valueOf(bu.Account__c)]);

        BrokerProfileController c2 = new BrokerProfileController();
        PageReference pr = c2.discardDraft();
        System.assert(pr.getUrl().contains('docmsg=discarded'));
        System.assertEquals(0, [SELECT COUNT() FROM Approval_Request__c WHERE Related_Record_Id__c = :String.valueOf(bu.Account__c)], 'draft removed');
        System.assertEquals(0, [SELECT COUNT() FROM ContentVersion WHERE Description = 'BROKER_PORTAL_PENDING_REUPLOAD'], 'staged file removed');
    }

    @isTest
    static void docmsg_param_sets_banner() {
        PageReference pg = Page.BrokerProfile;
        pg.getParameters().put('docmsg', 'submitted');
        Test.setCurrentPage(pg);
        BrokerProfileController c = new BrokerProfileController();
        System.assertEquals(true, c.docSubmitted);
        System.assertNotEquals(null, c.docMessage);
    }

    // ---- File viewer ----
    private static Id addFileExt(Id accId, String title, String ext) {
        ContentVersion cv = new ContentVersion(
            Title = title, PathOnClient = title + '.' + ext,
            VersionData = Blob.valueOf('file-bytes'), FirstPublishLocationId = accId
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
    }

    @isTest
    static void view_image_and_pdf_return_data_uri() {
        Broker_User__c bu = setupCompany();
        Id img = addFileExt(bu.Account__c, 'Logo', 'png');
        Id pdf = addFileExt(bu.Account__c, 'Trade License', 'pdf');
        loginAs(bu);

        BrokerProfileController c = new BrokerProfileController();
        c.viewDocId = String.valueOf(img);
        c.viewDoc();
        System.assertNotEquals(null, c.viewFile, 'image loaded');
        System.assertEquals(true, c.viewFile.isImage);
        System.assertEquals(false, c.viewFile.isPdf);
        System.assertEquals('Logo.png', c.viewFile.fileName);
        System.assert(c.viewFile.dataUri.startsWith('data:image/png;base64,'), c.viewFile.dataUri.left(40));

        BrokerProfileController c2 = new BrokerProfileController();
        c2.viewDocId = String.valueOf(pdf);
        c2.viewDoc();
        System.assertEquals(true, c2.viewFile.isPdf);
        System.assert(c2.viewFile.dataUri.startsWith('data:application/pdf;base64,'), c2.viewFile.dataUri.left(40));
    }

    @isTest
    static void view_word_is_download_only() {
        Broker_User__c bu = setupCompany();
        Id doc = addFileExt(bu.Account__c, 'Agreement', 'docx');
        loginAs(bu);
        BrokerProfileController c = new BrokerProfileController();
        c.viewDocId = String.valueOf(doc);
        c.viewDoc();
        System.assertEquals(true, c.viewFile.downloadOnly, 'word -> download only');
        System.assertEquals(false, c.viewFile.isImage);
        System.assertEquals(false, c.viewFile.isPdf);
        System.assertNotEquals(null, c.viewFile.dataUri, 'download link still available within cap');
        System.assertNotEquals(null, c.viewFile.note);
    }

    @isTest
    static void view_rejects_foreign_file() {
        Broker_User__c bu = setupCompany();
        Account other = new Account(Name = 'Other Co', Skip_Trigger__c = true);
        insert other;
        Id foreignDoc = addFileExt(other.Id, 'Secret', 'pdf');
        loginAs(bu);
        BrokerProfileController c = new BrokerProfileController();
        c.viewDocId = String.valueOf(foreignDoc);
        c.viewDoc();
        System.assertEquals(null, c.viewFile, 'cannot view another account\'s file');
    }

    @isTest
    static void view_no_session_or_bad_id() {
        Test.setCurrentPage(Page.BrokerProfile);
        BrokerProfileController c = new BrokerProfileController();
        c.viewDocId = '068000000000000AAA';
        c.viewDoc();
        System.assertEquals(null, c.viewFile, 'no session -> nothing');

        Broker_User__c bu = setupCompany();
        loginAs(bu);
        BrokerProfileController c2 = new BrokerProfileController();
        c2.viewDocId = 'not-an-id';
        c2.viewDoc();
        System.assertEquals(null, c2.viewFile, 'bad id -> nothing');
    }

    @isTest
    static void view_oversize_is_blocked() {
        Broker_User__c bu = setupCompany();
        String oneK = '';
        for (Integer i = 0; i < 1000; i++) oneK += 'x';
        List<String> parts = new List<String>();
        for (Integer i = 0; i < 2100; i++) parts.add(oneK);   // ~2.1 MB > 2 MB cap
        ContentVersion cv = new ContentVersion(
            Title = 'Big Scan', PathOnClient = 'big.pdf',
            VersionData = Blob.valueOf(String.join(parts, '')), FirstPublishLocationId = bu.Account__c
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
        loginAs(bu);
        BrokerProfileController c = new BrokerProfileController();
        c.viewDocId = String.valueOf(docId);
        c.viewDoc();
        System.assertNotEquals(null, c.viewFile);
        System.assertEquals(true, c.viewFile.downloadOnly, 'oversize -> download only');
        System.assertEquals(null, c.viewFile.dataUri, 'oversize -> no data URI');
        System.assertNotEquals(null, c.viewFile.note);
    }
}