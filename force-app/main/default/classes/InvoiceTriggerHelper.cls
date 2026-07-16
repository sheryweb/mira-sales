public class InvoiceTriggerHelper {
    @TestVisible private static Boolean skipTrigger = false;
    
    public static void handleInvoiceNumberAssignment(List<Invoice__c> newInvoices) {
        System.debug('=== InvoiceTriggerHelper.handleInvoiceNumberAssignment called ===');
        System.debug('Number of invoices to process: ' + newInvoices.size());
        System.debug('Skip trigger flag: ' + skipTrigger);
        
        if(skipTrigger) {
            System.debug('Skipping trigger due to skipTrigger flag');
            return;
        }
        
        // First get all Unit IDs to query their project names
        Set<Id> unitIds = new Set<Id>();
        for(Invoice__c inv : newInvoices) {
            if(inv.Unit__c != null) {
                unitIds.add(inv.Unit__c);
            }
        }
        
        // Query Units to get project names
        Map<Id, Unit__c> unitsMap = new Map<Id, Unit__c>([
            SELECT Id, Project_Name_F__c
            FROM Unit__c
            WHERE Id IN :unitIds
        ]);
        
        // Get project names from units
        Set<String> projectNames = new Set<String>();
        for(Unit__c unit : unitsMap.values()) {
            if(unit.Project_Name_F__c != null) {
                projectNames.add(unit.Project_Name_F__c);
            }
        }
        
        System.debug('Project Names to process: ' + projectNames);
        
        // Query for existing invoices to get max numbers for each project
        List<Invoice__c> existingInvoices = [
            SELECT Unit__r.Project_Name_F__c, 
                   Invoice_Number_To_Process_Trussardi__c,
                   Invoice_Number_To_Process_Trussardi2__c,
                   Invoice_Number_To_Process_Bentley__c,
                   Invoice_Number_To_Process_POST__c,
                   Invoice_Number_To_Process_Gianfranco__c,
                   Invoice_Number_To_Process_T2_Offices__c,
                   Invoice_Number_To_Process_MIRA_VERDE__c,
                   Invoice_Number_To_Process_Richmond__c
            FROM Invoice__c 
            WHERE Unit__r.Project_Name_F__c IN :projectNames
            AND (Invoice_Number_To_Process_Trussardi__c != null 
                 OR Invoice_Number_To_Process_Trussardi2__c != null 
                 OR Invoice_Number_To_Process_Bentley__c != null
                 OR Invoice_Number_To_Process_POST__c != null
                 OR Invoice_Number_To_Process_Gianfranco__c != null
                 OR Invoice_Number_To_Process_T2_Offices__c != null
                 OR Invoice_Number_To_Process_MIRA_VERDE__c != null
                 OR Invoice_Number_To_Process_Richmond__c != null)
            ORDER BY CreatedDate DESC, Invoice_Number_To_Process_Trussardi__c DESC,
                     Invoice_Number_To_Process_Trussardi2__c DESC,
                     Invoice_Number_To_Process_Bentley__c DESC,
                     Invoice_Number_To_Process_POST__c DESC,
                     Invoice_Number_To_Process_Gianfranco__c DESC,
                     Invoice_Number_To_Process_T2_Offices__c DESC,
                     Invoice_Number_To_Process_MIRA_VERDE__c DESC,
                     Invoice_Number_To_Process_Richmond__c DESC
        ];
        
        System.debug('Existing invoices found: ' + existingInvoices);
        
        // Initialize max numbers
        Map<String, Decimal> maxNumbersByProject = new Map<String, Decimal>();
        maxNumbersByProject.put('Trussardi Residences', 0);
        maxNumbersByProject.put('Trussardi Residences 2', 0);
        maxNumbersByProject.put('MIRA Villas Designed by Bentley Home', 0);
        maxNumbersByProject.put('POST HOTEL & RESIDENCES By ELIE SAAB', 0);
        maxNumbersByProject.put('GIANFRANCO FERRE RESIDENCES', 0);
        maxNumbersByProject.put('Trussardi Residences 2 Offices', 0);
        maxNumbersByProject.put('Trussardi Residences MIRA VERDE', 0);
        maxNumbersByProject.put('John Richmond Residences', 0);
        
        // Get the maximum numbers from existing invoices
        for(Invoice__c inv : existingInvoices) {
            String projectName = inv.Unit__r.Project_Name_F__c;
            if(projectName == 'Trussardi Residences' && inv.Invoice_Number_To_Process_Trussardi__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), inv.Invoice_Number_To_Process_Trussardi__c));
            }
            else if(projectName == 'Trussardi Residences 2' && inv.Invoice_Number_To_Process_Trussardi2__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), inv.Invoice_Number_To_Process_Trussardi2__c));
            }
            else if(projectName == 'MIRA Villas Designed by Bentley Home' && inv.Invoice_Number_To_Process_Bentley__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), inv.Invoice_Number_To_Process_Bentley__c));
            }
            else if(projectName == 'POST HOTEL & RESIDENCES By ELIE SAAB' && inv.Invoice_Number_To_Process_POST__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), inv.Invoice_Number_To_Process_POST__c));
            }
            else if(projectName == 'GIANFRANCO FERRE RESIDENCES' && inv.Invoice_Number_To_Process_Gianfranco__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), inv.Invoice_Number_To_Process_Gianfranco__c));
            }
            else if(projectName == 'Trussardi Residences 2 Offices' && inv.Invoice_Number_To_Process_T2_Offices__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), inv.Invoice_Number_To_Process_T2_Offices__c));
            }
            else if(projectName == 'Trussardi Residences MIRA VERDE' && inv.Invoice_Number_To_Process_MIRA_VERDE__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), inv.Invoice_Number_To_Process_MIRA_VERDE__c));
            }
            else if(projectName == 'John Richmond Residences' && inv.Invoice_Number_To_Process_Richmond__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), inv.Invoice_Number_To_Process_Richmond__c));
            }
        }
        
        System.debug('Max numbers by project: ' + maxNumbersByProject);
        
        // Process new invoices
        for(Invoice__c invoice : newInvoices) {
            if(invoice.Unit__c == null || !unitsMap.containsKey(invoice.Unit__c)) {
                System.debug('Skipping invoice due to missing Unit: ' + invoice);
                // Explicitly set all numbering fields to null to ensure they don't get default values
                invoice.Invoice_Number_To_Process_Trussardi__c = null;
                invoice.Invoice_Number_To_Process_Trussardi2__c = null;
                invoice.Invoice_Number_To_Process_Bentley__c = null;
                invoice.Invoice_Number_To_Process_POST__c = null;
                invoice.Invoice_Number_To_Process_Gianfranco__c = null;
                invoice.Invoice_Number_To_Process_T2_Offices__c = null;
                invoice.Invoice_Number_To_Process_MIRA_VERDE__c = null;
                invoice.Invoice_Number_To_Process_Richmond__c = null;
                invoice.Invoice_Number__c = null;
                continue;
            }
            
            String projectName = unitsMap.get(invoice.Unit__c).Project_Name_F__c;
            if(projectName == null) {
                System.debug('Skipping invoice due to null project name');
                // Explicitly set all numbering fields to null to ensure they don't get default values
                invoice.Invoice_Number_To_Process_Trussardi__c = null;
                invoice.Invoice_Number_To_Process_Trussardi2__c = null;
                invoice.Invoice_Number_To_Process_Bentley__c = null;
                invoice.Invoice_Number_To_Process_POST__c = null;
                invoice.Invoice_Number_To_Process_Gianfranco__c = null;
                invoice.Invoice_Number_To_Process_T2_Offices__c = null;
                invoice.Invoice_Number_To_Process_MIRA_VERDE__c = null;
                invoice.Invoice_Number_To_Process_Richmond__c = null;
                invoice.Invoice_Number__c = null;
                continue;
            }
            
            System.debug('Processing invoice for project: ' + projectName);
            
            if(projectName == 'Trussardi Residences') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                invoice.Invoice_Number_To_Process_Trussardi__c = currentMax;
                invoice.Invoice_Number__c = 'INV-TRD-' + String.valueOf(currentMax);
                System.debug('Assigned Trussardi number: ' + currentMax);
            }
            else if(projectName == 'Trussardi Residences 2') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                invoice.Invoice_Number_To_Process_Trussardi2__c = currentMax;
                invoice.Invoice_Number__c = 'INV-TRD2-' + String.valueOf(currentMax);
                System.debug('Assigned Trussardi 2 number: ' + currentMax);
            }
            else if(projectName == 'MIRA Villas Designed by Bentley Home') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                invoice.Invoice_Number_To_Process_Bentley__c = currentMax;
                invoice.Invoice_Number__c = 'INV-BTL-' + String.valueOf(currentMax);
                System.debug('Assigned Bentley number: ' + currentMax);
            }
            else if(projectName == 'POST HOTEL & RESIDENCES By ELIE SAAB') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                invoice.Invoice_Number_To_Process_POST__c = currentMax;
                invoice.Invoice_Number__c = 'INV-POST-' + String.valueOf(currentMax);
                System.debug('Assigned POST number: ' + currentMax);
            }
            else if(projectName == 'GIANFRANCO FERRE RESIDENCES') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                invoice.Invoice_Number_To_Process_Gianfranco__c = currentMax;
                invoice.Invoice_Number__c = 'INV-GFF-' + String.valueOf(currentMax);
                System.debug('Assigned Gianfranco number: ' + currentMax);
            }
            else if(projectName == 'Trussardi Residences 2 Offices') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                invoice.Invoice_Number_To_Process_T2_Offices__c = currentMax;
                if(invoice.Unit__r != null && invoice.Unit__r.Type__c == 'Retail') {
                    invoice.Invoice_Number__c = 'INV-TR2-Retail-' + String.valueOf(currentMax);
                } else {
                    invoice.Invoice_Number__c = 'INV-TR2-Office-' + String.valueOf(currentMax);
                }
                System.debug('Assigned Trussardi Residences 2 Offices number: ' + currentMax);
            }
            else if(projectName == 'Trussardi Residences MIRA VERDE') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                invoice.Invoice_Number_To_Process_MIRA_VERDE__c = currentMax;
                invoice.Invoice_Number__c = 'INV-MIRA-VERDE-' + String.valueOf(currentMax);
                System.debug('Assigned MIRA VERDE number: ' + currentMax);
            }
            else if(projectName == 'John Richmond Residences') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                invoice.Invoice_Number_To_Process_Richmond__c = currentMax;
                invoice.Invoice_Number__c = 'INV-JRD-T1-' + String.valueOf(currentMax);
                System.debug('Assigned John Richmond number: ' + currentMax);
            }
            else {
                System.debug('Unknown project name: ' + projectName);
            }
        }
    }
}