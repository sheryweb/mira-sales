@RestResource(urlMapping='/CompanyRegistration/*')
global with sharing class CompanyRegistrationService {
    @HttpPost
    global static List<String> handleCompanyRegistration(String internationalAgency, String companyName, String tradeLicense, String issueDate,
                                                  String expiryDate, String ornNumber, String trnNumber,
                                                  String companyAddress, String poBox, String email,
                                                  String phone, String landline, String adminEmail,
                                                  String adminMobile, String relationManager, String signatoryName,
                                                  String signatoryNumber, String signatoryEmail,
                                                  List<String> shareholderNames, List<Decimal> shareholderPercentages,
                                                  List<String> bankNames, List<String> accountNames,
                                                  List<String> accountNumbers, List<String> accountIBANs,
                                                  List<String> accountSwiftCodes, List<String> branchNames,
                                                  List<String> fileNames, List<String> fileContents) {
        List<String> responseReturned = new List<String>();
        // Initialize lists for DML operations
        List<Account> accountsToInsert = new List<Account>();
        List<Shareholder__c> shareholdersToInsert = new List<Shareholder__c>();
        List<Bank__c> bankAccountsToInsert = new List<Bank__c>();
        List<ContentVersion> contentVersionsToInsert = new List<ContentVersion>();

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
            OwnerId = '005Hp00000j94YpIAI'
        );
        accountsToInsert.add(newAccount);

        // Collect shareholders into the list
        for (Integer i = 0; i < shareholderNames.size(); i++) {
            Shareholder__c shareholder = new Shareholder__c(
                Name = shareholderNames[i],
                Percent__c = shareholderPercentages[i],
                Account__c = newAccount.Id // Placeholder until account is inserted
            );
            shareholdersToInsert.add(shareholder);
        }

        // Collect bank accounts into the list
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

        // Insert Accounts first to get the Ids for the relationships
        insert accountsToInsert;

        // Update Account Ids for Shareholders and Bank Accounts
        for (Shareholder__c shareholder : shareholdersToInsert) {
            shareholder.Account__c = newAccount.Id;
        }
        for (Bank__c bankAccount : bankAccountsToInsert) {
            bankAccount.Account__c = newAccount.Id;
        }

        // Insert Shareholders and Bank Accounts in bulk
        insert shareholdersToInsert;
        insert bankAccountsToInsert;

        responseReturned.add('Account Added Successfully');
        responseReturned.add(newAccount.Id);
                                                      
        return responseReturned;
    }
}