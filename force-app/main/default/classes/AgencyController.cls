global without sharing class AgencyController {
    @RemoteAction
    global static String getAccountExist(String tradeLicenseNumber) {
        if (String.isBlank(tradeLicenseNumber)) {
            return 'Trade License not provided';
        }

        // Query for the account using the account name
        List<Account> accountList = [
            SELECT Id, Name, Trade_License_Number__c, Status__c, VAT_TRN__c 
            FROM Account 
            WHERE Trade_License_Number__c = :tradeLicenseNumber 
            LIMIT 1
        ];

        if (accountList.isEmpty()) {
            return 'Account Not Found';
        } else {
            return 'Account Exist';
        }
    }

    @RemoteAction
    global static List<String> handleCompanyRegistration(
        String internationalAgency,
        String companyName,
        String tradeLicense,
        String issueDate,
        String expiryDate,
        String ornNumber,
        String trnNumber,
        String companyAddress,
        String poBox,
        String email,
        String phone,
        String landline,
        String adminEmail,
        String adminMobile,
        String relationManager,
        String signatoryName,
        String signatoryEmail,
        String signatoryNumber,
        List<String> shareholderNames,
        List<Decimal> shareholderPercentages,
        List<String> bankNames,
        List<String> accountNames,
        List<String> accountNumbers,
        List<String> accountIBANs,
        List<String> accountSwiftCodes,
        List<String> branchNames,
        String trnSwitchValue,
        String emirateValue
    ) {
        List<String> responseReturned = new List<String>();
        List<String> debugLogs = new List<String>();

        // Initialize lists for DML operations
        List<Account> accountsToInsert = new List<Account>();
        List<Shareholder__c> shareholdersToInsert = new List<Shareholder__c>();
        List<Bank__c> bankAccountsToInsert = new List<Bank__c>();

        // Create a new account and add it to the list
        Account newAccount = new Account(
            Is_Agency_International__c = internationalAgency,
            Name = companyName,
            Trade_License_Number__c = tradeLicense,
            Trade_License_Issue_Date__c = Date.valueOf(issueDate),
            Trade_License_Expiry_Date__c = Date.valueOf(expiryDate),
            ORN_Number__c = ornNumber,
            TRN_Number__c = trnNumber,
            BillingStreet = companyAddress,
            BillingPostalCode = poBox,
            Company_Email__c = email,
            Phone = phone,
            Landline_Number__c = landline,
            Contact_Email_2__c = adminEmail,
            Admin_Number__c = adminMobile,
            Assigned_RM__c = relationManager,
            Signatory_Name__c = signatoryName,
            Signatory_Email__c = signatoryEmail,
            Signatory_Number__c = signatoryNumber,
            RecordTypeId = '012Hp000001yUTAIA2',
            Status__c = 'Incomplete Registration',
            Type = 'Agency',
            AccountSource = 'Agency App',
            Agency_Category__c = 'United Arab Emirates',
            OwnerId = '005Hp00000j94YpIAI',
            VAT_TRN__c = internationalAgency == 'Yes' ? 'No' : trnSwitchValue,
            Agency_Registered_Emirate__c = internationalAgency == 'Yes' ? null : emirateValue
        );
        accountsToInsert.add(newAccount);

        //Insert Accounts first to get the Ids for the relationships
        insert accountsToInsert;

        //Collect shareholders into the list
        for (Integer i = 0; i < shareholderNames.size(); i++) {
            Shareholder__c shareholder = new Shareholder__c(
                Name = shareholderNames[i],
                Percent__c = shareholderPercentages[i],
                Account__c = newAccount.Id // Placeholder until account is inserted
            );
            shareholdersToInsert.add(shareholder);
        }

        //Collect bank accounts into the list
        for (Integer i = 0; i < bankNames.size(); i++) {
            Bank__c bankAccount = new Bank__c(
                Name = bankNames[i],
                Bank_Account_Name__c = accountNames[i],
                Bank_Account_Number__c = accountNumbers[i],
                IBAN__c = accountIBANs[i],
                Swift_Code__c = accountSwiftCodes[i],
                Branch_Name__c = branchNames[i],
                Account__c = newAccount.Id // Placeholder until account is inserted
            );
            bankAccountsToInsert.add(bankAccount);
        }

        //Update Account Ids for Shareholders and Bank Accounts
        for (Shareholder__c shareholder : shareholdersToInsert) {
            shareholder.Account__c = newAccount.Id;
        }
        for (Bank__c bankAccount : bankAccountsToInsert) {
            bankAccount.Account__c = newAccount.Id;
        }

        //Insert Shareholders and Bank Accounts in bulk
        insert shareholdersToInsert;
        insert bankAccountsToInsert;

        responseReturned.add('Account Added Successfully');
        responseReturned.add(newAccount.Id);
        responseReturned.addAll(debugLogs);

        return responseReturned;
    }

    public Account agencyAccount { get; private set; }
    
    public AgencyController() {
        // Render the ProjectNotificationDraft PDF inline in the browser while giving it
        // a fixed file name for when the user saves/downloads it. The contentType
        // "#filename" hint is ignored for renderAs="pdf", so the Content-Disposition
        // header is used instead. Guarded so it only affects the PDF page (this
        // controller is shared) and skipped in async/batch contexts (currentPage null).
        PageReference currentPage = ApexPages.currentPage();
        if (currentPage != null && currentPage.getUrl() != null
                && currentPage.getUrl().contains('ProjectNotificationDraft')) {
            currentPage.getHeaders().put(
                'Content-Disposition',
                'inline; filename="Project Notification - NOC.pdf"'
            );
        }

        try {
            // First try to get from URL parameter
            String accountId = ApexPages.currentPage().getParameters().get('actId');
            
            // If no URL parameter, try to get the first Agency account for testing
            if(String.isBlank(accountId)) {
                List<Account> agencies = [SELECT Id, Name, Agency_Category__c
                                       FROM Account 
                                       WHERE RecordType.DeveloperName = 'Agency' 
                                       AND Status__c = 'Completed' 
                                       LIMIT 1];
                if(!agencies.isEmpty()) {
                    agencyAccount = agencies[0];
                }
            } else {
                agencyAccount = [SELECT Id, Name, Agency_Category__c FROM Account WHERE Id = :accountId LIMIT 1];
            }
        } catch(Exception e) {
            // Handle any errors gracefully
            System.debug('Error in AgencyController constructor: ' + e.getMessage());
        }
    }
    
    public Map<String, String> getAgencyInfo() {
        if (agencyAccount == null) {
            return new Map<String, String>{ 'error' => 'No Agency Found' };
        }
        return new Map<String, String>{
            'name'           => agencyAccount.Name,
            'agencyCategory' => agencyAccount.Agency_Category__c
        };
    }
}