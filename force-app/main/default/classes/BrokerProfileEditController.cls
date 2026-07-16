public without sharing class BrokerProfileEditController extends BrokerLoginController {

    // Editable field, bound to the form (value is two-way bound on the wrapper)
    public class FieldDef {
        public String api { get; set; }
        public String label { get; set; }
        public String fieldType { get; set; }   // text | date | yesno
        public String value { get; set; }
        public String original { get; set; }
    }

    public List<FieldDef> fields { get; private set; }
    public String message { get; private set; }
    public Boolean submitted { get; private set; }
    public Boolean locked { get; private set; }

    public BrokerProfileEditController() {
        submitted = false;
        fields = buildFieldDefs();
        Id accId = getCurrentAccountId();
        locked = (accId == null) || pendingExists(accId);
        if (accId != null) loadValues(accId);
    }

    // Keep this set aligned with AgencyProfileApprovalService.ALLOWED_FIELDS. All editable for now; trim later.
    private List<FieldDef> buildFieldDefs() {
        // Editable fields only. Non-editable (Name, Status, Emirate, International Agency, RM, Type,
        // Trade License #/dates, ORN) are intentionally excluded and kept read-only on the profile.
        return new List<FieldDef>{
            def('Company_Email__c', 'Company Email', 'text'),
            def('Phone', 'Phone', 'text'),
            def('Landline_Number__c', 'Landline', 'text'),
            def('Contact_Email_2__c', 'Admin Email', 'text'),
            def('Admin_Number__c', 'Admin Mobile', 'text'),
            def('BillingStreet', 'Address', 'text'),
            def('TRN_Number__c', 'TRN Number', 'text'),
            def('VAT_TRN__c', 'VAT TRN', 'yesno'),
            def('BillingPostalCode', 'P.O. Box', 'text'),
            def('Signatory_Name__c', 'Signatory Name', 'text'),
            def('Signatory_Email__c', 'Signatory Email', 'text'),
            def('Signatory_Number__c', 'Signatory Mobile', 'text')
        };
    }
    private FieldDef def(String a, String l, String t) {
        FieldDef f = new FieldDef();
        f.api = a; f.label = l; f.fieldType = t; f.value = ''; f.original = '';
        return f;
    }

    private void loadValues(Id accId) {
        Set<String> apis = new Set<String>();
        for (FieldDef f : fields) apis.add(f.api);
        String soql = 'SELECT ' + String.join(new List<String>(apis), ', ') + ' FROM Account WHERE Id = :accId LIMIT 1';
        List<Account> a = Database.query(soql);
        if (a.isEmpty()) return;
        Account acc = a[0];
        for (FieldDef f : fields) {
            String v = toStr(acc.get(f.api));
            f.value = v;
            f.original = v;
        }
    }

    private String toStr(Object o) {
        if (o == null) return '';
        // Show dates in the user's locale so the date input displays/round-trips correctly;
        // they are normalised to ISO in save() before going into the JSON payload.
        if (o instanceof Date) return ((Date) o).format();
        if (o instanceof Datetime) return ((Datetime) o).date().format();
        return String.valueOf(o);
    }

    // Locale string (from the date input) -> ISO yyyy-MM-dd for safe storage/apply.
    private String toIso(String s) {
        if (String.isBlank(s)) return '';
        Date d;
        try { d = Date.parse(s.trim()); }
        catch (Exception e) { try { d = Date.valueOf(s.trim()); } catch (Exception e2) { return s; } }
        return DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
    }

    private Boolean pendingExists(Id accId) {
        return ![
            SELECT Id FROM Approval_Request__c
            WHERE Related_Record_Id__c = :String.valueOf(accId)
              AND Request_Type__c = 'Agency Profile Update'
              AND Status__c IN ('Draft', 'Pending')
            LIMIT 1
        ].isEmpty();
    }

    public PageReference save() {
        message = null;
        Id accId = getCurrentAccountId();
        if (accId == null) { message = 'Your session has expired. Please log in again.'; return null; }
        if (pendingExists(accId)) { locked = true; message = 'You already have changes pending approval.'; return null; }

        List<Object> changes = new List<Object>();
        for (FieldDef f : fields) {
            String newV = (f.value == null) ? '' : f.value.trim();
            String oldV = (f.original == null) ? '' : f.original;
            if (newV == oldV) continue;
            String jsonOld = oldV;
            String jsonNew = newV;
            if (f.fieldType == 'date') { jsonOld = toIso(oldV); jsonNew = toIso(newV); }
            changes.add(new Map<String, Object>{
                'field' => f.api, 'label' => f.label, 'oldValue' => jsonOld, 'newValue' => jsonNew
            });
        }
        if (changes.isEmpty()) { message = 'No changes to submit.'; return null; }

        Approval_Request__c req = new Approval_Request__c(
            Request_Type__c = 'Agency Profile Update',
            Related_Object_Type__c = 'Account',
            Related_Record_Id__c = String.valueOf(accId),
            Field_To_Update__c = 'Company Profile (multiple)',
            Current_Value__c = 'See Profile Changes',
            Requested_Value__c = 'See Profile Changes',
            Justification__c = 'Company profile update submitted from the Broker Portal.',
            Profile_Changes_JSON__c = JSON.serialize(changes),
            Status__c = 'Pending'
        );
        insert req;

        // Escape guest context to submit into the native Approval Process (handled by the platform-event trigger)
        EventBus.publish(new Broker_Profile_Submit__e(Approval_Request_Id__c = req.Id));

        submitted = true;
        locked = true;
        message = 'Your changes have been submitted for approval.';
        return null;
    }
}