public class ReceiptRecordInsert {
    // Add a static flag that can be set by tests
    @TestVisible private static Boolean TRACE_ENABLED = false;

    @InvocableMethod(label='Process Receipt Insertion' description='Processes collections of Receipt, Milestone Receipt, and Receipt Amount records')
    public static List<ResponseWrapper> processReceipts(List<RequestWrapper> requestList) {
        if (requestList == null || requestList.isEmpty()) {
            throw new AuraHandledException('No data passed from the flow.');
        }

        //Extract data from the wrapper
        RequestWrapper request = requestList[0];
        List<Receipt__c> receiptRecordAll = request.receiptRecordAll;
        List<Receipt_Invoice__c> receiptInvoiceAll = request.receiptInvoiceAll;
        List<Receipt_Amount__c> receiptAmountAll = request.receiptAmountAll;

        if (receiptRecordAll == null || receiptRecordAll.isEmpty()) {
            throw new AuraHandledException('The ReceiptRecordAll collection must have at least one record.');
        }

        //Step 1: Insert the first Receipt__c record
        Receipt__c receipt = receiptRecordAll[0];
        insert receipt;

        //Get the newly inserted Receipt ID
        Id receiptId = receipt.Id;

        //Step 2: Assign the Receipt ID to other two collections
        if (receiptAmountAll != null && !receiptAmountAll.isEmpty()) {
            for (Receipt_Amount__c receiptAmount : receiptAmountAll) {
                receiptAmount.Receipt__c = receiptId;
            }
            
            // Calculate cumulative paid amounts
            Set<Id> invoiceIds = new Set<Id>();
            for (Receipt_Amount__c ra : receiptAmountAll) {
                if (ra.Invoice__c != null) {
                    invoiceIds.add(ra.Invoice__c);
                }
            }
            
            // Query the most recent Receipt_Amount__c for each invoice to get the last cumulative amount
            Map<Id, Decimal> lastCumulativeAmountByInvoice = new Map<Id, Decimal>();
            if (!invoiceIds.isEmpty()) {
                // For each invoice, find the latest Receipt_Amount__c record by Receipt__r.Receipt_Added_Date__c
                for (Id invoiceId : invoiceIds) {
                    List<Receipt_Amount__c> lastReceipts = [
                        SELECT Invoice__c, Amount__c, Cumulative_Paid_Amount__c, 
                               Receipt__r.Receipt_Added_Date__c, Receipt__r.Payment_Date__c
                        FROM Receipt_Amount__c
                        WHERE Invoice__c = :invoiceId
                        ORDER BY Receipt__r.Receipt_Added_Date__c DESC, Receipt__r.Payment_Date__c DESC
                        LIMIT 1
                    ];
                    
                    if (!lastReceipts.isEmpty() && lastReceipts[0].Cumulative_Paid_Amount__c != null) {
                        lastCumulativeAmountByInvoice.put(invoiceId, lastReceipts[0].Cumulative_Paid_Amount__c);
                        System.debug('Last cumulative amount for invoice ' + invoiceId + ': ' + lastReceipts[0].Cumulative_Paid_Amount__c);
                    } else {
                        lastCumulativeAmountByInvoice.put(invoiceId, 0);
                        System.debug('No previous cumulative amount found for invoice ' + invoiceId);
                    }
                }
            }
            
            // Set the cumulative amount for each receipt amount record
            for (Receipt_Amount__c ra : receiptAmountAll) {
                if (ra.Invoice__c != null && ra.Amount__c != null) {
                    Decimal previousCumulativeAmount = lastCumulativeAmountByInvoice.containsKey(ra.Invoice__c) ? 
                                                    lastCumulativeAmountByInvoice.get(ra.Invoice__c) : 0;
                    
                    // Calculate new cumulative amount as previous amount + current amount
                    ra.Cumulative_Paid_Amount__c = previousCumulativeAmount + ra.Amount__c;
                    
                    System.debug('Setting Cumulative_Paid_Amount__c for Invoice ' + ra.Invoice__c + 
                               ': Previous=' + previousCumulativeAmount + 
                               ', Current=' + ra.Amount__c + 
                               ', New Cumulative=' + ra.Cumulative_Paid_Amount__c);
                }
            }
            
            //Insert updated Receipt Amount records
            insert receiptAmountAll;
        }

        // Track invoice payments for status and paid amount updates
        Map<Id, Decimal> invoicePayments = new Map<Id, Decimal>();

        // Process Receipt Amount records to get payment amounts by invoice
        if (receiptAmountAll != null && !receiptAmountAll.isEmpty()) {
            for (Receipt_Amount__c receiptAmount : receiptAmountAll) {
                if (receiptAmount.Invoice__c != null && receiptAmount.Amount__c != null) {
                    // Add the payment amount to the invoice's total
                    if (invoicePayments.containsKey(receiptAmount.Invoice__c)) {
                        invoicePayments.put(
                            receiptAmount.Invoice__c, 
                            invoicePayments.get(receiptAmount.Invoice__c) + receiptAmount.Amount__c
                        );
                    } else {
                        invoicePayments.put(receiptAmount.Invoice__c, receiptAmount.Amount__c);
                    }
                }
            }
        }

        // Also process Receipt_Invoice__c records to collect invoice IDs
        if (receiptInvoiceAll != null && !receiptInvoiceAll.isEmpty()) {
            for (Receipt_Invoice__c receiptInvoice : receiptInvoiceAll) {
                receiptInvoice.Receipt__c = receiptId;
            }
            //Insert updated Receipt Invoice records
            insert receiptInvoiceAll;
        }
            
        // Update invoices with payment amounts and proper status.
        // When the centralized engine owns the totals (feature flag ON), skip this legacy
        // incremental math entirely — the self-healing triggers already re-derived the correct
        // totals when the Receipt_Amount__c lines were inserted above. Running it here too would
        // double-count. With the flag OFF (production, pre-cutover) this path is unchanged.
        if (!invoicePayments.isEmpty() && !FinancialEngine.isEngineEnabled()) {
            // Fetch the current invoice data to check pending amounts
            List<Invoice__c> currentInvoices = [
                SELECT Id, Pending_Amount__c, Paid_Amount__c 
                FROM Invoice__c 
                WHERE Id IN :invoicePayments.keySet()
            ];
            
            List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();
            
            for (Invoice__c inv : currentInvoices) {
                Decimal paymentAmount = invoicePayments.get(inv.Id);
                Decimal currentPaidAmount = inv.Paid_Amount__c != null ? inv.Paid_Amount__c : 0;
                Decimal newPaidAmount = currentPaidAmount + paymentAmount;
                Decimal pendingAmount = inv.Pending_Amount__c != null ? inv.Pending_Amount__c : 0;
                
                // Get the remaining amount after this payment
                Decimal remainingAmount = pendingAmount - paymentAmount;
                
                // Determine status based on remaining amount
                String status;
                if (remainingAmount <= 0) {
                    status = 'Fully Paid';
                } else {
                    status = 'Partially Paid';
                }
                
                System.debug('Invoice: ' + inv.Id);
                System.debug('Current Paid Amount: ' + currentPaidAmount);
                System.debug('Payment Amount: ' + paymentAmount);
                System.debug('New Paid Amount: ' + newPaidAmount);
                System.debug('Pending Amount: ' + pendingAmount);
                System.debug('Remaining Amount: ' + remainingAmount);
                System.debug('Status: ' + status);
                
                // Create update record with accumulated paid amount
                Invoice__c updateInv = new Invoice__c(
                    Id = inv.Id,
                    Paid_Amount__c = newPaidAmount,
                    Status__c = status
                );
                
                invoicesToUpdate.add(updateInv);
            }
            
            if (!invoicesToUpdate.isEmpty()) {
                update invoicesToUpdate;
            }
            
            // New functionality: Fetch Cash_Flow__c from Milestone_Invoice__c and update Received_Amount__c
            updateCashFlowReceivedAmounts(invoicePayments);
        }
        
        // Create and return the response with the receipt ID
        ResponseWrapper response = new ResponseWrapper();
        response.receiptId = receiptId;
        return new List<ResponseWrapper>{response};
    }
    
    // Helper method to update Cash_Flow__c.Received_Amount__c based on Invoice payments
    private static void updateCashFlowReceivedAmounts(Map<Id, Decimal> invoicePayments) {
        try {
            // Step 1: First, get Invoice records to determine the Unit__c associated with each invoice
            Map<Id, Invoice__c> invoicesMap = new Map<Id, Invoice__c>([
                SELECT Id, Unit__c 
                FROM Invoice__c 
                WHERE Id IN :invoicePayments.keySet() 
                AND Unit__c != null
            ]);
            
            if (invoicesMap.isEmpty()) {
                System.debug('No invoices found with Unit__c references');
                return;
            }
            
            // Step 2: Get all related Milestone_Invoice__c records to find linked Cash_Flow__c records
            Map<Id, List<Milestone_Invoice__c>> invoiceToMilestonesMap = new Map<Id, List<Milestone_Invoice__c>>();
            
            List<Milestone_Invoice__c> milestoneInvoices = [
                SELECT Id, Invoice__c, Cash_Flow__c, Cash_Flow__r.Price_Formula__c, 
                       Cash_Flow__r.Received_Amount__c, Cash_Flow__r.Date__c, Cash_Flow__r.Unit__c,
                       Cash_Flow__r.Remaining_Amount__c
                FROM Milestone_Invoice__c 
                WHERE Invoice__c IN :invoicePayments.keySet() 
                AND Cash_Flow__c != null
                ORDER BY Cash_Flow__r.Date__c ASC, Id ASC
            ];
            
            System.debug('Found ' + milestoneInvoices.size() + ' Milestone_Invoice__c records');
            
            for (Milestone_Invoice__c mi : milestoneInvoices) {
                if (!invoiceToMilestonesMap.containsKey(mi.Invoice__c)) {
                    invoiceToMilestonesMap.put(mi.Invoice__c, new List<Milestone_Invoice__c>());
                }
                invoiceToMilestonesMap.get(mi.Invoice__c).add(mi);
                System.debug('Added Milestone_Invoice__c: ' + mi.Id + ' with Cash_Flow__c: ' + mi.Cash_Flow__c);
            }
            
            // Step 3: Group payments by Unit and track original invoice payment amounts
            Map<Id, Decimal> unitTotalPayments = new Map<Id, Decimal>();
            Map<Id, Id> invoiceToUnitMap = new Map<Id, Id>();
            Set<Id> unitIds = new Set<Id>();
            
            for (Id invoiceId : invoicePayments.keySet()) {
                if (invoicesMap.containsKey(invoiceId) && invoicesMap.get(invoiceId).Unit__c != null) {
                    Id unitId = invoicesMap.get(invoiceId).Unit__c;
                    Decimal paymentAmount = invoicePayments.get(invoiceId);
                    
                    // Track unit ID for each invoice
                    invoiceToUnitMap.put(invoiceId, unitId);
                    unitIds.add(unitId);
                    
                    // Sum payments by Unit
                    if (unitTotalPayments.containsKey(unitId)) {
                        unitTotalPayments.put(unitId, unitTotalPayments.get(unitId) + paymentAmount);
                    } else {
                        unitTotalPayments.put(unitId, paymentAmount);
                    }
                    
                    System.debug('Added payment of ' + paymentAmount + ' for Unit: ' + unitId + 
                              ' from Invoice: ' + invoiceId);
                }
            }
            
            if (unitTotalPayments.isEmpty()) {
                System.debug('No valid Unit payments to process');
                return;
            }
            
            // Step 4: Get ALL Cash_Flow__c records for all Units, for later use if needed
            Map<Id, List<Cash_Flow__c>> unitToCashFlowsMap = new Map<Id, List<Cash_Flow__c>>();
            Map<Id, Cash_Flow__c> cashFlowsById = new Map<Id, Cash_Flow__c>();
            
            List<Cash_Flow__c> allUnitCashFlows = [
                SELECT Id, Unit__c, Price_Formula__c, Received_Amount__c, Date__c, Name, 
                       Remaining_Amount__c
                FROM Cash_Flow__c
                WHERE Unit__c IN :unitIds
                ORDER BY Date__c ASC, Id ASC
            ];
            
            System.debug('Found ' + allUnitCashFlows.size() + ' total Cash_Flow__c records for the units');
            
            for (Cash_Flow__c cf : allUnitCashFlows) {
                if (!unitToCashFlowsMap.containsKey(cf.Unit__c)) {
                    unitToCashFlowsMap.put(cf.Unit__c, new List<Cash_Flow__c>());
                }
                unitToCashFlowsMap.get(cf.Unit__c).add(cf);
                cashFlowsById.put(cf.Id, cf);
                
                System.debug('Unit: ' + cf.Unit__c + ' has Cash_Flow__c: ' + cf.Id + 
                           ' (Date: ' + cf.Date__c + ', Price: ' + cf.Price_Formula__c + 
                           ', Received: ' + cf.Received_Amount__c + 
                           ', Remaining: ' + cf.Remaining_Amount__c + ')');
            }
            
            // Step 5: Prepare Cash_Flow__c records for update
            List<Cash_Flow__c> cashFlowsToUpdate = new List<Cash_Flow__c>();
            
            // Step 6: Process each invoice and first distribute payments to linked Cash Flows
            Map<Id, Decimal> remainingPaymentByUnit = new Map<Id, Decimal>();
            
            for (Id invoiceId : invoicePayments.keySet()) {
                if (!invoiceToUnitMap.containsKey(invoiceId)) {
                    System.debug('Skipping invoice: ' + invoiceId + ' - No Unit reference');
                    continue;
                }
                
                Id unitId = invoiceToUnitMap.get(invoiceId);
                Decimal invoicePayment = invoicePayments.get(invoiceId);
                Decimal remainingInvoicePayment = invoicePayment;
                
                System.debug('Processing invoice: ' + invoiceId + ' with payment: ' + invoicePayment + 
                           ' for unit: ' + unitId);
                
                // First apply to Cash_Flow__c records linked to this invoice via Milestone_Invoice__c
                if (invoiceToMilestonesMap.containsKey(invoiceId) && !invoiceToMilestonesMap.get(invoiceId).isEmpty()) {
                    List<Milestone_Invoice__c> linkedMilestones = invoiceToMilestonesMap.get(invoiceId);
                    
                    System.debug('Found ' + linkedMilestones.size() + ' linked milestones for invoice: ' + invoiceId);
                    
                    // Process each linked Cash_Flow__c in order
                    for (Milestone_Invoice__c mi : linkedMilestones) {
                        if (remainingInvoicePayment <= 0) {
                            break; // No more payment to distribute for this invoice
                        }
                        
                        Id cashFlowId = mi.Cash_Flow__c;
                        
                        // Ensure we have the latest data for this Cash_Flow__c
                        if (!cashFlowsById.containsKey(cashFlowId)) {
                            System.debug('Cash Flow ID ' + cashFlowId + ' not found in queried records, skipping');
                            continue;
                        }
                        
                        Cash_Flow__c cashFlow = cashFlowsById.get(cashFlowId);
                        
                        // Check if this cash flow has remaining amount > 0
                        Decimal remainingAmount = cashFlow.Remaining_Amount__c != null ? 
                                                cashFlow.Remaining_Amount__c : 0;
                                                
                        if (remainingAmount <= 0) {
                            System.debug('Skipping linked cash flow: ' + cashFlowId + 
                                      ' because Remaining_Amount__c is not greater than 0: ' + remainingAmount);
                            continue; // Skip cash flows with no remaining amount
                        }
                        
                        // Calculate how much can be applied to this cash flow
                        Decimal cashFlowPrice = cashFlow.Price_Formula__c != null ? cashFlow.Price_Formula__c : 0;
                        Decimal currentReceived = cashFlow.Received_Amount__c != null ? cashFlow.Received_Amount__c : 0;
                        Decimal capacity = cashFlowPrice - currentReceived;
                        
                        if (capacity <= 0) {
                            System.debug('Linked cash flow already fully paid, skipping: ' + cashFlowId);
                            continue; // Skip fully paid cash flows
                        }
                        
                        // Determine amount to apply - consider the remaining amount, capacity, and payment
                        Decimal paymentToApply = Math.min(Math.min(remainingInvoicePayment, capacity), remainingAmount);
                        
                        if (paymentToApply <= 0) {
                            System.debug('No payment to apply for linked cash flow: ' + cashFlowId);
                            continue;
                        }
                        
                        Decimal newReceived = currentReceived + paymentToApply;
                        remainingInvoicePayment -= paymentToApply;
                        
                        // Update in our cache to reflect this payment
                        cashFlow.Received_Amount__c = newReceived;
                        
                        // Check if this cash flow is already in our update list
                        boolean alreadyInUpdateList = false;
                        for (Cash_Flow__c cf : cashFlowsToUpdate) {
                            if (cf.Id == cashFlowId) {
                                cf.Received_Amount__c = newReceived;
                                alreadyInUpdateList = true;
                                break;
                            }
                        }
                        
                        if (!alreadyInUpdateList) {
                            // Create update record
                            cashFlowsToUpdate.add(new Cash_Flow__c(
                                Id = cashFlowId,
                                Received_Amount__c = newReceived
                            ));
                        }
                        
                        System.debug('Updated linked cash flow: ' + cashFlowId + 
                                   ', Applied: ' + paymentToApply + 
                                   ', New Total: ' + newReceived + 
                                   ', Remaining Invoice Payment: ' + remainingInvoicePayment);
                    }
                } else {
                    System.debug('No linked milestones found for invoice: ' + invoiceId);
                }
                
                // Track any remaining payment by unit for second phase distribution
                if (remainingInvoicePayment > 0) {
                    if (remainingPaymentByUnit.containsKey(unitId)) {
                        remainingPaymentByUnit.put(unitId, remainingPaymentByUnit.get(unitId) + remainingInvoicePayment);
                    } else {
                        remainingPaymentByUnit.put(unitId, remainingInvoicePayment);
                    }
                    
                    System.debug('After processing linked cash flows, remaining payment for unit ' + 
                               unitId + ' is: ' + remainingInvoicePayment);
                }
            }
            
            // Step 7: Distribute any remaining payments to next chronological Cash_Flow__c records
            for (Id unitId : remainingPaymentByUnit.keySet()) {
                Decimal remainingPayment = remainingPaymentByUnit.get(unitId);
                
                if (remainingPayment <= 0 || !unitToCashFlowsMap.containsKey(unitId) || 
                    unitToCashFlowsMap.get(unitId).isEmpty()) {
                    continue;
                }
                
                System.debug('Processing remaining payment of ' + remainingPayment + ' for unit: ' + unitId);
                
                // Sort all unit cash flows by date to ensure correct order
                List<CashFlowDateWrapper> wrappers = new List<CashFlowDateWrapper>();
                for (Cash_Flow__c cf : unitToCashFlowsMap.get(unitId)) {
                    wrappers.add(new CashFlowDateWrapper(cf));
                }
                wrappers.sort();
                
                // Rebuild sorted list
                List<Cash_Flow__c> sortedUnitCashFlows = new List<Cash_Flow__c>();
                for (CashFlowDateWrapper wrapper : wrappers) {
                    sortedUnitCashFlows.add(wrapper.cashFlow);
                }
                
                // Process each cash flow in date order
                for (Cash_Flow__c cashFlow : sortedUnitCashFlows) {
                    if (remainingPayment <= 0) {
                        break; // No more payment to distribute
                    }
                    
                    // Skip if this cash flow was already fully updated
                    boolean alreadyProcessed = false;
                    if (TRACE_ENABLED) System.debug(LoggingLevel.ERROR, '### TRACE: Starting alreadyProcessed check for Cash Flow: ' + cashFlow.Id);
                    for (Cash_Flow__c cf : cashFlowsToUpdate) {
                        if (cf.Id == cashFlow.Id) {
                            if (TRACE_ENABLED) System.debug(LoggingLevel.ERROR, '### TRACE: Found Cash Flow in update list: ' + cashFlow.Id);
                            alreadyProcessed = true;
                            
                            // If there's still capacity, we could add more
                            Decimal cashFlowPrice = cashFlow.Price_Formula__c != null ? cashFlow.Price_Formula__c : 0;
                            Decimal updatedReceived = cf.Received_Amount__c;
                            Decimal remainingCapacity = cashFlowPrice - updatedReceived;
                            
                            if (TRACE_ENABLED) System.debug(LoggingLevel.ERROR, '### TRACE: Cash Flow: ' + cashFlow.Id + 
                                                     ', Price: ' + cashFlowPrice + 
                                                     ', Updated Received: ' + updatedReceived + 
                                                     ', Remaining Capacity: ' + remainingCapacity + 
                                                     ', Remaining Amount: ' + cashFlow.Remaining_Amount__c);
                            
                            if (remainingCapacity > 0 && cashFlow.Remaining_Amount__c > 0) {
                                if (TRACE_ENABLED) System.debug(LoggingLevel.ERROR, '### TRACE: Cash Flow still has capacity, setting alreadyProcessed to false');
                                alreadyProcessed = false;
                                cashFlow.Received_Amount__c = updatedReceived; // Update our cached value
                            }
                            
                            break;
                        }
                    }
                    
                    if (alreadyProcessed) {
                        if (TRACE_ENABLED) System.debug(LoggingLevel.ERROR, '### TRACE: Cash flow ' + cashFlow.Id + ' already processed, skipping');
                        continue;
                    }
                    
                    // Check if this cash flow has remaining amount > 0
                    Decimal remainingAmount = cashFlow.Remaining_Amount__c != null ? 
                                            cashFlow.Remaining_Amount__c : 0;
                                            
                    if (remainingAmount <= 0) {
                        System.debug('Skipping next cash flow: ' + cashFlow.Id + 
                                   ' because Remaining_Amount__c is not greater than 0: ' + remainingAmount);
                        continue; // Skip cash flows with no remaining amount
                    }
                    
                    // Calculate how much can be applied to this cash flow
                    Decimal cashFlowPrice = cashFlow.Price_Formula__c != null ? cashFlow.Price_Formula__c : 0;
                    Decimal currentReceived = cashFlow.Received_Amount__c != null ? cashFlow.Received_Amount__c : 0;
                    Decimal capacity = cashFlowPrice - currentReceived;
                    
                    if (capacity <= 0) {
                        System.debug('Cash flow already fully paid, skipping: ' + cashFlow.Id);
                        continue; // Skip fully paid cash flows
                    }
                    
                    // Determine amount to apply - consider the remaining amount, capacity, and payment
                    Decimal paymentToApply = Math.min(Math.min(remainingPayment, capacity), remainingAmount);
                    
                    if (paymentToApply <= 0) {
                        System.debug('No payment to apply for cash flow: ' + cashFlow.Id);
                        continue;
                    }
                    
                    Decimal newReceived = currentReceived + paymentToApply;
                    remainingPayment -= paymentToApply;
                    
                    // Update in our cache
                    cashFlow.Received_Amount__c = newReceived;
                    
                    // Check if already in update list
                    boolean alreadyInUpdateList = false;
                    for (Cash_Flow__c cf : cashFlowsToUpdate) {
                        if (cf.Id == cashFlow.Id) {
                            cf.Received_Amount__c = newReceived;
                            alreadyInUpdateList = true;
                            break;
                        }
                    }
                    
                    if (!alreadyInUpdateList) {
                        // Create update record
                        cashFlowsToUpdate.add(new Cash_Flow__c(
                            Id = cashFlow.Id,
                            Received_Amount__c = newReceived
                        ));
                    }
                    
                    System.debug('Updated next chronological cash flow: ' + cashFlow.Id + 
                               ', Applied: ' + paymentToApply + 
                               ', New Total: ' + newReceived + 
                               ', Remaining Payment: ' + remainingPayment);
                }
                
                // If still remaining payment, apply to the last cash flow with remaining amount > 0
                if (remainingPayment > 0 && !sortedUnitCashFlows.isEmpty()) {
                    // Find the last cash flow with remaining amount > 0
                    Cash_Flow__c lastValidCashFlow = null;
                    for (Integer i = sortedUnitCashFlows.size() - 1; i >= 0; i--) {
                        Cash_Flow__c cf = sortedUnitCashFlows[i];
                        Decimal cfRemainingAmount = cf.Remaining_Amount__c != null ? cf.Remaining_Amount__c : 0;
                        
                        if (cfRemainingAmount > 0) {
                            lastValidCashFlow = cf;
                            break;
                        }
                    }
                    
                    if (lastValidCashFlow != null) {
                        // Check if we already updated this cash flow
                        boolean alreadyUpdated = false;
                        for (Cash_Flow__c cf : cashFlowsToUpdate) {
                            if (cf.Id == lastValidCashFlow.Id) {
                                cf.Received_Amount__c += remainingPayment;
                                System.debug('Adding remaining ' + remainingPayment + 
                                           ' to already updated cash flow: ' + lastValidCashFlow.Id);
                                alreadyUpdated = true;
                                break;
                            }
                        }
                        
                        if (!alreadyUpdated) {
                            Decimal lastReceived = lastValidCashFlow.Received_Amount__c != null ? 
                                                lastValidCashFlow.Received_Amount__c : 0;
                            Decimal lastNewReceived = lastReceived + remainingPayment;
                            
                            cashFlowsToUpdate.add(new Cash_Flow__c(
                                Id = lastValidCashFlow.Id,
                                Received_Amount__c = lastNewReceived
                            ));
                            
                            System.debug('Adding remaining ' + remainingPayment + 
                                       ' to last valid cash flow: ' + lastValidCashFlow.Id);
                        }
                    } else {
                        System.debug('No valid cash flow with Remaining_Amount__c > 0 found to apply remaining payment: ' + remainingPayment);
                    }
                }
            }
            
            // Step 8: Update Cash_Flow__c records
            if (!cashFlowsToUpdate.isEmpty()) {
                System.debug('Updating ' + cashFlowsToUpdate.size() + ' Cash_Flow__c records:');
                for (Cash_Flow__c cf : cashFlowsToUpdate) {
                    System.debug('  - ID: ' + cf.Id + ', New Received_Amount__c: ' + cf.Received_Amount__c);
                }
                
                update cashFlowsToUpdate;
                System.debug('Successfully updated ' + cashFlowsToUpdate.size() + ' Cash_Flow__c records');
            } else {
                System.debug('No Cash_Flow__c records to update');
            }
            
        } catch (Exception e) {
            System.debug('ERROR updating Cash_Flow__c records: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // Don't throw the exception to ensure the main process completes
        }
    }

    //Wrapper class to accept multiple collection variables from the flow
    public class RequestWrapper {
        @InvocableVariable(required=true label='Receipt Records' description='Collection of Receipt__c records')
        public List<Receipt__c> receiptRecordAll;

        @InvocableVariable(required=false label='Receipt Invoice Records' description='Collection of Receipt_Invoice__c records')
        public List<Receipt_Invoice__c> receiptInvoiceAll;

        @InvocableVariable(required=false label='Receipt Amount Records' description='Collection of Receipt_Amount__c records')
        public List<Receipt_Amount__c> receiptAmountAll;
    }
    
    // Wrapper class to enable sorting Cash_Flow__c records by Date__c
    private class CashFlowDateWrapper implements Comparable {
        public Cash_Flow__c cashFlow;
        
        public CashFlowDateWrapper(Cash_Flow__c cf) {
            this.cashFlow = cf;
        }
        
        // Implement the Comparable interface
        public Integer compareTo(Object compareTo) {
            CashFlowDateWrapper compareToWrapper = (CashFlowDateWrapper)compareTo;
            
            // Handle null dates
            if (this.cashFlow.Date__c == null && compareToWrapper.cashFlow.Date__c == null) {
                return 0; // Both null, consider equal
            }
            if (this.cashFlow.Date__c == null) {
                return 1; // Null dates sort last
            }
            if (compareToWrapper.cashFlow.Date__c == null) {
                return -1; // Null dates sort last
            }
            
            // Compare dates
            if (this.cashFlow.Date__c < compareToWrapper.cashFlow.Date__c) {
                return -1; // This date is earlier
            }
            if (this.cashFlow.Date__c > compareToWrapper.cashFlow.Date__c) {
                return 1; // This date is later
            }
            return 0; // Dates are equal
        }
    }
    
    // Wrapper class to return the Receipt ID back to the flow
    public class ResponseWrapper {
        @InvocableVariable(label='Receipt ID' description='ID of the newly created Receipt record')
        public Id receiptId;
    }

    // Wrapper class to enable sorting Milestone_Invoice__c records by Date__c
    private class MilestoneInvoiceWrapper implements Comparable {
        public Milestone_Invoice__c milestoneInvoice;
        
        public MilestoneInvoiceWrapper(Milestone_Invoice__c mi) {
            this.milestoneInvoice = mi;
        }
        
        // Implement the Comparable interface
        public Integer compareTo(Object compareTo) {
            MilestoneInvoiceWrapper compareToWrapper = (MilestoneInvoiceWrapper)compareTo;
            
            // Get the dates from Cash_Flow__r.Date__c
            Date thisDate = this.milestoneInvoice.Cash_Flow__r.Date__c;
            Date compareDate = compareToWrapper.milestoneInvoice.Cash_Flow__r.Date__c;
            
            // Handle null dates
            if (thisDate == null && compareDate == null) {
                return 0; // Both null, consider equal
            }
            if (thisDate == null) {
                return 1; // Null dates sort last
            }
            if (compareDate == null) {
                return -1; // Null dates sort last
            }
            
            // Compare dates
            if (thisDate < compareDate) {
                return -1; // This date is earlier
            }
            if (thisDate > compareDate) {
                return 1; // This date is later
            }
            return 0; // Dates are equal
        }
    }
}