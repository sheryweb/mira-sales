public without sharing class InvoiceDetailsController {
    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> getInvoiceDetails(List<String> invoiceIds) {
        FinancialEngine.requireEnabled();
        try {
            System.debug('Received invoice IDs: ' + invoiceIds);
            
            if (invoiceIds == null || invoiceIds.isEmpty()) {
                System.debug('No invoice IDs provided');
                return new List<Invoice__c>();
            }

            // Convert to valid Salesforce IDs
            List<Id> sfIds = new List<Id>();
            for(String idValue : invoiceIds) {
                try {
                    if (String.isNotBlank(idValue)) {
                        // Clean up the ID value
                        idValue = idValue.trim();
                        if (idValue.startsWith('"') && idValue.endsWith('"')) {
                            idValue = idValue.substring(1, idValue.length() - 1);
                        }
                        
                        // Try to convert to a valid SF ID
                        Id sfId = Id.valueOf(idValue);
                        sfIds.add(sfId);
                    }
                } catch(Exception e) {
                    System.debug('Invalid ID format: ' + idValue + ' Error: ' + e.getMessage());
                    // Continue with the next ID
                }
            }
            
            if(sfIds.isEmpty()) {
                System.debug('No valid Salesforce IDs found');
                return new List<Invoice__c>();
            }
            
            System.debug('Valid Salesforce IDs: ' + sfIds);
            
            List<Invoice__c> invoices = [
                SELECT Id, Name, Invoice_Number__c, Invoice_Date__c, Paid_Amount__c, Pending_Amount__c, Sub_Total_Amount__c, 
                 Account__r.Name, Unit__r.Project_Name_Text__c, Unit__r.Building__c,
                    Unit__r.Title__c, Due_Date__c, Description__c
                FROM Invoice__c
                WHERE Id IN :sfIds
            ];
            
            System.debug('Found ' + invoices.size() + ' invoices');
            return invoices;
            
        } catch (Exception e) {
            System.debug('Error in getInvoiceDetails: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
            return new List<Invoice__c>();
        }
    }
}