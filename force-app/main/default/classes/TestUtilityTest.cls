@isTest
public class TestUtilityTest {
    
    @isTest
    static void testGetFakeId() {
        TestUtility.s_num = 1;
        // Test with Account
        String accountId = TestUtility.getFakeId(Account.SObjectType);
        System.assertEquals(18, accountId.length(), 'ID should be 18 characters long');
        System.assertEquals('001', accountId.substring(0, 3), 'Should start with Account key prefix');
        
        // Test with Opportunity
        String opportunityId = TestUtility.getFakeId(Opportunity.SObjectType);
        System.assertEquals(18, opportunityId.length(), 'ID should be 18 characters long');
        System.assertEquals('006', opportunityId.substring(0, 3), 'Should start with Opportunity key prefix');
        
        // Test with Contact
        String contactId = TestUtility.getFakeId(Contact.SObjectType);
        System.assertEquals(18, contactId.length(), 'ID should be 18 characters long');
        System.assertEquals('003', contactId.substring(0, 3), 'Should start with Contact key prefix');
        
        // Verify sequential numbering (checking only the base number part, excluding prefix and suffix)
        String firstId = TestUtility.getFakeId(Account.SObjectType);
        String secondId = TestUtility.getFakeId(Account.SObjectType);
        Integer firstNum = Integer.valueOf(firstId.substring(3, 15));
        Integer secondNum = Integer.valueOf(secondId.substring(3, 15));
        System.assertEquals(1, secondNum - firstNum, 'Sequential IDs should increment by 1');
    }
    
    @isTest
    static void testGetFakeId_MultipleDigits() {
        TestUtility.s_num = 1;
        // Generate enough IDs to test double digits
        List<String> ids = new List<String>();
        for(Integer i = 0; i < 15; i++) {
            ids.add(TestUtility.getFakeId(Account.SObjectType));
        }
        
        // Verify all IDs are valid
        for(String id : ids) {
            System.assertEquals(18, id.length(), 'All IDs should be 18 characters');
            System.assertEquals('001', id.substring(0, 3), 'All IDs should start with Account key prefix');
            System.assertEquals('000', id.substring(15), 'All IDs should end with numeric suffix');
        }
        
        // Verify the sequential numbers in the middle
        String firstId = ids[0];
        String lastId = ids[ids.size() - 1];
        Integer firstNum = Integer.valueOf(firstId.substring(3, 15));
        Integer lastNum = Integer.valueOf(lastId.substring(3, 15));
        System.assert(lastNum > firstNum, 'Numbers should be sequential');
        System.assertEquals(14, lastNum - firstNum, 'Should have correct number of increments');
    }
}