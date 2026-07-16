@isTest
private class PicklistValuesServiceTest {

    @isTest
    static void testDoGet() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/picklistValues';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        PicklistValuesService.doGet();
        Test.stopTest();

        System.assertEquals('application/json', RestContext.response.headers.get('Content-Type'));

        List<Object> jsonResponse = (List<Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );

        System.assertEquals(4, jsonResponse.size(), 'Expected 4 picklists in the response');

        for (Object picklist : jsonResponse) {
            Map<String, Object> picklistMap = (Map<String, Object>) picklist;
            String picklistName = picklistMap.keySet().iterator().next();
            List<Object> picklistValues = (List<Object>) picklistMap.get(picklistName);

            switch on picklistName {
                when 'projectStatus' {
                    System.assertEquals(true, picklistValues.size() != null);
                }
                when 'realEstateType' {
                    System.assertEquals(true, picklistValues.size() != null);
                }
                when 'district' {
                    System.assertEquals(true, picklistValues.size() != null);
                }
                when 'country' {
                    System.assertEquals(true, picklistValues.size() != null);
                }
            }
        }
    }
}