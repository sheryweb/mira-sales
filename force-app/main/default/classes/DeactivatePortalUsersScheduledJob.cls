global class DeactivatePortalUsersScheduledJob implements Schedulable {

    global void execute(SchedulableContext SC) {
        Date thresholdDate = Date.today().addDays(-14);
        List<User> portalUsersToDeactivate = new List<User>();

        if(Test.isRunningTest()){
            portalUsersToDeactivate = [SELECT Id, Name
                FROM User
                WHERE Name = 'Schedule Test User'
                AND Profile.Name = 'Agency User'];
        } else {
            portalUsersToDeactivate = [SELECT Id, Name
                FROM User
                WHERE LastLoginDate < :thresholdDate
                AND Profile.Name = 'Agency User'
                AND IsActive = true];
        }

        for(User portalUser : portalUsersToDeactivate) {
            portalUser.IsActive = false;
            portalUser.Deactivated_by_process__c = true;
        }

        update portalUsersToDeactivate;
    }
}