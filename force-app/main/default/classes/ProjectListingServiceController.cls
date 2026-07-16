@RestResource(urlMapping='/Projects/*')
global without sharing class ProjectListingServiceController {
    
    @HttpGet
    global static ResponseWrapper getProjects() {
        ResponseWrapper response = new ResponseWrapper();
        
        try {
            // Validate RestContext
            if(RestContext.request == null) {
                throw new ProjectListingException('Invalid request context');
            }
            
            // Query Projects excluding Draft status
            List<Project__c> projects = [
                SELECT 
                    Id,
                    Name,
                    Description__c
                FROM Project__c 
                WHERE Publish_Project__c = 'Published'
                ORDER BY Name
            ];
            
            if(projects.isEmpty()) {
                response.success = true;
                response.message = 'No projects found';
                response.projects = new List<ProjectWrapper>();
                return response;
            }
            
            // Convert Project__c records to ProjectWrapper objects
            List<ProjectWrapper> projectWrappers = new List<ProjectWrapper>();
            for(Project__c proj : projects) {
                projectWrappers.add(new ProjectWrapper(proj));
            }
            
            response.success = true;
            response.message = 'Projects retrieved successfully';
            response.projects = projectWrappers;
            
        } catch(Exception e) {
            response.success = false;
            response.message = 'Error: ' + e.getMessage();
            response.projects = new List<ProjectWrapper>();
        }
        
        return response;
    }
    
    // Custom exception class
    public class ProjectListingException extends Exception {}
    
    // Wrapper class for Project data
    global class ProjectWrapper {
        global String Id { get; set; }
        global String Name { get; set; }
        global String Description { get; set; }
        
        global ProjectWrapper(Project__c proj) {
            this.Id = proj.Id;
            this.Name = proj.Name;
            this.Description = proj.Description__c;
        }
    }
    
    // Wrapper class for the response
    global class ResponseWrapper {
        global Boolean success { get; set; }
        global String message { get; set; }
        global List<ProjectWrapper> projects { get; set; }
        
        global ResponseWrapper() {
            this.success = false;
            this.message = '';
            this.projects = new List<ProjectWrapper>();
        }
    }
}