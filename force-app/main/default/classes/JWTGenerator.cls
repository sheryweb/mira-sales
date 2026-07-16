public class JWTGenerator {

    public static String generateJWT(String privateKey, String issuer, String audience, String scope) {
        String header = '{"alg":"RS256","typ":"JWT"}';
        String claimSet = '{"iss":"' + issuer + '","sub":"' + issuer + '","scope":"' + scope + '","aud":"' + audience + '","exp":' + getExpirationTime() + ',"iat":' + getIssuedAtTime() + '}';

        String jwtHeader = EncodingUtil.base64Encode(Blob.valueOf(header));
        String jwtClaimSet = EncodingUtil.base64Encode(Blob.valueOf(claimSet));
        String signatureInput = jwtHeader + '.' + jwtClaimSet;

        Blob privateKeyBlob = EncodingUtil.base64Decode(privateKey);
        Blob signature = Crypto.sign('RSA-SHA256', Blob.valueOf(signatureInput), privateKeyBlob);
        String jwtSignature = EncodingUtil.base64Encode(signature);

        jwtSignature = jwtSignature.replaceAll('\\+', '-');
        jwtSignature = jwtSignature.replaceAll('/', '_');
        jwtSignature = jwtSignature.replaceAll('=', '');
        return jwtHeader + '.' + jwtClaimSet + '.' + jwtSignature;
    }

    private static Integer getExpirationTime() {
        return (DateTime.now().addHours(1).getTime() / 1000).intValue();
    }

    private static Integer getIssuedAtTime() {
        return (DateTime.now().getTime() / 1000).intValue();
    }
}