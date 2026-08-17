/**
 * Builds the MIRA Sales Report (Monthly + Weekly + Date Range): queries booked/sold/reserved
 * Opportunities for a period, applies shared-deal 50/50 splits (including
 * same-manager full credit), aggregates leaderboards, and renders dark-theme
 * HTML for Visualforce PDF generation.
 */
public with sharing class MonthlySalesReportService {
    // Include Booked / Sold / Reserved — filtered by booking date in the period, not "current stage = Booked only".
    public static final Set<String> REPORT_STAGES = new Set<String>{ 'Booked', 'Sold', 'Reserved' };
    // Keep each logical page under one A4 landscape sheet. Overflow + forced
    // page-break creates a blank physical page between content pages.
    @TestVisible private static final Integer PAGE_1_TRANSACTION_COUNT = 14;
    @TestVisible private static final Integer CONTINUED_PAGE_TRANSACTION_COUNT = 18;
    private static final String FOOTER_BRAND = 'Mira Developments | Confidential';
    // Test hook: force manager names by User Id (bypasses role mapping).
    @TestVisible private static Map<Id, String> managerNameByUserIdOverride;

    public class MonthlySalesReportException extends Exception {}

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    public static MonthlySalesReportModels.MonthlyReportDTO buildReport(Integer year, Integer month) {
        validatePeriod(year, month);
        Date startDate = Date.newInstance(year, month, 1);
        Date endDate = startDate.addMonths(1).addDays(-1);
        return buildReport(MonthlySalesReportModels.REPORT_TYPE_MONTHLY, startDate, endDate);
    }

    public static MonthlySalesReportModels.MonthlyReportDTO buildWeeklyReport(Date anyDateInWeek) {
        if (anyDateInWeek == null) {
            throw new MonthlySalesReportException('Provide a date within the reporting week.');
        }
        Date startDate = weekStartMonday(anyDateInWeek);
        Date endDate = startDate.addDays(6);
        return buildReport(MonthlySalesReportModels.REPORT_TYPE_WEEKLY, startDate, endDate);
    }

    public static MonthlySalesReportModels.MonthlyReportDTO buildDateRangeReport(
        Date startDate,
        Date endDate
    ) {
        return buildReport(MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE, startDate, endDate);
    }

    public static MonthlySalesReportModels.MonthlyReportDTO buildReport(
        String reportType,
        Date startDate,
        Date endDate
    ) {
        validateDateRange(startDate, endDate);
        String normalizedType = normalizeReportType(reportType);
        List<Opportunity> opportunities = queryOpportunities(startDate, endDate);
        return assembleReport(normalizedType, startDate, endDate, opportunities);
    }

    public static String buildReportHtml(Integer year, Integer month) {
        return renderHtml(buildReport(year, month));
    }

    public static String buildReportHtml(Date anyDateInWeek) {
        return renderHtml(buildWeeklyReport(anyDateInWeek));
    }

    public static String buildReportHtml(String reportType, Date startDate, Date endDate) {
        return renderHtml(buildReport(reportType, startDate, endDate));
    }

    /**
     * Generates a PDF via Visualforce getContentAsPDF for a monthly period.
     * @return base64-encoded PDF bytes
     */
    public static String generatePdf(Integer year, Integer month) {
        return EncodingUtil.base64Encode(renderPdfBlob(year, month));
    }

    /**
     * Generates a PDF via Visualforce getContentAsPDF for an explicit date range.
     * @return base64-encoded PDF bytes
     */
    public static String generatePdf(String reportType, Date startDate, Date endDate) {
        return EncodingUtil.base64Encode(renderPdfBlob(reportType, startDate, endDate));
    }

    /**
     * Renders PDF for a period and saves it as a Salesforce File.
     * Important: getContentAsPDF runs BEFORE any DML (Salesforce callout rule).
     * @return ContentDocumentId of the saved PDF
     */
    public static Id savePdfDocument(
        String reportType,
        Integer year,
        Integer month,
        String weekStartIso,
        String fileName
    ) {
        Blob pdfBlob = renderPdfBlobForRequest(reportType, year, month, weekStartIso);
        return insertPdfDocument(pdfBlob, fileName);
    }

    /**
     * Accepts pre-rendered HTML from LWC, stores it briefly as ContentVersion,
     * and renders PDF via the Visualforce page (htmlContentDocumentId param).
     * @return base64-encoded PDF bytes
     * @deprecated Prefer period-based generatePdf/savePdfDocument — HTML path
     *             requires DML before getContentAsPDF and fails in Lightning.
     */
    public static String generatePdfFromHtml(String htmlContent) {
        return EncodingUtil.base64Encode(renderPdfBlobFromHtml(htmlContent));
    }

    /**
     * @deprecated Prefer savePdfDocument(reportType,...) — same DML/callout issue.
     */
    public static Id savePdfDocumentFromHtml(String htmlContent, String fileName) {
        Blob pdfBlob = renderPdfBlobFromHtml(htmlContent);
        return insertPdfDocument(pdfBlob, fileName);
    }

    private static Blob renderPdfBlobForRequest(
        String reportType,
        Integer year,
        Integer month,
        String weekStartIso
    ) {
        String normalized = String.isBlank(reportType)
            ? MonthlySalesReportModels.REPORT_TYPE_MONTHLY
            : reportType;
        if (normalized.equalsIgnoreCase(MonthlySalesReportModels.REPORT_TYPE_WEEKLY)) {
            if (String.isBlank(weekStartIso)) {
                throw new MonthlySalesReportException(
                    'weekStartIso (yyyy-MM-dd) is required for weekly reports.'
                );
            }
            MonthlySalesReportModels.MonthlyReportDTO report =
                buildWeeklyReport(Date.valueOf(weekStartIso.trim()));
            return renderPdfBlob(
                MonthlySalesReportModels.REPORT_TYPE_WEEKLY,
                report.startDate,
                report.endDate
            );
        }
        return renderPdfBlob(year, month);
    }

    private static Blob renderPdfBlob(Integer year, Integer month) {
        validatePeriod(year, month);
        PageReference pdfPage = Page.MonthlySalesReportPDF;
        pdfPage.getParameters().put('reportType', MonthlySalesReportModels.REPORT_TYPE_MONTHLY);
        pdfPage.getParameters().put('year', String.valueOf(year));
        pdfPage.getParameters().put('month', String.valueOf(month));
        return Test.isRunningTest()
            ? Blob.valueOf('MONTHLY_SALES_REPORT_TEST_PDF')
            : pdfPage.getContentAsPDF();
    }

    private static Blob renderPdfBlob(String reportType, Date startDate, Date endDate) {
        validateDateRange(startDate, endDate);
        String normalizedType = normalizeReportType(reportType);
        PageReference pdfPage = Page.MonthlySalesReportPDF;
        pdfPage.getParameters().put('reportType', normalizedType);
        pdfPage.getParameters().put('startDate', String.valueOf(startDate));
        pdfPage.getParameters().put('endDate', String.valueOf(endDate));
        if (normalizedType == MonthlySalesReportModels.REPORT_TYPE_MONTHLY) {
            pdfPage.getParameters().put('year', String.valueOf(startDate.year()));
            pdfPage.getParameters().put('month', String.valueOf(startDate.month()));
        }
        return Test.isRunningTest()
            ? Blob.valueOf('SALES_REPORT_RANGE_TEST_PDF')
            : pdfPage.getContentAsPDF();
    }

    private static Id insertPdfDocument(Blob pdfBlob, String fileName) {
        String safeName = String.isBlank(fileName) ? 'MIRA_Sales_Report.pdf' : fileName.trim();
        if (!safeName.toLowerCase().endsWith('.pdf')) {
            safeName += '.pdf';
        }
        String title = safeName.substring(0, safeName.length() - 4);

        ContentVersion pdfCv = new ContentVersion(
            Title = title,
            PathOnClient = safeName,
            VersionData = pdfBlob,
            ContentLocation = 'S'
        );
        insert pdfCv;

        return [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :pdfCv.Id
            LIMIT 1
        ].ContentDocumentId;
    }

    /**
     * HTML-via-ContentDocument path. Only safe when no prior DML occurred, or in tests.
     * Lightning callers should use renderPdfBlobForRequest instead.
     */
    private static Blob renderPdfBlobFromHtml(String htmlContent) {
        if (String.isBlank(htmlContent)) {
            throw new MonthlySalesReportException('Report HTML is required to generate the PDF.');
        }

        ContentVersion cv = new ContentVersion(
            Title = 'MonthlySalesReportHtml_' + Datetime.now().getTime(),
            PathOnClient = 'monthly-sales-report.html',
            VersionData = Blob.valueOf(htmlContent),
            ContentLocation = 'S'
        );
        insert cv;

        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].ContentDocumentId;

        try {
            PageReference pdfPage = Page.MonthlySalesReportPDF;
            pdfPage.getParameters().put('htmlContentDocumentId', String.valueOf(contentDocumentId));
            return Test.isRunningTest()
                ? Blob.valueOf('MONTHLY_SALES_REPORT_HTML_PDF')
                : pdfPage.getContentAsPDF();
        } finally {
            delete new ContentDocument(Id = contentDocumentId);
        }
    }

    public static String loadHtmlFromContentDocument(Id contentDocumentId) {
        if (contentDocumentId == null) {
            return null;
        }
        ContentVersion cv = [
            SELECT VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            ORDER BY VersionNumber DESC
            LIMIT 1
        ];
        return cv.VersionData == null ? null : cv.VersionData.toString();
    }

    // -------------------------------------------------------------------------
    // Week helpers
    // -------------------------------------------------------------------------

    /**
     * Monday of the ISO week containing anyDate (1=Mon .. 7=Sun via Datetime.format('u')).
     */
    @TestVisible
    private static Date weekStartMonday(Date anyDate) {
        Datetime noon = Datetime.newInstance(anyDate.year(), anyDate.month(), anyDate.day(), 12, 0, 0);
        Integer isoDay = Integer.valueOf(noon.format('u'));
        return anyDate.addDays(1 - isoDay);
    }

    @TestVisible
    private static String weekPeriodLabel(Date startDate, Date endDate) {
        return formatDayMonthYear(startDate) + ' — ' + formatDayMonthYear(endDate);
    }

    private static String formatDayMonthYear(Date d) {
        if (d == null) {
            return '';
        }
        Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day(), 12, 0, 0);
        // e.g. "20 July 2026" (no leading zero on day when locale permits; force pattern)
        String day = String.valueOf(d.day());
        String monthYear = dt.format('MMMM yyyy');
        return day + ' ' + monthYear;
    }

    // -------------------------------------------------------------------------
    // Query
    // -------------------------------------------------------------------------

    @TestVisible
    private static List<Opportunity> queryOpportunities(Date startDate, Date endDate) {
        Datetime startDt = Datetime.newInstance(startDate.year(), startDate.month(), startDate.day(), 0, 0, 0);
        Date dayAfterEnd = endDate.addDays(1);
        Datetime endExclusive = Datetime.newInstance(
            dayAfterEnd.year(),
            dayAfterEnd.month(),
            dayAfterEnd.day(),
            0,
            0,
            0
        );
        return [
            SELECT Id, Name, StageName, Unit_Price__c, Unit__r.Cost_AED__c, Property_Code__c, Project_Name__c,
                   Agency_Name__c, Agency__c, Agency__r.Name,
                   OwnerId, Owner.Name, Owner.FirstName, Owner.LastName, Owner.UserRole.Name,
                   Manager_Name__c, Manager__c, Manager__r.Name,
                   Unit_Booked_Date_Only__c, Booking_Date_Time__c,
                   Share_Deal__c, Shared_RM__c,
                   Shared_RM__r.Name, Shared_RM__r.FirstName, Shared_RM__r.LastName,
                   Shared_RM__r.UserRole.Name,
                   Owner_Credit_Amount__c, Shared_RM_Credit_Amount__c,
                   (
                       SELECT Id, RM__c, RM_Name__c, Manager_Name__c, Credit_Percent__c,
                              Credit_Amount__c, Is_Primary__c, Deal_Type__c
                       FROM RM_Deal_Credits__r
                       ORDER BY Is_Primary__c DESC, RM_Name__c ASC
                   )
            FROM Opportunity
            WHERE StageName IN :REPORT_STAGES
              AND Booking_Date_Time__c >= :startDt
              AND Booking_Date_Time__c < :endExclusive
            ORDER BY Booking_Date_Time__c ASC, Property_Code__c ASC, Name ASC
        ];
    }

    // -------------------------------------------------------------------------
    // Assembly / shared-deal logic
    // -------------------------------------------------------------------------

    @TestVisible
    private static MonthlySalesReportModels.MonthlyReportDTO assembleReport(
        String reportType,
        Date startDate,
        Date endDate,
        List<Opportunity> opportunities
    ) {
        MonthlySalesReportModels.MonthlyReportDTO report = new MonthlySalesReportModels.MonthlyReportDTO();
        Boolean isWeekly = reportType == MonthlySalesReportModels.REPORT_TYPE_WEEKLY;
        Boolean isDateRange = reportType == MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE;

        report.reportType = reportType;
        if (isWeekly) {
            report.reportTitle = 'Sales Weekly Report';
            report.performanceTitle = 'Weekly Performance';
            report.periodGrainLabel = 'OF THE WEEK';
            report.periodLabel = weekPeriodLabel(startDate, endDate);
        } else if (isDateRange) {
            report.reportTitle = 'Sales Date Range Report';
            report.performanceTitle = 'Period Performance';
            report.periodGrainLabel = 'OF THE PERIOD';
            report.periodLabel = weekPeriodLabel(startDate, endDate);
        } else {
            report.reportTitle = 'Sales Monthly Report';
            report.performanceTitle = 'Monthly Performance';
            report.periodGrainLabel = 'OF THE MONTH';
            report.periodLabel = periodLabel(startDate.year(), startDate.month());
        }
        report.startDate = startDate;
        report.endDate = endDate;
        report.year = startDate.year();
        report.month = startDate.month();
        report.generatedDate = Date.today();
        report.generatedDateDisplay = formatLongDate(Date.today());
        report.page1TransactionCount = PAGE_1_TRANSACTION_COUNT;
        report.transactions = new List<MonthlySalesReportModels.TransactionDTO>();
        report.sharedDeals = new List<MonthlySalesReportModels.SharedDealDTO>();
        report.salesByProject = new List<MonthlySalesReportModels.ProjectSummaryDTO>();
        report.topTeams = new List<MonthlySalesReportModels.ManagerSummaryDTO>();

        if (opportunities == null) {
            opportunities = new List<Opportunity>();
        }

        Integer sharedFootnoteIndex = 0;
        Map<String, Decimal> projectUnits = new Map<String, Decimal>();
        Map<String, Decimal> projectValues = new Map<String, Decimal>();
        Map<String, Decimal> managerUnits = new Map<String, Decimal>();
        Map<String, Decimal> managerValues = new Map<String, Decimal>();
        Map<String, Decimal> rmUnits = new Map<String, Decimal>();
        Map<String, Decimal> rmValues = new Map<String, Decimal>();
        Map<String, String> rmManagerByName = new Map<String, String>();
        Map<String, Decimal> brokerUnits = new Map<String, Decimal>();
        Map<String, Decimal> brokerValues = new Map<String, Decimal>();

        Decimal totalValue = 0;
        Integer bookedCount = 0;
        Integer soldCount = 0;
        Integer reservedCount = 0;
        Set<String> projectNames = new Set<String>();

        for (Opportunity opp : opportunities) {
            Decimal unitPrice = resolveDealValue(opp);
            totalValue += unitPrice;

            String stage = opp.StageName == null ? '' : opp.StageName;
            if (stage == 'Booked') {
                bookedCount++;
            } else if (stage == 'Sold') {
                soldCount++;
            } else if (stage == 'Reserved') {
                reservedCount++;
            }

            String projectName = blankToDash(opp.Project_Name__c);
            if (String.isNotBlank(opp.Project_Name__c)) {
                projectNames.add(opp.Project_Name__c);
            }
            addDecimal(projectUnits, projectName, 1);
            addDecimal(projectValues, projectName, unitPrice);

            String agencyName = resolveAgencyName(opp);
            if (agencyName != '—') {
                addDecimal(brokerUnits, agencyName, 1);
                addDecimal(brokerValues, agencyName, unitPrice);
            }

            Boolean isShared = opp.Share_Deal__c == true && opp.Shared_RM__c != null;
            MonthlySalesReportModels.TransactionDTO txn = buildTransaction(opp, isShared);
            report.transactions.add(txn);

            if (isShared) {
                sharedFootnoteIndex++;
                String marker = footnoteMarker(sharedFootnoteIndex);
                txn.footnoteMarker = marker;

                MonthlySalesReportModels.SharedDealDTO shared = buildSharedDeal(opp, marker);
                report.sharedDeals.add(shared);
                txn.ownerDisplay = joinNames(sharedOwnerNames(opp)) + marker;
                txn.managerDisplay = joinNames(managerNamesForShared(opp, shared.sameManager)) + marker;
                txn.ownerNames = sharedOwnerNames(opp);
                txn.managerNames = managerNamesForShared(opp, shared.sameManager);

                for (MonthlySalesReportModels.CreditSplitDTO ownerCredit : shared.ownerCredits) {
                    addDecimal(rmUnits, ownerCredit.name, ownerCredit.unitCredit);
                    addDecimal(rmValues, ownerCredit.name, ownerCredit.creditAmount);
                }
                for (MonthlySalesReportModels.CreditSplitDTO managerCredit : shared.managerCredits) {
                    addDecimal(managerUnits, managerCredit.name, managerCredit.unitCredit);
                    addDecimal(managerValues, managerCredit.name, managerCredit.creditAmount);
                }

                List<String> owners = sharedOwnerNames(opp);
                List<String> managers = managerNamesForShared(opp, shared.sameManager);
                for (Integer i = 0; i < owners.size(); i++) {
                    String mgr = managers.isEmpty()
                        ? 'Not Assigned'
                        : (shared.sameManager ? managers[0] : (i < managers.size() ? managers[i] : managers[0]));
                    rmManagerByName.put(owners[i], mgr);
                }
            } else {
                String ownerName = formatUserName(opp.Owner);
                String managerName = resolveManagerName(opp);
                addDecimal(rmUnits, ownerName, 1);
                addDecimal(rmValues, ownerName, unitPrice);
                rmManagerByName.put(ownerName, managerName);
                addDecimal(managerUnits, managerName, 1);
                addDecimal(managerValues, managerName, unitPrice);
                txn.ownerNames = new List<String>{ ownerName };
                txn.managerNames = new List<String>{ managerName };
            }
        }

        report.totalSalesValue = totalValue.setScale(0, System.RoundingMode.HALF_UP);
        report.transactionCount = opportunities.size();
        report.unitsBooked = Decimal.valueOf(opportunities.size());
        report.projectCount = projectNames.size();
        report.projectsLabel = joinSorted(projectNames);
        report.bookedCount = bookedCount;
        report.soldCount = soldCount;
        report.reservedCount = reservedCount;
        report.bookingStatusLabel =
            bookedCount + ' Booked · ' + soldCount + ' Sold\n' + reservedCount + ' Reserved';

        report.salesByProject = buildProjectSummaries(projectUnits, projectValues, totalValue);
        report.topTeams = buildManagerLeaderboard(managerUnits, managerValues);
        report.topRm = buildTopRm(rmUnits, rmValues, rmManagerByName);
        report.topBroker = buildTopBroker(brokerUnits, brokerValues);
        return report;
    }

    private static MonthlySalesReportModels.TransactionDTO buildTransaction(
        Opportunity opp,
        Boolean isShared
    ) {
        MonthlySalesReportModels.TransactionDTO txn = new MonthlySalesReportModels.TransactionDTO();
        txn.opportunityId = opp.Id;
        txn.propertyCode = blankToDash(opp.Property_Code__c);
        txn.unitPrice = resolveDealValue(opp).setScale(0, System.RoundingMode.HALF_UP);
        txn.projectName = blankToDash(opp.Project_Name__c);
        txn.agencyName = resolveAgencyName(opp);
        txn.ownerDisplay = formatUserName(opp.Owner);
        txn.bookedDate = opp.Unit_Booked_Date_Only__c != null
            ? opp.Unit_Booked_Date_Only__c
            : (opp.Booking_Date_Time__c == null ? null : opp.Booking_Date_Time__c.date());
        txn.bookedDateDisplay = formatShortDate(txn.bookedDate);
        txn.managerDisplay = resolveManagerName(opp);
        txn.stageName = opp.StageName == null ? '' : opp.StageName.toUpperCase();
        txn.isSharedDeal = isShared;
        return txn;
    }

    /**
     * Shared-deal split rules:
     * - Owners always receive 50/50 value and 0.5 unit credit each.
     * - If owners report to different managers → managers also split 50/50.
     * - If owners report to the same manager → that manager receives full value and 1 unit.
     */
    private static MonthlySalesReportModels.SharedDealDTO buildSharedDeal(
        Opportunity opp,
        String marker
    ) {
        Decimal unitPrice = resolveDealValue(opp);
        Decimal halfValue = (unitPrice * 0.5).setScale(0, System.RoundingMode.HALF_UP);

        String ownerName = formatUserName(opp.Owner);
        String sharedRmName = formatUserName(opp.Shared_RM__r);
        String ownerManager = resolveManagerNameForUser(opp.Owner);
        String sharedManager = resolveManagerNameForUser(opp.Shared_RM__r);
        Boolean sameManager = ownerManager == sharedManager;

        MonthlySalesReportModels.SharedDealDTO shared = new MonthlySalesReportModels.SharedDealDTO();
        shared.opportunityId = opp.Id;
        shared.propertyCode = blankToDash(opp.Property_Code__c);
        shared.dealValue = unitPrice.setScale(0, System.RoundingMode.HALF_UP);
        shared.footnoteMarker = marker;
        shared.sameManager = sameManager;
        shared.ownerCredits = new List<MonthlySalesReportModels.CreditSplitDTO>{
            credit(ownerName, halfValue, 0.5, null),
            credit(sharedRmName, halfValue, 0.5, null)
        };

        if (sameManager) {
            shared.managerCredits = new List<MonthlySalesReportModels.CreditSplitDTO>{
                credit(ownerManager, unitPrice.setScale(0, System.RoundingMode.HALF_UP), 1, 'full, same manager')
            };
            shared.footnoteText =
                shared.propertyCode + ' is a shared deal between two owners (' +
                ownerName + ', ' + sharedRmName + ') under a single manager (' + ownerManager +
                '). Sales value and unit credit are split 50/50 between the two owners; the manager receives full credit since both owners report to the same manager.';
        } else {
            shared.managerCredits = new List<MonthlySalesReportModels.CreditSplitDTO>{
                credit(ownerManager, halfValue, 0.5, null),
                credit(sharedManager, halfValue, 0.5, null)
            };
            shared.footnoteText =
                shared.propertyCode + ' is a shared deal between two owners (' +
                ownerName + ', ' + sharedRmName + ') and two managers (' +
                ownerManager + ', ' + sharedManager +
                '). Sales value and unit credit are split 50/50 between both owners and both managers in the performance leaderboards below.';
        }
        return shared;
    }

    private static MonthlySalesReportModels.CreditSplitDTO credit(
        String name,
        Decimal amount,
        Decimal units,
        String note
    ) {
        MonthlySalesReportModels.CreditSplitDTO dto = new MonthlySalesReportModels.CreditSplitDTO();
        dto.name = name;
        dto.creditAmount = amount;
        dto.unitCredit = units;
        dto.note = note;
        return dto;
    }

    private static List<MonthlySalesReportModels.ProjectSummaryDTO> buildProjectSummaries(
        Map<String, Decimal> unitsByProject,
        Map<String, Decimal> valuesByProject,
        Decimal totalValue
    ) {
        List<MonthlySalesReportModels.ProjectSummaryDTO> rows =
            new List<MonthlySalesReportModels.ProjectSummaryDTO>();
        List<String> names = new List<String>(valuesByProject.keySet());
        names.sort(new ValueDescComparator(valuesByProject));

        for (String name : names) {
            MonthlySalesReportModels.ProjectSummaryDTO row =
                new MonthlySalesReportModels.ProjectSummaryDTO();
            row.projectName = name;
            row.units = nullToZero(unitsByProject.get(name));
            row.totalValue = nullToZero(valuesByProject.get(name)).setScale(0, System.RoundingMode.HALF_UP);
            row.shareOfSalesPercent = totalValue == 0
                ? 0
                : ((row.totalValue / totalValue) * 100).setScale(2, System.RoundingMode.HALF_UP);
            rows.add(row);
        }
        return rows;
    }

    private static List<MonthlySalesReportModels.ManagerSummaryDTO> buildManagerLeaderboard(
        Map<String, Decimal> unitsByManager,
        Map<String, Decimal> valuesByManager
    ) {
        List<String> names = new List<String>(valuesByManager.keySet());
        names.sort(new ValueDescComparator(valuesByManager));

        List<MonthlySalesReportModels.ManagerSummaryDTO> rows =
            new List<MonthlySalesReportModels.ManagerSummaryDTO>();
        Integer rank = 1;
        for (String name : names) {
            if (name == 'Not Assigned') {
                continue;
            }
            MonthlySalesReportModels.ManagerSummaryDTO row =
                new MonthlySalesReportModels.ManagerSummaryDTO();
            row.managerName = name;
            row.units = nullToZero(unitsByManager.get(name));
            row.totalValue = nullToZero(valuesByManager.get(name)).setScale(0, System.RoundingMode.HALF_UP);
            row.rank = rank++;
            rows.add(row);
        }
        return rows;
    }

    private static MonthlySalesReportModels.RMSummaryDTO buildTopRm(
        Map<String, Decimal> unitsByRm,
        Map<String, Decimal> valuesByRm,
        Map<String, String> rmManagerByName
    ) {
        if (valuesByRm.isEmpty()) {
            return null;
        }
        List<String> names = new List<String>(valuesByRm.keySet());
        names.sort(new ValueDescComparator(valuesByRm));
        String topName = names[0];

        MonthlySalesReportModels.RMSummaryDTO top = new MonthlySalesReportModels.RMSummaryDTO();
        top.rmName = topName;
        top.managerName = rmManagerByName.containsKey(topName)
            ? rmManagerByName.get(topName)
            : 'Not Assigned';
        top.units = nullToZero(unitsByRm.get(topName));
        top.totalValue = nullToZero(valuesByRm.get(topName)).setScale(0, System.RoundingMode.HALF_UP);
        top.rank = 1;
        return top;
    }

    private static MonthlySalesReportModels.BrokerSummaryDTO buildTopBroker(
        Map<String, Decimal> unitsByBroker,
        Map<String, Decimal> valuesByBroker
    ) {
        if (valuesByBroker.isEmpty()) {
            return null;
        }
        List<String> names = new List<String>(valuesByBroker.keySet());
        names.sort(new ValueDescComparator(valuesByBroker));
        String topName = names[0];

        MonthlySalesReportModels.BrokerSummaryDTO top = new MonthlySalesReportModels.BrokerSummaryDTO();
        top.agencyName = topName;
        top.units = nullToZero(unitsByBroker.get(topName));
        top.totalValue = nullToZero(valuesByBroker.get(topName)).setScale(0, System.RoundingMode.HALF_UP);
        top.rank = 1;
        return top;
    }

    // -------------------------------------------------------------------------
    // HTML renderer (dark theme, VF / Flying Saucer table layout)
    // -------------------------------------------------------------------------

    public static String renderHtml(MonthlySalesReportModels.MonthlyReportDTO report) {
        if (report == null) {
            return '';
        }
        Boolean isWeekly = report.reportType == MonthlySalesReportModels.REPORT_TYPE_WEEKLY;
        return isWeekly ? renderWeeklyHtml(report) : renderMonthlyHtml(report);
    }

    private static String renderMonthlyHtml(MonthlySalesReportModels.MonthlyReportDTO report) {
        Integer page1Capacity = report.page1TransactionCount == null
            ? PAGE_1_TRANSACTION_COUNT
            : report.page1TransactionCount;
        List<MonthlySalesReportModels.TransactionDTO> allTxns =
            report.transactions == null
                ? new List<MonthlySalesReportModels.TransactionDTO>()
                : report.transactions;

        List<MonthlySalesReportModels.TransactionDTO> page1Txns =
            new List<MonthlySalesReportModels.TransactionDTO>();
        List<List<MonthlySalesReportModels.TransactionDTO>> continuedPages =
            new List<List<MonthlySalesReportModels.TransactionDTO>>();

        for (Integer i = 0; i < allTxns.size(); i++) {
            if (i < page1Capacity) {
                page1Txns.add(allTxns[i]);
            } else {
                Integer continuedIndex = i - page1Capacity;
                Integer pageIndex = continuedIndex / CONTINUED_PAGE_TRANSACTION_COUNT;
                while (continuedPages.size() <= pageIndex) {
                    continuedPages.add(new List<MonthlySalesReportModels.TransactionDTO>());
                }
                continuedPages[pageIndex].add(allTxns[i]);
            }
        }

        // Drop empty continued chunks (defensive)
        List<List<MonthlySalesReportModels.TransactionDTO>> continuedNonEmpty =
            new List<List<MonthlySalesReportModels.TransactionDTO>>();
        for (List<MonthlySalesReportModels.TransactionDTO> chunk : continuedPages) {
            if (chunk != null && !chunk.isEmpty()) {
                continuedNonEmpty.add(chunk);
            }
        }

        Integer txnPageCount = 1 + continuedNonEmpty.size();
        Integer totalPages = txnPageCount + 1; // + performance page
        // Footnotes on a full continued page overflow → blank spill page. Keep them on
        // page 1 only when everything fits there; otherwise on the performance page.
        Boolean footnotesOnPage1 = continuedNonEmpty.isEmpty();
        Boolean footnotesOnPerformance = !footnotesOnPage1;

        List<String> parts = new List<String>();
        parts.add('<!DOCTYPE html><html><head><meta charset="utf-8"/>');
        parts.add('<style type="text/css">' + reportCss() + '</style></head><body>');
        parts.add(renderTransactionPage(
            report,
            page1Txns,
            false,
            1,
            totalPages,
            true,
            footnotesOnPage1,
            false
        ));

        for (Integer p = 0; p < continuedNonEmpty.size(); p++) {
            parts.add(renderTransactionPage(
                report,
                continuedNonEmpty[p],
                true,
                p + 2,
                totalPages,
                false,
                false,
                false
            ));
        }

        parts.add(renderPerformancePage(report, totalPages, totalPages, footnotesOnPerformance));
        parts.add('</body></html>');
        return String.join(parts, '');
    }

    private static String renderWeeklyHtml(MonthlySalesReportModels.MonthlyReportDTO report) {
        List<String> parts = new List<String>();
        parts.add('<!DOCTYPE html><html><head><meta charset="utf-8"/>');
        parts.add('<style type="text/css">' + reportCss() + '</style></head><body>');
        parts.add('<div class="page page-weekly">');
        parts.add(renderHeader(report, report.reportTitle));
        parts.add(renderKpiCards(report));
        parts.add(renderSectionTitle('TRANSACTION DETAILS'));
        parts.add(renderTransactionTable(report.transactions));
        parts.add(renderTopThreeSideBySide(report));
        parts.add(renderSectionTitle('SALES BY PROJECT'));
        parts.add(renderSalesByProjectTable(report, true));
        if (report.sharedDeals != null && !report.sharedDeals.isEmpty()) {
            parts.add(renderFootnotes(report));
        }
        parts.add(renderFooter(report, 1, 1));
        parts.add('</div></body></html>');
        return String.join(parts, '');
    }

    private static String renderTransactionPage(
        MonthlySalesReportModels.MonthlyReportDTO report,
        List<MonthlySalesReportModels.TransactionDTO> txns,
        Boolean continued,
        Integer pageNumber,
        Integer totalPages,
        Boolean includeKpis,
        Boolean includeFootnotes,
        Boolean isLastPage
    ) {
        String titleSuffix = continued ? ' ( CONTINUED )' : '';
        List<String> parts = new List<String>();
        // page-break-after on non-last pages (explicit class — :last-child is unreliable in Flying Saucer).
        // Avoid page-break-before: when a page slightly overflows, before + spill = blank sheet.
        String pageClass = isLastPage == true ? 'page page-last' : 'page page-break-after';
        parts.add('<div class="' + pageClass + '">');
        parts.add(renderHeader(report, report.reportTitle));
        // Match shared PDF: KPI strip under header on page 1, then transactions.
        if (includeKpis) {
            parts.add(renderKpiCards(report));
        }
        parts.add(renderSectionTitle('TRANSACTION DETAILS' + titleSuffix));
        parts.add(renderTransactionTable(txns));

        if (includeFootnotes && report.sharedDeals != null && !report.sharedDeals.isEmpty()) {
            parts.add(renderFootnotes(report));
        }

        parts.add(renderFooter(report, pageNumber, totalPages));
        parts.add('</div>');
        return String.join(parts, '');
    }

    private static String renderTransactionTable(List<MonthlySalesReportModels.TransactionDTO> txns) {
        List<String> parts = new List<String>();
        parts.add('<table class="txn-table">');
        parts.add('<thead><tr>');
        parts.add('<th class="col-code">PROPERTY CODE</th>');
        parts.add('<th class="col-price">UNIT PRICE<br/>(AED)</th>');
        parts.add('<th class="col-project">PROJECT</th>');
        parts.add('<th class="col-agency">AGENCY</th>');
        parts.add('<th class="col-owner">OWNER (RM)</th>');
        parts.add('<th class="col-date">BOOKED<br/>DATE</th>');
        parts.add('<th class="col-manager">MANAGER</th>');
        parts.add('<th class="col-stage">STAGE</th>');
        parts.add('</tr></thead><tbody>');

        if (txns != null) {
            for (MonthlySalesReportModels.TransactionDTO txn : txns) {
                parts.add('<tr>');
                parts.add('<td class="col-code">');
                parts.add('<div class="prop-code-cell">');
                parts.add('<div class="prop-code">' + escape(txn.propertyCode) + '</div>');
                if (txn.isSharedDeal == true) {
                    parts.add(roundedPill('SHARED DEAL', '#4C1D95', '#C4B5FD'));
                }
                parts.add('</div>');
                parts.add('</td>');
                parts.add('<td class="col-price num gold">' + formatNumber(txn.unitPrice) + '</td>');
                parts.add('<td class="col-project cyan">' + escape(txn.projectName) + '</td>');
                parts.add('<td class="col-agency">' + escape(txn.agencyName) + '</td>');
                parts.add('<td class="col-owner">' + escape(txn.ownerDisplay) + '</td>');
                parts.add('<td class="col-date">' + escape(txn.bookedDateDisplay) + '</td>');
                parts.add('<td class="col-manager">' + escape(txn.managerDisplay) + '</td>');
                parts.add('<td class="col-stage">' + stagePill(txn.stageName) + '</td>');
                parts.add('</tr>');
            }
        }
        parts.add('</tbody></table>');
        return String.join(parts, '');
    }

    private static String stagePill(String stageName) {
        String stage = stageName == null ? '' : stageName.toUpperCase();
        if (stage == 'BOOKED') {
            return roundedPill(stage, '#064E3B', '#34D399');
        }
        if (stage == 'SOLD') {
            return roundedPill(stage, '#0C4A6E', '#38BDF8');
        }
        if (stage == 'RESERVED') {
            return roundedPill(stage, '#78350F', '#FBBF24');
        }
        return roundedPill(stage, '#1F2937', '#E5E7EB');
    }

    /** Inline styles for pills — VF PDF ignores border-radius but keeps layout clean (no images). */
    private static String roundedPill(String label, String bgColor, String textColor) {
        return '<span class="stage-pill" style="'
            + 'display:inline-block;'
            + 'width:72px;'
            + 'min-width:72px;'
            + 'max-width:72px;'
            + 'box-sizing:border-box;'
            + 'text-align:center;'
            + 'background-color:' + bgColor + ';'
            + 'color:' + textColor + ';'
            + 'padding:3px 0;'
            + 'font-size:7px;'
            + 'font-weight:700;'
            + 'letter-spacing:0.6px;'
            + 'white-space:nowrap;'
            + 'border-radius:10px;'
            + '-webkit-border-radius:10px;'
            + '">' + escape(label) + '</span>';
    }

    private static String renderKpiCards(MonthlySalesReportModels.MonthlyReportDTO report) {
        List<String> parts = new List<String>();
        // Fixed-height row so all four cards stay equal in PDF (content no longer drives height).
        parts.add('<table class="kpi-table" cellpadding="0" cellspacing="0"><tr valign="top">');

        parts.add('<td class="kpi-cell" width="25%" height="88">');
        parts.add(kpiCardShell(
            '#FBBF24',
            '<div class="kpi-label">TOTAL SALES VALUE</div>'
                + '<div class="kpi-value">AED ' + formatNumber(report.totalSalesValue) + '</div>'
                + '<div class="kpi-sub">Across ' + formatNumber(report.transactionCount) + ' transactions</div>'
        ));
        parts.add('</td>');

        parts.add('<td class="kpi-gap" width="1%">&nbsp;</td>');

        parts.add('<td class="kpi-cell" width="25%" height="88">');
        parts.add(kpiCardShell(
            '#38BDF8',
            '<div class="kpi-label">UNITS BOOKED</div>'
                + '<div class="kpi-value cyan">' + formatNumber(report.unitsBooked) + '</div>'
                + '<div class="kpi-sub">Booked&nbsp;·&nbsp;Sold&nbsp;·&nbsp;Reserved</div>'
        ));
        parts.add('</td>');

        parts.add('<td class="kpi-gap" width="1%">&nbsp;</td>');

        parts.add('<td class="kpi-cell" width="25%" height="88">');
        parts.add(kpiCardShell(
            '#34D399',
            '<div class="kpi-label">PROJECTS</div>'
                + '<div class="kpi-value">' + formatNumber(report.projectCount) + '</div>'
                + '<div class="kpi-sub">' + escape(report.projectsLabel) + '</div>'
        ));
        parts.add('</td>');

        parts.add('<td class="kpi-gap" width="1%">&nbsp;</td>');

        parts.add('<td class="kpi-cell" width="25%" height="88">');
        String statusBody = '<div class="kpi-label">BOOKING STATUS</div>'
            + '<div class="kpi-value-sm">'
            + '<span class="status-booked">' + formatNumber(report.bookedCount) + '&nbsp;Booked</span>'
            + '&nbsp;·&nbsp;'
            + '<span class="status-sold">' + formatNumber(report.soldCount) + '&nbsp;Sold</span>'
            + '&nbsp;·&nbsp;'
            + '<span class="status-reserved">' + formatNumber(report.reservedCount) + '&nbsp;Reserved</span>'
            + '</div>';
        parts.add(kpiCardShell('#A855F7', statusBody));
        parts.add('</td>');

        parts.add('</tr></table>');
        return String.join(parts, '');
    }

    /** Fixed-height card — equal KPI heights in VF PDF (no images). */
    private static String kpiCardShell(String accentColor, String bodyHtml) {
        return '<table class="kpi-card card-shell" width="100%" cellpadding="0" cellspacing="0" height="88" style="'
            + 'width:100%;height:88px;background-color:#172640;border:1px solid #24344F;'
            + 'border-collapse:separate;border-spacing:0;border-radius:12px;-webkit-border-radius:12px;'
            + 'overflow:hidden;">'
            + '<tr><td height="3" style="height:3px;font-size:0;line-height:0;padding:0;border:none;'
            + 'background-color:' + accentColor + ';"></td></tr>'
            + '<tr><td class="kpi-body-cell" height="85" valign="top" style="'
            + 'height:85px;padding:8px 10px;background-color:#172640;vertical-align:top;border:none;">'
            + bodyHtml + '</td></tr>'
            + '</table>';
    }

    private static String renderFootnotes(MonthlySalesReportModels.MonthlyReportDTO report) {
        List<String> parts = new List<String>();
        parts.add('<div class="footnotes">');
        for (MonthlySalesReportModels.SharedDealDTO shared : report.sharedDeals) {
            parts.add('<p><span class="fn-mark">' + escape(shared.footnoteMarker) + '</span> ');
            parts.add(escape(shared.footnoteText) + '</p>');
        }
        parts.add('</div>');
        return String.join(parts, '');
    }

    private static String renderPerformancePage(
        MonthlySalesReportModels.MonthlyReportDTO report,
        Integer pageNumber,
        Integer totalPages
    ) {
        return renderPerformancePage(report, pageNumber, totalPages, false);
    }

    private static String renderPerformancePage(
        MonthlySalesReportModels.MonthlyReportDTO report,
        Integer pageNumber,
        Integer totalPages,
        Boolean includeFootnotes
    ) {
        String emptyShared = report.reportType == MonthlySalesReportModels.REPORT_TYPE_WEEKLY
            ? 'No shared deals this week'
            : (report.reportType == MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE
                ? 'No shared deals in this period'
                : 'No shared deals this month');

        List<String> parts = new List<String>();
        parts.add('<div class="page page-last">');
        parts.add(renderHeader(report, report.performanceTitle));

        parts.add(renderSectionTitle('SALES BY PROJECT'));
        parts.add(renderSalesByProjectTable(report, false));

        parts.add(renderSectionTitle('TARGET SPLIT — SHARED DEALS'));
        parts.add('<table class="perf-table shared-split-table">');
        parts.add('<thead><tr><th>DEAL</th><th class="num">VALUE (AED)</th><th>OWNER CREDIT</th><th>MANAGER CREDIT</th></tr></thead><tbody>');
        if (report.sharedDeals != null && !report.sharedDeals.isEmpty()) {
            for (MonthlySalesReportModels.SharedDealDTO shared : report.sharedDeals) {
                parts.add('<tr>');
                parts.add('<td><span class="prop-code">' + escape(shared.propertyCode) + '</span></td>');
                parts.add('<td class="num gold">' + formatNumber(shared.dealValue) + '</td>');
                parts.add('<td>' + escape(formatCreditList(shared.ownerCredits)) + '</td>');
                parts.add('<td>' + escape(formatCreditList(shared.managerCredits)) + '</td>');
                parts.add('</tr>');
            }
        } else {
            parts.add('<tr><td colspan="4" class="empty">' + emptyShared + '</td></tr>');
        }
        parts.add('</tbody></table>');

        parts.add(renderTopThreeSideBySide(report));
        if (includeFootnotes == true && report.sharedDeals != null && !report.sharedDeals.isEmpty()) {
            parts.add(renderFootnotes(report));
        }
        parts.add(renderFooter(report, pageNumber, totalPages));
        parts.add('</div>');
        return String.join(parts, '');
    }

    private static String renderSalesByProjectTable(
        MonthlySalesReportModels.MonthlyReportDTO report,
        Boolean compact
    ) {
        List<String> parts = new List<String>();
        parts.add('<table class="perf-table' + (compact ? ' compact' : '') + '">');
        parts.add('<thead><tr><th>PROJECT</th><th class="num">UNITS</th><th class="num">TOTAL VALUE (AED)</th><th class="num">SHARE OF SALES</th></tr></thead><tbody>');
        if (report.salesByProject != null) {
            for (MonthlySalesReportModels.ProjectSummaryDTO row : report.salesByProject) {
                parts.add('<tr>');
                parts.add('<td class="cyan">' + escape(row.projectName) + '</td>');
                parts.add('<td class="num cyan">' + formatNumber(row.units) + '</td>');
                parts.add('<td class="num gold">' + formatNumber(row.totalValue) + '</td>');
                parts.add('<td class="num">' + formatPercent(row.shareOfSalesPercent) + '</td>');
                parts.add('</tr>');
            }
        }
        parts.add('</tbody></table>');
        return String.join(parts, '');
    }

    private static String renderTopThreeSideBySide(MonthlySalesReportModels.MonthlyReportDTO report) {
        String grain = String.isBlank(report.periodGrainLabel) ? 'OF THE MONTH' : report.periodGrainLabel;
        List<String> parts = new List<String>();
        parts.add('<table class="top-three-table" cellpadding="0" cellspacing="0"><tr valign="top">');

        parts.add('<td class="top-cell" width="32%" height="118">');
        parts.add(topCardShell(
            'top-shell-team',
            '<div class="section-title section-title-sm">TOP TEAM ' + escape(grain) + '</div>'
                + renderTopTeamTable(report)
        ));
        parts.add('</td>');

        parts.add('<td class="top-gap" width="2%">&nbsp;</td>');

        parts.add('<td class="top-cell" width="32%" height="118">');
        String rmBody = '<div class="section-title section-title-sm">TOP RM ' + escape(grain) + '</div>';
        if (report.topRm != null) {
            rmBody += '<div class="spotlight">'
                + '<div class="spotlight-name">' + escape(report.topRm.rmName) + '</div>'
                + '<table class="spotlight-stats"><tr><th>UNITS</th><th>VALUE (AED)</th></tr>'
                + '<tr><td class="num cyan">' + formatNumber(report.topRm.units) + '</td>'
                + '<td class="num gold">' + formatNumber(report.topRm.totalValue) + '</td></tr></table>'
                + '<div class="spotlight-caption">Manager ' + escape(report.topRm.managerName) + '</div>'
                + '</div>';
        } else {
            rmBody += '<div class="empty">No RM data</div>';
        }
        parts.add(topCardShell('top-shell-rm', rmBody));
        parts.add('</td>');

        parts.add('<td class="top-gap" width="2%">&nbsp;</td>');

        parts.add('<td class="top-cell" width="32%" height="118">');
        String brokerBody = '<div class="section-title section-title-sm">TOP BROKER ' + escape(grain) + '</div>';
        if (report.topBroker != null) {
            brokerBody += '<div class="spotlight">'
                + '<div class="spotlight-name">' + escape(report.topBroker.agencyName) + '</div>'
                + '<table class="spotlight-stats"><tr><th>UNITS</th><th>VALUE (AED)</th></tr>'
                + '<tr><td class="num cyan">' + formatNumber(report.topBroker.units) + '</td>'
                + '<td class="num gold">' + formatNumber(report.topBroker.totalValue) + '</td></tr></table>'
                + '<div class="spotlight-caption">Leading agency by total sales value</div>'
                + '</div>';
        } else {
            brokerBody += '<div class="empty">No broker data</div>';
        }
        parts.add(topCardShell('top-shell-broker', brokerBody));
        parts.add('</td>');

        parts.add('</tr></table>');
        return String.join(parts, '');
    }

    private static String topCardShell(String topClass, String bodyHtml) {
        String topBorder = '#FBBF24';
        if (topClass != null && topClass.contains('rm')) {
            topBorder = '#38BDF8';
        } else if (topClass != null && topClass.contains('broker')) {
            topBorder = '#34D399';
        }
        return '<table class="top-card card-shell ' + topClass + '" width="100%" cellpadding="0" cellspacing="0" height="118" style="'
            + 'width:100%;height:118px;background-color:#172640;border:1px solid #24344F;'
            + 'border-top:3px solid ' + topBorder + ';'
            + 'border-collapse:separate;border-spacing:0;border-radius:12px;-webkit-border-radius:12px;'
            + 'overflow:hidden;">'
            + '<tr><td class="top-card-inner" height="118" valign="top" style="'
            + 'height:118px;padding:10px 12px;background-color:#172640;vertical-align:top;border:none;">'
            + bodyHtml + '</td></tr>'
            + '</table>';
    }

    private static String renderTopTeamTable(MonthlySalesReportModels.MonthlyReportDTO report) {
        List<String> parts = new List<String>();
        parts.add('<table class="leaderboard-table">');
        if (report.topTeams != null && !report.topTeams.isEmpty()) {
            for (MonthlySalesReportModels.ManagerSummaryDTO team : report.topTeams) {
                parts.add('<tr>');
                parts.add('<td class="lb-name">' + escape(team.managerName) + '</td>');
                parts.add('<td class="num cyan">' + formatNumber(team.units) + '</td>');
                parts.add('<td class="num gold">' + formatNumber(team.totalValue) + '</td>');
                parts.add('</tr>');
            }
        } else {
            parts.add('<tr><td class="empty" colspan="3">No team data</td></tr>');
        }
        parts.add('</table>');
        return String.join(parts, '');
    }

    private static String renderHeader(MonthlySalesReportModels.MonthlyReportDTO report, String subtitle) {
        List<String> parts = new List<String>();
        parts.add('<div class="header">');
        parts.add('<table class="header-table"><tr>');
        parts.add('<td class="brand-block">');
        parts.add('<div class="brand">MIRA DEVELOPMENTS</div>');
        parts.add('<div class="subtitle">' + escape(subtitle) + '</div>');
        parts.add('</td>');
        parts.add('<td class="period-block">');
        parts.add(renderPeriodBadge(report.periodLabel));
        parts.add('</td>');
        parts.add('</tr></table>');
        parts.add(renderAccentLine());
        parts.add('</div>');
        return String.join(parts, '');
    }

    private static String renderPeriodBadge(String periodLabel) {
        return '<div class="period-badge" style="'
            + 'display:inline-block;text-align:left;padding:8px 14px;'
            + 'background-color:#16233A;border:1px solid #38BDF8;'
            + 'border-radius:12px;-webkit-border-radius:12px;">'
            + '<div class="period-label">REPORTING PERIOD</div>'
            + '<div class="period-value">' + escape(periodLabel) + '</div>'
            + '</div>';
    }

    private static String renderSectionTitle(String title) {
        return '<div class="section-title">' + escape(title) + '</div>' + renderAccentLine();
    }

    /** Multi-cell strip — reliable in Visualforce PDF (no CSS gradients). */
    private static String renderAccentLine() {
        return '<table class="accent-line" cellpadding="0" cellspacing="0"><tr>'
            + '<td class="al al1"></td><td class="al al2"></td><td class="al al3"></td>'
            + '<td class="al al4"></td><td class="al al5"></td><td class="al al6"></td>'
            + '</tr></table>';
    }

    private static String renderFooter(
        MonthlySalesReportModels.MonthlyReportDTO report,
        Integer pageNumber,
        Integer totalPages
    ) {
        List<String> parts = new List<String>();
        parts.add('<div class="footer">');
        parts.add('<table class="footer-table"><tr>');
        parts.add('<td>' + FOOTER_BRAND + '</td>');
        parts.add('<td class="footer-right">Generated ' + escape(report.generatedDateDisplay));
        parts.add(' · Page ' + String.valueOf(pageNumber) + ' of ' + String.valueOf(totalPages) + '</td>');
        parts.add('</tr></table>');
        parts.add('</div>');
        return String.join(parts, '');
    }

    private static String reportCss() {
        List<String> css = new List<String>();
        css.add('@page { size: A4 landscape; margin: 10mm; background-color: #0A1625; }');
        css.add('html { background-color: #0A1625 !important; }');
        css.add('html, body { font-family: Arial, Helvetica, sans-serif; font-size: 9px;');
        css.add(' color: #E5E7EB; background-color: #0A1625 !important; margin: 0; padding: 0;');
        css.add(' width: 100%; }');
        // Browser print / Save as PDF (MonthlySalesReportPrint) — keep dark fills.
        css.add('*, *::before, *::after { -webkit-print-color-adjust: exact !important;');
        css.add(' print-color-adjust: exact !important; color-adjust: exact !important; }');
        css.add('.print-toolbar { position: fixed; top: 10px; right: 12px; z-index: 9999;');
        css.add(' background: #172640; border: 1px solid #38BDF8; border-radius: 10px;');
        css.add(' padding: 10px 14px; color: #E5E7EB; font-size: 12px; max-width: 320px;');
        css.add(' box-shadow: 0 4px 16px rgba(0,0,0,0.35); }');
        css.add('.print-toolbar button { display: block; width: 100%; margin-bottom: 8px;');
        css.add(' background: #38BDF8; color: #0A1625; border: none; border-radius: 8px;');
        css.add(' padding: 8px 12px; font-weight: 700; cursor: pointer; font-size: 13px; }');
        css.add('.print-toolbar span { display: block; line-height: 1.35; color: #9CA3AF;');
        css.add(' font-size: 11px; }');
        css.add('@media print { .no-print, .print-toolbar { display: none !important; }');
        css.add(' body { background-color: #0A1625 !important; } }');
        css.add('.page { position: relative; background-color: #0A1625 !important; color: #E5E7EB;');
        css.add(' padding: 8mm 8mm 8mm 8mm; margin: 0; }');
        css.add('.page-break-after { page-break-after: always; }');
        css.add('.page-last { page-break-after: auto; page-break-before: auto; }');
        css.add('.page-weekly { page-break-before: auto; page-break-after: auto; }');
        css.add('.header { margin-bottom: 8px; }');
        css.add('.header-table { width: 100%; border-collapse: collapse; }');
        css.add('.brand-block { vertical-align: middle; width: 62%; }');
        css.add('.period-block { text-align: right; vertical-align: middle; width: 38%; }');
        css.add('.brand { font-size: 11px; font-weight: 700; letter-spacing: 3.5px;');
        css.add(' text-transform: uppercase; color: #9CA3AF; }');
        css.add('.subtitle { font-size: 18px; margin-top: 4px; color: #FFFFFF; font-weight: 700; }');
        // Pills / cards: border-radius works in browser print; ignored by Flying Saucer PDF.
        css.add('.period-badge { display: inline-block; text-align: left; padding: 8px 14px;');
        css.add(' background-color: #16233A; border: 1px solid #38BDF8;');
        css.add(' border-radius: 12px; -webkit-border-radius: 12px; }');
        css.add('.period-label { font-size: 7px; letter-spacing: 1.8px; color: #9CA3AF;');
        css.add(' text-transform: uppercase; margin-bottom: 2px; }');
        css.add('.period-value { font-size: 13px; font-weight: 700; color: #FFFFFF; }');
        css.add('.stage-pill { display: inline-block; width: 72px; min-width: 72px; max-width: 72px;');
        css.add(' box-sizing: border-box; text-align: center; padding: 3px 0; font-size: 7px;');
        css.add(' font-weight: 700; letter-spacing: 0.6px; white-space: nowrap;');
        css.add(' border-radius: 10px; -webkit-border-radius: 10px; }');
        css.add('.accent-line { width: 100%; border-collapse: collapse; margin: 8px 0 10px;');
        css.add(' height: 2px; }');
        css.add('.accent-line .al { height: 2px; font-size: 0; line-height: 0; padding: 0;');
        css.add(' border: none; }');
        css.add('.al1 { width: 16%; background-color: #A855F7; }');
        css.add('.al2 { width: 17%; background-color: #6366F1; }');
        css.add('.al3 { width: 17%; background-color: #3B82F6; }');
        css.add('.al4 { width: 17%; background-color: #38BDF8; }');
        css.add('.al5 { width: 17%; background-color: #22D3EE; }');
        css.add('.al6 { width: 16%; background-color: #34D399; }');
        css.add('.section-title { font-size: 9px; font-weight: 700; letter-spacing: 2.8px;');
        css.add(' margin: 10px 0 4px; text-transform: uppercase; color: #9CA3AF; }');
        css.add('.section-title-sm { font-size: 8px; margin: 0 0 8px; letter-spacing: 2px; color: #9CA3AF; }');
        css.add('.card-shell { background-color: #172640; border: 1px solid #24344F;');
        css.add(' border-radius: 12px; -webkit-border-radius: 12px; }');
        css.add('.kpi-card { width: 100%; height: 88px; background-color: #172640;');
        css.add(' border: 1px solid #24344F; border-collapse: separate; border-spacing: 0;');
        css.add(' border-radius: 12px; -webkit-border-radius: 12px; overflow: hidden; }');
        css.add('.kpi-body-cell { height: 85px; padding: 8px 10px; background-color: #172640;');
        css.add(' vertical-align: top; border: none; }');
        css.add('.top-card { width: 100%; height: 118px; background-color: #172640;');
        css.add(' border: 1px solid #24344F; border-collapse: separate; border-spacing: 0;');
        css.add(' border-radius: 12px; -webkit-border-radius: 12px; overflow: hidden; }');
        css.add('.top-shell-team { border-top: 3px solid #FBBF24; }');
        css.add('.top-shell-rm { border-top: 3px solid #38BDF8; }');
        css.add('.top-shell-broker { border-top: 3px solid #34D399; }');
        css.add('table { width: 100%; border-collapse: collapse; }');
        css.add('.txn-table { width: 100%; border-collapse: collapse; }');
        css.add('.txn-table th { background-color: #0F1C33; font-size: 7.5px; letter-spacing: 0.9px;');
        css.add(' text-align: left; color: #9CA3AF; border-bottom: 1px solid #24344F;');
        css.add(' border-top: none; border-left: none; border-right: none; padding: 4px 5px; }');
        css.add('.txn-table td { background-color: transparent; color: #E5E7EB;');
        css.add(' border-bottom: 1px solid #132035; border-top: none; border-left: none;');
        css.add(' border-right: none; padding: 4px 5px; vertical-align: top; }');
        css.add('.perf-table th, .spotlight-stats th { background-color: #0F1C33; font-size: 7.5px;');
        css.add(' letter-spacing: 0.8px; text-align: left; color: #9CA3AF;');
        css.add(' border: 1px solid #24344F; padding: 5px; }');
        css.add('.perf-table td, .spotlight-stats td, .leaderboard-table td {');
        css.add(' background-color: #172640; color: #E5E7EB; border: 1px solid #24344F;');
        css.add(' padding: 5px; vertical-align: top; }');
        css.add('.num { text-align: right; white-space: nowrap; }');
        css.add('.gold { color: #FBBF24; }');
        css.add('.cyan { color: #38BDF8; }');
        css.add('.prop-code { color: #FBBF24; font-weight: 700; display: block; }');
        css.add('.prop-code-cell { display: block; }');
        css.add('.col-code { width: 11%; } .col-price { width: 10%; } .col-project { width: 15%; }');
        css.add('.col-agency { width: 15%; } .col-owner { width: 15%; } .col-date { width: 9%; }');
        css.add('.col-manager { width: 14%; } .col-stage { width: 11%; text-align: center; }');
        css.add('.kpi-table { width: 100%; table-layout: fixed; border-collapse: collapse;');
        css.add(' margin: 6px 0 10px; }');
        css.add('.kpi-gap { width: 8px; background-color: #0A1625; border: none; padding: 0; }');
        css.add('.kpi-cell { vertical-align: top; padding: 0; background-color: transparent;');
        css.add(' border: none; height: 88px; }');
        css.add('.kpi-label { font-size: 7.5px; letter-spacing: 1.4px; font-weight: 700;');
        css.add(' margin-bottom: 6px; color: #9CA3AF; text-transform: uppercase; }');
        css.add('.kpi-value { font-size: 15px; font-weight: 700; color: #FFFFFF; line-height: 1.2; }');
        css.add('.kpi-value-sm { font-size: 11px; font-weight: 700; color: #FFFFFF; line-height: 1.3;');
        css.add(' white-space: nowrap; }');
        css.add('.kpi-sub { font-size: 7px; color: #9CA3AF; margin-top: 4px; line-height: 1.25;');
        css.add(' height: 18px; overflow: hidden; }');
        css.add('.status-booked { color: #34D399; }');
        css.add('.status-sold { color: #38BDF8; }');
        css.add('.status-reserved { color: #FBBF24; }');
        css.add('.footnotes { margin-top: 12px; font-size: 7.5px; line-height: 1.4; color: #9CA3AF; }');
        css.add('.footnotes p { margin: 0 0 6px; }');
        css.add('.fn-mark { font-weight: 700; color: #FBBF24; }');
        css.add('.top-three-table { width: 100%; table-layout: fixed; border-collapse: collapse;');
        css.add(' margin-top: 14px; }');
        css.add('.top-gap { width: 8px; background-color: #0A1625; border: none; padding: 0; }');
        css.add('.top-cell { width: 32%; vertical-align: top; padding: 0; border: none;');
        css.add(' background-color: transparent; height: 118px; }');
        css.add('.top-card-inner { padding: 10px 12px; height: 118px;');
        css.add(' background-color: #172640; vertical-align: top; border: none; }');
        css.add('.leaderboard-table { width: 100%; margin-bottom: 0; }');
        css.add('.leaderboard-table td { border: 1px solid #24344F; padding: 5px 6px;');
        css.add(' background-color: #0F1C33; }');
        css.add('.lb-name { font-weight: 700; color: #FFFFFF; }');
        css.add('.spotlight { padding: 2px 0; }');
        css.add('.spotlight-name { font-size: 14px; font-weight: 700; margin-bottom: 8px; color: #FFFFFF; }');
        css.add('.spotlight-stats { width: 100%; margin-bottom: 6px; }');
        css.add('.spotlight-caption { font-size: 8px; color: #9CA3AF; }');
        css.add('.shared-split-table td { font-size: 8px; }');
        css.add('.perf-table.compact th, .perf-table.compact td { padding: 3px 4px; }');
        css.add('.empty { color: #9CA3AF; font-style: italic; padding: 6px; }');
        css.add('.footer { margin-top: 8px; padding-top: 6px; border-top: 1px solid #24344F;');
        css.add(' font-size: 7.5px; color: #9CA3AF; }');
        css.add('.footer-table { width: 100%; border-collapse: collapse; }');
        css.add('.footer-right { text-align: right; }');
        return String.join(css, '');
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private static String normalizeReportType(String reportType) {
        if (String.isBlank(reportType)
            || reportType.equalsIgnoreCase(MonthlySalesReportModels.REPORT_TYPE_MONTHLY)) {
            return MonthlySalesReportModels.REPORT_TYPE_MONTHLY;
        }
        if (reportType.equalsIgnoreCase(MonthlySalesReportModels.REPORT_TYPE_WEEKLY)) {
            return MonthlySalesReportModels.REPORT_TYPE_WEEKLY;
        }
        if (reportType.equalsIgnoreCase(MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE)) {
            return MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE;
        }
        throw new MonthlySalesReportException(
            'Report type must be Monthly, Weekly, or Date Range. Received: ' + reportType
        );
    }

    private static void validatePeriod(Integer year, Integer month) {
        if (year == null || month == null || month < 1 || month > 12 || year < 2000 || year > 2100) {
            throw new MonthlySalesReportException('Provide a valid year and month (1-12).');
        }
    }

    private static void validateDateRange(Date startDate, Date endDate) {
        if (startDate == null || endDate == null) {
            throw new MonthlySalesReportException('Start date and end date are required.');
        }
        if (endDate < startDate) {
            throw new MonthlySalesReportException('End date must be on or after start date.');
        }
    }

    private static String periodLabel(Integer year, Integer month) {
        Datetime dt = Datetime.newInstance(year, month, 1, 0, 0, 0);
        return dt.format('MMMM yyyy');
    }

    private static String formatLongDate(Date d) {
        if (d == null) {
            return '';
        }
        Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day(), 0, 0, 0);
        return dt.format('dd MMM yyyy');
    }

    private static String formatShortDate(Date d) {
        if (d == null) {
            return '—';
        }
        Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day(), 0, 0, 0);
        return dt.format('dd MMM yyyy');
    }

    private static String formatNumber(Decimal value) {
        if (value == null) {
            return '0';
        }
        Decimal scaled = value.stripTrailingZeros();
        String raw = scaled.toPlainString();
        Boolean negative = raw.startsWith('-');
        if (negative) {
            raw = raw.substring(1);
        }
        List<String> parts = raw.split('\\.');
        String intPart = parts[0];
        String frac = parts.size() > 1 ? parts[1] : null;

        String formatted = '';
        Integer count = 0;
        for (Integer i = intPart.length() - 1; i >= 0; i--) {
            formatted = intPart.substring(i, i + 1) + formatted;
            count++;
            if (count == 3 && i > 0) {
                formatted = ',' + formatted;
                count = 0;
            }
        }
        if (frac != null) {
            formatted += '.' + frac;
        }
        return negative ? '-' + formatted : formatted;
    }

    private static String formatPercent(Decimal value) {
        if (value == null) {
            return '0%';
        }
        return formatNumber(value) + '%';
    }

    private static String formatCreditList(List<MonthlySalesReportModels.CreditSplitDTO> credits) {
        if (credits == null || credits.isEmpty()) {
            return '—';
        }
        List<String> parts = new List<String>();
        for (MonthlySalesReportModels.CreditSplitDTO c : credits) {
            String unitPart = formatNumber(c.unitCredit) + ' unit';
            if (String.isNotBlank(c.note)) {
                unitPart += ' — ' + c.note;
            }
            parts.add(c.name + ': ' + formatNumber(c.creditAmount) + ' (' + unitPart + ')');
        }
        return String.join(parts, ' | ');
    }

    private static String footnoteMarker(Integer index) {
        String marker = '';
        for (Integer i = 0; i < index; i++) {
            marker += '*';
        }
        return marker;
    }

    private static List<String> sharedOwnerNames(Opportunity opp) {
        return new List<String>{ formatUserName(opp.Owner), formatUserName(opp.Shared_RM__r) };
    }

    private static List<String> managerNamesForShared(Opportunity opp, Boolean sameManager) {
        String ownerManager = resolveManagerNameForUser(opp.Owner);
        String sharedManager = resolveManagerNameForUser(opp.Shared_RM__r);
        if (sameManager) {
            return new List<String>{ ownerManager };
        }
        return new List<String>{ ownerManager, sharedManager };
    }

    private static String joinNames(List<String> names) {
        if (names == null || names.isEmpty()) {
            return '—';
        }
        return String.join(names, ' & ');
    }

    private static String resolveAgencyName(Opportunity opp) {
        if (opp.Agency__r != null && String.isNotBlank(opp.Agency__r.Name)) {
            return opp.Agency__r.Name;
        }
        if (String.isNotBlank(opp.Agency_Name__c)) {
            return opp.Agency_Name__c;
        }
        return '—';
    }

    /**
     * Sales report values are always AED via Unit.Cost_AED__c for every project
     * (including POST / MIRA VERDE, whose Opportunity.Unit_Price__c may be CHF/USD).
     */
    private static Decimal resolveDealValue(Opportunity opp) {
        if (opp == null || opp.Unit__r == null) {
            return 0;
        }
        return nullToZero(opp.Unit__r.Cost_AED__c);
    }

    private static String resolveManagerName(Opportunity opp) {
        if (String.isNotBlank(opp.Manager_Name__c)) {
            return opp.Manager_Name__c;
        }
        return resolveManagerNameForUser(opp.Owner);
    }

    private static String resolveManagerNameForUser(User u) {
        if (u == null) {
            return 'Not Assigned';
        }
        if (managerNameByUserIdOverride != null && managerNameByUserIdOverride.containsKey(u.Id)) {
            return managerNameByUserIdOverride.get(u.Id);
        }
        String roleName = u.UserRole == null ? null : u.UserRole.Name;
        return RMDealCreditService.getManagerNameForRole(roleName);
    }

    private static String formatUserName(User u) {
        if (u == null) {
            return '—';
        }
        String first = u.FirstName == null ? '' : u.FirstName.trim();
        String last = u.LastName == null ? '' : u.LastName.trim();
        String full = (first + ' ' + last).trim();
        return String.isNotBlank(full) ? full : (String.isNotBlank(u.Name) ? u.Name : '—');
    }

    private static String joinSorted(Set<String> values) {
        if (values == null || values.isEmpty()) {
            return '—';
        }
        List<String> listVals = new List<String>(values);
        listVals.sort();
        return String.join(listVals, ', ');
    }

    private static void addDecimal(Map<String, Decimal> target, String key, Decimal amount) {
        if (String.isBlank(key) || amount == null) {
            return;
        }
        Decimal current = target.containsKey(key) ? target.get(key) : 0;
        target.put(key, current + amount);
    }

    private static Decimal nullToZero(Decimal value) {
        return value == null ? 0 : value;
    }

    private static String blankToDash(String value) {
        return String.isBlank(value) ? '—' : value;
    }

    private static String escape(String value) {
        if (value == null) {
            return '';
        }
        return value
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;');
    }

    /**
     * Sort map keys by associated Decimal value descending; tie-break by name ascending.
     */
    private class ValueDescComparator implements System.Comparator<String> {
        private Map<String, Decimal> valuesByKey;
        ValueDescComparator(Map<String, Decimal> valuesByKey) {
            this.valuesByKey = valuesByKey;
        }
        public Integer compare(String a, String b) {
            Decimal va = valuesByKey.containsKey(a) ? valuesByKey.get(a) : 0;
            Decimal vb = valuesByKey.containsKey(b) ? valuesByKey.get(b) : 0;
            if (va == vb) {
                return a.compareTo(b);
            }
            return va > vb ? -1 : 1;
        }
    }
}
