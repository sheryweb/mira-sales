@RestResource(urlMapping='/generateMultipleSalesOfferPdf/*')
global without sharing class MultipleUnitsGeneratePdfRestService {

    public class BadRequestException extends Exception {}

    @HttpGet
    global static void generateMultipleSalesOfferPdf() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String rawUnitIds = req.params.get('unitIds');
            String sCurrency = req.params.get('sCurrency');

            if (String.isBlank(rawUnitIds)) {
                writeJsonError(res, 400, 'unitIds query parameter is required (comma-separated Unit__c Ids)');
                return;
            }

            List<Id> orderedUnitIds = parseOrderedUnitIds(rawUnitIds);
            if (orderedUnitIds.isEmpty()) {
                writeJsonError(res, 400, 'unitIds must contain at least one valid Id');
                return;
            }

            List<Unit__c> units = [
                SELECT Id, Project_Name_F__c, Title__c
                FROM Unit__c
                WHERE Id IN :orderedUnitIds
                AND Status__c = 'Published'
            ];

            if (units.size() != orderedUnitIds.size()) {
                writeJsonError(res, 404, 'One or more Unit records were not found');
                return;
            }

            Map<Id, Unit__c> unitById = new Map<Id, Unit__c>(units);
            String projectName = unitById.get(orderedUnitIds[0]).Project_Name_F__c;
            for (Id uid : orderedUnitIds) {
                Unit__c u = unitById.get(uid);
                if (u.Project_Name_F__c != projectName) {
                    writeJsonError(res, 400, 'All units must belong to the same project (Project_Name_F__c)');
                    return;
                }
            }

            String unitIdsParam = joinIds(orderedUnitIds);

            deleteExistingSalesOfferFiles(orderedUnitIds);

            PageReference pdfPage = MultipleSalesPDFActionController.getPageReferenceForMultipleSalesOffer(projectName);
            pdfPage.getParameters().put('unitIds', unitIdsParam);
            if (String.isNotBlank(sCurrency)) {
                pdfPage.getParameters().put('sCurrency', sCurrency);
            }

            Blob pdfBody = Test.isRunningTest()
                ? Blob.valueOf('TEST')
                : pdfPage.getContentAsPDF();

            String fileName = 'Sales Offer ' + Date.today().format() + '.pdf';

            ContentVersion cv = new ContentVersion(
                Title           = fileName,
                PathOnClient    = fileName,
                VersionData     = pdfBody,
                ContentLocation = 'S'
            );
            insert cv;

            Id contentDocumentId = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
            ].ContentDocumentId;

            insert new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId    = orderedUnitIds[0],
                ShareType         = 'V'
            );

            res.statusCode = 200;
            res.addHeader('Content-Type', 'application/pdf');
            res.addHeader('Content-Disposition', 'attachment; filename="' + fileName + '"');
            res.responseBody = pdfBody;

        } catch (BadRequestException bre) {
            writeJsonError(res, 400, bre.getMessage());
        } catch (Exception e) {
            writeJsonError(res, 500, e.getMessage());
        }
    }

    private static List<Id> parseOrderedUnitIds(String raw) {
        List<Id> result = new List<Id>();
        Set<Id> seen = new Set<Id>();
        for (String part : raw.split(',')) {
            if (part == null) {
                continue;
            }
            String t = part.trim();
            if (String.isBlank(t)) {
                continue;
            }
            Id uid;
            try {
                uid = Id.valueOf(t);
            } catch (Exception ex) {
                throw new BadRequestException('Invalid unit Id: ' + t);
            }
            if (seen.add(uid)) {
                result.add(uid);
            }
        }
        return result;
    }

    private static String joinIds(List<Id> ids) {
        List<String> parts = new List<String>();
        for (Id i : ids) {
            parts.add(String.valueOf(i));
        }
        return String.join(parts, ',');
    }

    /**
     * SOQL cannot filter ContentDocumentLink by LinkedEntityId IN (...) and ContentDocument.Title together.
     * Logic matches MultipleSalesPDFActionController.querySalesOfferDocumentLinks (kept local so this class
     * deploys even if that helper is not yet on the org).
     */
    private static List<ContentDocumentLink> querySalesOfferLinksForLinkedEntities(List<Id> linkedEntityIds) {
        if (linkedEntityIds == null || linkedEntityIds.isEmpty()) {
            return new List<ContentDocumentLink>();
        }
        List<ContentDocumentLink> rows = [
            SELECT ContentDocumentId, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :linkedEntityIds
        ];
        List<ContentDocumentLink> matches = new List<ContentDocumentLink>();
        for (ContentDocumentLink cdl : rows) {
            String t = cdl.ContentDocument.Title;
            if (!String.isBlank(t) && t.toUpperCase().startsWith('SALES OFFER')) {
                matches.add(cdl);
            }
        }
        return matches;
    }

    /**
     * Matches MultipleSalesPDFActionController: remove prior Sales Offer files linked to any of the units.
     */
    private static void deleteExistingSalesOfferFiles(List<Id> recordIds) {
        List<ContentDocumentLink> existingLinks = querySalesOfferLinksForLinkedEntities(recordIds);
        if (existingLinks.isEmpty()) {
            return;
        }
        List<Id> contentDocumentIdsToDelete = new List<Id>();
        for (ContentDocumentLink link : existingLinks) {
            contentDocumentIdsToDelete.add(link.ContentDocumentId);
        }
        delete existingLinks;
        delete [
            SELECT Id
            FROM ContentDocument
            WHERE Id IN :contentDocumentIdsToDelete
        ];
    }

    private static void writeJsonError(RestResponse res, Integer status, String msg) {
        res.statusCode = status;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(JSON.serialize(
            new Map<String, Object>{ 'success' => false, 'message' => msg }
        ));
    }
}