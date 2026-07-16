@isTest
private class CodeExtractorAPITest {

    @isTest
    static void testDoGetSuccess() {
        RestRequest req = new RestRequest();
        RestResponse response = new RestResponse();

        req.params.put('code', 'testCode');
        req.params.put('sfdc_community_url', 'testURL');
        req.params.put('sfdc_community_id', 'testID');
        req.params.put('state', 'testState');

        RestContext.request = req;
        RestContext.response = response;

        CodeExtractorAPI.CodeResponse successResponse = CodeExtractorAPI.doGet();

        System.assertEquals('testCode', successResponse.code);
        System.assertEquals('testURL', successResponse.sfdc_community_url);
        System.assertEquals('testID', successResponse.sfdc_community_id);
        System.assertEquals('testState', successResponse.state);
        System.assertEquals(true, successResponse.success);
        System.assertEquals(null, successResponse.errMsg);
    }

    @isTest
    static void testDoGetError() {
        RestRequest req = new RestRequest();
        RestResponse response = new RestResponse();

        RestContext.request = req;
        RestContext.response = response;

        CodeExtractorAPI.CodeResponse errorResponse = CodeExtractorAPI.doGet();
        errorResponse = new CodeExtractorAPI.CodeResponse('Could not parse auth code redirect URI');
        
        System.assertEquals(null, errorResponse.code);
        System.assertEquals(null, errorResponse.sfdc_community_url);
        System.assertEquals(null, errorResponse.sfdc_community_id);
        System.assertEquals(null, errorResponse.state);
        System.assertEquals(false, errorResponse.success);
        System.assertNotEquals('Could not parse auth code redirect URI', errorResponse.errMsg);
    }
}