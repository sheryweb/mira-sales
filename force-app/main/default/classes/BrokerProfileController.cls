public without sharing class BrokerProfileController extends BrokerLoginController {

    // PRG: document actions redirect back here with ?docmsg=<code>, so a refresh never re-submits.
    public BrokerProfileController() {
        if (ApexPages.currentPage() == null) return;
        String code = ApexPages.currentPage().getParameters().get('docmsg');
        if (String.isNotBlank(code)) {
            docMessage = docMsgFor(code);
            docSubmitted = (code == 'staged' || code == 'submitted' || code == 'discarded');
        }
    }

    private String docMsgFor(String code) {
        if (code == 'staged')         return 'Document staged for re-upload. Add more if needed, then submit them all for approval.';
        if (code == 'submitted')      return 'Your re-uploaded document(s) have been submitted for approval.';
        if (code == 'discarded')      return 'Staged re-uploads were discarded.';
        if (code == 'nofile')         return 'Please choose a file to upload.';
        if (code == 'locked')         return 'This document cannot be re-uploaded.';
        if (code == 'alreadypending') return 'A re-upload for this document is already pending approval.';
        if (code == 'alreadystaged')  return 'This document is already staged for re-upload.';
        if (code == 'expired')        return 'Your session has expired. Please log in again.';
        if (code == 'nostaged')       return 'There are no staged documents to submit.';
        return 'Could not determine which document to replace.';   // nodoc / notfound
    }

    // The logged-in broker's company (Account), with the registration fields
    public Account company {
        get {
            if (company == null) {
                Id acc = getCurrentAccountId();
                if (acc != null) {
                    List<Account> a = [
                        SELECT Name, Type, Status__c, Trade_License_Number__c, Trade_License_Issue_Date__c,
                               Trade_License_Expiry_Date__c, ORN_Number__c, TRN_Number__c, VAT_TRN__c,
                               Is_Agency_International__c, Agency_Registered_Emirate__c,
                               BillingStreet, BillingPostalCode, Company_Email__c, Phone, Landline_Number__c,
                               Contact_Email_2__c, Admin_Number__c, Assigned_RM__c,
                               Signatory_Name__c, Signatory_Email__c, Signatory_Number__c
                        FROM Account WHERE Id = :acc LIMIT 1
                    ];
                    if (!a.isEmpty()) company = a[0];
                }
            }
            return company;
        }
        set;
    }

    // Date-only formatting for the licence dates (avoids the datetime/time portion)
    public String getLicenseIssueDate()  { return fmtDate(company == null ? null : company.Trade_License_Issue_Date__c); }
    public String getLicenseExpiryDate() { return fmtDate(company == null ? null : company.Trade_License_Expiry_Date__c); }

    private String fmtDate(Date d) {
        if (d == null) return '';
        return Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0)).format('dd MMM yyyy');
    }

    // True when a profile change is awaiting approval (locks the portal edit UI)
    public Boolean getHasPendingRequest() {
        Id accId = getCurrentAccountId();
        if (accId == null) return false;
        return ![
            SELECT Id FROM Approval_Request__c
            WHERE Related_Record_Id__c = :String.valueOf(accId)
              AND Request_Type__c = 'Agency Profile Update'
              AND Status__c IN ('Draft', 'Pending')
            LIMIT 1
        ].isEmpty();
    }

    // True when a bank-detail change is awaiting approval (locks the Bank Details edit UI)
    public Boolean getHasPendingBankRequest() {
        Id accId = getCurrentAccountId();
        if (accId == null) return false;
        return ![
            SELECT Id FROM Approval_Request__c
            WHERE Related_Record_Id__c = :String.valueOf(accId)
              AND Request_Type__c = 'Bank Detail Update'
              AND Status__c IN ('Draft', 'Pending')
            LIMIT 1
        ].isEmpty();
    }

    // Initials for the header avatar (e.g. "ABC Agency" -> "AA")
    public String getInitials() {
        String n = (company == null) ? null : company.Name;
        if (String.isBlank(n)) return 'BR';
        List<String> parts = n.trim().split('\\s+');
        String s = parts[0].substring(0, 1);
        if (parts.size() > 1) s += parts[1].substring(0, 1);
        return s.toUpperCase();
    }

    // ---- Bank accounts ----
    public class BankRow {
        public String bank { get; set; }
        public String accountName { get; set; }
        public String accountNumber { get; set; }
        public String iban { get; set; }
        public String swift { get; set; }
        public String branch { get; set; }
    }

    private List<Bank__c> bankRecs {
        get {
            if (bankRecs == null) {
                Id acc = getCurrentAccountId();
                bankRecs = (acc == null) ? new List<Bank__c>() : [
                    SELECT Name, Bank_Account_Name__c, Bank_Account_Number__c, IBAN__c, Swift_Code__c, Branch_Name__c
                    FROM Bank__c WHERE Account__c = :acc ORDER BY CreatedDate
                ];
            }
            return bankRecs;
        }
        set;
    }

    public Boolean getHasBanks() { return !bankRecs.isEmpty(); }

    public List<BankRow> getBanks() {
        List<BankRow> rows = new List<BankRow>();
        for (Bank__c b : bankRecs) {
            BankRow r = new BankRow();
            r.bank = b.Name;
            r.accountName = b.Bank_Account_Name__c;
            r.accountNumber = b.Bank_Account_Number__c;
            r.iban = b.IBAN__c;
            r.swift = b.Swift_Code__c;
            r.branch = b.Branch_Name__c;
            rows.add(r);
        }
        return rows;
    }

    // ---- Shareholders ----
    public class ShareholderRow {
        public String holder { get; set; }
        public String percentage { get; set; }
    }

    private List<Shareholder__c> shareholderRecs {
        get {
            if (shareholderRecs == null) {
                Id acc = getCurrentAccountId();
                shareholderRecs = (acc == null) ? new List<Shareholder__c>() : [
                    SELECT Name, Percent__c FROM Shareholder__c WHERE Account__c = :acc ORDER BY Percent__c DESC
                ];
            }
            return shareholderRecs;
        }
        set;
    }

    public Boolean getHasShareholders() { return !shareholderRecs.isEmpty(); }

    public List<ShareholderRow> getShareholders() {
        List<ShareholderRow> rows = new List<ShareholderRow>();
        for (Shareholder__c s : shareholderRecs) {
            ShareholderRow r = new ShareholderRow();
            r.holder = s.Name;
            r.percentage = (s.Percent__c == null) ? '' : s.Percent__c.stripTrailingZeros().toPlainString() + '%';
            rows.add(r);
        }
        return rows;
    }

    // ---- Documents (ALL Files on the Account; re-upload staged into ONE approval request) ----
    // Files whose Title contains any of these are shown but NOT re-uploadable (system-generated docs).
    private static final List<String> NO_REUPLOAD = new List<String>{
        'NOC_Broker Agreement', 'Project Notification'
    };
    // Marker on a staged re-upload's Description so the in-flight file is hidden from the list until approved.
    private static final String PENDING_MARKER = 'BROKER_PORTAL_PENDING_REUPLOAD';

    public class DocRow {
        public String fileName { get; set; }
        public String fileType { get; set; }
        public String dateAdded { get; set; }
        public String contentDocumentId { get; set; }
        public Boolean staged { get; set; }         // queued in the open Draft request (not yet submitted)
        public Boolean pending { get; set; }        // in a submitted (Pending) request awaiting approval
        public Boolean canReupload { get; set; }    // false for the fixed system-generated documents
    }

    // Upload binding for the re-upload form (transient: never stored in view state)
    public transient Blob docFileBody { get; set; }
    public String docFileName { get; set; }
    public String selectedDocId { get; set; }   // ContentDocumentId of the file being replaced (set by hidden field)
    public String docMessage { get; private set; }
    public Boolean docSubmitted { get; private set; }

    private List<DocRow> cachedDocs;

    // --- open-request state: a single Draft request stages uploads; a Pending one is awaiting approval ---
    private Boolean openLoaded = false;
    private Id draftReqId;
    private Integer stagedCount = 0;
    private Set<String> stagedDocIds = new Set<String>();
    private Set<String> pendingDocIds = new Set<String>();

    private void loadOpenState(Id acc) {
        if (openLoaded) return;
        openLoaded = true;
        for (Approval_Request__c r : [
            SELECT Id, Status__c, Profile_Changes_JSON__c FROM Approval_Request__c
            WHERE Related_Record_Id__c = :String.valueOf(acc)
              AND Request_Type__c = 'Document Re-upload'
              AND Status__c IN ('Draft', 'Pending')
        ]) {
            List<Object> docs = parseDocs(r.Profile_Changes_JSON__c);
            for (Object o : docs) {
                Map<String, Object> m = (Map<String, Object>) o;
                String oldId = String.valueOf(m.get('oldContentDocumentId'));
                if (String.isBlank(oldId)) continue;
                if (r.Status__c == 'Draft') stagedDocIds.add(oldId); else pendingDocIds.add(oldId);
            }
            if (r.Status__c == 'Draft') { draftReqId = r.Id; stagedCount = docs.size(); }
        }
    }

    private List<Object> parseDocs(String js) {
        if (String.isBlank(js)) return new List<Object>();
        try {
            Object parsed = JSON.deserializeUntyped(js);
            if (parsed instanceof List<Object>) return (List<Object>) parsed;
        } catch (Exception e) { /* fall through */ }
        return new List<Object>();
    }

    public List<DocRow> getDocuments() {
        if (cachedDocs != null) return cachedDocs;
        cachedDocs = new List<DocRow>();
        Id acc = getCurrentAccountId();
        if (acc == null) return cachedDocs;
        loadOpenState(acc);

        Set<Id> seen = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocument.Id, ContentDocument.Title, ContentDocument.FileType,
                   ContentDocument.CreatedDate, ContentDocument.LatestPublishedVersion.Description
            FROM ContentDocumentLink WHERE LinkedEntityId = :acc
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {
            String descVal = cdl.ContentDocument.LatestPublishedVersion.Description;
            if (descVal != null && descVal.contains(PENDING_MARKER)) continue;   // hide in-flight staged uploads
            Id docId = cdl.ContentDocument.Id;
            if (seen.contains(docId)) continue;
            seen.add(docId);

            String title = cdl.ContentDocument.Title;
            if (BrokerDocLinkVisibilityHandler.isInternalOnly(title)) continue;   // staff-marked internal-only file
            DocRow d = new DocRow();
            d.fileName = title;
            d.fileType = cdl.ContentDocument.FileType;
            d.dateAdded = (cdl.ContentDocument.CreatedDate == null) ? '' : cdl.ContentDocument.CreatedDate.format('dd MMM yyyy');
            d.contentDocumentId = docId;
            d.canReupload = isReuploadable(title);
            d.staged = stagedDocIds.contains(String.valueOf(docId));
            d.pending = pendingDocIds.contains(String.valueOf(docId));
            cachedDocs.add(d);
        }
        return cachedDocs;
    }

    public Boolean getHasDocuments() { return !getDocuments().isEmpty(); }

    public Integer getStagedCount() {
        Id acc = getCurrentAccountId();
        if (acc != null) loadOpenState(acc);
        return stagedCount;
    }
    public Boolean getHasStaged() { return getStagedCount() > 0; }

    private Boolean isReuploadable(String title) {
        if (String.isBlank(title)) return true;
        for (String s : NO_REUPLOAD) {
            if (title.containsIgnoreCase(s)) return false;
        }
        return true;
    }

    // Stage one re-uploaded file into the single open Draft request (creating it if needed). PRG redirect.
    public PageReference stageDoc() {
        Id acc = getCurrentAccountId();
        if (acc == null) return redirectDocs('expired');
        if (docFileBody == null || docFileBody.size() == 0 || String.isBlank(docFileName)) return redirectDocs('nofile');
        Id oldDocId;
        try { oldDocId = Id.valueOf(selectedDocId); } catch (Exception e) { return redirectDocs('nodoc'); }

        Boolean owned = false;
        String oldTitle = null;
        String oldDescription = '';
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersion.Description
            FROM ContentDocumentLink WHERE LinkedEntityId = :acc
        ]) {
            if (cdl.ContentDocumentId == oldDocId) {
                owned = true;
                oldTitle = cdl.ContentDocument.Title;
                oldDescription = (cdl.ContentDocument.LatestPublishedVersion.Description == null)
                    ? '' : cdl.ContentDocument.LatestPublishedVersion.Description;
                break;
            }
        }
        if (!owned) return redirectDocs('notfound');
        if (!isReuploadable(oldTitle)) return redirectDocs('locked');

        loadOpenState(acc);
        if (pendingDocIds.contains(String.valueOf(oldDocId))) return redirectDocs('alreadypending');
        if (stagedDocIds.contains(String.valueOf(oldDocId))) return redirectDocs('alreadystaged');

        // Store the new file with the marker Description so it stays hidden from the list until approved.
        ContentVersion cv = new ContentVersion(
            Title = docFileName, PathOnClient = docFileName, VersionData = docFileBody,
            FirstPublishLocationId = acc, Description = PENDING_MARKER
        );
        insert cv;
        Id newDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;

        Map<String, Object> entry = new Map<String, Object>{
            'oldContentDocumentId' => String.valueOf(oldDocId),
            'newContentDocumentId' => String.valueOf(newDocId),
            'restoreDescription' => oldDescription,
            'oldFileName' => oldTitle,
            'newFileName' => docFileName
        };

        // Find the open Draft request, or create one. All staged docs share this single request.
        List<Approval_Request__c> existing = [
            SELECT Id, Profile_Changes_JSON__c FROM Approval_Request__c
            WHERE Related_Record_Id__c = :String.valueOf(acc)
              AND Request_Type__c = 'Document Re-upload' AND Status__c = 'Draft' LIMIT 1
        ];
        Id reqId;
        if (!existing.isEmpty()) {
            List<Object> docs = parseDocs(existing[0].Profile_Changes_JSON__c);
            docs.add(entry);
            existing[0].Profile_Changes_JSON__c = JSON.serialize(docs);
            update existing[0];
            reqId = existing[0].Id;
        } else {
            Approval_Request__c draft = new Approval_Request__c(
                Request_Type__c = 'Document Re-upload',
                Related_Object_Type__c = 'Account',
                Related_Record_Id__c = String.valueOf(acc),
                Field_To_Update__c = 'Documents (multiple)',
                Current_Value__c = 'Existing documents',
                Requested_Value__c = 'Re-uploaded documents',
                Justification__c = 'Document re-upload submitted from the Broker Portal.',
                Profile_Changes_JSON__c = JSON.serialize(new List<Object>{ entry }),
                Status__c = 'Draft'
            );
            insert draft;
            reqId = draft.Id;
        }

        // Link the new file to the request so the approver can preview/download it before deciding.
        try {
            insert new ContentDocumentLink(
                ContentDocumentId = newDocId, LinkedEntityId = reqId, ShareType = 'V', Visibility = 'AllUsers'
            );
        } catch (Exception e) { System.debug('Could not link staged file to request: ' + e.getMessage()); }

        return redirectDocs('staged');
    }

    // Submit ALL staged documents as the single approval request. PRG redirect.
    public PageReference submitAllDocs() {
        Id acc = getCurrentAccountId();
        if (acc == null) return redirectDocs('expired');
        List<Approval_Request__c> drafts = [
            SELECT Id, Profile_Changes_JSON__c FROM Approval_Request__c
            WHERE Related_Record_Id__c = :String.valueOf(acc)
              AND Request_Type__c = 'Document Re-upload' AND Status__c = 'Draft' LIMIT 1
        ];
        if (drafts.isEmpty() || parseDocs(drafts[0].Profile_Changes_JSON__c).isEmpty()) return redirectDocs('nostaged');

        drafts[0].Status__c = 'Pending';
        update drafts[0];
        EventBus.publish(new Broker_Doc_Submit__e(Approval_Request_Id__c = drafts[0].Id));
        return redirectDocs('submitted');
    }

    // Discard the staged (Draft) request and its staged files. PRG redirect.
    public PageReference discardDraft() {
        Id acc = getCurrentAccountId();
        if (acc == null) return redirectDocs('expired');
        List<Approval_Request__c> drafts = [
            SELECT Id, Profile_Changes_JSON__c FROM Approval_Request__c
            WHERE Related_Record_Id__c = :String.valueOf(acc)
              AND Request_Type__c = 'Document Re-upload' AND Status__c = 'Draft' LIMIT 1
        ];
        if (!drafts.isEmpty()) {
            Set<Id> newDocIds = new Set<Id>();
            for (Object o : parseDocs(drafts[0].Profile_Changes_JSON__c)) {
                Map<String, Object> m = (Map<String, Object>) o;
                try { newDocIds.add(Id.valueOf(String.valueOf(m.get('newContentDocumentId')))); } catch (Exception e) {}
            }
            if (!newDocIds.isEmpty()) {
                List<ContentDocument> cds = [SELECT Id FROM ContentDocument WHERE Id IN :newDocIds];
                if (!cds.isEmpty()) delete cds;
            }
            delete drafts[0];
        }
        return redirectDocs('discarded');
    }

    // ---- In-browser file viewer ----------------------------------------------------------------
    // Streams the selected file to the page as a base64 data URI so the guest can view it inline
    // (no dependency on the Salesforce file servlet / Site URL). Capped to keep heap < 6 MB.
    private static final Integer MAX_PREVIEW_BYTES = 2 * 1024 * 1024;   // 2 MB (blob + base64 ~= 4.7 MB heap)

    public String viewDocId { get; set; }                 // ContentDocumentId to view (set by the View button)
    public transient ViewFile viewFile { get; private set; }

    public class ViewFile {
        public String fileName { get; set; }
        public String dataUri { get; set; }
        public Boolean isImage { get; set; }
        public Boolean isPdf { get; set; }
        public Boolean downloadOnly { get; set; }
        public String note { get; set; }
    }

    public void viewDoc() {
        viewFile = null;
        Id acc = getCurrentAccountId();
        if (acc == null) return;
        Id docId;
        try { docId = Id.valueOf(viewDocId); } catch (Exception e) { return; }

        // Defence in depth: the file must be linked to THIS broker's own account.
        Boolean owned = ![
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :acc AND ContentDocumentId = :docId LIMIT 1
        ].isEmpty();
        if (!owned) return;

        List<ContentVersion> metas = [
            SELECT Id, Title, FileExtension, ContentSize
            FROM ContentVersion WHERE ContentDocumentId = :docId AND IsLatest = true LIMIT 1
        ];
        if (metas.isEmpty()) return;
        ContentVersion meta = metas[0];

        ViewFile vf = new ViewFile();
        String ext = (meta.FileExtension == null) ? '' : meta.FileExtension.toLowerCase();
        vf.fileName = (String.isBlank(meta.Title) ? 'document' : meta.Title) + (String.isBlank(ext) ? '' : ('.' + ext));
        vf.isImage = false; vf.isPdf = false; vf.downloadOnly = false;

        // Too big to hold in heap as a data URI -> tell the user, no preview/download here.
        if (meta.ContentSize != null && meta.ContentSize > MAX_PREVIEW_BYTES) {
            vf.downloadOnly = true;
            vf.note = 'This file is larger than 2 MB and can\'t be previewed in the portal. Please contact MIRA for a copy.';
            viewFile = vf;
            return;
        }

        // Safe to load the bytes now (only queried once we know it is within the cap).
        Blob body = [SELECT VersionData FROM ContentVersion WHERE Id = :meta.Id LIMIT 1].VersionData;
        vf.dataUri = 'data:' + mimeFor(ext) + ';base64,' + EncodingUtil.base64Encode(body);
        if (isImageExt(ext))      vf.isImage = true;
        else if (ext == 'pdf')    vf.isPdf = true;
        else {                    // Word / Excel / other: browsers can't render inline -> download
            vf.downloadOnly = true;
            vf.note = 'This file type can\'t be previewed in the browser. Use Download to open it.';
        }
        viewFile = vf;
    }

    private Boolean isImageExt(String ext) {
        return ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'gif' || ext == 'bmp' || ext == 'webp';
    }

    private String mimeFor(String ext) {
        if (ext == 'pdf')  return 'application/pdf';
        if (ext == 'png')  return 'image/png';
        if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
        if (ext == 'gif')  return 'image/gif';
        if (ext == 'bmp')  return 'image/bmp';
        if (ext == 'webp') return 'image/webp';
        if (ext == 'doc')  return 'application/msword';
        if (ext == 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        if (ext == 'xls')  return 'application/vnd.ms-excel';
        if (ext == 'xlsx') return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        return 'application/octet-stream';
    }

    private PageReference redirectDocs(String code) {
        PageReference pr = Page.BrokerProfile;
        pr.getParameters().put('docmsg', code);
        pr.setRedirect(true);
        return pr;
    }
}