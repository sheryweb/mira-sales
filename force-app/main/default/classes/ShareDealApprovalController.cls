public with sharing class ShareDealApprovalController {
    /**
     * Resolves the Booked Opportunity linked to a Unit for use on the Unit action bar.
     */
    @AuraEnabled(cacheable=true)
    public static Id getBookedOpportunityIdForUnit(Id unitId) {
        if (unitId == null) {
            return null;
        }
        List<Opportunity> opps = [
            SELECT Id
            FROM Opportunity
            WHERE Unit__c = :unitId
              AND StageName = 'Booked'
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0].Id;
    }

    @AuraEnabled(cacheable=true)
    public static ShareDealApprovalService.ShareDealInfoDTO getShareDealInfo(Id opportunityId) {
        return ShareDealApprovalService.getShareDealInfo(opportunityId);
    }

    @AuraEnabled(cacheable=true)
    public static List<ShareDealApprovalService.RmOptionDTO> getEligibleSharedRmOptions(Id opportunityId) {
        return ShareDealApprovalService.getEligibleSharedRmOptions(opportunityId);
    }

    @AuraEnabled(cacheable=true)
    public static List<ShareDealApprovalService.RmOptionDTO> getLineManagerOptions() {
        return ShareDealApprovalService.getLineManagerOptions();
    }

    @AuraEnabled(cacheable=true)
    public static ShareDealApprovalService.OpenShareDealRequestDTO getOpenShareDealRequest(Id opportunityId) {
        return ShareDealApprovalService.getOpenShareDealRequest(opportunityId);
    }

    @AuraEnabled
    public static Id submitShareDealApproval(
        Id opportunityId,
        Id requestedSharedRmId,
        String justification,
        Id approvalRequestId,
        Id lineManagerUserId
    ) {
        return ShareDealApprovalService.submitShareDealApproval(
            opportunityId,
            requestedSharedRmId,
            justification,
            approvalRequestId,
            lineManagerUserId
        );
    }
}
