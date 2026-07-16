@RestResource(urlMapping='/generatePdf/*')
global without sharing class SalesOfferPDFService {

    @HttpGet
    global static void generatePdf() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        String unitId = req.params.get('unitId');
        
        if (String.isBlank(unitId)) {
            res.responseBody = Blob.valueOf('Unit ID parameter is required.');
            return;
        }
        
        PageReference pdfPage = Page.SalesOfferPDF;
        pdfPage.getParameters().put('unitId',unitId);
        Blob pdfBody;
        if(!test.isRunningTest()){
            pdfBody = pdfPage.getContent();
          }else{
            pdfBody = blob.valueof('TEST');
          }
        
        res.responseBody = pdfBody;
        res.addHeader('Content-Disposition', 'attachment; filename="SalesOfferPDF.pdf"');
        res.addHeader('Content-Type', 'application/pdf');
    }

}