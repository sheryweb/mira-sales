import { LightningElement, api, wire } from 'lwc';
import getInvoiceDetails from '@salesforce/apex/InvoiceDetailsController.getInvoiceDetails';

export default class ReceiptPreviewLWC extends LightningElement {
    @api receiptsJson;  // Receipts data passed from Flow
    @api milestonesJson;  // Milestones data passed from Flow
    @api invoicesJson;  // Invoice IDs passed from Flow (back to using this)
    @api paymentsJson;  // Payments data passed from Flow

    parsedReceipts = [];
    parsedPayments = [];
    invoiceDetails = [];
    paymentsByInvoice = {};  // Map to store payments by invoice ID
    error;

    connectedCallback() {
        try {
            console.log('Component initialized with props:', {
                receiptsJson: this.receiptsJson,
                milestonesJson: this.milestonesJson,
                invoicesJson: this.invoicesJson,
                paymentsJson: this.paymentsJson
            });

            // Parse the JSON strings to arrays if not empty
            this.parsedReceipts = this.receiptsJson ? JSON.parse(this.receiptsJson) : [];
            this.parsedPayments = this.paymentsJson ? JSON.parse(this.paymentsJson) : [];
            
            // Process payments to add type flags and formatted values
            this.processPayments();

            // Map payments to invoices
            this.mapPaymentsToInvoices();

            // Process invoices - handling multiple invoices
            if (this.invoicesJson) {
                console.log('Processing invoices:', this.invoicesJson);
                this.processInvoiceIds();
            } else {
                console.warn('No invoice data provided to component');
            }

            // Format date for each item in the arrays
            this.parsedReceipts = this.parsedReceipts.map(record => ({
                ...record,
                formattedReceiptDate: record.Receipt_Added_Date__c ? this.formatDate(record.Receipt_Added_Date__c) : '',
                formattedPaymentDate: record.Payment_Date__c ? this.formatDate(record.Payment_Date__c) : '',
                formattedPayableAmount: record.Payable_Amount__c ? this.formatAmount(record.Payable_Amount__c) : '',
                formattedReceivedAmount: record.Received_Amount__c ? this.formatAmount(record.Received_Amount__c) : '',
                formattedBalanceAmount: this.formatAmount(record.Payable_Amount__c - record.Received_Amount__c)
            }));

        } catch (error) {
            console.error('Error in connectedCallback:', error);
            this.error = error;
        }
    }

    mapPaymentsToInvoices() {
        if (!this.parsedPayments || this.parsedPayments.length === 0) {
            return;
        }

        // Initialize the payment by invoice map
        this.paymentsByInvoice = {};

        // Process each payment and organize by invoice ID
        this.parsedPayments.forEach(payment => {
            // Check if payment has an Invoice__c field
            if (payment.Invoice__c) {
                // If this invoice doesn't have an entry yet, create one
                if (!this.paymentsByInvoice[payment.Invoice__c]) {
                    this.paymentsByInvoice[payment.Invoice__c] = {
                        totalAmount: 0,
                        payments: []
                    };
                }

                // Get the payment amount
                const amount = payment.Amount_Text__c ? parseFloat(payment.Amount_Text__c.replace(/,/g, '')) : 0;
                
                // Add this payment to the invoice's payments collection
                this.paymentsByInvoice[payment.Invoice__c].payments.push(payment);
                
                // Add the amount to the total for this invoice
                this.paymentsByInvoice[payment.Invoice__c].totalAmount += amount;
            }
        });

        console.log('Mapped payments to invoices:', this.paymentsByInvoice);
    }

    processPayments() {
        if (!this.parsedPayments || this.parsedPayments.length === 0) {
            return;
        }
        
        this.parsedPayments = this.parsedPayments.map(payment => {
            const mode = payment.Mode_of_Payment__c;
            const formattedPayment = {
                ...payment,
                formattedReceiptAmount: payment.Amount_Text__c || 0.00,
                formattedChequeDate: payment.Cheque_Date__c ? this.formatDate(payment.Cheque_Date__c) : '',
                // Add flags for payment type conditions
                isSimplePayment: ['Cash', 'Bank Transfer', 'Card', 'Online Payment'].includes(mode),
                isChequePayment: mode === 'Cheque',
                isPOSPayment: mode === 'POS Machine'
            };
            
            // Store the invoice number if available
            if (payment.Invoice__c && payment.Invoice_Number__c) {
                formattedPayment.Invoice_Number__c = payment.Invoice_Number__c;
            } else if (payment.Invoice__c && !payment.Invoice_Number__c) {
                // If we have Invoice__c but not the number, we'll look it up later
                formattedPayment.pendingInvoiceNumberLookup = true;
            }
            
            return formattedPayment;
        });
        
        console.log('Processed payments:', this.parsedPayments);
    }

    processInvoiceIds() {
        try {
            let invoiceIds = [];
            
            // Try to parse as JSON first
            try {
                const parsed = JSON.parse(this.invoicesJson);
                
                if (Array.isArray(parsed)) {
                    // If it's an array, extract Invoice__c from each object
                    invoiceIds = parsed.map(item => {
                        if (item && typeof item === 'object' && 'Invoice__c' in item) {
                            return item.Invoice__c;
                        }
                        return item;
                    });
                } else if (typeof parsed === 'string') {
                    // If it's a single ID string
                    invoiceIds = [parsed];
                } else if (parsed && typeof parsed === 'object') {
                    // If it's a single object, extract Invoice__c
                    invoiceIds = [parsed.Invoice__c || parsed];
                }
            } catch (e) {
                // If it's not JSON, assume it's a single ID or comma-separated list
                if (this.invoicesJson.includes(',')) {
                    invoiceIds = this.invoicesJson.split(',').map(id => id.trim());
                } else {
                    invoiceIds = [this.invoicesJson];
                }
            }
            
            console.log('Extracted invoice IDs:', invoiceIds);
            
            // Add invoice IDs from payment collections if they're not already included
            if (this.parsedPayments && this.parsedPayments.length > 0) {
                this.parsedPayments.forEach(payment => {
                    if (payment.Invoice__c && !invoiceIds.includes(payment.Invoice__c)) {
                        invoiceIds.push(payment.Invoice__c);
                    }
                });
            }
            
            // Filter out any null, undefined or empty values
            const validIds = invoiceIds.filter(id => id);
            
            if (validIds && validIds.length > 0) {
                this.fetchInvoiceDetails(validIds);
            } else {
                console.warn('No valid invoice IDs found');
            }
        } catch (error) {
            console.error('Error processing invoice IDs:', error);
        }
    }

    async fetchInvoiceDetails(invoiceIds) {
        try {
            console.log('Fetching details for invoice IDs:', invoiceIds);
            
            const result = await getInvoiceDetails({ 
                invoiceIds: invoiceIds 
            });
            
            console.log('Received invoice details:', result);
            
            if (result && result.length > 0) {
                // Create a map of invoice IDs to their invoice numbers
                const invoiceNumberMap = {};
                result.forEach(invoice => {
                    invoiceNumberMap[invoice.Id] = invoice.Invoice_Number__c;
                });
                
                // Update any payments that need invoice number lookup
                this.parsedPayments = this.parsedPayments.map(payment => {
                    if (payment.pendingInvoiceNumberLookup && payment.Invoice__c && invoiceNumberMap[payment.Invoice__c]) {
                        payment.Invoice_Number__c = invoiceNumberMap[payment.Invoice__c];
                        payment.pendingInvoiceNumberLookup = false;
                    }
                    return payment;
                });
                
                this.invoiceDetails = result.map(invoice => {
                    // Get the payment amount for this invoice from the mapped payments
                    const paymentInfo = this.paymentsByInvoice[invoice.Id] || { totalAmount: 0 };
                    const paidAmount = paymentInfo.totalAmount || 0;
                    
                    // If the invoice already has a Paid_Amount__c, use the greater of the two values
                    const totalPaidAmount = Math.max(
                        invoice.Paid_Amount__c || 0, 
                        paidAmount
                    );
                    
                    return {
                        ...invoice,
                        formattedInvoiceDate: invoice.Invoice_Date__c ? this.formatDate(invoice.Invoice_Date__c) : '',
                        formattedDueAmount: invoice.Pending_Amount__c ? this.formatAmount(invoice.Pending_Amount__c) : '',
                        formattedPaidAmount: this.formatAmount(totalPaidAmount),
                        paymentAmount: paidAmount,
                        formattedBalanceAmount: this.formatAmount(invoice.Pending_Amount__c - totalPaidAmount)
                    };
                });
                console.log('Formatted invoice details with payment info:', this.invoiceDetails);
            } else {
                console.warn('No invoice details returned from Apex');
                this.invoiceDetails = [];
            }
        } catch (error) {
            console.error('Error fetching invoice details:', error);
            this.error = error;
            this.invoiceDetails = [];
        }
    }

    formatDate(rawDate) {
        try {
            if (!rawDate) return '';
            const date = new Date(rawDate);
            if (isNaN(date.getTime())) return '';
            const day = String(date.getDate()).padStart(2, '0');
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const year = date.getFullYear();
            return `${day}-${month}-${year}`;
        } catch (error) {
            console.error('Error formatting date:', error);
            return '';
        }
    }

    formatAmount(amount) {
        try {
            if (amount === null || amount === undefined) return '0.00';
            const numAmount = Number(amount);
            if (isNaN(numAmount)) return '0.00';
            return numAmount.toFixed(2).replace(/\d(?=(\d{3})+\.)/g, '$&,');
        } catch (error) {
            console.error('Error formatting amount:', error);
            return '0.00';
        }
    }

    get singleItemReceipt() {
        const receipt = this.parsedReceipts[0] || {};
        console.log('Single Receipt Data:', receipt);
        return receipt;
    }

    get accountName() {
        const receipt = this.singleItemReceipt;
        return receipt.Customer_Name__c || '';
    }

    get projectName() {
        const receipt = this.singleItemReceipt;
        return receipt.Project_Name__c || '';
    }

    get towerName() {
        const receipt = this.singleItemReceipt;
        return receipt.Unit_Building__c || '';
    }

    get unitName() {
        const receipt = this.singleItemReceipt;
        return receipt.Unit_No__c || '';
    }

    get amountInWords() {
        // Use the Amount_In_Words__c field if available, otherwise generate from Received_Amount__c
        if (this.singleItemReceipt.Amount_In_Words__c) {
            return this.singleItemReceipt.Amount_In_Words__c;
        }
        
        // Generate amount in words from Received_Amount__c
        const receipt = this.singleItemReceipt;
        const amount = receipt.Received_Amount__c || 0;
        
        // Simple conversion of numbers to words
        return this.convertNumberToWords(amount) + ' Dirhams Only';
    }
    
    convertNumberToWords(amount) {
        if (!amount) return 'Zero';
        
        const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
            'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
        const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
        
        // Handle decimal part
        const decimalStr = amount.toString().includes('.') ? amount.toString().split('.')[1] : '00';
        const decimal = parseInt(decimalStr.padEnd(2, '0').substring(0, 2));
        
        // Convert whole number part
        let whole = Math.floor(amount);
        
        // Convert to words
        let result = '';
        
        // Handle millions
        if (whole >= 1000000) {
            result += this.convertLessThanThousand(Math.floor(whole / 1000000)) + ' Million ';
            whole %= 1000000;
        }
        
        // Handle thousands
        if (whole >= 1000) {
            result += this.convertLessThanThousand(Math.floor(whole / 1000)) + ' Thousand ';
            whole %= 1000;
        }
        
        // Handle hundreds and smaller
        if (whole > 0) {
            result += this.convertLessThanThousand(whole);
        }
        
        // Add decimal part if needed
        if (decimal > 0) {
            result += ' and ' + decimal + '/100';
        }
        
        return result || 'Zero';
    }
    
    convertLessThanThousand(num) {
        const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
            'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
        const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
        
        let result = '';
        
        // Handle hundreds
        if (num >= 100) {
            result += ones[Math.floor(num / 100)] + ' Hundred ';
            num %= 100;
        }
        
        // Handle tens and ones
        if (num >= 20) {
            result += tens[Math.floor(num / 10)] + ' ';
            num %= 10;
        }
        
        if (num > 0) {
            result += ones[num] + ' ';
        }
        
        return result.trim();
    }

    get formattedReceivedAmount() {
        const receipt = this.singleItemReceipt;
        const amount = receipt.Received_Amount__c || 0;
        return this.formatAmount(amount);
    }

    get receiptDescription() {
        return this.singleItemReceipt.Description__c || '';
    }
}