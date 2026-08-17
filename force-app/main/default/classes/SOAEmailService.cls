public with sharing class SOAEmailService {

    /** Set by BulkSoaQueueable so the SOA_Log__c row records the bulk channel. */
    public static Boolean bulkContext = false;

    /**
     * Finance Center audit trail: one SOA_Log__c row per send attempt (who = CreatedBy,
     * for whom, when, outcome). Logging must never block or break the send itself.
     */
    private static void logAttempt(Opportunity opp, String sentTo, String result) {
        try {
            insert new SOA_Log__c(
                Opportunity__c = opp == null ? null : opp.Id,
                Account__c = opp == null ? null : opp.AccountId,
                Unit__c = opp == null ? null : opp.Unit__c,
                Channel__c = bulkContext ? 'Bulk Email' : 'Email',
                Sent_To__c = sentTo,
                Result__c = result == null ? null : result.abbreviate(255),
                Is_Success__c = result != null && result.startsWith('Success')
            );
        } catch (Exception ignored) {
            // the log is best-effort; the send result has already been determined
        }
    }

    @AuraEnabled
    public static String sendSOAEmail(Id opportunityId) {
        FinancialEngine.requireEnabled();
        try {
            // Validate input
            if (opportunityId == null) {
                return 'Error: Opportunity ID cannot be null.';
            }
            
            // Fetch Opportunity record with required fields
            List<Opportunity> opps = [
                SELECT Id, Name, AccountId, Unit__c, Account_Name__c, Account_Email__c,
                       Unit__r.Title__c, Unit__r.Project_Name_F__c, Unit__r.Building__c,
                       Owner.Email
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];
            
            // Check if opportunity exists
            if (opps.isEmpty()) {
                return 'Error: Opportunity not found.';
            }
            
            Opportunity opp = opps[0];
            
            // Validate customer email
            if (String.isBlank(opp.Account_Email__c)) {
                return 'Error: No customer email found for this opportunity.';
            }
            
            // Validate Unit is associated
            if (opp.Unit__r == null || opp.Unit__r.Title__c == null) {
                return 'Error: No unit associated with this opportunity.';
            }
            
            // Generate PDF content
            PageReference pdfPage = Page.SOAPDF;
            pdfPage.getParameters().put('oppId', opportunityId);
            
            // Set rendering options to ensure PDF is fully rendered
            pdfPage.setRedirect(true);
            
            // Generate the PDF blob
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test SOA PDF Content');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }
            
            // Prepare email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            // Set email recipients
            email.setToAddresses(new String[] { opp.Account_Email__c });
            
            // Set CC recipient - include Opportunity Owner if available
            List<String> ccAddresses = new List<String>{ 'finance@miradevelopments.ae' };
            if (String.isNotBlank(opp.Owner.Email)) {
                ccAddresses.add(opp.Owner.Email);
            }
            email.setCcAddresses(ccAddresses);
            
            // Set email subject and body
            String unitInfo = opp.Unit__r.Title__c != null ? opp.Unit__r.Title__c : '';
            String projectInfo = opp.Unit__r.Project_Name_F__c != null ? opp.Unit__r.Project_Name_F__c : '';
            String buildingInfo = opp.Unit__r.Building__c != null ? opp.Unit__r.Building__c : '';
            String customerName = opp.Account_Name__c != null ? opp.Account_Name__c : 'Valued Customer';
            
            email.setSubject('Statement of Account for Unit ' + unitInfo + ' ' + projectInfo);
            email.setHtmlBody('Dear ' + customerName + ',<br/><br/>' +
                             'I hope this email finds you well.<br/><br/>' +
                             'Please find the attached Statement of Account (SOA) for Unit No. ' + unitInfo + ' at ' + projectInfo + 
                             (String.isNotBlank(buildingInfo) ? ' - ' + buildingInfo : '') + ', for your reference.<br/><br/>' +
                             'This statement provides a comprehensive overview of your payment history and outstanding balances.<br/><br/>' +
                             'If you have any questions or need clarification on any item in the statement, please don`t hesitate to reach out.<br/><br/>' +
                             'Thank you for your continued trust in us.<br/><br/><br/>' +
                             'Best regards,<br/><br/>' +
                             'Finance: finance@miradevelopments.ae<br/>' +
                             'M I R A Developments L L C');
            
            // Attach PDF to email
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName('SOA_' + unitInfo + '_' + projectInfo + '.pdf');
            attachment.setBody(pdfBlob);
            attachment.setContentType('application/pdf');
            //email.setOrgWideEmailAddressId('0D2U90000000z9xKAA'); //SandBox Organization-Wide Email Address ID
            email.setOrgWideEmailAddressId('0D2Rg0000000VWrKAM'); //Production Organization-Wide Email Address ID

            email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
            
            // Send email
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            
            // Check results
            String outcome = results[0].isSuccess()
                ? 'Success: SOA email sent to ' + opp.Account_Email__c
                : 'Error: ' + results[0].getErrors()[0].getMessage();
            logAttempt(opp, opp.Account_Email__c, outcome);
            return outcome;

        } catch (Exception e) {
            String outcome = 'Error: ' + e.getMessage();
            List<Opportunity> failedOpps = [
                SELECT Id, AccountId, Unit__c, Account_Email__c FROM Opportunity
                WHERE Id = :opportunityId LIMIT 1
            ];
            logAttempt(failedOpps.isEmpty() ? null : failedOpps[0],
                failedOpps.isEmpty() ? null : failedOpps[0].Account_Email__c, outcome);
            return outcome;
        }
    }
}