@isTest
private class BrokerShareholderApplyHandlerTest {

    private static Account makeAgency() {
        Account a = new Account(Name = 'SH Agency ' + String.valueOf(Crypto.getRandomLong()), Skip_Trigger__c = true);
        insert a;
        return a;
    }

    @isTest
    static void updates_inserts_and_deletes() {
        Account acc = makeAgency();
        Shareholder__c keep = new Shareholder__c(Account__c = acc.Id, Name = 'Alice', Percent__c = 50);
        Shareholder__c drop = new Shareholder__c(Account__c = acc.Id, Name = 'Bob', Percent__c = 50);
        insert new List<Shareholder__c>{ keep, drop };

        Map<String, Object> payload = new Map<String, Object>{
            'upserts' => new List<Object>{
                new Map<String, Object>{ 'recordId' => keep.Id, 'name' => 'Alice', 'percent' => 70 },
                new Map<String, Object>{ 'recordId' => '', 'name' => 'Carol', 'percent' => 30 }
            },
            'deletes' => new List<Object>{ drop.Id }
        };

        Test.startTest();
        EventBus.publish(new Broker_Shareholder_Apply__e(
            Account_Id__c = acc.Id, Changes_JSON__c = JSON.serialize(payload)));
        Test.stopTest();

        Map<String, Decimal> byName = new Map<String, Decimal>();
        for (Shareholder__c sh : [SELECT Name, Percent__c FROM Shareholder__c WHERE Account__c = :acc.Id]) {
            byName.put(sh.Name, sh.Percent__c);
        }
        System.assertEquals(2, byName.size(), 'Bob deleted, Carol added, Alice kept');
        System.assertEquals(70, byName.get('Alice'), 'Alice updated to 70');
        System.assertEquals(30, byName.get('Carol'), 'Carol inserted at 30');
        System.assertEquals(false, byName.containsKey('Bob'), 'Bob removed');
    }

    @isTest
    static void ignores_other_accounts_records() {
        Account mine = makeAgency();
        Account other = makeAgency();
        Shareholder__c othersSh = new Shareholder__c(Account__c = other.Id, Name = 'Outsider', Percent__c = 100);
        insert othersSh;

        // Tampered payload: try to update / delete another account's shareholder via my event.
        Map<String, Object> payload = new Map<String, Object>{
            'upserts' => new List<Object>{
                new Map<String, Object>{ 'recordId' => othersSh.Id, 'name' => 'Hacked', 'percent' => 1 } },
            'deletes' => new List<Object>{ othersSh.Id }
        };

        Test.startTest();
        BrokerShareholderApplyHandler.handle(new List<Broker_Shareholder_Apply__e>{
            new Broker_Shareholder_Apply__e(Account_Id__c = mine.Id, Changes_JSON__c = JSON.serialize(payload)) });
        Test.stopTest();

        Shareholder__c after = [SELECT Name, Percent__c FROM Shareholder__c WHERE Id = :othersSh.Id];
        System.assertEquals('Outsider', after.Name, 'another account\'s shareholder untouched');
        System.assertEquals(100, after.Percent__c);
    }

    @isTest
    static void blank_and_bad_payloads_are_safe() {
        Account acc = makeAgency();
        BrokerShareholderApplyHandler.handle(new List<Broker_Shareholder_Apply__e>{
            new Broker_Shareholder_Apply__e(Account_Id__c = null, Changes_JSON__c = null),
            new Broker_Shareholder_Apply__e(Account_Id__c = acc.Id, Changes_JSON__c = 'not json'),
            new Broker_Shareholder_Apply__e(Account_Id__c = acc.Id, Changes_JSON__c = '{}')
        });
        System.assert(true, 'no exception on blank / malformed payloads');
    }
}