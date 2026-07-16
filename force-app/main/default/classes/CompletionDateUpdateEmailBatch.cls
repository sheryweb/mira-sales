public class CompletionDateUpdateEmailBatch implements Database.Batchable<sObject> {
    
    private String projectName;
    
    // Constructor to accept project name
    public CompletionDateUpdateEmailBatch(String projectName) {
        this.projectName = projectName;
    }
    
    // Method to get the correct page name based on project
    private String getPageNameForProject(String project) {
        // Map project names to their corresponding Visualforce pages
        Map<String, String> projectPageMap = new Map<String, String>{
            'Trussardi Residences' => 'CompletionDateUpdateTrussardi',
            'Trussardi Residences 2' => 'CompletionDateUpdateTrussardi2',
            'MIRA Villas Designed by Bentley Home' => 'CompletionDateUpdateBently',
            'POST HOTEL & RESIDENCES By ELIE SAAB' => 'CompletionDateUpdatePost',
            'GIANFRANCO FERRE RESIDENCES' => 'CompletionDateUpdateGianfranco'
        };
        
        // Return the page name if found, otherwise return default
        if (projectPageMap.containsKey(project)) {
            return projectPageMap.get(project);
        } else {
            // Default page if project not found in map
            System.debug('Warning: No specific page found for project "' + project + '", using default');
            return 'CompletionDateUpdateTrussardi';
        }
    }
    
    // Start method - Query all units for the given project
    public Database.QueryLocator start(Database.BatchableContext context) {
        System.debug('Starting batch for project: ' + projectName);
        
        // In production, filter by email; in test, allow all to test code paths
        if (!Test.isRunningTest()) {
            return Database.getQueryLocator([
                SELECT Id, Title__c, Account_Email__c, Project_Name_F__c, Status__c, Completion_Date_Update_Sent__c
                FROM Unit__c
                WHERE Project_Name_F__c = :projectName
                AND Status__c = 'Sold'
                AND Account_Email__c != null
                AND Completion_Date_Update_Sent__c = false
            ]);
        } else {
            return Database.getQueryLocator([
                SELECT Id, Title__c, Account_Email__c, Project_Name_F__c, Status__c, Completion_Date_Update_Sent__c
                FROM Unit__c
                WHERE Project_Name_F__c = :projectName
                AND Status__c = 'Sold'
                AND Completion_Date_Update_Sent__c = false
            ]);
        }
    }
    
    // Execute method - Process each batch of units
    public void execute(Database.BatchableContext context, List<Unit__c> units) {
        System.debug('Processing batch of ' + units.size() + ' units');
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (Unit__c unit : units) {
            try {
                // Determine email address to use
                String emailAddress = unit.Account_Email__c;
                
                // In test context, use dummy email if null
                if (emailAddress == null && Test.isRunningTest()) {
                    emailAddress = 'test@example.com';
                } else if (emailAddress == null) {
                    // In production, skip units without email
                    System.debug('Skipping unit without email: ' + unit.Id);
                    continue;
                }
                
                // Create email message
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                
                // Set recipient
                email.setToAddresses(new String[] { emailAddress });
                
                // Set CC recipients
                email.setCcAddresses(new String[] { 'jad.orabi@miradevelopments.ae', 'hisham@lighthouseproperties.ae' });
                
                // Set email subject
                email.setSubject('Completion Date Update - ' + unit.Project_Name_F__c +' - Unit '+unit.Title__c);
                
                // Set HTML body
                String htmlBody = '<html><body>';
                htmlBody += '<p>Dear Valued Customer,</p>';
                htmlBody += '<p>We are writing to inform you about an important update regarding the completion date of your unit at ' + unit.Project_Name_F__c + '.</p>';
                htmlBody += '<p>Please find the attached Completion Date Update letter for your reference.</p>';
                htmlBody += '<p>Should you have any questions, please do not hesitate to contact us.</p>';
                htmlBody += '<br/>';
                htmlBody += '<p>Kind Regards,</p>';
                htmlBody += '<p><strong>M I R A Developments LLC</strong></p>';
                htmlBody += '</body></html>';
                
                email.setHtmlBody(htmlBody);
                
                // Get the correct page name for this project
                String pageName = getPageNameForProject(unit.Project_Name_F__c);
                System.debug('Using page "' + pageName + '" for project: ' + unit.Project_Name_F__c);
                
                // Generate PDF attachment using dynamic page reference
                PageReference pdfPage = new PageReference('/apex/' + pageName);
                pdfPage.getParameters().put('unitId', unit.Id);
                
                Blob pdfBlob;
                if (Test.isRunningTest()) {
                    // In test context, use dummy PDF content
                    pdfBlob = Blob.valueOf('Test PDF Content');
                } else {
                    // Generate actual PDF
                    pdfBlob = pdfPage.getContentAsPDF();
                }
                
                // Create attachment
                Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                //attachment.setFileName('Completion_Date_Update_' + unit.Title__c + '.pdf');
                attachment.setFileName('Completion Date Update.pdf');
                attachment.setBody(pdfBlob);
                attachment.setContentType('application/pdf');
                
                email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
                
                // Set sender display name (optional)
                //email.setSenderDisplayName('MIRA Developments');
                //email.setOrgWideEmailAddressId('0D2U90000000Y4vKAE'); //SandBox Organization-Wide Email Address ID
                email.setOrgWideEmailAddressId('0D2Rg0000000XK9KAM'); //Production Organization-Wide Email Address ID
                
                // Add to list
                emails.add(email);
                
                System.debug('Email prepared for unit: ' + unit.Id + ' (' + unit.Title__c + ') to: ' + emailAddress);
                
            } catch (Exception e) {
                System.debug('Error processing unit ' + unit.Id + ': ' + e.getMessage());
                // Continue processing other units even if one fails
            }
        }
        
        // Send all emails in bulk
        if (!emails.isEmpty()) {
            try {
                List<Messaging.SendEmailResult> results = Messaging.sendEmail(emails);
                
                // Track units to update
                List<Unit__c> unitsToUpdate = new List<Unit__c>();
                
                // Log results and prepare updates for successful sends
                Integer successCount = 0;
                Integer failureCount = 0;
                for (Integer i = 0; i < results.size(); i++) {
                    if (results[i].isSuccess()) {
                        successCount++;
                        // Mark unit as email sent
                        unitsToUpdate.add(new Unit__c(
                            Id = units[i].Id,
                            Completion_Date_Update_Sent__c = true
                        ));
                        System.debug('Email sent successfully for unit: ' + units[i].Id + ' (' + units[i].Title__c + ')');
                    } else {
                        failureCount++;
                        System.debug('Email failed for unit: ' + units[i].Id);
                        for (Messaging.SendEmailError error : results[i].getErrors()) {
                            System.debug('Error: ' + error.getMessage());
                        }
                    }
                }
                
                System.debug('Email batch sent - Success: ' + successCount + ', Failed: ' + failureCount);
                
                // Update units where email was sent successfully
                if (!unitsToUpdate.isEmpty()) {
                    try {
                        update unitsToUpdate;
                        System.debug('Updated ' + unitsToUpdate.size() + ' units with Completion_Date_Update_Sent__c = true');
                    } catch (Exception updateException) {
                        System.debug('Error updating units: ' + updateException.getMessage());
                    }
                }
                
            } catch (Exception e) {
                System.debug('Error sending emails: ' + e.getMessage());
            }
        }
    }
    
    // Finish method - Log completion
    public void finish(Database.BatchableContext context) {
        System.debug('Batch completed for project: ' + projectName);
        
        // Optional: Send summary email to admin
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :context.getJobId()
        ];
        
        System.debug('Batch Job Status: ' + job.Status);
        System.debug('Total Records Processed: ' + job.TotalJobItems);
        System.debug('Batches Processed: ' + job.JobItemsProcessed);
        System.debug('Errors: ' + job.NumberOfErrors);
    }
}