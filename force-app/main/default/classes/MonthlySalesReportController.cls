/**
 * Aura-enabled entry points for the MIRA Sales Report LWC (Monthly + Weekly + Date Range).
 */
public with sharing class MonthlySalesReportController {
    /**
     * @param reportType Monthly, Weekly, or Date Range (blank defaults to Monthly)
     * @param year month/year for Monthly
     * @param month month/year for Monthly
     * @param weekStartIso yyyy-MM-dd any date in the week (Weekly)
     * @param startDateIso yyyy-MM-dd range start (Date Range)
     * @param endDateIso yyyy-MM-dd range end (Date Range)
     */
    @AuraEnabled(cacheable=true)
    public static MonthlySalesReportModels.MonthlyReportDTO getReportData(
        String reportType,
        Integer year,
        Integer month,
        String weekStartIso,
        String startDateIso,
        String endDateIso
    ) {
        try {
            return resolveReport(reportType, year, month, weekStartIso, startDateIso, endDateIso);
        } catch (Exception e) {
            throw auraError(e, 'Failed to build sales report');
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getReportHtml(
        String reportType,
        Integer year,
        Integer month,
        String weekStartIso,
        String startDateIso,
        String endDateIso
    ) {
        try {
            return MonthlySalesReportService.renderHtml(
                resolveReport(reportType, year, month, weekStartIso, startDateIso, endDateIso)
            );
        } catch (Exception e) {
            throw auraError(e, 'Failed to render sales report HTML');
        }
    }

    /**
     * Server-side PDF generation for a reporting period (Visualforce getContentAsPDF).
     * @return base64-encoded PDF
     */
    @AuraEnabled
    public static String generatePdf(
        String reportType,
        Integer year,
        Integer month,
        String weekStartIso,
        String startDateIso,
        String endDateIso
    ) {
        try {
            String normalized = String.isBlank(reportType)
                ? MonthlySalesReportModels.REPORT_TYPE_MONTHLY
                : reportType;
            if (normalized.equalsIgnoreCase(MonthlySalesReportModels.REPORT_TYPE_WEEKLY)) {
                Date anyDate = parseIsoDate(weekStartIso, 'weekStartIso');
                if (anyDate == null) {
                    throw new MonthlySalesReportService.MonthlySalesReportException(
                        'weekStartIso (yyyy-MM-dd) is required for weekly reports.'
                    );
                }
                MonthlySalesReportModels.MonthlyReportDTO report =
                    MonthlySalesReportService.buildWeeklyReport(anyDate);
                return MonthlySalesReportService.generatePdf(
                    MonthlySalesReportModels.REPORT_TYPE_WEEKLY,
                    report.startDate,
                    report.endDate
                );
            }
            if (normalized.equalsIgnoreCase(MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE)) {
                Date startDate = parseIsoDate(startDateIso, 'startDateIso');
                Date endDate = parseIsoDate(endDateIso, 'endDateIso');
                if (startDate == null || endDate == null) {
                    throw new MonthlySalesReportService.MonthlySalesReportException(
                        'startDateIso and endDateIso (yyyy-MM-dd) are required for date range reports.'
                    );
                }
                return MonthlySalesReportService.generatePdf(
                    MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE,
                    startDate,
                    endDate
                );
            }
            return MonthlySalesReportService.generatePdf(year, month);
        } catch (Exception e) {
            throw auraError(e, 'Failed to generate sales report PDF');
        }
    }

    /**
     * Accepts HTML rendered by the LWC and converts it to PDF via generatePdfFromHtml().
     * @return base64-encoded PDF
     */
    @AuraEnabled
    public static String generatePdfFromHtml(String htmlContent) {
        try {
            return MonthlySalesReportService.generatePdfFromHtml(htmlContent);
        } catch (Exception e) {
            throw auraError(e, 'Failed to generate PDF from HTML');
        }
    }

    /**
     * Renders PDF for the selected period and saves it as a Salesforce File.
     * Uses getContentAsPDF before any DML so Lightning downloads work.
     * @return ContentDocumentId for /sfc/servlet.shepherd/document/download/{id}
     */
    @AuraEnabled
    public static Id savePdfDocument(
        String reportType,
        Integer year,
        Integer month,
        String weekStartIso,
        String fileName
    ) {
        try {
            return MonthlySalesReportService.savePdfDocument(
                reportType,
                year,
                month,
                weekStartIso,
                fileName
            );
        } catch (Exception e) {
            throw auraError(e, 'Failed to save sales report PDF');
        }
    }

    /**
     * @deprecated Prefer savePdfDocument — HTML path DML blocks getContentAsPDF in Lightning.
     */
    @AuraEnabled
    public static Id savePdfDocumentFromHtml(String htmlContent, String fileName) {
        try {
            return MonthlySalesReportService.savePdfDocumentFromHtml(htmlContent, fileName);
        } catch (Exception e) {
            throw auraError(e, 'Failed to save sales report PDF');
        }
    }

    private static MonthlySalesReportModels.MonthlyReportDTO resolveReport(
        String reportType,
        Integer year,
        Integer month,
        String weekStartIso,
        String startDateIso,
        String endDateIso
    ) {
        String normalized = String.isBlank(reportType)
            ? MonthlySalesReportModels.REPORT_TYPE_MONTHLY
            : reportType;

        if (normalized.equalsIgnoreCase(MonthlySalesReportModels.REPORT_TYPE_WEEKLY)) {
            Date anyDate = parseIsoDate(weekStartIso, 'weekStartIso');
            if (anyDate == null) {
                throw new MonthlySalesReportService.MonthlySalesReportException(
                    'weekStartIso (yyyy-MM-dd) is required for weekly reports.'
                );
            }
            return MonthlySalesReportService.buildWeeklyReport(anyDate);
        }

        if (normalized.equalsIgnoreCase(MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE)) {
            Date startDate = parseIsoDate(startDateIso, 'startDateIso');
            Date endDate = parseIsoDate(endDateIso, 'endDateIso');
            if (startDate == null || endDate == null) {
                throw new MonthlySalesReportService.MonthlySalesReportException(
                    'startDateIso and endDateIso (yyyy-MM-dd) are required for date range reports.'
                );
            }
            return MonthlySalesReportService.buildDateRangeReport(startDate, endDate);
        }

        return MonthlySalesReportService.buildReport(year, month);
    }

    private static Date parseIsoDate(String iso, String fieldLabel) {
        if (String.isBlank(iso)) {
            return null;
        }
        try {
            // Accept yyyy-MM-dd
            return Date.valueOf(iso.trim());
        } catch (Exception e) {
            throw new MonthlySalesReportService.MonthlySalesReportException(
                fieldLabel + ' must be yyyy-MM-dd. Received: ' + iso
            );
        }
    }

    private static AuraHandledException auraError(Exception e, String fallbackPrefix) {
        String message = e.getMessage();
        if (!(e instanceof MonthlySalesReportService.MonthlySalesReportException)) {
            message = fallbackPrefix + ': ' + message;
        }
        // Salesforce often strips AuraHandledException message unless setMessage is used.
        AuraHandledException ahe = new AuraHandledException(message);
        ahe.setMessage(message);
        return ahe;
    }
}
