public class ReceiptPDFController {
    public Receipt__c receipt { get; private set; }
    public List<Invoice__c> invoices { get; private set; }
    public List<Map<String, Object>> payments { get; private set; }
    public String jointOwnerNames { get; private set; }
    public String fullCustomerName { get; private set; }
    
    // Map to store receipt amounts for each invoice
    private Map<Id, Decimal> invoiceToReceiptAmountMap;
    
    // Constructor
    public ReceiptPDFController() {
        // Initialize collections to prevent null pointer exceptions
        receipt = new Receipt__c();
        invoices = new List<Invoice__c>();
        payments = new List<Map<String, Object>>();
        invoiceToReceiptAmountMap = new Map<Id, Decimal>();
        
        try {
            // Get receipt ID from page parameters
            String receiptId = ApexPages.currentPage().getParameters().get('id');
            
            // Validate receipt ID
            if (String.isBlank(receiptId)) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR, 
                    'Receipt ID is required. Please provide a valid receipt ID.'
                ));
                return;
            }
            
            // Try to parse the ID to ensure it's a valid Salesforce ID
            Id validReceiptId;
            try {
                validReceiptId = Id.valueOf(receiptId);
                if (validReceiptId.getSObjectType() != Receipt__c.SObjectType) {
                    ApexPages.addMessage(new ApexPages.Message(
                        ApexPages.Severity.ERROR, 
                        'The provided ID is not a valid Receipt ID.'
                    ));
                    return;
                }
            } catch (Exception e) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR, 
                    'Invalid Receipt ID format: ' + receiptId
                ));
                return;
            }
            
            // Load receipt data
            loadReceiptData(validReceiptId);
            
        } catch (Exception e) {
            System.debug('Error in constructor: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 
                'Error initializing PDF: ' + e.getMessage()
            ));
        }
    }
    
    // Load data from the database
    private void loadReceiptData(Id receiptId) {
        try {
            System.debug('Starting loadReceiptData for receipt ID: ' + receiptId);
            
            // Query the receipt record with all needed fields
            List<Receipt__c> receipts = [
                SELECT Id, Name, Receipt_Added_Date__c, Payment_Date__c, Voucher_Number__c, Voucher_Number_Retail__c,
                       Payable_Amount__c, Received_Amount__c, Deposited_To__c,
                       Customer_Name__c, Project_Name__c, Unit_Building__c, Unit_No__c, Unit__r.Type__c, Description__c, Opportunity__c
                FROM Receipt__c 
                WHERE Id = :receiptId
                LIMIT 1
            ];
            
            if (receipts.isEmpty()) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.ERROR, 
                    'Receipt not found with ID: ' + receiptId
                ));
                return;
            }
            
            receipt = receipts[0];
            
            // Query related invoice records through Receipt_Invoice__c
            List<Receipt_Invoice__c> receiptInvoices = [
                SELECT Id, Invoice__c, Amount__c
                FROM Receipt_Invoice__c
                WHERE Receipt__c = :receiptId
            ];
            
            // Extract invoice IDs
            Set<Id> invoiceIds = new Set<Id>();
            for (Receipt_Invoice__c ri : receiptInvoices) {
                if (ri.Invoice__c != null) {
                    invoiceIds.add(ri.Invoice__c);
                }
            }
            
            // Query the invoice details
            if (!invoiceIds.isEmpty()) {
                invoices = [
                    SELECT Id, Name, Invoice_Date__c, Paid_Amount__c, Pending_Amount__c, 
                           Description__c, Invoice_Number__c, VAT_Amount__c, Sub_Total_Amount__c
                    FROM Invoice__c
                    WHERE Id IN :invoiceIds
                ];
            }
            
            // Initialize the map
            invoiceToReceiptAmountMap = new Map<Id, Decimal>();
            
            // MUCH SIMPLER APPROACH: Use Cumulative_Paid_Amount__c directly
            if (!invoiceIds.isEmpty()) {
                // Query Receipt_Amount__c records for the current receipt
                List<Receipt_Amount__c> receiptAmounts = [
                    SELECT Id, Invoice__c, Amount__c, Cumulative_Paid_Amount__c, Receipt__c
                    FROM Receipt_Amount__c
                    WHERE Receipt__c = :receiptId AND Invoice__c IN :invoiceIds
                ];
                
                // Store the cumulative paid amount for each invoice
                for (Receipt_Amount__c ra : receiptAmounts) {
                    if (ra.Invoice__c != null) {
                        // Use Cumulative_Paid_Amount__c if available, otherwise fallback to Amount__c
                        Decimal cumulativeAmount = ra.Cumulative_Paid_Amount__c != null ? 
                                                 ra.Cumulative_Paid_Amount__c : ra.Amount__c;
                        
                        invoiceToReceiptAmountMap.put(ra.Invoice__c, cumulativeAmount);
                        System.debug('Invoice ' + ra.Invoice__c + 
                                    ' Cumulative Paid Amount: ' + cumulativeAmount);
                    }
                }
            }
            
            // Query receipt amount records for the current receipt for display
            List<Receipt_Amount__c> receiptAmounts = [
                SELECT Id, Mode_of_Payment__c, Reference_Number__c, Amount_Text__c,
                       Cheque_Number__c, Cheque_Date__c, Bank_Name__c, POS_Receipt_Number__c,
                       Invoice__c, Amount__c, Receipt__c, Cumulative_Paid_Amount__c,
                       Invoice__r.Invoice_Number__c
                FROM Receipt_Amount__c
                WHERE Receipt__c = :receiptId
            ];
            
            System.debug('Found ' + receiptAmounts.size() + ' receipt amounts');
            
            // Transform payment data for display
            payments.clear();
            for (Receipt_Amount__c ra : receiptAmounts) {
                System.debug('Processing receipt amount: ' + ra);
                System.debug('Invoice__c: ' + ra.Invoice__c);
                System.debug('Invoice__r.Invoice_Number__c: ' + ra.Invoice__r.Invoice_Number__c);
                
                Map<String, Object> payment = new Map<String, Object>{
                    'id' => ra.Id,
                    'Mode_of_Payment__c' => ra.Mode_of_Payment__c != null ? ra.Mode_of_Payment__c : '',
                    'Reference_Number__c' => ra.Reference_Number__c != null ? ra.Reference_Number__c : '',
                    'formattedReceiptAmount' => ra.Amount_Text__c != null
                        ? ra.Amount_Text__c
                        : (ra.Amount__c != null ? ra.Amount__c.setScale(2).format() : ''),
                    'Cheque_Number__c' => ra.Cheque_Number__c != null ? ra.Cheque_Number__c : '',
                    'formattedChequeDate' => formatDate(ra.Cheque_Date__c),
                    'Bank_Name__c' => ra.Bank_Name__c != null ? ra.Bank_Name__c : '',
                    'POS_Receipt_Number__c' => ra.POS_Receipt_Number__c != null ? ra.POS_Receipt_Number__c : '',
                    'isSimplePayment' => isSimplePayment(ra.Mode_of_Payment__c),
                    'isChequePayment' => ra.Mode_of_Payment__c == 'Cheque',
                    'isPOSPayment' => ra.Mode_of_Payment__c == 'POS Machine',
                    'Invoice__c' => ra.Invoice__c,
                    'Invoice_Number__c' => ra.Invoice__r != null ? ra.Invoice__r.Invoice_Number__c : ''
                };
                payments.add(payment);
            }
            
            // Fetch joint owners if opportunity exists
            if (receipt.Opportunity__c != null) {
                fetchJointOwners();
            }
            
            // Set full customer name
            setFullCustomerName();
            
        } catch (Exception e) {
            System.debug('Error in loadReceiptData: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 
                'Error loading receipt data: ' + e.getMessage()
            ));
        }
    }
    
    // Format helpers
    public String formatDate(Date dateValue) {
        if (dateValue == null) return '';
        return dateValue.day() + '-' + dateValue.month() + '-' + dateValue.year();
    }
    
    public String formatAmount(String amount) {
        if (String.isBlank(amount)) return '0.00';
        try {
            Decimal numAmount = Decimal.valueOf(amount);
            // Ensure consistent formatting with two decimal places
            return numAmount.setScale(2).format();
        } catch (Exception e) {
            return '0.00';
        }
    }

    /** Page action: redirect to a notice when the Financial Engine is disabled (blocks direct URL access). */
    public PageReference blockIfDisabled() {
        if (!FinancialEngine.isEngineEnabled()) {
            PageReference ref = Page.FinanceDisabled;
            ref.setRedirect(true);
            return ref;
        }
        return null;
    }

    public String getCurrencySymbol() {
        String projectName = receipt.Project_Name__c;
        if (projectName == null) return '';
        
        if (projectName == 'POST HOTEL & RESIDENCES By ELIE SAAB') {
            return 'CHF';
        } else if (projectName == 'Trussardi Residences MIRA VERDE') {
            return 'USD';
        } else {
            return 'AED';
        }
    }
    
    // Helper methods for payment type determination
    private Boolean isSimplePayment(String paymentMode) {
        if (paymentMode == null) return false;
        return paymentMode == 'Cash' || 
               paymentMode == 'Bank Transfer' || 
               paymentMode == 'Card' || 
               paymentMode == 'Online Payment' ||
               paymentMode == 'Adjustment';
    }
    
    // Calculated fields
    public String getFormattedReceiptDate() {
        return formatDate(receipt.Payment_Date__c);
    }
    
    public String getFormattedReceivedAmount() {
        return formatAmount(String.valueOf(receipt.Received_Amount__c));
    }
    
    public String getAmountInWords() {
        // Convert amount to words
        Decimal amount = receipt.Received_Amount__c != null ? receipt.Received_Amount__c : 0;
        String amountStr = String.valueOf(amount.setScale(2));
        String[] parts = amountStr.split('\\.');
        Integer cents = Integer.valueOf(parts[1]);
        
        String mainUnit;
        String subUnitName;
        if (receipt.Project_Name__c == 'POST HOTEL & RESIDENCES By ELIE SAAB') {
            mainUnit = ' Francs';
            subUnitName = ' Rappens';
        } else if (receipt.Project_Name__c == 'Trussardi Residences MIRA VERDE') {
            mainUnit = ' Dollars';
            subUnitName = ' Cents';
        } else {
            mainUnit = ' Dirhams';
            subUnitName = ' Fils';
        }
        String subUnit = ' and ' + convertNumberToWords(cents) + subUnitName;
        
        String result = convertNumberToWords(amount.intValue()) + mainUnit + (cents > 0 ? subUnit : '') + ' Only';
        return result;
    }
    
    // Invoice helpers
    public List<Map<String, Object>> getFormattedInvoices() {
        List<Map<String, Object>> formattedInvoices = new List<Map<String, Object>>();
        for (Invoice__c inv : invoices) {
            // Get the receipt amount for this invoice from our map
            // This should only show the current receipt's amount
            Decimal receiptAmount = invoiceToReceiptAmountMap.containsKey(inv.Id) ? 
                                   invoiceToReceiptAmountMap.get(inv.Id) : 0;
            
            // Calculate the balance amount as due amount minus paid amount
            Decimal dueAmount = (inv.Sub_Total_Amount__c != null ? inv.Sub_Total_Amount__c : 0) + (inv.VAT_Amount__c != null ? inv.VAT_Amount__c : 0);
            Decimal paidAmount = inv.Paid_Amount__c != null ? inv.Paid_Amount__c : 0;
            Decimal pendingAmount = inv.Pending_Amount__c != null ? inv.Pending_Amount__c : 0;
            //Decimal balanceAmount = dueAmount - receiptAmount;
            
            Map<String, Object> formatted = new Map<String, Object>{
                'Id' => inv.Id,
                'Description__c' => inv.Description__c != null ? inv.Description__c : '',
                'Name' => inv.Name != null ? inv.Name : '',
                'Invoice_Number__c' => inv.Invoice_Number__c != null ? inv.Invoice_Number__c : '',
                'formattedInvoiceDate' => formatDate(inv.Invoice_Date__c),
                'formattedDueAmount' => formatAmount(String.valueOf(dueAmount)),
                'formattedPaidAmount' => formatAmount(String.valueOf(paidAmount)),
                'formattedBalanceAmount' => formatAmount(String.valueOf(pendingAmount))
            };
            formattedInvoices.add(formatted);
        }
        return formattedInvoices;
    }
    
    // Number to words conversion
    private String convertNumberToWords(Decimal amount) {
        if (amount == null || amount == 0) return 'Zero';
        
        String[] ones = new String[]{'', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
            'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'};
        String[] tens = new String[]{'', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'};
        
        // Handle decimal part
        String amountStr = String.valueOf(amount.setScale(2));
        String decimalStr = amountStr.contains('.') ? amountStr.split('\\.')[1] : '00';
        Integer decimalPart = Integer.valueOf(decimalStr);
        
        // Convert whole number part
        Integer whole = amount.intValue();
        
        // Convert to words
        String result = '';
        
        // Handle millions
        if (whole >= 1000000) {
            result += convertLessThanThousand(Math.floor(whole / 1000000).intValue()) + ' Million ';
            whole = Math.mod(whole, 1000000);
        }
        
        // Handle thousands
        if (whole >= 1000) {
            result += convertLessThanThousand(Math.floor(whole / 1000).intValue()) + ' Thousand ';
            whole = Math.mod(whole, 1000);
        }
        
        // Handle hundreds and smaller
        if (whole > 0) {
            result += convertLessThanThousand(whole);
        }
        
        // Add decimal part if needed
        if (decimalPart > 0) {
            result += ' and ' + decimalPart + '/100';
        }
        
        return result.trim();
    }
    
    private String convertLessThanThousand(Integer num) {
        String[] ones = new String[]{'', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
            'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'};
        String[] tens = new String[]{'', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'};
        
        String result = '';
        
        // Handle hundreds
        if (num >= 100) {
            result += ones[Math.floor(num / 100).intValue()] + ' Hundred ';
            num = Math.mod(num, 100);
        }
        
        // Handle tens and ones
        if (num >= 20) {
            result += tens[Math.floor(num / 10).intValue()] + ' ';
            num = Math.mod(num, 10);
        }
        
        if (num > 0) {
            result += ones[num] + ' ';
        }
        
        return result.trim();
    }
    
    private void fetchJointOwners() {
        try {
            // Fetch joint owners for the opportunity
            List<Joint_Owners__c> jointOwners = [
                SELECT Id, Account__c, Account__r.Name
                FROM Joint_Owners__c
                WHERE Opportunity__c = :receipt.Opportunity__c
                ORDER BY Order__c ASC NULLS LAST, CreatedDate ASC
            ];
            
            if (!jointOwners.isEmpty()) {
                List<String> ownerNames = new List<String>();
                
                for (Joint_Owners__c jointOwner : jointOwners) {
                    if (jointOwner.Account__r != null && String.isNotBlank(jointOwner.Account__r.Name)) {
                        ownerNames.add(jointOwner.Account__r.Name);
                    }
                }
                
                // Join names with " & " separator
                jointOwnerNames = String.join(ownerNames, ' & ');
            } else {
                jointOwnerNames = '';
            }
        } catch (Exception e) {
            System.debug('Error fetching joint owners: ' + e.getMessage());
            jointOwnerNames = '';
        }
    }
    
    private void setFullCustomerName() {
        // Set full customer name
        if (String.isNotBlank(jointOwnerNames)) {
            fullCustomerName = receipt.Customer_Name__c + ' & ' + jointOwnerNames;
        } else {
            fullCustomerName = receipt.Customer_Name__c;
        }
    }
}