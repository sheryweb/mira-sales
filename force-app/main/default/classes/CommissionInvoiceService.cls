public class CommissionInvoiceService {

    public class CommissionInvoiceException extends Exception {}

    public static Id generateInvoice(Id commissionId) {
        return generateInvoice(commissionId, null);
    }

    public static Id generateInvoice(Id commissionId, Id financialDetailId) {
        if (commissionId == null) {
            throw new CommissionInvoiceException('Commission Id is required.');
        }

        List<Commission__c> matches = [
            SELECT Id, Status__c, Unit__c, Project_Name__c, Commission_Amount__c, Invoice__c,
                   Agency__c, Opportunity__c, Paid_Amount__c, Total_Commission_Amount__c
            FROM Commission__c
            WHERE Id = :commissionId
            LIMIT 1
        ];
        if (matches.isEmpty()) {
            throw new CommissionInvoiceException('Commission not found: ' + commissionId);
        }
        Commission__c c = matches[0];

        if (c.Invoice__c != null) {
            throw new CommissionInvoiceException('Commission already has an invoice (' + c.Invoice__c + ').');
        }
        if (c.Status__c == 'Cancelled' || c.Status__c == 'On Hold') {
            throw new CommissionInvoiceException('Cannot generate invoice: Commission is ' + c.Status__c + '.');
        }
        if (c.Commission_Amount__c == null || c.Commission_Amount__c <= 0) {
            throw new CommissionInvoiceException('Commission Amount must be greater than 0 to generate an invoice.');
        }

        Decimal paidSoFar = (c.Paid_Amount__c != null) ? c.Paid_Amount__c : 0;
        Decimal totalForStatus = (c.Total_Commission_Amount__c != null && c.Total_Commission_Amount__c > 0)
            ? c.Total_Commission_Amount__c
            : c.Commission_Amount__c;
        String backfillStatus = null;
        if (paidSoFar > 0) {
            backfillStatus = (paidSoFar >= totalForStatus - 0.005) ? 'Fully Paid' : 'Partially Paid';
        }

        Invoice__c inv = new Invoice__c(
            Unit__c = c.Unit__c,
            Account__c = c.Agency__c,
            Opportunity__c = c.Opportunity__c,
            Sub_Total_Amount__c = c.Commission_Amount__c,
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today().addDays(30),
            Type__c = 'Commission',
            Paid_Amount__c = paidSoFar > 0 ? paidSoFar : null,
            Status__c = backfillStatus,
            Financial_Detail__c = financialDetailId
        );
        insert inv;

        c.Invoice__c = inv.Id;
        c.Invoice_Generated_Date__c = Date.today();
        update c;

        return inv.Id;
    }

    public static void markPaid(Id commissionId) {
        markPaid(commissionId, Date.today(), null, null);
    }

    public static void markPaid(Id commissionId, Date paymentDate) {
        markPaid(commissionId, paymentDate, null, null);
    }

    public static void markPaid(Id commissionId, Date paymentDate, Decimal paymentAmount) {
        markPaid(commissionId, paymentDate, paymentAmount, null);
    }

    public static void markPaid(Id commissionId, Date paymentDate, Decimal paymentAmount, String paymentMethod) {
        if (commissionId == null) {
            throw new CommissionInvoiceException('Commission Id is required.');
        }

        List<Commission__c> matches = [
            SELECT Id, Status__c, Invoice__c, Commission_Amount__c,
                   Total_Commission_Amount__c, Paid_Amount__c, Unit__c
            FROM Commission__c
            WHERE Id = :commissionId
            LIMIT 1
        ];
        if (matches.isEmpty()) {
            throw new CommissionInvoiceException('Commission not found: ' + commissionId);
        }
        Commission__c c = matches[0];

        if (c.Status__c == 'Fully Paid') {
            throw new CommissionInvoiceException('Commission is already Fully Paid.');
        }
        if (c.Status__c == 'Cancelled' || c.Status__c == 'On Hold') {
            throw new CommissionInvoiceException('Cannot record payment: Commission is ' + c.Status__c + '.');
        }
        if (c.Commission_Amount__c == null || c.Commission_Amount__c <= 0) {
            throw new CommissionInvoiceException('Commission Amount must be greater than 0 to record a payment.');
        }

        Decimal totalAmount = (c.Total_Commission_Amount__c != null && c.Total_Commission_Amount__c > 0)
            ? c.Total_Commission_Amount__c
            : c.Commission_Amount__c;
        Decimal previousPaid = (c.Paid_Amount__c != null) ? c.Paid_Amount__c : 0;
        Decimal remaining = totalAmount - previousPaid;

        Decimal effectivePayment = (paymentAmount != null) ? paymentAmount : remaining;
        if (effectivePayment <= 0) {
            throw new CommissionInvoiceException('Payment Amount must be greater than 0.');
        }
        if (effectivePayment > remaining + 0.005) {
            throw new CommissionInvoiceException(
                'Payment Amount (' + effectivePayment.setScale(2) +
                ') exceeds the remaining balance (' + remaining.setScale(2) + ').'
            );
        }

        Decimal newCumulative = previousPaid + effectivePayment;
        Boolean isFullyPaid = (newCumulative >= totalAmount - 0.005);
        String invoiceStatus = isFullyPaid ? 'Fully Paid' : 'Partially Paid';

        if (c.Invoice__c != null) {
            update new Invoice__c(
                Id = c.Invoice__c,
                Paid_Amount__c = newCumulative,
                Status__c = invoiceStatus
            );
        }

        c.Paid_Amount__c = newCumulative;
        c.Payment_Date__c = (paymentDate != null) ? paymentDate : Date.today();
        if (String.isNotBlank(paymentMethod)) {
            c.Payment_Method__c = paymentMethod;
        }
        update c;
    }
}