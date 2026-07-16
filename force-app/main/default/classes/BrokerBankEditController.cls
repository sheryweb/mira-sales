public without sharing class BrokerBankEditController extends BrokerLoginController {

    // One editable bank row (existing or the blank "add new" row), two-way bound on the page.
    public class BankRow {
        public String recordId   { get; set; }   // blank => a new bank
        public Boolean isNew     { get; set; }
        public String bankName   { get; set; }
        public String accountName { get; set; }
        public String accountNumber { get; set; }
        public String iban       { get; set; }
        public String swift      { get; set; }
        public String branch     { get; set; }
        // originals, to detect what actually changed
        public String oBankName; public String oAccountName; public String oAccountNumber;
        public String oIban; public String oSwift; public String oBranch;
    }

    public List<BankRow> rows { get; private set; }
    public String message { get; private set; }
    public Boolean submitted { get; private set; }
    public Boolean locked { get; private set; }

    public BrokerBankEditController() {
        submitted = false;
        rows = new List<BankRow>();
        Id accId = getCurrentAccountId();
        locked = (accId == null) || pendingExists(accId);
        if (accId != null) loadRows(accId);
    }

    private void loadRows(Id accId) {
        for (Bank__c b : [
            SELECT Id, Name, Bank_Account_Name__c, Bank_Account_Number__c, IBAN__c, Swift_Code__c, Branch_Name__c
            FROM Bank__c WHERE Account__c = :accId ORDER BY CreatedDate
        ]) {
            BankRow r = new BankRow();
            r.recordId = b.Id;
            r.isNew = false;
            r.bankName      = s(b.Name);
            r.accountName   = s(b.Bank_Account_Name__c);
            r.accountNumber = s(b.Bank_Account_Number__c);
            r.iban          = s(b.IBAN__c);
            r.swift         = s(b.Swift_Code__c);
            r.branch        = s(b.Branch_Name__c);
            r.oBankName = r.bankName; r.oAccountName = r.accountName; r.oAccountNumber = r.accountNumber;
            r.oIban = r.iban; r.oSwift = r.swift; r.oBranch = r.branch;
            rows.add(r);
        }
    }

    public Boolean getHasRows() { return rows != null && !rows.isEmpty(); }

    private String s(Object o) { return o == null ? '' : String.valueOf(o); }
    private String t(String v) { return v == null ? '' : v.trim(); }

    private Boolean pendingExists(Id accId) {
        return ![
            SELECT Id FROM Approval_Request__c
            WHERE Related_Record_Id__c = :String.valueOf(accId)
              AND Request_Type__c = 'Bank Detail Update'
              AND Status__c IN ('Draft', 'Pending')
            LIMIT 1
        ].isEmpty();
    }

    public PageReference save() {
        message = null;
        Id accId = getCurrentAccountId();
        if (accId == null) { message = 'Your session has expired. Please log in again.'; return null; }
        if (pendingExists(accId)) { locked = true; message = 'You already have bank changes pending approval.'; return null; }

        List<Object> payload = new List<Object>();
        for (BankRow r : rows) {
            if (!rowChanged(r)) continue;          // skip rows with no edits

            payload.add(new Map<String, Object>{
                'recordId' => r.recordId,
                'fields' => new Map<String, Object>{
                    'Name' => t(r.bankName),
                    'Bank_Account_Name__c' => t(r.accountName),
                    'Bank_Account_Number__c' => t(r.accountNumber),
                    'IBAN__c' => t(r.iban),
                    'Swift_Code__c' => t(r.swift),
                    'Branch_Name__c' => t(r.branch)
                }
            });
        }

        if (payload.isEmpty()) { message = 'No changes to submit.'; return null; }

        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Bank Detail Update',
            Related_Object_Type__c = 'Account',
            Related_Record_Id__c = String.valueOf(accId),
            Field_To_Update__c = 'Bank Details (multiple)',
            Current_Value__c = 'See Bank Changes',
            Requested_Value__c = 'See Bank Changes',
            Justification__c = 'Bank detail update submitted from the Broker Portal.',
            Profile_Changes_JSON__c = JSON.serialize(payload),
            Status__c = 'Pending'
        );
        insert req;

        // Escape guest context to submit into the native Approval Process (handled by the platform-event trigger)
        EventBus.publish(new Broker_Bank_Submit__e(Approval_Request_Id__c = req.Id));

        submitted = true;
        locked = true;
        message = 'Your bank changes have been submitted for approval.';
        return null;
    }

    private Boolean rowChanged(BankRow r) {
        return t(r.bankName) != t(r.oBankName)
            || t(r.accountName) != t(r.oAccountName)
            || t(r.accountNumber) != t(r.oAccountNumber)
            || t(r.iban) != t(r.oIban)
            || t(r.swift) != t(r.oSwift)
            || t(r.branch) != t(r.oBranch);
    }
}