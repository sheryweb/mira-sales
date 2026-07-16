public class ReceiptTriggerHelper {
    @TestVisible private static Boolean skipTrigger = false;
    
    public static void handleVoucherNumberAssignment(List<Receipt__c> newReceipts) {
        System.debug('ReceiptTriggerHelper.handleVoucherNumberAssignment called with ' + newReceipts.size() + ' receipts');
        System.debug('skipTrigger value: ' + skipTrigger);
        
        if(skipTrigger) {
            System.debug('Skipping trigger due to skipTrigger flag');
            return;
        }
        
        // First get all Unit IDs to query their project names
        Set<Id> unitIds = new Set<Id>();
        for(Receipt__c rec : newReceipts) {
            if(rec.Unit__c != null) {
                unitIds.add(rec.Unit__c);
            }
        }
        
        System.debug('Unit IDs found: ' + unitIds.size());
        
        // If no valid units, return early
        if(unitIds.isEmpty()) {
            System.debug('No valid units found, returning early');
            // Reset any static variables that might be persisting between calls
            return;
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
        
        // Query for existing receipts to get max numbers for each project
        List<Receipt__c> existingReceipts = [
            SELECT Unit__r.Project_Name_F__c, 
                   Voucher_Number_To_Process_Trussardi__c,
                   Voucher_Number_To_Process_Trussardi2__c,
                   Voucher_Number_To_Process_Bentley__c,
                   Voucher_Number_To_Process_POST__c,
                   Voucher_Number_To_Process_Gianfranco__c,
                   Voucher_Number_To_Process_T2_Offices__c,
                   Voucher_Number_To_Process_MIRA_VERDE__c,
                   Voucher_Number_To_Process_Richmond__c
            FROM Receipt__c 
            WHERE Unit__r.Project_Name_F__c IN :projectNames
            AND (Voucher_Number_To_Process_Trussardi__c != null 
                 OR Voucher_Number_To_Process_Trussardi2__c != null 
                 OR Voucher_Number_To_Process_Bentley__c != null
                 OR Voucher_Number_To_Process_POST__c != null
                 OR Voucher_Number_To_Process_Gianfranco__c != null
                 OR Voucher_Number_To_Process_T2_Offices__c != null
                 OR Voucher_Number_To_Process_MIRA_VERDE__c != null
                 OR Voucher_Number_To_Process_Richmond__c != null)
            ORDER BY CreatedDate DESC, Voucher_Number_To_Process_Trussardi__c DESC,
                     Voucher_Number_To_Process_Trussardi2__c DESC,
                     Voucher_Number_To_Process_Bentley__c DESC,
                     Voucher_Number_To_Process_POST__c DESC,
                     Voucher_Number_To_Process_Gianfranco__c DESC,
                     Voucher_Number_To_Process_T2_Offices__c DESC,
                     Voucher_Number_To_Process_MIRA_VERDE__c DESC,
                     Voucher_Number_To_Process_Richmond__c DESC
        ];
        
        System.debug('Existing receipts found: ' + existingReceipts);
        
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
        // Get the maximum numbers from existing receipts
        for(Receipt__c rec : existingReceipts) {
            String projectName = rec.Unit__r.Project_Name_F__c;
            if(projectName == 'Trussardi Residences' && rec.Voucher_Number_To_Process_Trussardi__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), rec.Voucher_Number_To_Process_Trussardi__c));
            }
            else if(projectName == 'Trussardi Residences 2' && rec.Voucher_Number_To_Process_Trussardi2__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), rec.Voucher_Number_To_Process_Trussardi2__c));
            }
            else if(projectName == 'MIRA Villas Designed by Bentley Home' && rec.Voucher_Number_To_Process_Bentley__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), rec.Voucher_Number_To_Process_Bentley__c));
            }
            else if(projectName == 'POST HOTEL & RESIDENCES By ELIE SAAB' && rec.Voucher_Number_To_Process_POST__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), rec.Voucher_Number_To_Process_POST__c));
            }
            else if(projectName == 'GIANFRANCO FERRE RESIDENCES' && rec.Voucher_Number_To_Process_Gianfranco__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), rec.Voucher_Number_To_Process_Gianfranco__c));
            }
            else if(projectName == 'Trussardi Residences 2 Offices' && rec.Voucher_Number_To_Process_T2_Offices__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), rec.Voucher_Number_To_Process_T2_Offices__c));
            }
            else if(projectName == 'Trussardi Residences MIRA VERDE' && rec.Voucher_Number_To_Process_MIRA_VERDE__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), rec.Voucher_Number_To_Process_MIRA_VERDE__c));
            }
            else if(projectName == 'John Richmond Residences' && rec.Voucher_Number_To_Process_Richmond__c != null) {
                maxNumbersByProject.put(projectName, 
                    Math.max(maxNumbersByProject.get(projectName), rec.Voucher_Number_To_Process_Richmond__c));
            }
        }
        
        System.debug('Max numbers by project: ' + maxNumbersByProject);
        
        // Process new receipts
        for(Receipt__c receipt : newReceipts) {
            if(receipt.Unit__c == null || !unitsMap.containsKey(receipt.Unit__c)) {
                System.debug('Skipping receipt due to missing Unit: ' + receipt);
                continue; // Skip to next receipt without assigning any numbers
            }
            
            String projectName = unitsMap.get(receipt.Unit__c).Project_Name_F__c;
            if(projectName == null) {
                System.debug('Skipping receipt due to null project name');
                continue; // Skip to next receipt without assigning any numbers
            }
            
            System.debug('Processing receipt for project: ' + projectName);
            
            if(projectName == 'Trussardi Residences') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                receipt.Voucher_Number_To_Process_Trussardi__c = currentMax;
                System.debug('Assigned Trussardi number: ' + currentMax);
            }
            else if(projectName == 'Trussardi Residences 2') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                receipt.Voucher_Number_To_Process_Trussardi2__c = currentMax;
                System.debug('Assigned Trussardi 2 number: ' + currentMax);
            }
            else if(projectName == 'MIRA Villas Designed by Bentley Home') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                receipt.Voucher_Number_To_Process_Bentley__c = currentMax;
                System.debug('Assigned Bentley number: ' + currentMax);
            }
            else if(projectName == 'POST HOTEL & RESIDENCES By ELIE SAAB') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                receipt.Voucher_Number_To_Process_POST__c = currentMax;
                System.debug('Assigned POST number: ' + currentMax);
            }
            else if(projectName == 'GIANFRANCO FERRE RESIDENCES') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                receipt.Voucher_Number_To_Process_Gianfranco__c = currentMax;
                System.debug('Assigned Gianfranco number: ' + currentMax);
            }
            else if(projectName == 'Trussardi Residences 2 Offices') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                receipt.Voucher_Number_To_Process_T2_Offices__c = currentMax;
                System.debug('Assigned T2 Offices number: ' + currentMax);
            }
            else if(projectName == 'Trussardi Residences MIRA VERDE') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                receipt.Voucher_Number_To_Process_MIRA_VERDE__c = currentMax;
                System.debug('Assigned MIRA VERDE number: ' + currentMax);
            }
            else if(projectName == 'John Richmond Residences') {
                Decimal currentMax = maxNumbersByProject.get(projectName);
                currentMax++;
                maxNumbersByProject.put(projectName, currentMax);
                receipt.Voucher_Number_To_Process_Richmond__c = currentMax;
                System.debug('Assigned John Richmond number: ' + currentMax);
            }
            else {
                System.debug('Unknown project name: ' + projectName);
            }
        }
    }
}