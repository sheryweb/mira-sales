/**
 * Class to fetch Opportunity and related Account information
 * This class is designed to be called from Salesforce Flows
 */
public with sharing class SpaSignedNotification {
    
    private static final String PERSON_ACCOUNT_RECORD_TYPE_ID = '012Hp000001yUTFIA2';
    private static final List<String> CC_EMAIL_ADDRESSES = new List<String>{
        'maria.d@miradevelopments.ae',
        'jad.orabi@miradevelopments.ae',
        'info@miradevelopments.ae'
    };
    
    /**
     * Input variables for the invocable method
     */
    public class FlowInputs {
        @InvocableVariable(required=true description='Opportunity ID to fetch')
        public Id opportunityId;
    }
    
    /**
     * Output variables for the invocable method
     */
    public class FlowOutputs {
        @InvocableVariable(description='Account Name')
        public String accountName;
        
        @InvocableVariable(description='Account Email')
        public String accountEmail;
        
        @InvocableVariable(description='Account Mobile Phone')
        public String accountMobilePhone;
        
        @InvocableVariable(description='Account Billing Postal Code')
        public String billingPostalCode;
        
        @InvocableVariable(description='Account Billing City')
        public String billingCity;
        
        @InvocableVariable(description='Account Billing Street')
        public String billingStreet;
        
        @InvocableVariable(description='Account Billing Country')
        public String billingCountry;
        
        @InvocableVariable(description='Is Person Account')
        public Boolean isPersonAccount;
        
        @InvocableVariable(description='Success indicator')
        public Boolean isSuccess;
        
        @InvocableVariable(description='Error message if any')
        public String errorMessage;
    }
    
    /**
     * Invocable method to fetch Opportunity and Account information
     * @param inputs List of FlowInputs containing Opportunity IDs
     * @return List of FlowOutputs containing Account information
     */
    @InvocableMethod(label='Get Opportunity Account Info' description='Fetches Opportunity and related Account information for Flow')
    public static List<FlowOutputs> getOpportunityAccountInfo(List<FlowInputs> inputs) {
        List<FlowOutputs> outputs = new List<FlowOutputs>();
        
        for (FlowInputs input : inputs) {
            FlowOutputs output = new FlowOutputs();
            
            try {
                // Fetch Opportunity with related Account information
                Opportunity opp = [
                    SELECT Id, Name, AccountId, 
                           Account.Name,
                           Account.PersonEmail,
                           Account.PersonMobilePhone,
                           Account.BillingPostalCode,
                           Account.BillingCity,
                           Account.BillingStreet,
                           Account.BillingCountry,
                           Account.RecordTypeId,
                           Project_Name__c,
                           Unit_Number__c,
                           Unit_Tower__c,
                           Owner.Email
                    FROM Opportunity
                    WHERE Id = :input.opportunityId
                    LIMIT 1
                ];
                
                // Check if Account exists
                if (opp.AccountId == null) {
                    output.isSuccess = false;
                    output.errorMessage = 'No Account associated with this Opportunity';
                    outputs.add(output);
                    continue;
                }
                
                // Set Account basic information
                output.accountName = opp.Account.Name;
                output.billingPostalCode = opp.Account.BillingPostalCode;
                output.billingCity = opp.Account.BillingCity;
                output.billingStreet = opp.Account.BillingStreet;
                output.billingCountry = opp.Account.BillingCountry;
                output.isPersonAccount = (opp.Account.RecordTypeId == PERSON_ACCOUNT_RECORD_TYPE_ID);
                
                // Conditional logic for Email and Phone based on Account Record Type
                if (opp.Account.RecordTypeId == PERSON_ACCOUNT_RECORD_TYPE_ID) {
                    // For Person Account Record Type, use Person fields from Account
                    output.accountEmail = opp.Account.PersonEmail;
                    output.accountMobilePhone = opp.Account.PersonMobilePhone;
                } else {
                    // For other Record Types, fetch from related Contact
                    List<Contact> relatedContacts = [
                        SELECT Email, MobilePhone, Name
                        FROM Contact
                        WHERE AccountId = :opp.AccountId
                        LIMIT 1
                    ];
                    
                    if (!relatedContacts.isEmpty()) {
                        output.accountName = relatedContacts[0].Name;
                        output.accountEmail = relatedContacts[0].Email;
                        output.accountMobilePhone = relatedContacts[0].MobilePhone;
                    }
                }
                
                output.isSuccess = true;
                
                // Send email notification if successful
                if (output.isSuccess && String.isNotBlank(output.accountEmail)) {
                    output.isSuccess = sendEmailNotification(opp, output);
                    if (!output.isSuccess) {
                        output.errorMessage = 'Failed to send email notification.';
                    }
                }
                
            } catch (QueryException e) {
                output.isSuccess = false;
                output.errorMessage = 'Opportunity not found: ' + e.getMessage();
            } catch (Exception e) {
                output.isSuccess = false;
                output.errorMessage = 'An error occurred: ' + e.getMessage();
            }
            
            outputs.add(output);
        }
        
        return outputs;
    }
    
    /**
     * Sends email notification to the account email with CC recipients
     * @param opp The Opportunity record
     * @param output The FlowOutputs containing account information
     */
    private static Boolean sendEmailNotification(Opportunity opp, FlowOutputs output) {
        try {
            // Create a new email message
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            
            // Set the recipient (To address)
            mail.setToAddresses(new List<String>{output.accountEmail});
            
            // Set CC addresses - include owner email if available
            List<String> ccAddresses = new List<String>(CC_EMAIL_ADDRESSES);
            if (String.isNotBlank(opp.Owner.Email)) {
                ccAddresses.add(opp.Owner.Email);
            }
            mail.setCcAddresses(ccAddresses);
            
            // Set email subject
            mail.setSubject('Final SPA Courier Address Confirmation - '+output.accountName+' - '+opp.Project_Name__c+' - '+opp.Unit_Tower__c+'-'+opp.Unit_Number__c);
            
            // Build email body
            String body = 'Dear ' + output.accountName + ',<br><br>';
            body += 'Thank you for your investment!<br><br>';
            body += 'We are pleased to inform you that your Sale and Purchase Agreement (SPA) for your property in ' + opp.Project_Name__c + ', Unit: ' + opp.Unit_Tower__c + '-' + opp.Unit_Number__c + '<br>';
            body += 'has been fully signed and your original copy is ready to be dispatched to you.<br><br>';
            body += 'You are kindly requested to confirm your courier address and contact information provided below:<br>';
            body += '<strong>Contact Information:</strong><br>';
            body += '  • <strong>Address:</strong> ' + output.billingStreet + ', ' + output.billingCity + ', ' + output.billingCountry + '<br>';
            body += '  • <strong>Postal Code:</strong> ' + (String.isBlank(output.billingPostalCode) ? 'N/A' : output.billingPostalCode) + '<br>';
            body += '  • <strong>Mobile:</strong> ' + output.accountMobilePhone + '<br>';
            body += 'For any queries and clarification, please feel free to reply on this email.<br><br>';
            body += 'Best regards,<br>Mira Developments Team<br><br>';
            
            // Add logo signature using inline attachment
            String logoUrl = 'https://main-info-bucket.s3.us-east-1.amazonaws.com/miradev_logo.jpeg';
            
            body += '<img src="' + logoUrl + '" alt="Company Logo" style="height:50px;">';
            
            mail.setHtmlBody(body);

            //mail.setOrgWideEmailAddressId('0D2U90000000Y4vKAE'); //SandBox Organization-Wide Email Address ID
            mail.setOrgWideEmailAddressId('0D2Rg0000000XK9KAM'); //Production Organization-Wide Email Address ID
            
            if (Test.isRunningTest()) {
                return true;
            }

            // Send the email
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});

            if (results[0].isSuccess()) {
                return true;
            } else {
                System.debug('Error sending email: ' + results[0].getErrors()[0].getMessage());
                return false;
            }
            
        } catch (Exception e) {
            // Log error but don't throw it as email notification is not critical
            System.debug('Error sending email notification: ' + e.getMessage());
            return false;
        }
    }
}