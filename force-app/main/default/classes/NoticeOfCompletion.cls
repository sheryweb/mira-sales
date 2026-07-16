public class NoticeOfCompletion {
    public Unit__c unit { get; private set; }
    public String clientName { get; private set; }
    public String clientEmail { get; private set; }
    public String clientAddress { get; private set; }
    public String projectName { get; private set; }
    public String unitTitle { get; private set; }
    public String unitBuilding { get; private set; }
    public String todayDate { get; private set; }
    
    // Constructor
    public NoticeOfCompletion() {
        // Initialize unit to prevent null pointer exceptions
        unit = new Unit__c();
        
        try {
            // Get unit ID from page parameters
            String unitId = ApexPages.currentPage().getParameters().get('unitId');
            
            // Validate unit ID
            if (String.isBlank(unitId)) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR, 
                    'Unit ID is required. Please provide a valid unit ID.'
                ));
                return;
            }
            
            // Try to parse the ID to ensure it's a valid Salesforce ID
            Id validUnitId;
            try {
                validUnitId = Id.valueOf(unitId);
                if (validUnitId.getSObjectType() != Unit__c.SObjectType) {
                    ApexPages.addMessage(new ApexPages.Message(
                        ApexPages.Severity.ERROR, 
                        'The provided ID is not a valid Unit ID.'
                    ));
                    return;
                }
            } catch (Exception e) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR, 
                    'Invalid Unit ID format: ' + unitId
                ));
                return;
            }
            
            // Load unit data
            loadUnitData(validUnitId);
            
        } catch (Exception e) {
            System.debug('Error in constructor: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 
                'Error initializing PDF: ' + e.getMessage()
            ));
        }
    }
    
    // Load data from the database
    private void loadUnitData(Id unitId) {
        try {
            System.debug('Starting loadUnitData for unit ID: ' + unitId);
            
            // Query the unit record with all needed fields
            List<Unit__c> units = [
                SELECT Id, Title__c, Project_Name_F__c, Status__c, Building__c,
                       Account__r.Name, Account_Email__c, Account__r.BillingAddress
                FROM Unit__c 
                WHERE Id = :unitId
                AND Status__c = 'Sold'
                LIMIT 1
            ];
            
            if (units.isEmpty()) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR, 
                    'Unit not found or not in Sold status with ID: ' + unitId
                ));
                return;
            }
            
            unit = units[0];
            
            // Set the properties for easy access in the page
            unitTitle = unit.Title__c != null ? unit.Title__c : '';
            projectName = unit.Project_Name_F__c != null ? unit.Project_Name_F__c : '';
            unitBuilding = unit.Building__c != null ? unit.Building__c : '';
            
            // Query for the Opportunity linked to this Unit
            List<Opportunity> opportunities = [
                SELECT Id, Account.Name, AccountId
                FROM Opportunity
                WHERE Unit__c = :unitId
                AND StageName = 'Sold'
                LIMIT 1
            ];
            
            System.debug('Opportunities found: ' + opportunities.size());
            
            // Check if opportunity exists and has joint owners
            if (!opportunities.isEmpty()) {
                Opportunity opp = opportunities[0];
                System.debug('Opportunity ID: ' + opp.Id);
                System.debug('Opportunity Account Name: ' + (opp.Account != null ? opp.Account.Name : 'null'));
                
                // Query joint owners with Account names using relationship query
                List<Joint_Owners__c> jointOwners = [
                    SELECT Account__c, Account__r.Name
                    FROM Joint_Owners__c
                    WHERE Opportunity__c = :opp.Id
                    ORDER BY Order__c ASC NULLS LAST
                ];
                
                System.debug('Joint Owners found: ' + jointOwners.size());
                
                // If joint owners exist, build combined name with primary account and joint owners
                if (!jointOwners.isEmpty()) {
                    List<String> ownerNames = new List<String>();
                    
                    // Add primary account name first
                    if (opp.Account != null && opp.Account.Name != null) {
                        ownerNames.add(opp.Account.Name);
                    }
                    
                    // Add joint owner names in order
                    for (Joint_Owners__c jo : jointOwners) {
                        if (jo.Account__r != null && jo.Account__r.Name != null) {
                            ownerNames.add(jo.Account__r.Name);
                        }
                    }
                    
                    clientName = String.join(ownerNames, ' & ');
                    System.debug('Client Name (with joint owners): ' + clientName);
                } else {
                    // No joint owners - use primary account from unit
                    clientName = unit.Account__r != null && unit.Account__r.Name != null ? unit.Account__r.Name : '';
                    System.debug('Client Name (no joint owners): ' + clientName);
                }
            } else {
                // No opportunity found - use primary account from unit
                clientName = unit.Account__r != null && unit.Account__r.Name != null ? unit.Account__r.Name : '';
                System.debug('Client Name (no opportunity): ' + clientName);
            }
            
            // Set email and address from unit's account
            clientEmail = unit.Account_Email__c != null ? unit.Account_Email__c : '';
            if (unit.Account__r != null) {
                clientAddress = formatAddress(unit.Account__r.BillingAddress);
            } else {
                clientAddress = '';
            }
            
            // Format today's date
            todayDate = formatDate(Date.today());
            
            System.debug('Successfully loaded unit data');
        } catch (Exception e) {
            System.debug('Error loading unit data: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 
                'Error loading unit data: ' + e.getMessage()
            ));
        }
    }
    
    // Format address from Address object
    private String formatAddress(Address addr) {
        if (addr == null) {
            return '';
        }
        
        List<String> addressParts = new List<String>();
        
        if (String.isNotBlank(addr.getStreet())) {
            addressParts.add(addr.getStreet());
        }
        if (String.isNotBlank(addr.getCity())) {
            addressParts.add(addr.getCity());
        }
        if (String.isNotBlank(addr.getState())) {
            addressParts.add(addr.getState());
        }
        if (String.isNotBlank(addr.getPostalCode())) {
            addressParts.add(addr.getPostalCode());
        }
        if (String.isNotBlank(addr.getCountry())) {
            addressParts.add(addr.getCountry());
        }
        
        return String.join(addressParts, ', ');
    }
    
    // Format date to "DD Month YYYY" format
    private String formatDate(Date d) {
        if (d == null) {
            return '';
        }
        
        String[] monthNames = new String[] {
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };
        
        Integer day = d.day();
        Integer month = d.month();
        Integer year = d.year();
        
        return day + ' ' + monthNames[month - 1] + ' ' + year;
    }
}