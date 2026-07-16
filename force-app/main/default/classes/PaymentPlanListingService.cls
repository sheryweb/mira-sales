@RestResource(urlMapping='/PaymentPlanListing/*')
global without sharing class PaymentPlanListingService {

    @HttpGet
    global static PaymentPlanResponseWrapper getPaymentPlan() {
        PaymentPlanResponseWrapper response = new PaymentPlanResponseWrapper();

        try {
            String unitId = RestContext.request.params.get('unitId');

            // Validate the UnitId parameter
            if (String.isBlank(unitId)) {
                response.success = false;
                response.message = 'UnitId parameter is required';
                return response;
            }

            // Query Cash_Flow__c records related to the Unit__c
            List<Cash_Flow__c> cashFlows = [
                SELECT Id, Name, Installment_Milestone__c, Date__c, Percent__c, 
                       Price_CHF__c, Price_Formula__c
                FROM Cash_Flow__c
                WHERE Unit__c = :unitId
                AND Name NOT IN ('Oqood', 'DLD Fee', 'Registration Fee', 'Purchase Taxes')
                ORDER BY Date__c ASC
            ];

            if (cashFlows.isEmpty()) {
                response.success = false;
                response.message = 'No payment plan found for the specified unit';
                return response;
            }

            // Create payment plan items
            List<PaymentPlanItem> paymentPlanItems = new List<PaymentPlanItem>();
            for (Cash_Flow__c cashFlow : cashFlows) {
                PaymentPlanItem item = new PaymentPlanItem();
                item.milestoneName = cashFlow.Name;
                item.installmentName = cashFlow.Installment_Milestone__c;
                item.installmentDate = cashFlow.Date__c;
                item.percentage = cashFlow.Percent__c;
                
                // Calculate amount based on the condition: If (Price_CHF__c == 0, Price_Formula__c, Price_CHF__c)
                if (cashFlow.Price_CHF__c == 0 || cashFlow.Price_CHF__c == null) {
                    item.amount = cashFlow.Price_Formula__c;
                } else {
                    item.amount = cashFlow.Price_CHF__c;
                }
                
                paymentPlanItems.add(item);
            }

            response.success = true;
            response.message = 'Payment plan retrieved successfully';
            response.paymentPlanItems = paymentPlanItems;

        } catch (Exception e) {
            response.success = false;
            response.message = 'Error: ' + e.getMessage();
        }

        return response;
    }

    global class PaymentPlanResponseWrapper {
        global Boolean success { get; set; }
        global String message { get; set; }
        global List<PaymentPlanItem> paymentPlanItems { get; set; }

        global PaymentPlanResponseWrapper() {
            this.success = false;
            this.message = '';
            this.paymentPlanItems = new List<PaymentPlanItem>();
        }
    }

    global class PaymentPlanItem {
        global String milestoneName {get; set;}
        global String installmentName { get; set; }
        global Date installmentDate { get; set; }
        global Decimal percentage { get; set; }
        global Decimal amount { get; set; }
    }
}