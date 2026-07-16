public class InvoiceCommissionPDFController {
    public Invoice__c invoice { get; private set; }
    public String formattedInvoiceDate { get; private set; }
    public Financial_Detail__c financialDetail { get; private set; }
    public String agencyName { get; private set; }
    public String agencyRegistrationNumber { get; private set; }
    public String agencyTRN { get; private set; }
    public Boolean isVatRegistered { get; private set; }
    public String lineItemDescription { get; private set; }

    private Commission__c linkedCommission;
    private static final Decimal VAT_RATE = 0.05;

    public InvoiceCommissionPDFController() {
        try {
            String invoiceId = ApexPages.currentPage().getParameters().get('id');
            if (String.isBlank(invoiceId)) {
                throw new InvoiceCommissionPDFException('Invoice ID is required.');
            }

            invoice = [
                SELECT Id, Name, Invoice_Date__c, Invoice_Number__c, Paid_Amount__c,
                       Sub_Total_Amount__c, VAT_Amount__c,
                       Account__c, Account__r.Name, Account__r.Registration_Number__c, Account__r.VAT_TRN__c, Account__r.TRN_Number__c,
                       Unit__c, Unit__r.Project_Name_Text__c, Unit__r.Cost_AED__c, Unit__r.Cost_CHF__c,
                       Unit__r.Property_Code_Text__c, Unit__r.Title__c, Unit__r.Building__c,
                       Financial_Detail__c, Type__c
                FROM Invoice__c
                WHERE Id = :invoiceId
                LIMIT 1
            ];

            if (invoice.Invoice_Date__c != null) {
                Datetime dt = Datetime.newInstance(invoice.Invoice_Date__c, Time.newInstance(0, 0, 0, 0));
                formattedInvoiceDate = dt.format('dd-MM-yyyy');
            }

            if (invoice.Account__r != null) {
                agencyName = invoice.Account__r.Name;
                agencyRegistrationNumber = invoice.Account__r.Registration_Number__c;
                agencyTRN = invoice.Account__r.TRN_Number__c;
            }

            isVatRegistered = (
                invoice.Account__r != null
                && invoice.Account__r.VAT_TRN__c != null
                && invoice.Account__r.VAT_TRN__c.equalsIgnoreCase('Yes')
            );

            loadLinkedCommission();
            loadFinancialDetail();
        } catch (InvoiceCommissionPDFException e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error loading commission invoice: ' + e.getMessage()
            ));
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error loading commission invoice: ' + e.getMessage()
            ));
        }
    }

    private void loadLinkedCommission() {
        List<Commission__c> linkedCommissions = [
            SELECT Description__c, VAT_Amount__c, Total_Commission_Amount__c
            FROM Commission__c
            WHERE Invoice__c = :invoice.Id
            LIMIT 1
        ];
        if (!linkedCommissions.isEmpty()) {
            linkedCommission = linkedCommissions[0];
            if (String.isNotBlank(linkedCommission.Description__c)) {
                lineItemDescription = linkedCommission.Description__c;
            } else {
                lineItemDescription = 'Sales Commission';
            }
        } else {
            lineItemDescription = 'Sales Commission';
        }
    }

    private void loadFinancialDetail() {
        if (invoice.Financial_Detail__c != null) {
            financialDetail = [
                SELECT Id, Name, Account_Name__c, Account_Number__c,
                       IBAN__c, Swift_Code__c, Branch_Name__c
                FROM Financial_Detail__c
                WHERE Id = :invoice.Financial_Detail__c
                LIMIT 1
            ];
        }
    }

    private String getCurrencySuffix() {
        return (invoice.Unit__r != null
            && invoice.Unit__r.Project_Name_Text__c == 'POST HOTEL & RESIDENCES By ELIE SAAB')
            ? ' CHF Only' : ' AED Only';
    }

    private Decimal getEffectiveSubTotal() {
        return (invoice.Sub_Total_Amount__c != null) ? invoice.Sub_Total_Amount__c : 0;
    }

    private Decimal getEffectiveVat() {
        if (linkedCommission != null && linkedCommission.VAT_Amount__c != null) {
            return linkedCommission.VAT_Amount__c;
        }
        if (isVatRegistered != true) return 0;
        return getEffectiveSubTotal() * VAT_RATE;
    }

    private Decimal getEffectiveGrandTotal() {
        // Grand Total is the full invoice amount (Sub Total + VAT), not the remaining balance.
        // Paid Amount is shown separately on the PDF when applicable.
        if (linkedCommission != null && linkedCommission.Total_Commission_Amount__c != null) {
            return linkedCommission.Total_Commission_Amount__c;
        }
        return getEffectiveSubTotal() + getEffectiveVat();
    }

    public String getFormattedSubTotal() { return formatAmount(getEffectiveSubTotal()); }
    public String getFormattedVATAmount() { return formatAmount(getEffectiveVat()); }
    public String getFormattedGrandTotal() { return formatAmount(getEffectiveGrandTotal()); }
    public String getTotalInWords() {
        if (invoice == null) return '';
        return numberToWords(getEffectiveGrandTotal()) + getCurrencySuffix();
    }
    public String getFormattedPaidAmount() { return formatAmount(invoice.Paid_Amount__c); }
    public String getFormattedAmountInclVat() { return formatAmount(getEffectiveSubTotal() + getEffectiveVat()); }
    public String getVatPercentDisplay() { return isVatRegistered == true ? '5%' : '0%'; }

    public String getFormattedSalePrice() {
        if (invoice.Unit__r == null) return '';
        return formatAmount(invoice.Unit__r.Project_Name_Text__c == 'POST HOTEL & RESIDENCES By ELIE SAAB'
            ? invoice.Unit__r.Cost_CHF__c
            : invoice.Unit__r.Cost_AED__c);
    }

    public String getCurrencySymbol() {
        if (invoice.Unit__r == null) return 'AED';
        String projectName = invoice.Unit__r.Project_Name_Text__c;
        return (projectName == 'POST HOTEL & RESIDENCES By ELIE SAAB') ? 'CHF' : 'AED';
    }

    public String getBankName() { return financialDetail != null ? financialDetail.Name : '________'; }
    public String getAccountName() { return financialDetail != null ? financialDetail.Account_Name__c : '________'; }
    public String getAccountNumber() { return financialDetail != null ? financialDetail.Account_Number__c : '________'; }
    public String getIBAN() { return financialDetail != null ? financialDetail.IBAN__c : '________'; }
    public String getSwiftCode() { return financialDetail != null ? financialDetail.Swift_Code__c : '________'; }
    public String getBranchName() { return financialDetail != null ? financialDetail.Branch_Name__c : ''; }

    private String formatAmount(Decimal amount) {
        if (amount == null) return '0.00';
        String formattedAmount = amount.setScale(2).format();
        if (!formattedAmount.contains('.')) {
            formattedAmount += '.00';
        } else if (formattedAmount.endsWith('.')) {
            formattedAmount += '00';
        } else if (formattedAmount.split('\\.')[1].length() == 1) {
            formattedAmount += '0';
        }
        return formattedAmount;
    }

    private String numberToWords(Decimal amt) {
        if (amt == null) return '';
        if (amt == 0) return 'Zero';
        if (amt < 0) return 'Minus ' + numberToWords(Math.abs(amt));

        String[] ones = new String[] {'', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'};
        String[] tens = new String[] {'', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'};
        String[] teens = new String[] {'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'};

        Integer wholeNumber = amt.intValue();
        Integer decimalPart = ((amt - wholeNumber) * 100).intValue();
        String result = '';

        if (wholeNumber >= 1000000) {
            result += numberToWords(wholeNumber / 1000000) + ' Million ';
            wholeNumber = Math.mod(wholeNumber, 1000000);
        }
        if (wholeNumber >= 1000) {
            result += numberToWords(wholeNumber / 1000) + ' Thousand ';
            wholeNumber = Math.mod(wholeNumber, 1000);
        }
        if (wholeNumber >= 100) {
            result += ones[wholeNumber / 100] + ' Hundred ';
            wholeNumber = Math.mod(wholeNumber, 100);
        }
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

    public class InvoiceCommissionPDFException extends Exception {}
}