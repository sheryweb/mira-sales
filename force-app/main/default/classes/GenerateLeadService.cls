@RestResource(urlMapping='/GenerateLead/*')
global without sharing class GenerateLeadService {
    @HttpPost
    global static String leadGeneration() {
        try {
            // Parse the request parameters
            RestRequest req = RestContext.request;
            Map<String, String> params = req.params;
            
            // Log the request parameters for debugging
            System.debug('Request Parameters: ' + params);
            
            if (params.isEmpty()) {
                return JSON.serialize(new Map<String, String>{
                    'status' => 'error',
                    'message' => 'Request parameters are empty'
                });
            }

            // Initialize OwnerId
            Id ownerId;
            
            // Check if rmemail is provided
            String rmEmail = params.get('rmemail');
            if (String.isNotBlank(rmEmail)) {
                // Get the user using the rmemail parameter
                User ownerUser = [SELECT Id FROM User WHERE Email = :rmEmail LIMIT 1];
                ownerId = ownerUser.Id;
            } else {
                // Use default OwnerId if rmemail is empty
                ownerId = '005Hp00000j94YqIAI';
            }
            
            // Create a new lead and add it to the list
            Lead newLead = new Lead(
                FirstName = params.get('firstName'),
                LastName = params.get('lastName'),
                Email = params.get('clientEmail'),
                Phone = params.get('clientPhone'),
                Company = params.get('company'),
                Client_Location__c = params.get('clientLocation'),
                URL_of_Application__c = params.get('applicationUrl'),
                Language_of_Client__c = params.get('clientLanguage'),
                Page_Language__c = params.get('pageLanguage'),
                Building__c = params.get('building'),
                Phase__c = params.get('phase'),
                Budget__c = Decimal.valueOf(params.get('budget')),
                Google_Click_Id__c = params.get('gcid'),
                Project__c = params.get('project'),
                Entity__c = params.get('entity'),
                Unit__c = params.get('unit'),
                UTM__C = params.get('utm'),
                Description = params.get('comments'),
                Agency_Name__c = params.get('agencyName'),
                Agent_Email__c = params.get('agentEmail'),
                Agent_Phone__c = params.get('agentPhone'),
                Agent_Name__c = params.get('agentName'),
                Agent_Company__c = params.get('agentCompany'),
                Type__c = params.get('type'),
                LeadSource = params.get('leadSource'),
                Stand_Location__c = params.get('standLocation'),
                MIRA_RM__c = params.get('miraRM'),
                MIRA_Stand_Admin__c = params.get('miraStandAdmin'),
                Unit_Type__c = params.get('unitType'),
                External_Agent_Name__c = params.get('externalAgentName'),
                External_Agent_Phone__c = params.get('externalAgentPhone'),
                Funnel_Type__c = params.get('funnelType'),
                Form_Type__c = params.get('formType'),
                OwnerId = ownerId
            );
            insert newLead;

            // Query the lead back to get all fields including LeadStatus
            Lead insertedLead = [SELECT Id, FirstName, LastName, Email, Phone, Company, 
                                        Status, Client_Location__c, URL_of_Application__c, 
                                        Language_of_Client__c, Page_Language__c, Building__c, 
                                        Phase__c, Budget__c, Google_Click_Id__c, Project__c, 
                                        Entity__c, Unit__c, UTM__C, Description, Agency_Name__c, 
                                        Agent_Email__c, Agent_Phone__c, Agent_Name__c, 
                                        Agent_Company__c, Type__c, LeadSource, Stand_Location__c, 
                                        MIRA_RM__c, MIRA_Stand_Admin__c, Unit_Type__c, 
                                        External_Agent_Name__c, External_Agent_Phone__c, 
                                        Funnel_Type__c, Form_Type__c, OwnerId, CreatedDate, 
                                        LastModifiedDate 
                                 FROM Lead 
                                 WHERE Id = :newLead.Id 
                                 LIMIT 1];

            // Return the whole record as JSON
            return JSON.serialize(insertedLead);
        } catch (DmlException e) {
            // Handle DML exceptions
            return JSON.serialize(new Map<String, String>{
                'status' => 'error',
                'message' => 'DML Exception: ' + e.getMessage()
            });
        } catch (Exception e) {
            // Handle general exceptions
            return JSON.serialize(new Map<String, String>{
                'status' => 'error',
                'message' => 'Exception: ' + e.getMessage()
            });
        }
    }
}