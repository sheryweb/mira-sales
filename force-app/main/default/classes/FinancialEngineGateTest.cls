/**
 * Verifies the Financial Engine master switch gates the finance UI surface: requireEnabled()
 * throws when the engine is off and passes when on, and the cacheable UI flag mirrors it.
 */
@IsTest
private class FinancialEngineGateTest {

    @IsTest
    static void requireEnabledThrowsWhenDisabled() {
        // No Financial_Engine_Settings__c row => disabled by default.
        Boolean threw = false;
        Test.startTest();
        try {
            FinancialEngine.requireEnabled();
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'requireEnabled must throw when the engine is disabled');
        System.assertEquals(false, FinancialEngine.isFinanceUiEnabled(), 'UI flag should be false when disabled');
    }

    @IsTest
    static void requireEnabledPassesWhenEnabled() {
        insert new Financial_Engine_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(), Engine_Owns_Totals__c = true);
        Test.startTest();
        FinancialEngine.requireEnabled(); // must not throw
        Test.stopTest();
        System.assertEquals(true, FinancialEngine.isFinanceUiEnabled(), 'UI flag should be true when enabled');
    }
}
