public class UnitSharingBatch implements Database.Batchable<SObject> {
    public String query;

    public UnitSharingBatch() {
        query = 'SELECT Id, Status__c FROM Unit__c WHERE Status__c IN (\'Booked\', \'Reserved\', \'Sold\')';
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<Unit__c> units) {
        List<Unit__Share> sharesToDelete = new List<Unit__Share>();
        List<Unit__Share> sharesToInsert = new List<Unit__Share>();

        for (Unit__c unit : units) {
            List<Opportunity> opportunities = [
                SELECT Id, OwnerId, StageName
                FROM Opportunity
                WHERE Unit__c = :unit.Id
                AND StageName IN ('Booked', 'Reserved', 'Sold')
            ];

            if (!opportunities.isEmpty()) {
                Id opportunityOwnerId = opportunities[0].OwnerId;

                // Query for existing shares to remove non-owner shares
                List<Unit__Share> unitShares = [
                    SELECT Id, UserOrGroupId, ParentId 
                    FROM Unit__Share
                    WHERE ParentId = :unit.Id
                    AND RowCause = 'Manual'
                ];

                // Delete shares for users who are not the Opportunity owner
                for (Unit__Share share : unitShares) {
                    if (share.UserOrGroupId != opportunityOwnerId) {
                        sharesToDelete.add(share);
                    }
                }

                // Check if the Opportunity owner is already shared
                Boolean isOwnerShared = false;
                for (Unit__Share share : unitShares) {
                    if (share.UserOrGroupId == opportunityOwnerId) {
                        isOwnerShared = true;
                        break;
                    }
                }

                // If the Opportunity owner is not already shared, create the share
                if (!isOwnerShared) {
                    Unit__Share newShare = new Unit__Share(
                        ParentId = unit.Id,
                        UserOrGroupId = opportunityOwnerId,
                        RowCause = 'Manual',
                        AccessLevel = 'Read'
                    );
                    sharesToInsert.add(newShare);
                }
            }
        }

        // Insert new shares and delete unnecessary ones
        if (!sharesToInsert.isEmpty()) {
            insert sharesToInsert;
        }
        if (!sharesToDelete.isEmpty()) {
            delete sharesToDelete;
        }
    }

    public void finish(Database.BatchableContext BC) {
        // Optional post-processing (notifications, etc.)
    }
}