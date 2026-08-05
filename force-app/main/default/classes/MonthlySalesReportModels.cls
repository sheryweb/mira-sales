/**
 * DTOs for the MIRA Sales Report (Monthly + Weekly).
 * Mirrors July 2026 monthly / 20–26 July weekly report structures.
 */
public with sharing class MonthlySalesReportModels {
    public static final String REPORT_TYPE_MONTHLY = 'Monthly';
    public static final String REPORT_TYPE_WEEKLY = 'Weekly';

    public class TransactionDTO {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String propertyCode;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public String projectName;
        @AuraEnabled public String agencyName;
        @AuraEnabled public String ownerDisplay;
        @AuraEnabled public String bookedDateDisplay;
        @AuraEnabled public Date bookedDate;
        @AuraEnabled public String managerDisplay;
        @AuraEnabled public String stageName;
        @AuraEnabled public Boolean isSharedDeal;
        @AuraEnabled public String footnoteMarker;
        @AuraEnabled public List<String> ownerNames;
        @AuraEnabled public List<String> managerNames;
    }

    public class CreditSplitDTO {
        @AuraEnabled public String name;
        @AuraEnabled public Decimal creditAmount;
        @AuraEnabled public Decimal unitCredit;
        @AuraEnabled public String note;
    }

    public class SharedDealDTO {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String propertyCode;
        @AuraEnabled public Decimal dealValue;
        @AuraEnabled public List<CreditSplitDTO> ownerCredits;
        @AuraEnabled public List<CreditSplitDTO> managerCredits;
        @AuraEnabled public String footnoteMarker;
        @AuraEnabled public String footnoteText;
        @AuraEnabled public Boolean sameManager;
    }

    public class ProjectSummaryDTO {
        @AuraEnabled public String projectName;
        @AuraEnabled public Decimal units;
        @AuraEnabled public Decimal totalValue;
        @AuraEnabled public Decimal shareOfSalesPercent;
    }

    public class ManagerSummaryDTO {
        @AuraEnabled public String managerName;
        @AuraEnabled public Decimal units;
        @AuraEnabled public Decimal totalValue;
        @AuraEnabled public Integer rank;
    }

    public class RMSummaryDTO {
        @AuraEnabled public String rmName;
        @AuraEnabled public String managerName;
        @AuraEnabled public Decimal units;
        @AuraEnabled public Decimal totalValue;
        @AuraEnabled public Integer rank;
    }

    public class BrokerSummaryDTO {
        @AuraEnabled public String agencyName;
        @AuraEnabled public Decimal units;
        @AuraEnabled public Decimal totalValue;
        @AuraEnabled public Integer rank;
    }

    public class MonthlyReportDTO {
        @AuraEnabled public String reportType;
        @AuraEnabled public String reportTitle;
        @AuraEnabled public String performanceTitle;
        @AuraEnabled public String periodGrainLabel;
        @AuraEnabled public Integer year;
        @AuraEnabled public Integer month;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String periodLabel;
        @AuraEnabled public Date generatedDate;
        @AuraEnabled public String generatedDateDisplay;
        @AuraEnabled public Decimal totalSalesValue;
        @AuraEnabled public Integer transactionCount;
        @AuraEnabled public Decimal unitsBooked;
        @AuraEnabled public Integer projectCount;
        @AuraEnabled public String projectsLabel;
        @AuraEnabled public Integer bookedCount;
        @AuraEnabled public Integer soldCount;
        @AuraEnabled public Integer reservedCount;
        @AuraEnabled public String bookingStatusLabel;
        @AuraEnabled public List<TransactionDTO> transactions;
        @AuraEnabled public List<SharedDealDTO> sharedDeals;
        @AuraEnabled public List<ProjectSummaryDTO> salesByProject;
        @AuraEnabled public List<ManagerSummaryDTO> topTeams;
        @AuraEnabled public RMSummaryDTO topRm;
        @AuraEnabled public BrokerSummaryDTO topBroker;
        @AuraEnabled public Integer page1TransactionCount;
    }
}
