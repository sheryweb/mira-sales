@IsTest
private class MonthlySalesReportServiceTest {
    @TestSetup
    static void setupData() {
        Profile salesManagerProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Sales Manager MIRA'
            LIMIT 1
        ];

        // Roles drive Manager_Name__c / shared-deal manager credit rules
        Map<String, Id> roleIdsByName = new Map<String, Id>();
        for (UserRole role : [
            SELECT Id, Name
            FROM UserRole
            WHERE Name IN (
                'Sales Manager 1',
                'Sales Manager 2',
                'Sales Manager 4'
            )
        ]) {
            roleIdsByName.put(role.Name, role.Id);
        }

        Long stamp = System.currentTimeMillis();
        User ownerA = newUser('OwnerA', salesManagerProfile.Id, roleIdsByName.get('Sales Manager 2'), stamp);
        User ownerB = newUser('OwnerB', salesManagerProfile.Id, roleIdsByName.get('Sales Manager 1'), stamp);
        User ownerC = newUser('OwnerC', salesManagerProfile.Id, roleIdsByName.get('Sales Manager 4'), stamp);
        User sharedSameMgr = newUser('SharedSame', salesManagerProfile.Id, roleIdsByName.get('Sales Manager 4'), stamp);
        insert new List<User>{ ownerA, ownerB, ownerC, sharedSameMgr };

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Project__c project = new Project__c(
                Name = 'John Richmond Residences',
                Description__c = 'Test',
                District__c = 'Meydan',
                Coordinates_Latitude__c = 1,
                Coordinates_Longitude__c = 1,
                Handover__c = Date.today(),
                Minimum_Cost__c = 1,
                Publish_Project__c = 'Draft'
            );
            insert project;

            List<Unit__c> units = new List<Unit__c>();
            // Cost_AED drives Unit_Price formula — do not set Unit_Price directly
            List<Decimal> costs = new List<Decimal>{ 1000000, 952619, 1913927 };
            for (Integer i = 0; i < 3; i++) {
                units.add(new Unit__c(
                    Title__c = 'MSR Unit ' + (i + 1),
                    Cost_AED__c = costs[i],
                    Type__c = 'Apartment',
                    Total_Area__c = 1000,
                    Living_Space__c = 800,
                    Additional_Area__c = 200,
                    Floor__c = i + 1,
                    Number_of_Bedrooms__c = 2,
                    Number_of_Bathrooms__c = 2,
                    Status__c = 'Draft',
                    Building__c = 'Tower A',
                    Panorama_Link__c = 'Link',
                    Project__c = project.Id
                ));
            }
            insert units;
            for (Unit__c u : units) {
                u.Status__c = 'Booked';
            }
            update units;

            Account account = new Account(Name = 'MSR Test Account');
            insert account;

            Datetime bookedDt = Datetime.newInstance(2026, 7, 15, 10, 0, 0);

            // Single deal
            Opportunity single = new Opportunity(
                Name = 'MSR Single',
                StageName = 'New',
                CloseDate = Date.newInstance(2026, 7, 31),
                AccountId = account.Id,
                OwnerId = ownerA.Id
            );
            // Shared deal — different managers (50/50 manager split)
            Opportunity sharedDiff = new Opportunity(
                Name = 'MSR Shared Diff Mgr',
                StageName = 'New',
                CloseDate = Date.newInstance(2026, 7, 31),
                AccountId = account.Id,
                OwnerId = ownerA.Id
            );
            // Shared deal — same manager (full manager credit)
            Opportunity sharedSame = new Opportunity(
                Name = 'MSR Shared Same Mgr',
                StageName = 'New',
                CloseDate = Date.newInstance(2026, 7, 31),
                AccountId = account.Id,
                OwnerId = ownerC.Id
            );
            insert new List<Opportunity>{ single, sharedDiff, sharedSame };

            single.Unit__c = units[0].Id;
            single.StageName = 'Booked';
            single.Booking_Date_Time__c = bookedDt;

            sharedDiff.Unit__c = units[1].Id;
            sharedDiff.StageName = 'Booked';
            sharedDiff.Booking_Date_Time__c = bookedDt;
            sharedDiff.Share_Deal__c = true;
            sharedDiff.Shared_RM__c = ownerB.Id;
            sharedDiff.Share_Deal_Status__c = 'Approved';

            sharedSame.Unit__c = units[2].Id;
            sharedSame.StageName = 'Booked';
            sharedSame.Booking_Date_Time__c = bookedDt;
            sharedSame.Share_Deal__c = true;
            sharedSame.Shared_RM__c = sharedSameMgr.Id;
            sharedSame.Share_Deal_Status__c = 'Approved';

            update new List<Opportunity>{ single, sharedDiff, sharedSame };

            // Re-stamp booking datetime after stage automation (flows may clear/overwrite).
            List<Opportunity> bookedOpps = [
                SELECT Id
                FROM Opportunity
                WHERE Id IN :new List<Id>{ single.Id, sharedDiff.Id, sharedSame.Id }
            ];
            for (Opportunity o : bookedOpps) {
                o.Booking_Date_Time__c = bookedDt;
                o.StageName = 'Booked';
            }
            update bookedOpps;
        }
    }

    private static User newUser(String lastName, Id profileId, Id roleId, Long stamp) {
        return new User(
            Alias = lastName.left(8),
            LastName = lastName,
            FirstName = 'Test',
            Email = lastName.toLowerCase() + '@example.com',
            Username = lastName.toLowerCase() + '.' + stamp + '@example.com',
            ProfileId = profileId,
            UserRoleId = roleId,
            TimeZoneSidKey = 'Asia/Dubai',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
    }

    @IsTest
    static void testBuildReportSharedDealSplits() {
        Test.startTest();
        MonthlySalesReportModels.MonthlyReportDTO report =
            MonthlySalesReportService.buildReport(2026, 7);
        Test.stopTest();

        System.assertEquals(MonthlySalesReportModels.REPORT_TYPE_MONTHLY, report.reportType);
        System.assertEquals('Sales Monthly Report', report.reportTitle);
        System.assertEquals('Monthly Performance', report.performanceTitle);
        System.assertEquals('OF THE MONTH', report.periodGrainLabel);
        System.assertEquals(3, report.transactionCount, 'Expected 3 July transactions');
        System.assertEquals(2, report.sharedDeals.size(), 'Expected 2 shared deals');
        System.assert(report.totalSalesValue > 0, 'Total sales should be positive');

        MonthlySalesReportModels.SharedDealDTO diffMgr;
        MonthlySalesReportModels.SharedDealDTO sameMgr;
        for (MonthlySalesReportModels.SharedDealDTO deal : report.sharedDeals) {
            if (deal.sameManager == true) {
                sameMgr = deal;
            } else {
                diffMgr = deal;
            }
        }

        System.assertNotEquals(null, diffMgr, 'Different-manager shared deal expected');
        System.assertEquals(2, diffMgr.managerCredits.size(), 'Managers should split 50/50');
        System.assertEquals(0.5, diffMgr.managerCredits[0].unitCredit);
        System.assertEquals(476310, diffMgr.ownerCredits[0].creditAmount);

        System.assertNotEquals(null, sameMgr, 'Same-manager shared deal expected');
        System.assertEquals(1, sameMgr.managerCredits.size(), 'Same manager gets full credit');
        System.assertEquals(1, sameMgr.managerCredits[0].unitCredit);
        System.assertEquals(1913927, sameMgr.managerCredits[0].creditAmount);

        System.assertNotEquals(null, report.topTeams, 'Top teams should populate');
        System.assert(report.topTeams.size() > 0, 'At least one manager on leaderboard');
        System.assertNotEquals(null, report.topRm, 'Top RM should populate');
    }

    @IsTest
    static void testBuildWeeklyReport() {
        // 15 Jul 2026 is a Wednesday → week Mon 13 Jul — Sun 19 Jul 2026
        Date anyDateInWeek = Date.newInstance(2026, 7, 15);

        Test.startTest();
        MonthlySalesReportModels.MonthlyReportDTO report =
            MonthlySalesReportService.buildWeeklyReport(anyDateInWeek);
        String html = MonthlySalesReportService.buildReportHtml(anyDateInWeek);
        Test.stopTest();

        System.assertEquals(MonthlySalesReportModels.REPORT_TYPE_WEEKLY, report.reportType);
        System.assertEquals('Sales Weekly Report', report.reportTitle);
        System.assertEquals('Weekly Performance', report.performanceTitle);
        System.assertEquals('OF THE WEEK', report.periodGrainLabel);
        System.assertEquals(Date.newInstance(2026, 7, 13), report.startDate);
        System.assertEquals(Date.newInstance(2026, 7, 19), report.endDate);
        System.assert(
            report.periodLabel.contains('13 July 2026') && report.periodLabel.contains('19 July 2026'),
            'Weekly period label should be Mon–Sun range: ' + report.periodLabel
        );
        System.assertEquals(3, report.transactionCount, 'July 15 deals fall in that week');
        System.assert(html.contains('Sales Weekly Report'), 'Weekly HTML header');
        System.assert(html.contains('TOP TEAM OF THE WEEK'), 'Weekly grain labels');
        System.assert(html.contains('SALES BY PROJECT'), 'Weekly includes sales by project');
        System.assert(html.contains('#0A1625'), 'Navy theme background from sample');
        System.assert(html.contains('#172640'), 'Card surface matches sample');
        System.assert(html.contains('border-radius:10px'), 'Inline stage/shared pills');
        System.assert(html.contains('border-radius:12px'), 'Inline period badge / cards');
        System.assert(html.contains('print-color-adjust'), 'Print CSS keeps dark theme fills');
        System.assert(!html.contains('data:image/png'), 'No embedded images in PDF HTML');
        System.assert(!html.contains('MonthlySalesReportRound'), 'No Static Resource corner images');
        System.assert(html.contains('kpi-card'), 'Fixed-height KPI cards');
        System.assert(html.contains('accent-line'), 'Gradient accent lines under titles');
        System.assert(html.contains('card-shell'), 'Card shells');
    }

    @IsTest
    static void testBuildDateRangeReport() {
        Date startDate = Date.newInstance(2026, 7, 10);
        Date endDate = Date.newInstance(2026, 7, 20);

        Test.startTest();
        MonthlySalesReportModels.MonthlyReportDTO report =
            MonthlySalesReportService.buildDateRangeReport(startDate, endDate);
        String html = MonthlySalesReportService.buildReportHtml(
            MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE,
            startDate,
            endDate
        );
        MonthlySalesReportModels.MonthlyReportDTO viaController =
            MonthlySalesReportController.getReportData(
                MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE,
                null,
                null,
                null,
                '2026-07-10',
                '2026-07-20',
                null
            );
        String rangeHtml = MonthlySalesReportController.getReportHtml(
            MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE,
            null,
            null,
            null,
            '2026-07-10',
            '2026-07-20',
            null
        );
        String rangePdf = MonthlySalesReportController.generatePdf(
            MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE,
            null,
            null,
            null,
            '2026-07-10',
            '2026-07-20',
            null
        );

        PageReference printRef = Page.MonthlySalesReportPrint;
        printRef.getParameters().put('reportType', MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE);
        printRef.getParameters().put('startDate', '2026-07-10');
        printRef.getParameters().put('endDate', '2026-07-20');
        Test.setCurrentPage(printRef);
        MonthlySalesReportPDFController printCtrl = new MonthlySalesReportPDFController();
        Test.stopTest();

        System.assertEquals(MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE, report.reportType);
        System.assertEquals('Sales Date Range Report', report.reportTitle);
        System.assertEquals('Period Performance', report.performanceTitle);
        System.assertEquals('OF THE PERIOD', report.periodGrainLabel);
        System.assertEquals(startDate, report.startDate);
        System.assertEquals(endDate, report.endDate);
        System.assert(
            report.periodLabel.contains('10 July 2026') && report.periodLabel.contains('20 July 2026'),
            'Date range period label: ' + report.periodLabel
        );
        System.assertEquals(viaController.transactionCount, report.transactionCount);
        System.assert(String.isNotBlank(rangeHtml), 'Date range controller HTML');
        System.assert(String.isNotBlank(rangePdf), 'Date range controller PDF');
        System.assert(html.contains('Sales Date Range Report'), 'Date range HTML header');
        System.assert(html.contains('TOP TEAM OF THE PERIOD'), 'Date range grain labels');
        System.assert(html.contains('TRANSACTION DETAILS'), 'Date range uses paginated layout');
        System.assert(
            printCtrl.htmlContent.contains('Sales Date Range Report')
                || printCtrl.htmlContent.contains('TRANSACTION'),
            'Date range print HTML expected'
        );
        System.assert(printCtrl.htmlContent.contains('window.print'), 'Date range print script');

        Boolean missingRangeThrew = false;
        try {
            MonthlySalesReportController.getReportData(
                MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE,
                null,
                null,
                null,
                null,
                '2026-07-20',
                null
            );
        } catch (AuraHandledException e) {
            missingRangeThrew = true;
        }
        System.assertEquals(true, missingRangeThrew, 'Date Range without start should fail');

        Boolean invertedThrew = false;
        try {
            MonthlySalesReportService.buildDateRangeReport(endDate, startDate);
        } catch (MonthlySalesReportService.MonthlySalesReportException e) {
            invertedThrew = true;
        }
        System.assertEquals(true, invertedThrew, 'Inverted date range should fail');
    }

    @IsTest
    static void testPrintPageInjectsWindowPrint() {
        PageReference printRef = Page.MonthlySalesReportPrint;
        printRef.getParameters().put('year', '2026');
        printRef.getParameters().put('month', '7');
        Test.setCurrentPage(printRef);

        Test.startTest();
        MonthlySalesReportPDFController printCtrl = new MonthlySalesReportPDFController();

        PageReference weeklyPrint = Page.MonthlySalesReportPrint;
        weeklyPrint.getParameters().put('reportType', MonthlySalesReportModels.REPORT_TYPE_WEEKLY);
        weeklyPrint.getParameters().put('weekStartIso', '2026-07-15');
        Test.setCurrentPage(weeklyPrint);
        MonthlySalesReportPDFController weeklyCtrl = new MonthlySalesReportPDFController();
        Test.stopTest();

        System.assert(printCtrl.htmlContent.contains('print-toolbar'), 'Print toolbar expected');
        System.assert(printCtrl.htmlContent.contains('window.print'), 'Auto print script expected');
        System.assert(
            weeklyCtrl.htmlContent.contains('Sales Weekly Report')
                || weeklyCtrl.htmlContent.contains('TRANSACTION'),
            'Weekly print HTML expected'
        );
        System.assert(weeklyCtrl.htmlContent.contains('window.print'), 'Weekly print script expected');
    }

    @IsTest
    static void testBuildReportHtmlAndController() {
        Test.startTest();
        String html = MonthlySalesReportController.getReportHtml(
            MonthlySalesReportModels.REPORT_TYPE_MONTHLY, 2026, 7, null, null, null, null
        );
        MonthlySalesReportModels.MonthlyReportDTO data =
            MonthlySalesReportController.getReportData(
                MonthlySalesReportModels.REPORT_TYPE_MONTHLY, 2026, 7, null, null, null, null
            );
        String pdfBase64 = MonthlySalesReportController.generatePdf(
            MonthlySalesReportModels.REPORT_TYPE_MONTHLY, 2026, 7, null, null, null, null
        );
        String pdfFromHtml = MonthlySalesReportController.generatePdfFromHtml(html);
        Id pdfDocId = MonthlySalesReportController.savePdfDocument(
            MonthlySalesReportModels.REPORT_TYPE_MONTHLY,
            2026,
            7,
            null,
            'MIRA_Monthly_Sales_Report_2026_07.pdf'
        );

        // Weekly controller path
        MonthlySalesReportModels.MonthlyReportDTO weekly =
            MonthlySalesReportController.getReportData(
                MonthlySalesReportModels.REPORT_TYPE_WEEKLY, null, null, '2026-07-15', null, null, null
            );
        String weeklyPdf = MonthlySalesReportController.generatePdf(
            MonthlySalesReportModels.REPORT_TYPE_WEEKLY, null, null, '2026-07-15', null, null, null
        );
        Test.stopTest();

        System.assert(html.contains('TRANSACTION DETAILS'), 'HTML should include transaction section');
        System.assert(html.contains('SALES BY PROJECT'), 'HTML should include project section');
        System.assert(html.contains('TOP TEAM OF THE MONTH'), 'HTML should include top team');
        System.assert(html.contains('stage-pill'), 'Stage pills in dark theme');
        System.assert(html.contains('border-radius:10px'), 'Inline stage pills');
        System.assertEquals(3, data.transactionCount);
        System.assertEquals(3, weekly.transactionCount);
        System.assertEquals(MonthlySalesReportModels.REPORT_TYPE_WEEKLY, weekly.reportType);
        System.assert(String.isNotBlank(pdfBase64), 'PDF base64 expected');
        System.assert(String.isNotBlank(pdfFromHtml), 'HTML PDF base64 expected');
        System.assertNotEquals(null, pdfDocId, 'Saved PDF ContentDocumentId expected');
        System.assert(String.isNotBlank(weeklyPdf), 'Weekly PDF base64 expected');
    }

    @IsTest
    static void testPdfControllerYearMonthAndRange() {
        PageReference pageRef = Page.MonthlySalesReportPDF;
        pageRef.getParameters().put('year', '2026');
        pageRef.getParameters().put('month', '7');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        MonthlySalesReportPDFController ctrl = new MonthlySalesReportPDFController();

        PageReference rangeRef = Page.MonthlySalesReportPDF;
        rangeRef.getParameters().put('reportType', MonthlySalesReportModels.REPORT_TYPE_WEEKLY);
        rangeRef.getParameters().put('startDate', '2026-07-13');
        rangeRef.getParameters().put('endDate', '2026-07-19');
        Test.setCurrentPage(rangeRef);
        MonthlySalesReportPDFController rangeCtrl = new MonthlySalesReportPDFController();
        Test.stopTest();

        System.assert(String.isNotBlank(ctrl.htmlContent), 'VF controller should render HTML');
        System.assert(
            ctrl.htmlContent.contains('July 2026') || ctrl.htmlContent.contains('TRANSACTION'),
            'Rendered HTML should include report content'
        );
        System.assert(String.isNotBlank(rangeCtrl.htmlContent), 'Range VF path should render');
        System.assert(
            rangeCtrl.htmlContent.contains('Sales Weekly Report')
                || rangeCtrl.htmlContent.contains('TRANSACTION'),
            'Weekly range HTML expected'
        );
    }

    @IsTest
    static void testInvalidPeriod() {
        Boolean threw = false;
        try {
            MonthlySalesReportService.buildReport(2026, 13);
        } catch (MonthlySalesReportService.MonthlySalesReportException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Invalid month should throw');

        Boolean weekThrew = false;
        try {
            MonthlySalesReportService.buildWeeklyReport(null);
        } catch (MonthlySalesReportService.MonthlySalesReportException e) {
            weekThrew = true;
        }
        System.assertEquals(true, weekThrew, 'Null weekly date should throw');
    }

    @IsTest
    static void testControllerErrorPathsAndPdfFromContent() {
        Boolean invalidThrew = false;
        try {
            MonthlySalesReportController.getReportData(
                MonthlySalesReportModels.REPORT_TYPE_MONTHLY, 2026, 0, null, null, null, null
            );
        } catch (AuraHandledException e) {
            invalidThrew = true;
        }
        System.assertEquals(true, invalidThrew, 'Invalid period should surface as AuraHandledException');

        Boolean blankHtmlThrew = false;
        try {
            MonthlySalesReportController.generatePdfFromHtml('   ');
        } catch (AuraHandledException e) {
            blankHtmlThrew = true;
        }
        System.assertEquals(true, blankHtmlThrew, 'Blank HTML should be rejected');

        Boolean weeklyMissingThrew = false;
        try {
            MonthlySalesReportController.getReportData(
                MonthlySalesReportModels.REPORT_TYPE_WEEKLY, null, null, null, null, null, null
            );
        } catch (AuraHandledException e) {
            weeklyMissingThrew = true;
        }
        System.assertEquals(true, weeklyMissingThrew, 'Weekly without weekStartIso should fail');

        String html = MonthlySalesReportService.buildReportHtml(2026, 7);
        ContentVersion cv = new ContentVersion(
            Title = 'MSR_Test_Html',
            PathOnClient = 'report.html',
            VersionData = Blob.valueOf(html),
            ContentLocation = 'S'
        );
        insert cv;
        Id contentDocumentId = [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id
        ].ContentDocumentId;

        PageReference pageRef = Page.MonthlySalesReportPDF;
        pageRef.getParameters().put('htmlContentDocumentId', String.valueOf(contentDocumentId));
        Test.setCurrentPage(pageRef);

        MonthlySalesReportPDFController fromDoc = new MonthlySalesReportPDFController();
        System.assert(String.isNotBlank(fromDoc.htmlContent), 'HTML from ContentDocument expected');

        Test.setCurrentPage(Page.MonthlySalesReportPDF);
        MonthlySalesReportPDFController defaults = new MonthlySalesReportPDFController();
        System.assert(String.isNotBlank(defaults.htmlContent), 'Default period HTML expected');

        PageReference badParams = Page.MonthlySalesReportPDF;
        badParams.getParameters().put('year', 'abc');
        badParams.getParameters().put('month', 'xyz');
        Test.setCurrentPage(badParams);
        MonthlySalesReportPDFController bad = new MonthlySalesReportPDFController();
        System.assert(String.isNotBlank(bad.htmlContent), 'Bad params should fall back to defaults');
    }

    @IsTest
    static void testEmptyMonth() {
        Test.startTest();
        MonthlySalesReportModels.MonthlyReportDTO report =
            MonthlySalesReportService.buildReport(2020, 1);
        String html = MonthlySalesReportService.renderHtml(report);
        String rangeHtml = MonthlySalesReportService.buildReportHtml(
            MonthlySalesReportModels.REPORT_TYPE_MONTHLY,
            Date.newInstance(2020, 1, 1),
            Date.newInstance(2020, 1, 31)
        );
        String pdfRange = MonthlySalesReportService.generatePdf(
            MonthlySalesReportModels.REPORT_TYPE_MONTHLY,
            Date.newInstance(2020, 1, 1),
            Date.newInstance(2020, 1, 31)
        );
        Test.stopTest();
        System.assertEquals(0, report.transactionCount);
        System.assertEquals(0, report.totalSalesValue);
        System.assert(html.contains('TRANSACTION DETAILS'), 'Empty report still renders shell');
        System.assert(html.contains('No shared deals this month'), 'Empty shared deals message');
        System.assert(rangeHtml.contains('Sales Monthly Report'), 'Date-range HTML overload');
        System.assert(String.isNotBlank(pdfRange), 'Date-range PDF overload');
    }

    @IsTest
    static void testOwnerRmFilterAndOptions() {
        User ownerA = [
            SELECT Id, LastName
            FROM User
            WHERE LastName = 'OwnerA'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        Test.startTest();
        List<MonthlySalesReportModels.PicklistOptionDTO> options =
            MonthlySalesReportController.getRmOptions(
                MonthlySalesReportModels.REPORT_TYPE_MONTHLY,
                2026,
                7,
                null,
                null,
                null
            );
        List<MonthlySalesReportModels.PicklistOptionDTO> weeklyOptions =
            MonthlySalesReportController.getRmOptions(
                MonthlySalesReportModels.REPORT_TYPE_WEEKLY,
                null,
                null,
                '2026-07-15',
                null,
                null
            );
        List<MonthlySalesReportModels.PicklistOptionDTO> rangeOptions =
            MonthlySalesReportController.getRmOptions(
                MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE,
                null,
                null,
                null,
                '2026-07-10',
                '2026-07-20'
            );
        MonthlySalesReportModels.MonthlyReportDTO filtered =
            MonthlySalesReportController.getReportData(
                MonthlySalesReportModels.REPORT_TYPE_MONTHLY,
                2026,
                7,
                null,
                null,
                null,
                String.valueOf(ownerA.Id)
            );
        MonthlySalesReportModels.MonthlyReportDTO weeklyFiltered =
            MonthlySalesReportController.getReportData(
                MonthlySalesReportModels.REPORT_TYPE_WEEKLY,
                null,
                null,
                '2026-07-15',
                null,
                null,
                String.valueOf(ownerA.Id)
            );
        MonthlySalesReportModels.MonthlyReportDTO rangeFiltered =
            MonthlySalesReportController.getReportData(
                MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE,
                null,
                null,
                null,
                '2026-07-10',
                '2026-07-20',
                String.valueOf(ownerA.Id)
            );
        String filteredHtml = MonthlySalesReportController.getReportHtml(
            MonthlySalesReportModels.REPORT_TYPE_MONTHLY,
            2026,
            7,
            null,
            null,
            null,
            String.valueOf(ownerA.Id)
        );
        String weeklyPdf = MonthlySalesReportController.generatePdf(
            MonthlySalesReportModels.REPORT_TYPE_WEEKLY,
            null,
            null,
            '2026-07-15',
            null,
            null,
            String.valueOf(ownerA.Id)
        );
        String rangePdf = MonthlySalesReportController.generatePdf(
            MonthlySalesReportModels.REPORT_TYPE_DATE_RANGE,
            null,
            null,
            null,
            '2026-07-10',
            '2026-07-20',
            String.valueOf(ownerA.Id)
        );

        PageReference printRef = Page.MonthlySalesReportPrint;
        printRef.getParameters().put('year', '2026');
        printRef.getParameters().put('month', '7');
        printRef.getParameters().put('ownerId', String.valueOf(ownerA.Id));
        Test.setCurrentPage(printRef);
        MonthlySalesReportPDFController printCtrl = new MonthlySalesReportPDFController();

        Boolean badOwnerThrew = false;
        try {
            MonthlySalesReportController.getReportData(
                MonthlySalesReportModels.REPORT_TYPE_MONTHLY,
                2026,
                7,
                null,
                null,
                null,
                'not-an-id'
            );
        } catch (AuraHandledException e) {
            badOwnerThrew = true;
        }

        Boolean missingRmOptionsThrew = false;
        try {
            MonthlySalesReportController.getRmOptions(
                MonthlySalesReportModels.REPORT_TYPE_WEEKLY,
                null,
                null,
                null,
                null,
                null
            );
        } catch (AuraHandledException e) {
            missingRmOptionsThrew = true;
        }
        Test.stopTest();

        System.assert(options.size() >= 2, 'Expected Sales Manager MIRA RMs in options');
        System.assertEquals(
            options.size(),
            weeklyOptions.size(),
            'RM options are profile-based and independent of period type'
        );
        System.assertEquals(
            options.size(),
            rangeOptions.size(),
            'RM options are profile-based and independent of period type'
        );
        Boolean foundOwnerA = false;
        for (MonthlySalesReportModels.PicklistOptionDTO opt : options) {
            if (opt.value == String.valueOf(ownerA.Id)) {
                foundOwnerA = true;
                System.assert(opt.label.contains('OwnerA'), 'RM label should include last name');
            }
        }
        System.assertEquals(true, foundOwnerA, 'OwnerA (Sales Manager MIRA) should appear in RM options');
        for (Integer i = 1; i < options.size(); i++) {
            System.assert(
                options[i - 1].label.toLowerCase() <= options[i].label.toLowerCase(),
                'RM options must be alphabetical by displayed name'
            );
        }
        // OwnerA owns single + sharedDiff = 2 deals
        System.assertEquals(2, filtered.transactionCount, 'Owner filter should limit to OwnerA deals');
        System.assertEquals(2, weeklyFiltered.transactionCount, 'Weekly owner filter');
        System.assertEquals(2, rangeFiltered.transactionCount, 'Date-range owner filter');
        System.assert(String.isNotBlank(filteredHtml), 'Filtered HTML expected');
        System.assert(String.isNotBlank(weeklyPdf), 'Weekly filtered PDF expected');
        System.assert(String.isNotBlank(rangePdf), 'Date-range filtered PDF expected');
        System.assert(
            String.isNotBlank(printCtrl.htmlContent),
            'Print page should honor ownerId param'
        );
        System.assertEquals(true, badOwnerThrew, 'Invalid ownerId should fail');
        System.assertEquals(true, missingRmOptionsThrew, 'Weekly RM options require weekStartIso');
    }
}
