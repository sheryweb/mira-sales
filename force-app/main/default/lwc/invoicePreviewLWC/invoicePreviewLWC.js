import { LightningElement, api, wire } from 'lwc';
import getFinancialDetail from '@salesforce/apex/InvoicePreviewController.getFinancialDetail';

export default class InvoicePreviewLWC extends LightningElement {
    @api invoicesJson;  // Invoices data passed from Flow
    @api lineItemsJson;  // Line Items data passed from Flow
    @api projectNameFromFlow;  // Project Name passed from Flow
    @api salePriceFromFlow;    // Sale Price passed from Flow
    @api propertyDetailsFromFlow;  // Property Details passed from Flow
    @api unitNameFromFlow;     // Unit Name passed from Flow
    @api unitId;
    @api secondaryCurrencyAmountFromFlow; // Secondary Currency Amount passed from Flow
    @api secondaryCurrencyFromFlow; // Secondary Currency Type passed from Flow

    parsedInvoices = [];
    parsedLineItems = [];
    financialDetail;
    financialDetailLoaded = false;
    error;

    connectedCallback() {
        try {
            // Parse the JSON strings to arrays if not empty
            if (this.invoicesJson) {
                this.parsedInvoices = JSON.parse(this.invoicesJson);
            }

            if (this.lineItemsJson) {
                this.parsedLineItems = JSON.parse(this.lineItemsJson);
            }

            // Format date and amounts for each item in the arrays
            if (this.parsedInvoices.length > 0) {
                this.parsedInvoices = this.parsedInvoices.map(record => ({
                    ...record,
                    formattedInvoiceDate: record.Invoice_Date__c ? this.formatDate(record.Invoice_Date__c) : '',
                    formattedSubTotalAmount: record.Sub_Total_Amount__c ? this.formatAmount(record.Sub_Total_Amount__c) : '',
                    formattedGrandTotalAmount: record.Grand_Total_Amount__c ? this.formatAmount(record.Grand_Total_Amount__c) : '',
                    formattedSecondaryCurrency: record.Secondary_Currency_Amount__c ? this.formatAmount(record.Secondary_Currency_Amount__c) : '',
                    secondaryCurrency: record.Secondary_Currency__c || this.secondaryCurrencyFromFlow || ''
                }));
                
                // If we have a financial detail ID, fetch the financial details
                if (this.singleItemInvoice.Financial_Detail__c) {
                    this.fetchFinancialDetail(this.singleItemInvoice.Financial_Detail__c);
                }
            }

            if (this.parsedLineItems.length > 0) {
                this.parsedLineItems = this.parsedLineItems.map((record, index) => ({
                    ...record,
                    serialNumber: index + 1,
                    formattedAmount: record.Amount__c ? this.formatAmount(record.Amount__c) : '',
                    formattedVATAmount: '0.00',
                    formattedTotalAmount: record.Amount__c ? this.formatAmount(record.Amount__c) : '',
                    Description: record.Name || ''
                }));
            }
        } catch (error) {
            console.error('Error in connectedCallback:', error);
        }
    }

    fetchFinancialDetail(financialDetailId) {
        getFinancialDetail({ financialDetailId: financialDetailId })
            .then(result => {
                this.financialDetail = result;
                this.financialDetailLoaded = true;
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.financialDetail = undefined;
                this.financialDetailLoaded = false;
                console.error('Error fetching financial detail:', error);
            });
    }

    formatDate(rawDate) {
        const date = new Date(rawDate);
        const day = String(date.getDate()).padStart(2, '0');
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const year = date.getFullYear();
        return `${day}-${month}-${year}`;
    }

    formatAmount(amount) {
        if (typeof amount !== 'number' || isNaN(amount)) {
            return '';
        }
        return Number(amount).toFixed(2).replace(/\d(?=(\d{3})+\.)/g, '$&,');
    }

    get singleItemInvoice() {
        return this.parsedInvoices[0] || {};
    }

    get customerId() {
        return this.singleItemInvoice.Customer_Id__c || '';
    }

    get customerName() {
        return this.singleItemInvoice.Customer_Name__c || '';
    }

    get projectName() {
        return this.projectNameFromFlow || '';
    }

    get salePrice() {
        return this.salePriceFromFlow ? this.formatAmount(parseFloat(this.salePriceFromFlow)) : '';
    }

    get propertyDetails() {
        return this.propertyDetailsFromFlow || '';
    }

    get unitName() {
        return this.unitNameFromFlow || '';
    }

    // Bank details getters
    get bankName() {
        return this.financialDetail?.Name || '________';
    }

    get accountName() {
        return this.financialDetail?.Account_Name__c || '________';
    }

    get accountNumber() {
        return this.financialDetail?.Account_Number__c || '________';
    }

    get iban() {
        return this.financialDetail?.IBAN__c || '________';
    }

    get swiftCode() {
        return this.financialDetail?.Swift_Code__c || '________';
    }

    get branchName() {
        return this.financialDetail?.Branch_Name__c || '';
    }

    get totalInWords() {
        const grandTotal = parseFloat(this.grandTotalAmount.replace(/,/g, ''));
        return this.numberToWords(grandTotal) + ' AED Only';
    }

    get subTotalAmount() {
        const subTotal = this.singleItemInvoice.Sub_Total_Amount__c || 0;
        return this.formatAmount(subTotal);
    }

    get totalVATAmount() {
        if (!this.parsedLineItems || this.parsedLineItems.length === 0) {
            return '0.00';
        }
        const totalVAT = this.parsedLineItems.reduce((sum, item) => {
            const vatAmount = parseFloat(item.formattedVATAmount?.replace(/,/g, '') || '0');
            return sum + vatAmount;
        }, 0);
        return this.formatAmount(totalVAT);
    }

    get grandTotalAmount() {
        const subTotal = parseFloat(this.singleItemInvoice.Sub_Total_Amount__c || '0');
        const totalVAT = parseFloat(this.totalVATAmount);
        const grandTotal = subTotal + totalVAT;
        return this.formatAmount(grandTotal);
    }

    numberToWords(number) {
        const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'];
        const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
        const teens = ['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];

        const convertLessThanThousand = (num) => {
            if (num === 0) return '';
            
            let result = '';
            
            if (num >= 100) {
                result += ones[Math.floor(num / 100)] + ' Hundred ';
                num %= 100;
            }
            
            if (num >= 10 && num < 20) {
                result += teens[num - 10];
                num = 0;
            } else if (num >= 20) {
                result += tens[Math.floor(num / 10)];
                num %= 10;
            }
            
            if (num > 0) {
                result += (result ? ' ' : '') + ones[num];
            }
            
            return result.trim();
        };
        
        const convert = (num) => {
            if (num === 0) return 'Zero';
            
            const parts = [];
            let decimalPart = '';
            
            // Handle decimal part
            if (num % 1 !== 0) {
                decimalPart = (num % 1).toFixed(2).slice(2);
                num = Math.floor(num);
            }
            
            if (num >= 1000000) {
                parts.push(convertLessThanThousand(Math.floor(num / 1000000)) + ' Million');
                num %= 1000000;
            }
            
            if (num >= 1000) {
                parts.push(convertLessThanThousand(Math.floor(num / 1000)) + ' Thousand');
                num %= 1000;
            }
            
            if (num > 0) {
                parts.push(convertLessThanThousand(num));
            }
            
            let result = parts.join(' ');
            
            // Add decimal part if exists
            if (decimalPart) {
                result += ' Point ' + decimalPart.split('').map(digit => ones[parseInt(digit)]).join(' ');
            }
            
            return result.trim();
        };

        return convert(number);
    }

    get hasSecondaryCurrency() {
        // Check if either from the Flow parameter or from the invoice record
        return (
            (this.secondaryCurrencyAmountFromFlow && 
             parseFloat(this.secondaryCurrencyAmountFromFlow) > 0) ||
            (this.singleItemInvoice.Secondary_Currency_Amount__c && 
             parseFloat(this.singleItemInvoice.Secondary_Currency_Amount__c) > 0)
        );
    }

    get secondaryCurrencyAmount() {
        // Use either from Flow or from the invoice record
        const amount = this.secondaryCurrencyAmountFromFlow || 
                       this.singleItemInvoice.Secondary_Currency_Amount__c || 0;
        return this.formatAmount(parseFloat(amount));
    }

    get secondaryCurrencyType() {
        const currency = this.secondaryCurrencyFromFlow || 
                         this.singleItemInvoice.Secondary_Currency__c || 'USD';
        return currency;
    }

    get secondaryCurrencySymbol() {
        const currency = this.secondaryCurrencyType;
        switch(currency) {
            case 'USD':
                return '$';
            case 'EUR':
            case 'EURO':
                return '€';
            case 'GBP':
                return '£';
            default:
                return '';
        }
    }
    
    get secondaryCurrencyInWords() {
        const amount = this.secondaryCurrencyAmountFromFlow || 
                      this.singleItemInvoice.Secondary_Currency_Amount__c || 0;
        const currencyType = this.secondaryCurrencyType;
        
        let currencyName = '';
        switch(currencyType) {
            case 'USD':
                currencyName = 'US Dollars';
                break;
            case 'EUR':
            case 'EURO':
                currencyName = 'Euros';
                break;
            case 'GBP':
                currencyName = 'Pounds Sterling';
                break;
            default:
                currencyName = currencyType;
        }
        
        return this.numberToWords(parseFloat(amount)) + ' ' + currencyName + ' Only';
    }
}