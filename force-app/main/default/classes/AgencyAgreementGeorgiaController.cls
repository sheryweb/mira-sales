/**
 * AgencyAgreementGeorgiaController
 *
 * Invocable Apex class designed to be called from Flow screen components.
 * Fetches the "Georgia Agency Agreement.pdf" file from an Account and sends it
 * via email with a predefined subject and body template.
 *
 * Flow Usage:
 *   - Add this class as an Action in your Flow
 *   - Pass the Account ID as input
 *   - The class will automatically handle file retrieval and email sending
 */
public without sharing class AgencyAgreementGeorgiaController {
    
    // ─── Constants ───────────────────────────────────────────────────────────
    
    // Org-Wide Email Address IDs differ between Sandbox and Production.
    // Using the wrong one causes Messaging.sendEmail to fail.
    private static final Id SANDBOX_OWA_ID = '0D2U90000000Y4vKAE';
    private static final Id PRODUCTION_OWA_ID = '0D2Rg0000000LkPKAU';
    
    // Custom exception so real send failures surface to the Flow output/logs
    public class AgencyAgreementException extends Exception {}
    
    // ─── Input/Output Wrapper Classes ───────────────────────────────────────
    
    public class FlowInput {
        @InvocableVariable(label='Account ID' description='The ID of the Account record' required=true)
        public String accountId;
    }
    
    public class FlowOutput {
        @InvocableVariable(label='Success' description='Whether the operation was successful')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Message' description='Success or error message')
        public String message;
        
        @InvocableVariable(label='Email Sent' description='Whether the email was successfully sent')
        public Boolean emailSent;
    }
    
    // ─── Invocable Method ────────────────────────────────────────────────────
    
    @InvocableMethod(label='Send Georgia Agency Agreement' 
                     description='Fetches Georgia Agency Agreement PDF and sends it via email')
    public static List<FlowOutput> sendGeorgiaAgencyAgreement(List<FlowInput> inputs) {
        List<FlowOutput> outputs = new List<FlowOutput>();
        
        for (FlowInput input : inputs) {
            FlowOutput output = new FlowOutput();
            output.isSuccess = false;
            output.emailSent = false;
            
            try {
                // Validate input
                if (String.isBlank(input.accountId)) {
                    output.message = 'Account ID is required';
                    outputs.add(output);
                    continue;
                }
                
                // Process the request
                output = processAgencyAgreement(input.accountId);
                
            } catch (Exception e) {
                output.message = 'Unexpected error: ' + e.getMessage();
                System.debug('AgencyAgreementGeorgiaController error: ' + e.getMessage() 
                    + '\n' + e.getStackTraceString());
            }
            
            outputs.add(output);
        }
        
        return outputs;
    }
    
    // ─── Private Helper Methods ──────────────────────────────────────────────
    
    /**
     * Main processing method that orchestrates the entire flow
     */
    private static FlowOutput processAgencyAgreement(String accountId) {
        FlowOutput result = new FlowOutput();
        result.isSuccess = false;
        result.emailSent = false;
        
        try {
            // Step 1: Fetch the Account record
            Account account = getAccountRecord(accountId);
            if (account == null) {
                result.message = 'Account not found with ID: ' + accountId;
                return result;
            }
            
            // Step 2: Find the Georgia Agency Agreement PDF file
            ContentVersion pdfFile = findGeorgiaAgreementFile(accountId);
            if (pdfFile == null) {
                result.message = 'Georgia Agency Agreement.pdf file not found for Account: ' + account.Name;
                return result;
            }
            
            // Step 3: Send the email with attachment
            Boolean emailSuccess = sendAgencyAgreementEmail(account, pdfFile);
            
            if (emailSuccess) {
                result.isSuccess = true;
                result.emailSent = true;
                result.message = 'Georgia Agency Agreement email sent successfully to Account: ' + account.Name;
            } else {
                result.message = 'Failed to send email for Account: ' + account.Name;
            }
            
        } catch (Exception e) {
            result.message = 'Error processing Agency Agreement: ' + e.getMessage();
            System.debug('processAgencyAgreement error: ' + e.getMessage() 
                + '\n' + e.getStackTraceString());
        }
        
        return result;
    }
    
    /**
     * Fetches the Account record with required fields
     */
    private static Account getAccountRecord(String accountId) {
        try {
            List<Account> accounts = [
                SELECT Id, Name, Company_Email__c, MIRA_RM_Email__c
                FROM Account 
                WHERE Id = :accountId 
                LIMIT 1
            ];
            
            return accounts.isEmpty() ? null : accounts[0];
            
        } catch (Exception e) {
            System.debug('getAccountRecord error: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Searches for the Georgia Agency Agreement PDF file
     * Looks in both ContentVersion (Files) and Attachment objects
     */
    private static ContentVersion findGeorgiaAgreementFile(String accountId) {
        String fileName = 'Georgia Agency Agreement.pdf';
        
        try {
            // First, get linked ContentDocument IDs for this account
            List<ContentDocumentLink> linkedDocs = [
                SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :accountId
            ];
            
            Set<Id> contentDocIds = new Set<Id>();
            for (ContentDocumentLink link : linkedDocs) {
                contentDocIds.add(link.ContentDocumentId);
            }
            
            // Now check ContentVersion (Salesforce Files) using the collected IDs
            List<ContentVersion> contentVersions = new List<ContentVersion>();
            if (!contentDocIds.isEmpty()) {
                contentVersions = [
                    SELECT Id, Title, VersionData, ContentDocumentId
                    FROM ContentVersion 
                    WHERE ContentDocumentId IN :contentDocIds
                    AND (Title = :fileName OR Title LIKE '%Georgia Agency Agreement%')
                    AND IsLatest = true
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
            }
            
            if (!contentVersions.isEmpty()) {
                return contentVersions[0];
            }
            
            // If not found in ContentVersion, check Attachments and convert
            List<Attachment> attachments = [
                SELECT Id, Name, Body, ContentType
                FROM Attachment 
                WHERE ParentId = :accountId 
                AND (Name = :fileName OR Name LIKE '%Georgia Agency Agreement%')
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            if (!attachments.isEmpty()) {
                // Convert Attachment to ContentVersion for consistent handling
                ContentVersion cv = new ContentVersion();
                cv.Title = attachments[0].Name;
                cv.VersionData = attachments[0].Body;
                cv.ContentLocation = 'S'; // Stored in Salesforce
                cv.PathOnClient = attachments[0].Name;
                return cv;
            }
            
        } catch (Exception e) {
            System.debug('findGeorgiaAgreementFile error: ' + e.getMessage());
        }
        
        return null;
    }
    
    /**
     * Sends the agency agreement email with PDF attachment
     */
    private static Boolean sendAgencyAgreementEmail(Account account, ContentVersion pdfFile) {
        // Determine recipient email
        String recipientEmail = getRecipientEmail(account);
        if (String.isBlank(recipientEmail)) {
            throw new AgencyAgreementException(
                'No valid recipient email found for Account: ' + account.Name +
                '. Please populate the Company Email field or a primary Contact email.');
        }
        
        // Create email message
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        
        // Set recipient
        email.setToAddresses(new String[] { recipientEmail });
        
        // Set CC recipients
        String ccEmails = 'agents@miradevelopments.ae, maria.d@miradevelopments.ae';
        if (!String.isBlank(account.MIRA_RM_Email__c)) {
            ccEmails += ', ' + account.MIRA_RM_Email__c;
        }
        
        if (!String.isBlank(ccEmails)) {
            List<String> ccList = new List<String>();
            for (String ccEmail : ccEmails.split(',')) {
                ccEmail = ccEmail.trim();
                if (!String.isBlank(ccEmail)) {
                    ccList.add(ccEmail);
                }
            }
            if (!ccList.isEmpty()) {
                email.setCcAddresses(ccList);
            }
        }
        
        // Set subject
        email.setSubject('Broker\'s Agency Agreement - Georgia');
        
        // Set body with Account Name placeholder replacement
        String emailBody = buildEmailBody(account.Name);
        email.setPlainTextBody(emailBody);
        email.setHtmlBody(emailBody.replace('\n', '<br/>'));
        
        // Attach the PDF file
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName('Georgia Agency Agreement.pdf');
        attachment.setBody(pdfFile.VersionData);
        attachment.setContentType('application/pdf');
        
        email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
        
        // Use the correct Org-Wide Email Address for the current org (Sandbox vs Production).
        // Only set it if it actually exists/verified here, otherwise sending would fail.
        Id owaId = resolveOrgWideEmailAddressId();
        if (owaId != null) {
            email.setOrgWideEmailAddressId(owaId);
        }
        
        // Send the email (allOrNothing = true by default -> throws on failure)
        List<Messaging.SendEmailResult> results =
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        
        // Check if email was sent successfully
        if (!results.isEmpty() && results[0].isSuccess()) {
            System.debug('Agency Agreement email sent successfully to: ' + recipientEmail +
                ' with CC: ' + ccEmails);
            return true;
        }
        
        // Surface the real error instead of silently returning false
        String errorDetail = '';
        if (!results.isEmpty()) {
            for (Messaging.SendEmailError err : results[0].getErrors()) {
                errorDetail += err.getStatusCode() + ': ' + err.getMessage() + '; ';
            }
        }
        throw new AgencyAgreementException('Email send failed. ' + errorDetail);
    }
    
    /**
     * Resolves the correct Org-Wide Email Address Id for the current org.
     * Sandbox and Production have different OWA Ids, and using one that does
     * not exist in the running org causes Messaging.sendEmail to fail.
     * Returns null if no matching verified OWA is available (falls back to
     * the running user's address rather than failing silently).
     */
    private static Id resolveOrgWideEmailAddressId() {
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        Id targetId = isSandbox ? SANDBOX_OWA_ID : PRODUCTION_OWA_ID;
        
        List<OrgWideEmailAddress> owas = [
            SELECT Id FROM OrgWideEmailAddress WHERE Id = :targetId LIMIT 1
        ];
        return owas.isEmpty() ? null : owas[0].Id;
    }
    
    /**
     * Determines the appropriate recipient email address
     */
    private static String getRecipientEmail(Account account) {
        // First try Company_Email__c field
        if (String.isNotBlank(account.Company_Email__c)) {
            return account.Company_Email__c;
        }
        
        // If Company_Email__c is blank, try to find a primary contact
        try {
            List<Contact> primaryContacts = [
                SELECT Id, Email 
                FROM Contact 
                WHERE AccountId = :account.Id 
                AND Primary__c = true 
                AND Email != null 
                LIMIT 1
            ];
            
            if (!primaryContacts.isEmpty()) {
                return primaryContacts[0].Email;
            }
        } catch (Exception e) {
            System.debug('Error finding primary contact: ' + e.getMessage());
        }
        
        return null;
    }
    
    /**
     * Builds the email body with account name replacement
     */
    private static String buildEmailBody(String accountName) {
        String template = 'Dear {Account Name},\n\n' +
            'Please find attached the Broker Agency Agreement for your review.\n\n' +
            'We kindly ask that you carefully review the document to confirm that all company details are accurate. ' +
            'Should any corrections or amendments be required, please do not hesitate to contact us and we will address them promptly.\n\n' +
            'Once everything has been verified, please sign, stamp, and initial all pages of the agreement.\n\n' +
            'Upon receipt of the fully executed agreement, we will countersign and return a completed copy to you via email.\n\n' +
            'Should you have any questions or require further assistance, please feel free to reach out. ' +
            'We appreciate your prompt attention to this matter.\n\n' +
            'Regards,\nAgent Relations\nMIRA Developments\n\n' +
            '<img src="https://main-info-bucket.s3.us-east-1.amazonaws.com/mira_logo_small.jpeg" alt="MIRA Developments Logo" style="max-width: 200px;"/>';
        
        return template.replace('{Account Name}', accountName);
    }
}