@RestResource(urlMapping='/units/*')
global without sharing class UnitsListService {
    
    // Added for testing
    @TestVisible
    private static String projectId = 'a01Rg00000MORNOIA5';
    //private static String projectId = 'a01U9000007W8uUIAS';
    @HttpGet
    global static String getUnits() {
        try {
            // Validate project ID
            if(String.isBlank(projectId) || !projectId.startsWith('a01')) {
                return JSON.serialize(new Map<String, Object>{
                    'status' => 'error',
                    'message' => 'Invalid Project ID format'
                });
            }
            
            // First check if project exists and is published
            List<Project__c> projects = [
                SELECT Publish_Project__c 
                FROM Project__c 
                WHERE Id = :projectId 
                LIMIT 1
            ];
            
            if(projects.isEmpty()) {
                return JSON.serialize(new Map<String, Object>{
                    'status' => 'error',
                    'message' => 'Project not found'
                });
            }
            
            if(projects[0].Publish_Project__c != 'Published') {
                return JSON.serialize(new Map<String, Object>{
                    'status' => 'error',
                    'message' => 'Project is not published'
                });
            }
            
            // Query units for the specified project
            List<Unit__c> units = [
                SELECT Id, Title__c, Cost_Per_Square_Meter_AED__c, Status__c 
                FROM Unit__c 
                WHERE Project__c = :projectId
            ];
            
            // Create a list to hold the simplified unit data
            List<Map<String, Object>> unitDataList = new List<Map<String, Object>>();
            
            // Convert units to the desired format
            for(Unit__c unit : units) {
                Map<String, Object> unitData = new Map<String, Object>{
                    'id' => unit.Id,
                    'title' => unit.Title__c,
                    'costPerSquareMeter' => unit.Cost_Per_Square_Meter_AED__c,
                    'status' => unit.Status__c
                };
                unitDataList.add(unitData);
            }
            
            // Return the response
            Map<String, Object> response = new Map<String, Object>{
                'status' => 'success',
                'units' => unitDataList
            };
            
            return JSON.serialize(response);
            
        } catch(Exception e) {
            return JSON.serialize(new Map<String, Object>{
                'status' => 'error',
                'message' => e.getMessage()
            });
        }
    }
}