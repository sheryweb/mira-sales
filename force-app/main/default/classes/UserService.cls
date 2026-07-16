@RestResource(urlMapping='/ChangeUserActiveFlag/*')
global without sharing class UserService {

    @HttpPut
    global static String manageUserActivation(String userId) {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        List<User> u = [SELECT Id, IsActive, Deactivated_by_process__c FROM User WHERE Id = :userId AND Profile.UserLicense.Name = 'Customer Community' LIMIT 1];
        if (!u.isEmpty()) {
            List<UserLicense> communityLicense = [SELECT Id, Name, UsedLicenses, TotalLicenses FROM UserLicense WHERE Name = 'Customer Community'];
            String response;
            if(u[0].IsActive == false && u[0].Deactivated_by_process__c == false){
                return 'inactive_user';
            }
            if(u[0].IsActive){
                return 'user_active';
            } else {
                if((communityLicense[0].TotalLicenses - communityLicense[0].UsedLicenses) > 0){
                    response = 'user_activated';
                    u[0].Deactivated_by_process__c = false;
                    u[0].IsActive = true;
                    update u;
                } else {
                    return 'license_unavailable';
                }
            }
            return response;
        } else {
            return 'incorrect_user';
        }
    }
}