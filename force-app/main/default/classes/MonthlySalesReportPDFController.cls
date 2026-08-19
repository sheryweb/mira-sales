/**
 * Visualforce controller for Sales Report printable HTML / legacy PDF page.
 * Supports year/month, reportType + startDate/endDate (Date Range), weekStartIso (Weekly),
 * or HTML from ContentDocument (legacy path).
 *
 * MonthlySalesReportPrint (no renderAs) injects a print toolbar + window.print().
 * MonthlySalesReportPDF (renderAs=pdf) keeps the legacy Flying Saucer path unused by LWC.
 */
public with sharing class MonthlySalesReportPDFController {
    public String htmlContent { get; private set; }

    public MonthlySalesReportPDFController() {
        String contentDocumentId = ApexPages.currentPage().getParameters().get('htmlContentDocumentId');
        if (String.isBlank(contentDocumentId)) {
            htmlContent = buildHtmlFromParams();
        } else {
            htmlContent = MonthlySalesReportService.loadHtmlFromContentDocument(
                (Id) contentDocumentId
            );
        }

        if (isPrintPage()) {
            htmlContent = injectPrintBootstrap(htmlContent);
        }
    }

    private static String buildHtmlFromParams() {
        String reportType = ApexPages.currentPage().getParameters().get('reportType');
        String weekStartIso = ApexPages.currentPage().getParameters().get('weekStartIso');
        Id ownerId = parseOwnerIdParam();
        Date startDate = parseDateParam('startDate');
        Date endDate = parseDateParam('endDate');

        if (String.isNotBlank(weekStartIso)
            || (String.isNotBlank(reportType)
                && reportType.equalsIgnoreCase(MonthlySalesReportModels.REPORT_TYPE_WEEKLY))) {
            Date anyDate = parseDateParam('weekStartIso');
            if (anyDate == null) {
                anyDate = startDate;
            }
            if (anyDate == null) {
                anyDate = Date.today();
            }
            return MonthlySalesReportService.buildReportHtml(anyDate, ownerId);
        }

        if (startDate != null && endDate != null) {
            String type = String.isBlank(reportType)
                ? MonthlySalesReportModels.REPORT_TYPE_MONTHLY
                : reportType;
            return MonthlySalesReportService.buildReportHtml(type, startDate, endDate, ownerId);
        }

        Integer year = parseIntParam('year');
        Integer month = parseIntParam('month');
        if (year == null || month == null) {
            Date today = Date.today();
            year = today.year();
            month = today.month();
        }
        return MonthlySalesReportService.buildReportHtml(year, month, ownerId);
    }

    private static Boolean isPrintPage() {
        String url = ApexPages.currentPage().getUrl();
        return url != null && url.toLowerCase().contains('monthlysalesreportprint');
    }

    /**
     * Adds a print toolbar and auto-opens the browser print dialog (Save as PDF).
     * Injected before </body> so the full HTML document stays valid.
     */
    @TestVisible
    private static String injectPrintBootstrap(String html) {
        if (String.isBlank(html)) {
            return html;
        }
        String toolbar =
            '<div class="print-toolbar no-print">'
            + '<button type="button" onclick="window.print()">Print / Save as PDF</button>'
            + '<span>Choose “Save as PDF” in the print dialog. Dark theme needs background graphics enabled.</span>'
            + '</div>';
        String script =
            '<script type="text/javascript">'
            + 'window.addEventListener("load",function(){'
            + 'setTimeout(function(){try{window.print();}catch(e){}},350);'
            + '});'
            + '</script>';
        Integer bodyClose = html.toLowerCase().lastIndexOf('</body>');
        if (bodyClose >= 0) {
            return html.substring(0, bodyClose) + toolbar + script + html.substring(bodyClose);
        }
        return html + toolbar + script;
    }

    private static Integer parseIntParam(String key) {
        String raw = ApexPages.currentPage().getParameters().get(key);
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return Integer.valueOf(raw);
        } catch (Exception e) {
            return null;
        }
    }

    private static Id parseOwnerIdParam() {
        String raw = ApexPages.currentPage().getParameters().get('ownerId');
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return Id.valueOf(raw.trim());
        } catch (Exception e) {
            return null;
        }
    }

    private static Date parseDateParam(String key) {
        String raw = ApexPages.currentPage().getParameters().get(key);
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return Date.valueOf(raw.trim());
        } catch (Exception e) {
            return null;
        }
    }
}
