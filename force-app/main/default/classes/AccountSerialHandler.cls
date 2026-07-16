public class AccountSerialHandler {
    public static void setSerialNumbers(List<Account> newAccounts) {
        //Id agencyRecordTypeId = '012Hp000001yUTAIA2'; //Sandbox
        Id agencyRecordTypeId = '012Hp000001yUTAIA2'; //Production
        // Query the highest existing Serial__c value
        AggregateResult result = [
            SELECT MAX(Serial__c) maxSerial
            FROM Account
            WHERE RecordTypeId = :agencyRecordTypeId AND Serial__c != null
        ];

        // Get the highest Serial__c or start from 0 if none exist
        Decimal maxSerialDecimal = (result.get('maxSerial') != null) ? 
                                    (Decimal)result.get('maxSerial') : 0;
        Integer maxSerial = maxSerialDecimal.intValue(); // Convert Decimal to Integer

        // Assign Serial__c for each new Account
        for (Account acc : newAccounts) {
            if (acc.RecordTypeId == agencyRecordTypeId) {
                maxSerial++;
                acc.Serial__c = maxSerial; // Assign the serial number
            }
        }
    }
}