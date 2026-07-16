@isTest
private class JWTGeneratorTest {
    
    @isTest
    static void testGenerateJWT() {
        FireBaseInfo__mdt firebaseInfo = [SELECT Issuer__c, Private_Key__c FROM FireBaseInfo__mdt LIMIT 1];
        String privateKey = firebaseInfo.Private_Key__c;
        String issuer = 'dummyIssuer';
        String audience = 'dummyAudience';
        String scope = 'dummyScope';
        
        String jwtToken = JWTGenerator.generateJWT(privateKey, issuer, audience, scope);
        
        System.assertNotEquals(null, jwtToken);
        
        List<String> jwtParts = jwtToken.split('\\.');
        
        System.assertEquals(3, jwtParts.size());
        
        System.assertNotEquals(null, jwtParts[0]);
        System.assertNotEquals(null, jwtParts[1]);
        System.assertNotEquals(null, jwtParts[2]);
    }
}