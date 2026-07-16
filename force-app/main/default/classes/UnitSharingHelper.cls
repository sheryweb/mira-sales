public class UnitSharingHelper {
    public static void manageUnitSharing(List<Unit__c> newUnits, Map<Id, Unit__c> oldUnits) {
        List<Unit__Share> sharesToInsert = new List<Unit__Share>();
        List<Unit__Share> sharesToDelete = new List<Unit__Share>();

        // Define the statuses we want to manage sharing for
        Set<String> targetStatuses = new Set<String>{'Booked', 'Reserved', 'Sold'};

        for (Unit__c unit : newUnits) {
            Unit__c oldUnit = oldUnits.get(unit.Id);

            // Check if the status has changed to one of the target statuses
            if (targetStatuses.contains(unit.Status__c) && 
                (oldUnit == null || !targetStatuses.contains(oldUnit.Status__c))) {
                
                // Query the related Opportunity record to get the Opportunity owner
                List<Opportunity> relatedOpportunities = [SELECT OwnerId FROM Opportunity WHERE Unit__c = :unit.Id LIMIT 1];
                
                // Ensure there's at least one Opportunity related to the Unit__c
                if (!relatedOpportunities.isEmpty()) {
                    Opportunity relatedOpportunity = relatedOpportunities[0];
                    
                    // Create a new sharing record for the Opportunity owner
                    Unit__Share unitShare = new Unit__Share();
                    unitShare.ParentId = unit.Id;  // Parent record ID
                    unitShare.UserOrGroupId = relatedOpportunity.OwnerId;  // Opportunity owner
                    unitShare.RowCause = 'Manual'; // Using 'Manual' as RowCause for custom sharing
                    unitShare.AccessLevel = 'Read'; // Set access level to Read, can be 'Edit' if needed

                    sharesToInsert.add(unitShare);
                }
            }
            
            // Remove sharing if the status changes away from one of the target statuses
            else if (oldUnit != null && targetStatuses.contains(oldUnit.Status__c) && 
                     !targetStatuses.contains(unit.Status__c)) {
                List<Unit__Share> existingShares = [
                    SELECT Id 
                    FROM Unit__Share 
                    WHERE ParentId = :unit.Id AND RowCause = 'Manual' // Adjust RowCause here if needed
                ];
                sharesToDelete.addAll(existingShares);
            }
        }

        if (!sharesToInsert.isEmpty()) {
            insert sharesToInsert;
        }
        if (!sharesToDelete.isEmpty()) {
            delete sharesToDelete;
        }
    }
}