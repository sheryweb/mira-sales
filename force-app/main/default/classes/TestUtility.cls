/**
 * Utility class for test data generation
 */
public class TestUtility {
    @TestVisible private static Integer s_num = 1;
    
    private TestUtility() {}
    
    /**
     * Generates a fake ID for the specified SObject type
     * @param sot The SObject type to generate an ID for
     * @return A fake ID string
     */
    public static String getFakeId(Schema.SObjectType sot) {
        String result = String.valueOf(s_num++);
        // Generate 15-char ID with key prefix and padded number
        String fifteenCharId = sot.getDescribe().getKeyPrefix() + 
               '0'.repeat(12-result.length()) + 
               result;
        // Add a numeric suffix to make it 18 chars
        return fifteenCharId + '000';
    }
}