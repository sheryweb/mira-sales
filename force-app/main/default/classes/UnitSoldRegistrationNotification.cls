public class UnitSoldRegistrationNotification {
	//Method to send email with PDF attached
    @InvocableMethod
    public static void sendEmailWithPdfAttachment(List<Id> recordIds) {
        //Assuming only one Id is passed from Flow
        Id recordId = recordIds[0];
        //Fetch the recipient email from the record
        Opportunity opp = [SELECT Id, Account_Name__c, Unit__c, Unit_Price__c, Unit_Title__c, Sold_Date_for_Email__c FROM Opportunity WHERE Id = :recordId LIMIT 1];
        Unit__c unt = [SELECT Id, Project_Name_F__c, Building__c FROM Unit__c WHERE Id = :opp.Unit__c LIMIT 1];
        
        //Prepare recipient emails
        List<String> recipientEmails = new List<String>{'admin@bhartirealestateconsultancy.com', 'founder@bhartirealestateconsultancy.com'};
        //List<String> recipientEmails = new List<String>{'sheraz.h@miradevelopments.ae'};
        
        //Set CC Emails
        String ccEmails = 'finance@miradevelopments.ae, jad.orabi@miradevelopments.ae, ayman.a@miradevelopments.ae';
        //String ccEmails = 'sheraz.dev@gmail.com';
        
        //Create an email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(recipientEmails);
        email.setSubject('Unit ' +opp.Unit_Title__c+ ' is Ready for Registration');
        
        //Set the plain text body
        Decimal unitPrice = opp.Unit_Price__c;
        String formattedAmount = unitPrice.format();
        String emailBody = 'Dear All,\n' +
        'Please note that the below unit is ready to be registered: \n\n'+
        'Customer Name: '+opp.Account_Name__c+'\n'+
        'Unit: '+opp.Unit_Title__c+'\n'+
        'Tower: '+unt.Building__c+'\n'+
        'Project: '+unt.Project_Name_F__c+'\n'+
        'Price: AED '+formattedAmount+'\n'+
        'Sold Date: '+opp.Sold_Date_for_Email__c+'\n\n'+
        'Regards,\n'+
        'Jadallah Orabi \n'+
        'Contracts Management \n\n';
        email.setPlainTextBody(emailBody);
        
        //Add CC addresses if any valid email addresses are present
        if (!String.isBlank(ccEmails)) {
            // Split CC emails by comma and check if any are valid
            List<String> ccList = new List<String>();
            for (String ccEmail : ccEmails.split(',')) {
                ccEmail = ccEmail.trim();
                if (!String.isBlank(ccEmail)) {
                    ccList.add(ccEmail);
                }
            }
            
            //Set CC addresses if we have valid ones
            if (!ccList.isEmpty()) {
                email.setCcAddresses(ccList);
            }
        }
        
        //email.setOrgWideEmailAddressId('0D2U90000000fO9KAI'); //SandBox Organization-Wide Email Address ID for jad.orabi@miradevelopments.ae
        email.setOrgWideEmailAddressId('0D2Rg0000000P85KAE'); //Production Organization-Wide Email Address ID for jad.orabi@miradevelopments.ae
        
        //Send the email
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }

    // Custom Exception to handle errors
    public class CustomException extends Exception {}
}