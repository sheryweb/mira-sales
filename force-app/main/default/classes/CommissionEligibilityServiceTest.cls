@isTest
private class CommissionEligibilityServiceTest {

    private static Id getAccountRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> rtByDevName =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        if (rtByDevName.containsKey('Agency') && rtByDevName.get('Agency').isAvailable()) {
            return rtByDevName.get('Agency').getRecordTypeId();
        }
        for (Schema.RecordTypeInfo info : rtByDevName.values()) {
            if (info.isAvailable() && !info.isMaster()) {
                return info.getRecordTypeId();
            }
        }
        return null;
    }

    private static Account createAgency() {
        Account agency = new Account(
            Name = 'EligTest Agency ' + String.valueOf(Crypto.getRandomLong()),
            Company_Email__c = 'eligtest_' + String.valueOf(Crypto.getRandomLong()) + '@example.com',
            Skip_Trigger__c = true
        );
        Id rtId = getAccountRecordTypeId();
        if (rtId != null) agency.RecordTypeId = rtId;
        insert agency;
        return agency;
    }

    // Builds an in-memory Opportunity via JSON deserialization. Bypasses Apex
    // field-writeability checks so the test can populate Agency__c / StageName / Amount
    // without satisfying the formula-field gates (Is_20_Paid__c, Unit_Sold_Date_Only__c)
    // that the public evaluate() method's SOQL pre-filter requires. The mock Opportunity
    // is passed directly to evaluateOpps() — never inserted.
    private static Opportunity buildMockOpp(Id agencyId, String stage, Decimal amount) {
        Map<String, Object> oppData = new Map<String, Object>{
            'attributes' => new Map<String, String>{ 'type' => 'Opportunity' },
            'Id' => '006000000000001AAA',
            'Name' => 'Test Opp',
            'StageName' => stage,
            'Agency__c' => agencyId,
            'Amount' => amount
        };
        return (Opportunity) JSON.deserialize(JSON.serialize(oppData), Opportunity.class);
    }

    private static Opportunity buildMockOppWithUnit(
        Id agencyId,
        String stage,
        Decimal amount,
        String projectName,
        String unitStatus,
        Decimal unitCost
    ) {
        Map<String, Object> unitData = new Map<String, Object>{
            'attributes' => new Map<String, String>{ 'type' => 'Unit__c' },
            'Id' => 'a0B000000000001EAA',
            'Project_Name_F__c' => projectName,
            'Status__c' => unitStatus,
            'Cost_AED__c' => unitCost
        };

        Map<String, Object> oppData = new Map<String, Object>{
            'attributes' => new Map<String, String>{ 'type' => 'Opportunity' },
            'Id' => '006000000000002AAA',
            'Name' => 'Test Opp With Unit',
            'StageName' => stage,
            'Agency__c' => agencyId,
            'Amount' => amount,
            'Unit__c' => 'a0B000000000001EAA',
            'Unit__r' => unitData
        };
        return (Opportunity) JSON.deserialize(JSON.serialize(oppData), Opportunity.class);
    }

    private static Commission_Eligibility_Config__mdt buildConfig(Boolean excludeIntl, String stage, String agencyStatus, Decimal rate, Integer priority) {
        Commission_Eligibility_Config__mdt config = new Commission_Eligibility_Config__mdt();
        config.MasterLabel = 'Test Rule ' + priority;
        config.Project_Name__c = '*';
        config.Required_Opportunity_Stage__c = stage;
        config.Required_Agency_Status__c = agencyStatus;
        config.Exclude_International__c = excludeIntl;
        config.Commission_Rate__c = rate;
        config.Active__c = true;
        config.Priority__c = priority;
        return config;
    }

    @isTest
    static void testEligibleOpportunityProducesCommission() {
        Account agency = createAgency();
        Opportunity opp = buildMockOpp(agency.Id, 'New', 1000000);
        Commission_Eligibility_Config__mdt cfg = buildConfig(false, 'New', null, 4, 1);
        Map<Id, Account> agencies = new Map<Id, Account>{ agency.Id => agency };

        Test.startTest();
        List<Commission__c> drafts = CommissionEligibilityService.evaluateOpps(
            new List<Opportunity>{ opp },
            agencies,
            new List<Commission_Eligibility_Config__mdt>{ cfg }
        );
        Test.stopTest();

        System.assertEquals(1, drafts.size(), 'One eligible Opp should produce one draft Commission');
        System.assertEquals(opp.Id, drafts[0].Opportunity__c);
        System.assertEquals(agency.Id, drafts[0].Agency__c);
        System.assertEquals(4, drafts[0].Commission_Rate__c);
        System.assertEquals(1000000, drafts[0].Base_Amount__c, 'Falls back to Opportunity.Amount when Unit__c is null');
    }

    @isTest
    static void testStageMismatchProducesNoCommission() {
        Account agency = createAgency();
        Opportunity opp = buildMockOpp(agency.Id, 'New', 1000000);
        Commission_Eligibility_Config__mdt cfg = buildConfig(false, 'Closed Won', null, 4, 1);
        Map<Id, Account> agencies = new Map<Id, Account>{ agency.Id => agency };

        List<Commission__c> drafts = CommissionEligibilityService.evaluateOpps(
            new List<Opportunity>{ opp },
            agencies,
            new List<Commission_Eligibility_Config__mdt>{ cfg }
        );

        System.assertEquals(0, drafts.size());
    }

    @isTest
    static void testFirstMatchingPriorityWins() {
        Account agency = createAgency();
        Opportunity opp = buildMockOpp(agency.Id, 'New', 1000000);
        Commission_Eligibility_Config__mdt low = buildConfig(false, 'New', null, 2, 100);
        Commission_Eligibility_Config__mdt high = buildConfig(false, 'New', null, 5, 1);
        Map<Id, Account> agencies = new Map<Id, Account>{ agency.Id => agency };

        List<Commission__c> drafts = CommissionEligibilityService.evaluateOpps(
            new List<Opportunity>{ opp },
            agencies,
            new List<Commission_Eligibility_Config__mdt>{ high, low }
        );

        System.assertEquals(1, drafts.size());
        System.assertEquals(5, drafts[0].Commission_Rate__c, 'Higher-priority rule (lower number) should win');
    }

    @isTest
    static void testInactiveConfigSkipped() {
        Account agency = createAgency();
        Opportunity opp = buildMockOpp(agency.Id, 'New', 1000000);
        Commission_Eligibility_Config__mdt cfg = buildConfig(false, 'New', null, 4, 1);
        cfg.Active__c = false;
        Map<Id, Account> agencies = new Map<Id, Account>{ agency.Id => agency };

        List<Commission__c> drafts = CommissionEligibilityService.evaluateOpps(
            new List<Opportunity>{ opp },
            agencies,
            new List<Commission_Eligibility_Config__mdt>{ cfg }
        );

        System.assertEquals(0, drafts.size());
    }

    @isTest
    static void testOppWithoutAgencyIsSkipped() {
        Account agency = createAgency();
        Opportunity opp = buildMockOpp(null, 'New', 1000000);
        Commission_Eligibility_Config__mdt cfg = buildConfig(false, 'New', null, 4, 1);
        Map<Id, Account> agencies = new Map<Id, Account>{ agency.Id => agency };

        List<Commission__c> drafts = CommissionEligibilityService.evaluateOpps(
            new List<Opportunity>{ opp },
            agencies,
            new List<Commission_Eligibility_Config__mdt>{ cfg }
        );

        System.assertEquals(0, drafts.size(), 'Opp without an Agency should be skipped');
    }

    @isTest
    static void testEmptyAccountIdsReturnsEmpty() {
        Commission_Eligibility_Config__mdt cfg = buildConfig(false, 'New', null, 4, 1);
        List<Commission__c> drafts = CommissionEligibilityService.evaluate(
            new Set<Id>(),
            new List<Commission_Eligibility_Config__mdt>{ cfg }
        );
        System.assertEquals(0, drafts.size());
    }

    @isTest
    static void testEmptyConfigsReturnsEmpty() {
        Account agency = createAgency();
        List<Commission__c> drafts = CommissionEligibilityService.evaluate(
            new Set<Id>{ agency.Id },
            new List<Commission_Eligibility_Config__mdt>()
        );
        System.assertEquals(0, drafts.size());
    }

    @isTest
    static void testPublicEntryPointDoesNotCrash() {
        Account agency = createAgency();

        Test.startTest();
        List<Commission__c> drafts = CommissionEligibilityService.evaluate(new Set<Id>{ agency.Id });
        Test.stopTest();

        System.assertNotEquals(null, drafts, 'Public entry point should always return a list, never null');
    }

    @isTest
    static void testProjectAndUnitStatusAndUnitCostAreApplied() {
        Account agency = createAgency();
        Opportunity opp = buildMockOppWithUnit(
            agency.Id,
            'Closed Won',
            1000000,
            'Palm View',
            'Booked',
            750000
        );

        Commission_Eligibility_Config__mdt cfg = buildConfig(false, 'Closed Won', null, 3, 1);
        cfg.Project_Name__c = 'Palm View';
        cfg.Required_Unit_Status__c = 'Booked';
        Map<Id, Account> agencies = new Map<Id, Account>{ agency.Id => agency };

        List<Commission__c> drafts = CommissionEligibilityService.evaluateOpps(
            new List<Opportunity>{ opp },
            agencies,
            new List<Commission_Eligibility_Config__mdt>{ cfg }
        );

        System.assertEquals(1, drafts.size(), 'Matching project and unit status should pass');
        System.assertEquals(750000, drafts[0].Base_Amount__c, 'Unit cost should override Opportunity amount');
        System.assertEquals('Palm View', drafts[0].Project_Name__c);
    }

    @isTest
    static void testAgencyStatusAndInternationalExclusion() {
        Account localAgency = createAgency();
        Account intlAgency = createAgency();

        Opportunity localOpp = buildMockOpp(localAgency.Id, 'New', 200000);
        Opportunity intlOpp = buildMockOpp(intlAgency.Id, 'New', 200000);

        Commission_Eligibility_Config__mdt cfg = buildConfig(true, 'New', null, 2, 1);
        Map<Id, Account> agencies = new Map<Id, Account>{
            localAgency.Id => new Account(Id = localAgency.Id, Is_Agency_International__c = 'No'),
            intlAgency.Id => new Account(Id = intlAgency.Id, Is_Agency_International__c = 'International')
        };

        List<Commission__c> drafts = CommissionEligibilityService.evaluateOpps(
            new List<Opportunity>{ localOpp, intlOpp },
            agencies,
            new List<Commission_Eligibility_Config__mdt>{ cfg }
        );

        System.assertEquals(1, drafts.size(), 'International agency should be excluded');
        System.assertEquals(localAgency.Id, drafts[0].Agency__c);
    }

    @isTest
    static void testProjectMismatchAgencyMissingAndNullInputs() {
        Account agency = createAgency();
        Opportunity opp = buildMockOppWithUnit(
            agency.Id,
            'New',
            150000,
            'Project A',
            'Ready',
            120000
        );
        Commission_Eligibility_Config__mdt cfg = buildConfig(false, 'New', null, 2, 1);
        cfg.Project_Name__c = 'Project B';
        cfg.Required_Unit_Status__c = 'Ready';

        List<Commission__c> draftsProjectMismatch = CommissionEligibilityService.evaluateOpps(
            new List<Opportunity>{ opp },
            new Map<Id, Account>{ agency.Id => agency },
            new List<Commission_Eligibility_Config__mdt>{ cfg }
        );
        System.assertEquals(0, draftsProjectMismatch.size(), 'Project mismatch should fail match');

        List<Commission__c> draftsMissingAgency = CommissionEligibilityService.evaluateOpps(
            new List<Opportunity>{ buildMockOpp(agency.Id, 'New', 150000) },
            new Map<Id, Account>(),
            new List<Commission_Eligibility_Config__mdt>{ buildConfig(false, 'New', null, 2, 1) }
        );
        System.assertEquals(0, draftsMissingAgency.size(), 'Opp should be skipped when agency not in map');

        System.assertEquals(
            0,
            CommissionEligibilityService.evaluate(null, new List<Commission_Eligibility_Config__mdt>{ cfg }).size(),
            'Null account ids should return empty'
        );
        System.assertEquals(
            0,
            CommissionEligibilityService.evaluate(new Set<Id>{ agency.Id }, null).size(),
            'Null configs should return empty'
        );
    }
}