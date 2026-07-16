@RestResource(urlMapping='/DeactivateUser/*')
global without sharing class UserDeactivationService {

    @HttpPut
    global static String manageUserDeactivation() {
        RestRequest req = RestContext.request;
        String userId = req.params.get('userId');
        RestResponse res = RestContext.response;

        List<User> u = [SELECT Id, IsActive, Deactivated_by_process__c FROM User WHERE Id = :userId AND Profile.UserLicense.Name = 'Customer Community' LIMIT 1];
        if (!u.isEmpty()) {
            String response;
            if(u[0].IsActive == false){
                response = 'inactive_user';
            }
            if(u[0].IsActive){
                u[0].IsActive = false;
                update u;
                response = 'user_deactivated';
            }
            return response;
        } else {
            return 'incorrect_user';
        }
    }
}