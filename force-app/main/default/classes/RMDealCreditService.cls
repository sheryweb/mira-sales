/**
 * Maintains RM_Deal_Credit__c rows for Opportunities.
 * Single deals: one row at 100%. Share deals: two rows at 50% each.
 */
public without sharing class RMDealCreditService {
    public static final Decimal PERCENT_FULL = 100;
    public static final Decimal PERCENT_HALF = 50;
    public static final String DEAL_TYPE_SINGLE = 'Single';
    public static final String DEAL_TYPE_SHARE = 'Share';

    public static void rebuildForOpportunityIds(Set<Id> opportunityIds) {
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return;
        }

        List<Opportunity> opportunities = [
            SELECT Id, OwnerId, Owner.FirstName, Owner.LastName, Owner.Name,
                   Owner.UserRole.Name, Share_Deal__c, Shared_RM__c,
                   Shared_RM__r.FirstName, Shared_RM__r.LastName, Shared_RM__r.Name,
                   Shared_RM__r.UserRole.Name, Unit_Price__c
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ];
        if (opportunities.isEmpty()) {
            return;
        }

        deleteExistingCredits(opportunityIds);

        Set<Id> userIds = new Set<Id>();
        for (Opportunity opp : opportunities) {
            if (opp.OwnerId != null) {
                userIds.add(opp.OwnerId);
            }
            if (opp.Share_Deal__c == true && opp.Shared_RM__c != null) {
                userIds.add(opp.Shared_RM__c);
            }
        }

        Map<Id, User> usersById = userIds.isEmpty()
            ? new Map<Id, User>()
            : new Map<Id, User>([
                SELECT Id, FirstName, LastName, Name, UserRole.Name
                FROM User
                WHERE Id IN :userIds
            ]);

        List<RM_Deal_Credit__c> creditsToInsert = new List<RM_Deal_Credit__c>();
        for (Opportunity opp : opportunities) {
            creditsToInsert.addAll(buildCreditsForOpportunity(opp, usersById));
        }

        if (!creditsToInsert.isEmpty()) {
            insert creditsToInsert;
        }
    }

    public static void rebuildForOpportunity(Id opportunityId) {
        if (opportunityId == null) {
            return;
        }
        rebuildForOpportunityIds(new Set<Id>{ opportunityId });
    }

    @TestVisible
    private static List<RM_Deal_Credit__c> buildCreditsForOpportunity(
        Opportunity opp,
        Map<Id, User> usersById
    ) {
        List<RM_Deal_Credit__c> credits = new List<RM_Deal_Credit__c>();
        if (opp == null || opp.OwnerId == null) {
            return credits;
        }

        Decimal unitPrice = opp.Unit_Price__c == null ? 0 : opp.Unit_Price__c;
        Boolean isShare = opp.Share_Deal__c == true && opp.Shared_RM__c != null;
        Decimal percent = isShare ? PERCENT_HALF : PERCENT_FULL;
        Decimal amount = isShare ? (unitPrice * 0.5).setScale(2, System.RoundingMode.HALF_UP) : unitPrice;
        String dealType = isShare ? DEAL_TYPE_SHARE : DEAL_TYPE_SINGLE;

        User owner = usersById.get(opp.OwnerId);
        credits.add(newCredit(
            opp.Id,
            opp.OwnerId,
            formatUserName(owner),
            managerNameForRole(owner == null ? null : owner.UserRole == null ? null : owner.UserRole.Name),
            percent,
            amount,
            true,
            dealType
        ));

        if (isShare) {
            User sharedRm = usersById.get(opp.Shared_RM__c);
            credits.add(newCredit(
                opp.Id,
                opp.Shared_RM__c,
                formatUserName(sharedRm),
                managerNameForRole(sharedRm == null ? null : sharedRm.UserRole == null ? null : sharedRm.UserRole.Name),
                percent,
                amount,
                false,
                dealType
            ));
        }

        return credits;
    }

    private static RM_Deal_Credit__c newCredit(
        Id opportunityId,
        Id rmId,
        String rmName,
        String managerName,
        Decimal percent,
        Decimal amount,
        Boolean isPrimary,
        String dealType
    ) {
        return new RM_Deal_Credit__c(
            Opportunity__c = opportunityId,
            RM__c = rmId,
            RM_Name__c = rmName,
            Manager_Name__c = managerName,
            Credit_Percent__c = percent,
            Credit_Amount__c = amount,
            Is_Primary__c = isPrimary,
            Deal_Type__c = dealType
        );
    }

    private static void deleteExistingCredits(Set<Id> opportunityIds) {
        List<RM_Deal_Credit__c> existing = [
            SELECT Id
            FROM RM_Deal_Credit__c
            WHERE Opportunity__c IN :opportunityIds
        ];
        if (!existing.isEmpty()) {
            delete existing;
        }
    }

    @TestVisible
    private static String formatUserName(User u) {
        if (u == null) {
            return null;
        }
        String first = u.FirstName == null ? '' : u.FirstName.trim();
        String last = u.LastName == null ? '' : u.LastName.trim();
        String full = (first + ' ' + last).trim();
        return String.isNotBlank(full) ? full : u.Name;
    }

    /**
     * Public accessor for monthly sales report / leaderboard aggregation.
     * Mirrors Opportunity.Manager_Name__c role-to-manager mapping.
     */
    public static String getManagerNameForRole(String roleName) {
        return managerNameForRole(roleName);
    }

    /**
     * Mirrors Opportunity.Manager_Name__c role-to-manager mapping.
     */
    @TestVisible
    private static String managerNameForRole(String roleName) {
        if (String.isBlank(roleName)) {
            return 'Not Assigned';
        }
        if (roleName == 'Sales Manager 1' || roleName == 'Sales Manager Georgia 1') {
            return 'Vijendra Singh';
        }
        if (roleName == 'Sales Manager 2' || roleName == 'Sales Manager Georgia 2') {
            return 'Aiham Alkeilani';
        }
        if (roleName == 'Sales Manager 3' || roleName == 'Sales Manager Georgia 3') {
            return 'Khalid Samir';
        }
        if (roleName == 'Sales Manager 4' || roleName == 'Sales Manager Georgia 4') {
            return 'Honghao Cheng';
        }
        return 'Not Assigned';
    }
}
