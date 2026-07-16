public class InvoicePDFController {
    public Invoice__c invoice { get; private set; }
    public List<LineItemWrapper> lineItems { get; private set; }
    public String totalInWords { get; private set; }
    private Decimal calculatedTotalVat;
    private Decimal calculatedGrandTotal;
    private Boolean hasExcludedVatMilestones;
    public String secondaryCurrencyInWords { get; private set; }
    public String formattedInvoiceDate { get; private set; }
    public Unit__c unitRecord { get; private set; }
    public Financial_Detail__c financialDetail { get; private set; }
    public String jointOwnerNames { get; private set; }
    public String jointOwnerCustomerIds { get; private set; }
    public String fullCustomerName { get; private set; }
    public String fullCustomerId { get; private set; }
    
    // Wrapper class to include serial number with line items
    public class LineItemWrapper {
        public Integer serialNumber { get; set; }
        public Milestone_Invoice__c item { get; set; }
        public String formattedAmount { get; set; }
        public String vatPercentDisplay { get; set; }
        public String formattedVatAmount { get; set; }
        public String formattedAmountInclVat { get; set; }
        
        public LineItemWrapper(Integer sNo, Milestone_Invoice__c mItem, String fAmount, String vatPct, String vatAmt, String amtInclVat) {
            this.serialNumber = sNo;
            this.item = mItem;
            this.formattedAmount = fAmount;
            this.vatPercentDisplay = vatPct;
            this.formattedVatAmount = vatAmt;
            this.formattedAmountInclVat = amtInclVat;
        }
    }
    
    public InvoicePDFController() {
        try {
            // Get the Invoice Id from the page parameters
            String invoiceId = ApexPages.currentPage().getParameters().get('id');
            if (String.isBlank(invoiceId)) {
                throw new InvoicePDFException('Invoice ID is required.');
            }

            // Fetch Invoice record with related fields
            invoice = [
                SELECT Id, Name, Invoice_Date__c, Invoice_Number__c, Customer_Id__c, Customer_Name__c, Paid_Amount__c,
                       Sub_Total_Amount__c, VAT_Amount__c, Grand_Total_Formula__c,
                       Secondary_Currency__c, Secondary_Currency_Amount__c,
                       Unit__c, Unit__r.Project_Name_Text__c, Unit__r.Cost_AED__c, Unit__r.Cost_CHF__c, Unit__r.Cost_USD__c,
                       Unit__r.Property_Code_Text__c, Unit__r.Title__c, Unit__r.Building__c, Financial_Detail__c,
                       Opportunity__c
                FROM Invoice__c
                WHERE Id = :invoiceId
                LIMIT 1
            ];

            // Format Invoice Date
            if (invoice.Invoice_Date__c != null) {
                Datetime dt = Datetime.newInstance(invoice.Invoice_Date__c, Time.newInstance(0, 0, 0, 0));
                formattedInvoiceDate = dt.format('dd-MM-yyyy');
            }

            // Fetch Financial Detail if available
            if (invoice.Financial_Detail__c != null) {
                financialDetail = [
                    SELECT Id, Name, Account_Name__c, Account_Number__c, 
                           IBAN__c, Swift_Code__c, Branch_Name__c
                    FROM Financial_Detail__c
                    WHERE Id = :invoice.Financial_Detail__c
                    LIMIT 1
                ];
            }

            // Fetch Line Items (Milestone Invoices)
            List<Milestone_Invoice__c> rawLineItems = [
                SELECT Id, Name, Amount__c, VAT_Amount__c, Total_with_VAT__c
                FROM Milestone_Invoice__c
                WHERE Invoice__c = :invoiceId
                ORDER BY Name ASC
            ];

            // Create wrapper list with serial numbers and calculate Total VAT / Grand Total from line items
            lineItems = new List<LineItemWrapper>();
            calculatedTotalVat = 0;
            Integer serialNo = 1;
            Set<String> noVatMilestones = new Set<String>{ 'Oqood', 'DLD Fee', 'Registration Fee' };
            hasExcludedVatMilestones = false;
            for(Milestone_Invoice__c item : rawLineItems) {
                Boolean excludeVat = noVatMilestones.contains(item.Name);
                if (excludeVat) hasExcludedVatMilestones = true;
                Boolean hasVat = !excludeVat && (item.VAT_Amount__c != null && item.VAT_Amount__c != 0);
                String vatPct = hasVat ? '5%' : '0%';
                String vatAmt = hasVat ? formatAmount(item.VAT_Amount__c) : '0.00';
                String amtInclVat = hasVat ? formatAmount(item.Total_with_VAT__c) : formatAmount(item.Amount__c);
                lineItems.add(new LineItemWrapper(
                    serialNo,
                    item,
                    formatAmount(item.Amount__c),
                    vatPct,
                    vatAmt,
                    amtInclVat
                ));
                if (!excludeVat && item.VAT_Amount__c != null) calculatedTotalVat += item.VAT_Amount__c;
                serialNo++;
            }
            Decimal subTotal = (invoice.Sub_Total_Amount__c != null) ? invoice.Sub_Total_Amount__c : 0;
            calculatedGrandTotal = subTotal + (calculatedTotalVat != null ? calculatedTotalVat : 0) - (invoice.Paid_Amount__c != null ? invoice.Paid_Amount__c : 0);

            // Calculate totals and format amounts
            calculateTotals();
            
            // Calculate secondary currency in words if available
            if (invoice.Secondary_Currency_Amount__c != null && invoice.Secondary_Currency_Amount__c > 0) {
                calculateSecondaryCurrencyInWords();
            }
            
            // Fetch joint owners if opportunity exists
            if (invoice.Opportunity__c != null) {
                fetchJointOwners();
            }
            
            // Set full customer name and ID
            setFullCustomerInfo();
            
        } catch (InvoicePDFException e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error loading invoice: ' + e.getMessage()
            ));
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error loading invoice: ' + e.getMessage()
            ));
        }
    }

    private void calculateSecondaryCurrencyInWords() {
        if (invoice == null || invoice.Secondary_Currency_Amount__c == null) return;
        
        String currencyName = '';
        if (invoice.Secondary_Currency__c == 'USD') {
            currencyName = 'US Dollars';
        } else if (invoice.Secondary_Currency__c == 'EUR' || invoice.Secondary_Currency__c == 'EURO') {
            currencyName = 'Euros';
        } else if (invoice.Secondary_Currency__c == 'GBP') {
            currencyName = 'Pounds Sterling';
        } else {
            currencyName = invoice.Secondary_Currency__c != null ? invoice.Secondary_Currency__c : '';
        }
        
        secondaryCurrencyInWords = numberToWords(invoice.Secondary_Currency_Amount__c) + ' ' + currencyName + ' Only';
    }

    private void fetchJointOwners() {
        try {
            // Fetch joint owners for the opportunity
            List<Joint_Owners__c> jointOwners = [
                SELECT Id, Account__c, Account__r.Name, Account__r.Financial_Number__c
                FROM Joint_Owners__c
                WHERE Opportunity__c = :invoice.Opportunity__c
                ORDER BY Order__c ASC NULLS LAST, CreatedDate ASC
            ];
            
            if (!jointOwners.isEmpty()) {
                List<String> ownerNames = new List<String>();
                List<String> customerIds = new List<String>();
                
                for (Joint_Owners__c jointOwner : jointOwners) {
                    if (jointOwner.Account__r != null) {
                        if (String.isNotBlank(jointOwner.Account__r.Name)) {
                            ownerNames.add(jointOwner.Account__r.Name);
                        }
                        if (String.isNotBlank(jointOwner.Account__r.Financial_Number__c)) {
                            customerIds.add(jointOwner.Account__r.Financial_Number__c);
                        }
                    }
                }
                
                // Join names with " & " separator, IDs with ", " separator
                jointOwnerNames = String.join(ownerNames, ' & ');
                jointOwnerCustomerIds = String.join(customerIds, ', ');
            } else {
                jointOwnerNames = '';
                jointOwnerCustomerIds = '';
            }
        } catch (Exception e) {
            System.debug('Error fetching joint owners: ' + e.getMessage());
            jointOwnerNames = '';
            jointOwnerCustomerIds = '';
        }
    }

    private void setFullCustomerInfo() {
        // Set full customer name
        if (String.isNotBlank(jointOwnerNames)) {
            fullCustomerName = invoice.Customer_Name__c + ' & ' + jointOwnerNames;
        } else {
            fullCustomerName = invoice.Customer_Name__c;
        }
        
        // Set full customer ID
        if (String.isNotBlank(jointOwnerCustomerIds)) {
            fullCustomerId = invoice.Customer_Id__c + ', ' + jointOwnerCustomerIds;
        } else {
            fullCustomerId = invoice.Customer_Id__c;
        }
    }

    private void calculateTotals() {
        if (invoice != null) {
            Decimal grandTotal = getEffectiveGrandTotal();
            if (grandTotal != null) {
                totalInWords = numberToWords(grandTotal) + (invoice.Unit__r.Project_Name_Text__c == 'POST HOTEL & RESIDENCES By ELIE SAAB' ? ' CHF Only' : ' AED Only');
            } else {
                totalInWords = '';
            }
        }
    }

    private Decimal getEffectiveSubTotal() {
        if (invoice.Sub_Total_Amount__c != null) return invoice.Sub_Total_Amount__c;
        return 0;
    }

    private Decimal getEffectiveVat() {
        return (lineItems != null && !lineItems.isEmpty() && calculatedTotalVat != null && calculatedTotalVat > 0)
            ? calculatedTotalVat
            : invoice.VAT_Amount__c;
    }

    private Decimal getEffectivePaid() {
        return invoice.Paid_Amount__c != null ? invoice.Paid_Amount__c : 0;
    }

    // Grand Total = Sub Total + VAT - Paid Amount
    private Decimal getEffectiveGrandTotal() {
        return getEffectiveSubTotal() + (getEffectiveVat() != null ? getEffectiveVat() : 0) - getEffectivePaid();
    }

    // Getter methods for formatted amounts
    public String getFormattedPaidAmount() {
        return formatAmount(invoice.Paid_Amount__c);
    }

    public String getFormattedSubTotal() {
        return formatAmount(getEffectiveSubTotal());
    }

    public String getFormattedVATAmount() {
        return formatAmount(getEffectiveVat());
    }

    public String getFormattedGrandTotal() {
        return formatAmount(getEffectiveGrandTotal());
    }

    public String getFormattedSalePrice() {
        String projectName = invoice.Unit__r.Project_Name_Text__c;
        if (projectName == 'POST HOTEL & RESIDENCES By ELIE SAAB') {
            return formatAmount(invoice.Unit__r.Cost_CHF__c);
        } else if (projectName == 'Trussardi Residences MIRA VERDE') {
            return formatAmount(invoice.Unit__r.Cost_USD__c);
        } else {
            return formatAmount(invoice.Unit__r.Cost_AED__c);
        }
    }

    // Builds the full "Sale Price" display string. For Trussardi (USD) we also show the
    // AED equivalent in parentheses, e.g. "1,000.00 USD (3,670.00 AED)".
    public String getSalePriceDisplay() {
        String projectName = invoice.Unit__r.Project_Name_Text__c;
        if (projectName == 'Trussardi Residences MIRA VERDE') {
            return formatAmount(invoice.Unit__r.Cost_USD__c) + ' USD ('
                + formatAmount(invoice.Unit__r.Cost_AED__c) + ' AED)';
        }
        return getCurrencySymbol() + ' ' + getFormattedSalePrice();
    }
    
    public String getFormattedSecondaryCurrencyAmount() {
        return formatAmount(invoice.Secondary_Currency_Amount__c);
    }
    
    // Secondary currency getters
    public Boolean getHasSecondaryCurrency() {
        return invoice.Secondary_Currency_Amount__c != null && invoice.Secondary_Currency_Amount__c > 0;
    }
    
    public String getSecondaryCurrencyType() {
        return invoice.Secondary_Currency__c;
    }

    public String getCurrencySymbol() {
        String projectName = invoice.Unit__r.Project_Name_Text__c;
        if (projectName == null) return '';
        
        if (projectName == 'POST HOTEL & RESIDENCES By ELIE SAAB') {
            return 'CHF';
        } else if (projectName == 'Trussardi Residences MIRA VERDE') {
            return 'USD';
        } else {
            return 'AED';
        }
    }
    
    public String getSecondaryCurrencySymbol() {
        String currencyCode = invoice.Secondary_Currency__c;
        if (currencyCode == null) return '';
        
        if (currencyCode == 'USD') {
            return '$';
        } else if (currencyCode == 'EUR' || currencyCode == 'EURO') {
            return '€';
        } else if (currencyCode == 'GBP') {
            return '£';
        } else if (currencyCode == 'AED') {
            return 'AED';
        } else {
            return '';
        }
    }
    
    // Bank detail getters with fallbacks
    public String getBankName() {
        return financialDetail != null ? financialDetail.Name : '________';
    }
    
    public String getAccountName() {
        return financialDetail != null ? financialDetail.Account_Name__c : '________';
    }
    
    public String getAccountNumber() {
        return financialDetail != null ? financialDetail.Account_Number__c : '________';
    }
    
    public String getIBAN() {
        return financialDetail != null ? financialDetail.IBAN__c : '________';
    }
    
    public String getSwiftCode() {
        return financialDetail != null ? financialDetail.Swift_Code__c : '________';
    }
    
    public String getBranchName() {
        return financialDetail != null ? financialDetail.Branch_Name__c : '';
    }

    // Helper method to format currency amounts
    private String formatAmount(Decimal amount) {
        if (amount == null) return '0.00';
        String formattedAmount = amount.setScale(2).format();
        // Ensure two decimal places are always shown
        if (!formattedAmount.contains('.')) {
            formattedAmount += '.00';
        } else if (formattedAmount.endsWith('.')) {
            formattedAmount += '00';
        } else if (formattedAmount.split('\\.')[1].length() == 1) {
            formattedAmount += '0';
        }
        return formattedAmount;
    }

    // Helper method to convert numbers to words
    private String numberToWords(Decimal amt) {
        if (amt == null) return '';
        if (amt == 0) return 'Zero';
        
        String[] ones = new String[] {'', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'};
        String[] tens = new String[] {'', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'};
        String[] teens = new String[] {'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'};
        
        Integer wholeNumber = amt.intValue();
        Integer decimalPart = ((amt - wholeNumber) * 100).intValue();
        
        String result = '';
        
        // Handle millions
        if (wholeNumber >= 1000000) {
            result += numberToWords(wholeNumber / 1000000) + ' Million ';
            wholeNumber = Math.mod(wholeNumber, 1000000);
        }
        
        // Handle thousands
        if (wholeNumber >= 1000) {
            result += numberToWords(wholeNumber / 1000) + ' Thousand ';
            wholeNumber = Math.mod(wholeNumber, 1000);
        }
        
        // Handle hundreds
        if (wholeNumber >= 100) {
            result += ones[wholeNumber / 100] + ' Hundred ';
            wholeNumber = Math.mod(wholeNumber, 100);
        }
        
        // Handle tens and ones
        if (wholeNumber >= 20) {
            result += tens[wholeNumber / 10] + ' ';
            wholeNumber = Math.mod(wholeNumber, 10);
            if (wholeNumber > 0) {
                result += ones[wholeNumber] + ' ';
            }
        } else if (wholeNumber >= 10) {
            result += teens[wholeNumber - 10] + ' ';
        } else if (wholeNumber > 0) {
            result += ones[wholeNumber] + ' ';
        }
        
        // Add decimal part if exists
        if (decimalPart > 0) {
            result += 'Point ';
            if (decimalPart >= 10) {
                result += numberToWords(decimalPart) + ' ';
            } else {
                result += 'Zero ' + numberToWords(decimalPart) + ' ';
            }
        }
        
        return result.trim();
    }

    // Custom exception class for Invoice PDF
    public class InvoicePDFException extends Exception {}
}