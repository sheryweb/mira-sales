public class PaymentPlanWrapper {
    public String numberOfPlan {get; set;}
    public String milestone {get; set;}
    public String percent {get; set;}
    public String paymentDate {get; set;}
    public String amount {get; set;}
    public String amountUSD {get; set;}
    public String amountEUR {get; set;}
    public String amountRUB {get; set;}
    public String amountGBP {get; set;}
    public String amountCHF {get; set;}
    public String amountAED {get; set;}
    public PaymentPlanWrapper(String numberOfPlan, String milestone, String percent, String paymentDate, String amount, String amountUSD, String amountEUR, String amountRUB, String amountGBP, String amountCHF, String amountAED) {
        this.numberOfPlan = numberOfPlan;
        this.milestone = milestone;
        this.percent = percent;
        this.paymentDate = paymentDate;
        this.amount = amount;
        this.amountUSD = amountUSD;
        this.amountEUR = amountEUR;
        this.amountRUB = amountRUB;
        this.amountGBP = amountGBP;
        this.amountCHF = amountCHF;
        this.amountAED = amountAED;
    }
}