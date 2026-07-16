public with sharing class MiraPublicReportsController {
    // A list to hold the reports fetched from the folder
    public List<Report> accessibleReports { get; private set; }
    
    // The folder name you want to fetch reports from
    private final String targetFolder = 'MIRA Sales Manager Reports';
    
    // Constructor to initialize the list of reports from the specified folder
    public MiraPublicReportsController() {
        accessibleReports = getReportsFromFolder();
    }
    
    // Method to retrieve reports from the specified folder
    private List<Report> getReportsFromFolder() {
        try {
            // Query for the reports in the specified folder, making sure the user has access to them
            return [
                SELECT Id, Name, Description 
                FROM Report 
                WHERE FolderName = :targetFolder
                ORDER BY Name ASC
            ];
        } catch (Exception e) {
            // Handle any exception and return an empty list if something goes wrong
            System.debug('Error fetching reports: ' + e.getMessage());
            return new List<Report>();
        }
    }
}