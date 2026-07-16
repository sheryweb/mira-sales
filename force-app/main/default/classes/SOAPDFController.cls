public without sharing class SOAPDFController {
    // Wrapper for first table row: Cash_Flow__c + Amount (incl. VAT when applicable)
    public class FirstTableRow {
        public Cash_Flow__c cf { get; set; }
        public Decimal amount { get; set; }
    }
    
    // Property and customer details
    public Unit__c propertyDetails {get; private set;}
    public Account customerDetails {get; private set;}
    public Opportunity opp {get; private set;}
    public Decimal totalInstallmentsPaid {get; private set;}
    public Date soaDate {get; private set;}
    public List<Account> jointOwners {get; private set;}
    
    // Cash Flow items for instalments - split into two collections for PDF rendering
    private static final Integer FIRST_TABLE_LIMIT = 26;
    public List<Cash_Flow__c> cashFlowItems {get; private set;} // All items (for calculations)
    public List<Cash_Flow__c> firstTableCashFlowItems {get; private set;} // First 26 records
    public List<Cash_Flow__c> secondTableCashFlowItems {get; private set;} // Records after first 26
    public List<FirstTableRow> firstTableDisplayRows {get; private set;} // First table rows with Amount (incl. VAT when applicable)
    
    // Cash Flow items for property registration/other charges
    public List<Cash_Flow__c> registrationItems {get; private set;}
    
    // Property to expose unitCost for the page
    public Decimal unitCost {get; private set;}
    
    // Constructor
    public SOAPDFController() {
        try {
            // Set SOA date to today
            soaDate = Date.today();
            
            // Get opportunity ID from URL parameter
            String oppId = ApexPages.currentPage().getParameters().get('oppId');
            
            if (String.isBlank(oppId)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Opportunity ID is required'));
                return;
            }
            
            // Load opportunity with related records
            List<Opportunity> opportunities = [
                SELECT Id, AccountId, Unit__c
                FROM Opportunity 
                WHERE Id = :oppId
                LIMIT 1
            ];
            
            if (opportunities.isEmpty()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Opportunity not found'));
                return;
            }
            
            opp = opportunities[0];
            
            // Load property details from Unit__c
            List<Unit__c> units = [
                SELECT Id, Title__c, Project_Name_F__c, Is_VAT_Applicable__c, Building__c, Type__c, Number_of_Bedrooms__c,
                       Cost_AED__c, Cost_CHF__c, Total_VAT_on_Unit__c, Booking_Date_Time__c, Received_Installments_Amount__c
                FROM Unit__c
                WHERE Id = :opp.Unit__c
                LIMIT 1
            ];
            
            if (!units.isEmpty()) {
                propertyDetails = units[0];
                
                // Set the unitCost property
                unitCost = getUnitCost();
                
                // Now fetch cash flow items for this unit
                fetchAllCashFlowItems();
                
                // Fetch registration/other charge items for this unit
                fetchRegistrationItems();
            }
            
            // Load customer details from Account
            List<Account> accounts = [
                SELECT Id, Name, Financial_Number__c
                FROM Account
                WHERE Id = :opp.AccountId
                LIMIT 1
            ];
            
            if (!accounts.isEmpty()) {
                customerDetails = accounts[0];
                
                // Get sum of Received_Amount__c from Receipt__c for this Account
                fetchTotalInstallmentsPaid();
            }
            
            // Load joint owners
            fetchJointOwners();
            
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error: ' + e.getMessage()));
            System.debug('SOAPDFController Error: ' + e.getMessage());
        }
    }
    
    // Helper method to check if the project is POST HOTEL & RESIDENCES By ELIE SAAB
    public Boolean getIsElieSaab() {
        return propertyDetails != null && 
               propertyDetails.Project_Name_F__c == 'POST HOTEL & RESIDENCES By ELIE SAAB';
    }
    
    /** Base purchase cost + unit-level VAT (null-safe). Exposed for tests because Total_VAT_on_Unit__c is often formula/rollup. */
    @TestVisible
    private static Decimal sumBaseCostAndUnitVat(Decimal baseCost, Decimal totalVatOnUnit) {
        Decimal b = baseCost != null ? baseCost : 0;
        Decimal v = totalVatOnUnit != null ? totalVatOnUnit : 0;
        return b + v;
    }
    
    // Helper method to get the appropriate cost field based on project (incl. unit-level VAT when present)
    public Decimal getUnitCost() {
        if (propertyDetails == null) return 0;
        
        if (getIsElieSaab()) {
            return sumBaseCostAndUnitVat(propertyDetails.Cost_CHF__c, propertyDetails.Total_VAT_on_Unit__c);
        }
        return sumBaseCostAndUnitVat(propertyDetails.Cost_AED__c, propertyDetails.Total_VAT_on_Unit__c);
    }
    
    // Helper method to get the appropriate price field from Cash_Flow__c based on project
    private Decimal getCashFlowPrice(Cash_Flow__c cf) {
        if (cf == null) return 0;
        
        if (getIsElieSaab()) {
            return cf.Price_CHF__c != null ? cf.Price_CHF__c : 0;
        } else {
            return cf.Price_Formula__c != null ? cf.Price_Formula__c : 0;
        }
    }
    
    // Helper method to get Amount for first table of Installments: includes VAT when propertyDetails.Is_VAT_Applicable__c is true
    public Decimal getFirstTableInstallmentAmount(Cash_Flow__c cf) {
        if (cf == null) return 0;
        Decimal basePrice = getCashFlowPrice(cf);
        if (propertyDetails != null && propertyDetails.Is_VAT_Applicable__c == true 
            && cf.VAT_Amount__c != null) {
            return basePrice + cf.VAT_Amount__c;
        }
        return basePrice;
    }
    
    // Fetch all cash flow items and split them into two collections
    private void fetchAllCashFlowItems() {
        try {
            // Get all items for calculations
            cashFlowItems = [
                SELECT Id, Name, Payment_Plan_Name__c, Date__c, Installment_Milestone__c, 
                       Price_Formula__c, Price_CHF__c, VAT_Amount__c, Received_Amount__c, Remaining_Amount__c
                FROM Cash_Flow__c
                WHERE Unit__c = :propertyDetails.Id
                AND (NOT Payment_Plan_Name__c LIKE '%Oqood%') 
                AND (NOT Payment_Plan_Name__c LIKE '%DLD Fee%')
                AND (NOT Payment_Plan_Name__c LIKE '%Registration Fee%')
                AND (NOT Payment_Plan_Name__c LIKE '%Purchase Taxes%')
                ORDER BY Date__c ASC
            ];
            
            // Get first table items (limited to 26)
            firstTableCashFlowItems = [
                SELECT Id, Name, Payment_Plan_Name__c, Date__c, Installment_Milestone__c, 
                       Price_Formula__c, Price_CHF__c, VAT_Amount__c, Received_Amount__c, Remaining_Amount__c
                FROM Cash_Flow__c
                WHERE Unit__c = :propertyDetails.Id
                AND (NOT Payment_Plan_Name__c LIKE '%Oqood%') 
                AND (NOT Payment_Plan_Name__c LIKE '%DLD Fee%')
                AND (NOT Payment_Plan_Name__c LIKE '%Registration Fee%')
                AND (NOT Payment_Plan_Name__c LIKE '%Purchase Taxes%')
                ORDER BY Date__c ASC
                LIMIT :FIRST_TABLE_LIMIT
            ];
            
            // Build display rows for first table (Amount incl. VAT when propertyDetails.Is_VAT_Applicable__c is true)
            firstTableDisplayRows = new List<FirstTableRow>();
            for (Cash_Flow__c cf : firstTableCashFlowItems) {
                FirstTableRow row = new FirstTableRow();
                row.cf = cf;
                row.amount = getFirstTableInstallmentAmount(cf);
                firstTableDisplayRows.add(row);
            }
            
            // Calculate how many total records we have
            Integer totalRecords = cashFlowItems.size();
            
            // If we have more than 26 records, fetch the remaining ones
            if (totalRecords > FIRST_TABLE_LIMIT) {
                // Use OFFSET to get records after the first 26
                secondTableCashFlowItems = [
                    SELECT Id, Name, Payment_Plan_Name__c, Date__c, Installment_Milestone__c, 
                           Price_Formula__c, Price_CHF__c, VAT_Amount__c, Received_Amount__c, Remaining_Amount__c
                    FROM Cash_Flow__c
                    WHERE Unit__c = :propertyDetails.Id
                    AND (NOT Payment_Plan_Name__c LIKE '%Oqood%') 
                    AND (NOT Payment_Plan_Name__c LIKE '%DLD Fee%')
                    AND (NOT Payment_Plan_Name__c LIKE '%Registration Fee%')
                    ORDER BY Date__c ASC
                    LIMIT 1000
                    OFFSET :FIRST_TABLE_LIMIT
                ];
            } else {
                // No additional records
                secondTableCashFlowItems = new List<Cash_Flow__c>();
            }
            
            System.debug('Fetched cash flow items: ' + 
                        'First table: ' + firstTableCashFlowItems.size() + 
                        ', Second table: ' + secondTableCashFlowItems.size() + 
                        ', Total: ' + totalRecords);
        } catch (Exception e) {
            // Initialize empty lists to avoid null pointer exceptions
            cashFlowItems = new List<Cash_Flow__c>();
            firstTableCashFlowItems = new List<Cash_Flow__c>();
            secondTableCashFlowItems = new List<Cash_Flow__c>();
            firstTableDisplayRows = new List<FirstTableRow>();
            System.debug('Error fetching cash flow items: ' + e.getMessage());
        }
    }
    
    // Check if we have items for the second table
    public Boolean getHasSecondTableItems() {
        return secondTableCashFlowItems != null && !secondTableCashFlowItems.isEmpty();
    }
    
    // Helper method to get total amount from instalments
    public Decimal getTotalInstalmentAmount() {
        Decimal total = 0;
        if (cashFlowItems != null) {
            for (Cash_Flow__c cf : cashFlowItems) {
                total += getCashFlowPrice(cf);
            }
        }
        return total;
    }
    
    // Total for first table Amount column (incl. VAT when applicable) - used when totals row is under first table only
    public Decimal getTotalFirstTableAmount() {
        Decimal total = 0;
        if (firstTableDisplayRows != null) {
            for (FirstTableRow row : firstTableDisplayRows) {
                total += row.amount != null ? row.amount : 0;
            }
        }
        return total;
    }
    
    // Total Balance for first table (Amount - Received per row, summed)
    public Decimal getTotalFirstTableBalance() {
        Decimal total = 0;
        if (firstTableDisplayRows != null) {
            for (FirstTableRow row : firstTableDisplayRows) {
                Decimal amt = row.amount != null ? row.amount : 0;
                Decimal received = row.cf != null && row.cf.Received_Amount__c != null ? row.cf.Received_Amount__c : 0;
                total += amt - received;
            }
        }
        return total;
    }
    
    // Grand total for installments: first table items with VAT when applicable + second table items without VAT
    public Decimal getTotalInstalmentAmountWithFirstTableVAT() {
        Decimal total = getTotalFirstTableAmount();
        if (secondTableCashFlowItems != null) {
            for (Cash_Flow__c cf : secondTableCashFlowItems) {
                total += getCashFlowPrice(cf);
            }
        }
        return total;
    }
    
    // Grand total Balance: first table calculated balance + second table Remaining_Amount__c
    public Decimal getTotalBalanceWithFirstTableVAT() {
        Decimal total = getTotalFirstTableBalance();
        if (secondTableCashFlowItems != null) {
            for (Cash_Flow__c cf : secondTableCashFlowItems) {
                total += cf.Remaining_Amount__c != null ? cf.Remaining_Amount__c : 0;
            }
        }
        return total;
    }
    
    // Helper method to get total received amount from instalments
    public Decimal getTotalReceivedAmount() {
        Decimal total = 0;
        if (cashFlowItems != null) {
            for (Cash_Flow__c cf : cashFlowItems) {
                if (cf.Received_Amount__c != null) {
                    total += cf.Received_Amount__c;
                }
            }
        }
        return total;
    }
    
    // Helper method to get total balance amount from instalments
    public Decimal getTotalBalanceAmount() {
        Decimal total = 0;
        if (cashFlowItems != null) {
            for (Cash_Flow__c cf : cashFlowItems) {
                if (cf.Remaining_Amount__c != null) {
                    total += cf.Remaining_Amount__c;
                }
            }
        }
        return total;
    }
    
    // Fetch total installments paid from Unit__c
    private void fetchTotalInstallmentsPaid() {
        try {
            // Get the Received_Installments_Amount__c from the Unit__c object
            if (propertyDetails != null && propertyDetails.Received_Installments_Amount__c != null) {
                totalInstallmentsPaid = propertyDetails.Received_Installments_Amount__c;
            } else {
                totalInstallmentsPaid = 0;
            }
        } catch (Exception e) {
            totalInstallmentsPaid = 0;
            System.debug('Error fetching total installments paid: ' + e.getMessage());
        }
    }
    
    // Fetch joint owners from Joint_Owners__c and their Account details
    private void fetchJointOwners() {
        try {
            // Initialize the list
            jointOwners = new List<Account>();
            
            // Get joint owners for this opportunity
            List<Joint_Owners__c> jointOwnerJunctions = [
                SELECT Id, Account__c, Order__c, Ownership_Share__c 
                FROM Joint_Owners__c 
                WHERE Opportunity__c = :opp.Id 
                ORDER BY Order__c ASC
            ];
            
            if (!jointOwnerJunctions.isEmpty()) {
                // Extract Account IDs
                Set<Id> accountIds = new Set<Id>();
                for (Joint_Owners__c jo : jointOwnerJunctions) {
                    if (jo.Account__c != null) {
                        accountIds.add(jo.Account__c);
                    }
                }
                
                // Query account details
                if (!accountIds.isEmpty()) {
                    jointOwners = [
                        SELECT Id, Name, Financial_Number__c
                        FROM Account 
                        WHERE Id IN :accountIds
                    ];
                }
            }
        } catch (Exception e) {
            System.debug('Error fetching joint owners: ' + e.getMessage());
        }
    }
    
    // Check if there are any joint owners
    public Boolean getHasJointOwners() {
        return jointOwners != null && !jointOwners.isEmpty();
    }
    
    // Format currency for display
    public String getFormattedInstallmentsPaid() {
        if (totalInstallmentsPaid == null) return (getIsElieSaab() ? 'CHF ' : 'AED ') + '0.00';
        return (getIsElieSaab() ? 'CHF ' : 'AED ') + String.valueOf(totalInstallmentsPaid.setScale(2).format());
    }
    
    // Calculate percentage paid based on total cost
    public Integer getPercentagePaid() {
        System.debug('totalInstallmentsPaid: ' + totalInstallmentsPaid);
        System.debug('getUnitCost(): ' + getUnitCost());
        
        if (totalInstallmentsPaid == null || totalInstallmentsPaid == 0 
            || getUnitCost() == 0) {
            System.debug('Returning 0 due to null or zero values');
            return 0;
        }
        
        // Ensure we're using Decimal division for precision
        Decimal numerator = totalInstallmentsPaid;
        Decimal denominator = getUnitCost();
        
        System.debug('Numerator (totalInstallmentsPaid): ' + numerator);
        System.debug('Denominator (getUnitCost()): ' + denominator);
        System.debug('Division result: ' + (numerator / denominator));
        
        Decimal percentage = (numerator / denominator) * 100;
        System.debug('Raw percentage calculated: ' + percentage);
        
        // If there's any payment but percentage rounds to 0, return 1% minimum
        if (percentage > 0 && percentage < 1) {
            System.debug('Small percentage detected, returning 1% minimum');
            return 1;
        }
        
        // Round to nearest integer to handle precision issues
        Integer roundedPercentage = Math.round(percentage);
        System.debug('Rounded percentage: ' + roundedPercentage);
        
        return roundedPercentage;
    }
    
    // Check if there are any cash flow items
    public Boolean getHasCashFlowItems() {
        return cashFlowItems != null && !cashFlowItems.isEmpty();
    }
    
    // Fetch registration-related cash flow items for this unit (Oqood, DLD, Booking)
    private void fetchRegistrationItems() {
        try {
            registrationItems = [
                SELECT Id, Name, Payment_Plan_Name__c, Date__c, Installment_Milestone__c, 
                       Price_Formula__c, Price_CHF__c, VAT_Amount__c, Received_Amount__c, Remaining_Amount__c
                FROM Cash_Flow__c
                WHERE Unit__c = :propertyDetails.Id
                AND (Payment_Plan_Name__c LIKE '%Oqood%' 
                     OR Payment_Plan_Name__c LIKE '%DLD Fee%'
                     OR Payment_Plan_Name__c LIKE '%Registration Fee%'
                     OR Payment_Plan_Name__c LIKE '%Purchase Taxes%')
                ORDER BY Date__c ASC
            ];
            
            System.debug('Fetched ' + registrationItems.size() + ' registration items for unit ' + propertyDetails.Id);
        } catch (Exception e) {
            registrationItems = new List<Cash_Flow__c>();
            System.debug('Error fetching registration items: ' + e.getMessage());
        }
    }
    
    // Helper method to get total amount from registration items
    public Decimal getTotalRegistrationAmount() {
        Decimal total = 0;
        if (registrationItems != null) {
            for (Cash_Flow__c cf : registrationItems) {
                total += getCashFlowPrice(cf);
            }
        }
        return total;
    }
    
    // Helper method to get total received amount from registration items
    public Decimal getTotalRegistrationReceivedAmount() {
        Decimal total = 0;
        if (registrationItems != null) {
            for (Cash_Flow__c cf : registrationItems) {
                if (cf.Received_Amount__c != null) {
                    total += cf.Received_Amount__c;
                }
            }
        }
        return total;
    }
    
    // Helper method to get total balance amount from registration items
    public Decimal getTotalRegistrationBalanceAmount() {
        Decimal total = 0;
        if (registrationItems != null) {
            for (Cash_Flow__c cf : registrationItems) {
                if (cf.Remaining_Amount__c != null) {
                    total += cf.Remaining_Amount__c;
                }
            }
        }
        return total;
    }
    
    // Check if there are any registration items
    public Boolean getHasRegistrationItems() {
        return registrationItems != null && !registrationItems.isEmpty();
    }

    // Get total remaining instalment amount for Current Amounts Due Summary
    public Decimal getTotalDueInstalmentsAmount() {
        Decimal total = 0;
        Date today = Date.today();
        
        if (cashFlowItems != null) {
            for (Cash_Flow__c cf : cashFlowItems) {
                // Only include items with dates in the past or today
                if (cf.Date__c != null && cf.Date__c <= today) {
                    if (cf.Remaining_Amount__c != null) {
                        total += cf.Remaining_Amount__c;
                    }
                }
            }
        }
        return total;
    }

    // Format the total due instalments amount for Current Amounts Due Summary
    public String getFormattedTotalDueInstalmentsAmount() {
        Decimal amount = getTotalDueInstalmentsAmount();
        if (amount == null) return (getIsElieSaab() ? 'CHF ' : 'AED ') + '0.00';
        return (getIsElieSaab() ? 'CHF ' : 'AED ') + String.valueOf(amount.setScale(2).format());
    }

    // Get total remaining registration charges amount for Current Amounts Due Summary
    public Decimal getTotalDueRegistrationAmount() {
        Decimal total = 0;
        Date today = Date.today();
        
        if (registrationItems != null) {
            for (Cash_Flow__c cf : registrationItems) {
                // Only include items with dates in the past or today
                if (cf.Date__c != null && cf.Date__c <= today) {
                    if (cf.Remaining_Amount__c != null) {
                        total += cf.Remaining_Amount__c;
                    }
                }
            }
        }
        return total;
    }

    // Format the total due registration amount for Current Amounts Due Summary
    public String getFormattedTotalDueRegistrationAmount() {
        Decimal amount = getTotalDueRegistrationAmount();
        if (amount == null) return (getIsElieSaab() ? 'CHF ' : 'AED ') + '0.00';
        return (getIsElieSaab() ? 'CHF ' : 'AED ') + String.valueOf(amount.setScale(2).format());
    }

    // Get total due amount (sum of registration and instalments)
    public Decimal getTotalDueAmount() {
        Decimal registrationAmount = getTotalDueRegistrationAmount();
        Decimal instalmentsAmount = getTotalDueInstalmentsAmount();
        
        return (registrationAmount != null ? registrationAmount : 0) + 
               (instalmentsAmount != null ? instalmentsAmount : 0);
    }

    // Format the total due amount for Current Amounts Due Summary
    public String getFormattedTotalDueAmount() {
        Decimal amount = getTotalDueAmount();
        if (amount == null) return (getIsElieSaab() ? 'CHF ' : 'AED ') + '0.00';
        return (getIsElieSaab() ? 'CHF ' : 'AED ') + String.valueOf(amount.setScale(2).format());
    }
}