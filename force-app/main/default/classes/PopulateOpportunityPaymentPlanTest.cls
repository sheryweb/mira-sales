@isTest
public class PopulateOpportunityPaymentPlanTest {
    static testMethod void paymentPlanTest() {
        //Insert Project
        Project__c pr = new Project__c();
        pr.Name = 'Test Project';
        pr.Payment_Plan_Title__c = 'Payment Plan';
        pr.Description__c = 'This is a test Description';
        pr.Coordinates_Latitude__c = 58;
        pr.Coordinates_Longitude__c = 58;
        pr.District__c = 'Meydan';
        pr.Handover__c = system.today();
        insert pr;
        
        //Insert Account
        Account ac = new Account();
        ac.Name = 'Test Account';
        ac.Type = 'Agency';
        ac.Phone = '023659856';
        insert ac;
        
        //Insert Unit
        Unit__c ut = new Unit__c();
        ut.Cost_AED__c = 1;
        ut.Project__c = pr.Id;
        ut.Type__c = 'Villa';
        ut.Number_of_Bathrooms__c = 1;
        ut.Number_of_Bedrooms__c = 1;
        ut.Total_Area__c = 1234;
        ut.Status__c = 'Draft';
        insert ut;
        
        //Insert Payment Plan
        List<Payment_Plan__c> paymentPlan = new List<Payment_Plan__c>();

        paymentPlan.add(new Payment_Plan__c(
            Name = 'payment plan',
            Percent__c = 20,
            Date__c = Date.today(),
            Project__c = pr.Id
        ));

        insert paymentPlan;

        //Insert Files
        List<File__c> files = new List<File__c>();

        files.add(new File__c(
            Type__c = 'Schemas/PDFs',
            Unit__c = ut.Id
        ));
        files.add(new File__c(
            Type__c = 'Schemas/PDFs',
            Unit__c = ut.Id
        ));
        files.add(new File__c(
            Type__c = 'Floor Plan',
            Unit__c = ut.Id
        ));
        files.add(new File__c(
            Type__c = 'Unit Layout Preview',
            Unit__c = ut.Id
        ));
        insert files;

        //Insert Content Version
        List<ContentVersion> contentVersions = new List<ContentVersion>();
        contentVersions.add(new ContentVersion(
            Title = 'Test Document',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document2',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        contentVersions.add(new ContentVersion(
            Title = 'Test Document3',
            VersionData = Blob.valueOf('Test content'),
            PathOnClient = 'TestDocument' + '.pdf',
            IsMajorVersion = true
        ));
        insert contentVersions;
        
        //Insert Content Document Link
        contentVersions = [SELECT Id, ContentDocumentId, Title, FileExtension FROM ContentVersion];

        List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[0].ContentDocumentId,
            LinkedEntityId = files[0].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[1].ContentDocumentId,
            LinkedEntityId = files[1].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));
        contentDocumentLinks.add(new ContentDocumentLink(
            ContentDocumentId = contentVersions[2].ContentDocumentId,
            LinkedEntityId = files[2].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        ));

        insert contentDocumentLinks;
        
        //Make Unit Available
        //ut.Status__c = 'Published';
        //update ut;
        
        //Insert Opportunity
        Opportunity op = new Opportunity();
        op.Unit__c = ut.Id;
        op.AccountId = ac.Id;
        op.Name = 'Test Opportunity';
        op.StageName = 'New';
        op.CloseDate = Date.today();
        insert op;
        
        //Insert Cash Flow Sum
        Cash_Flow_Sum__c cfs = new Cash_Flow_Sum__c();
        cfs.Name = 'Test Cash Flow Sum';
        cfs.Unit__c = ut.Id;
        insert cfs;
        
        //Insert Cash Flow
        List<Cash_Flow__c> cashFlows = new List<Cash_Flow__c>();

        cashFlows.add(new Cash_Flow__c(
            Unit__c = ut.Id,
            Name = 'cash Flow',
            Cash_Flow_Sum__c = cfs.Id,
            Date__c = Date.today()
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = ut.Id,
            Name = 'cash Flow',
            Cash_Flow_Sum__c = cfs.Id,
            Date__c = Date.today()
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = ut.Id,
            Name = 'cash Flow',
            Cash_Flow_Sum__c = cfs.Id,
            Date__c = Date.today()
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = ut.Id,
            Name = 'cash Flow',
            Cash_Flow_Sum__c = cfs.Id,
            Date__c = Date.today()
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = ut.Id,
            Name = 'cash Flow',
            Cash_Flow_Sum__c = cfs.Id,
            Date__c = Date.today()
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = ut.Id,
            Name = 'cash Flow',
            Cash_Flow_Sum__c = cfs.Id,
            Date__c = Date.today()
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = ut.Id,
            Name = 'cash Flow',
            Cash_Flow_Sum__c = cfs.Id,
            Date__c = Date.today()
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = ut.Id,
            Name = 'cash Flow',
            Cash_Flow_Sum__c = cfs.Id,
            Date__c = Date.today()
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = ut.Id,
            Name = 'cash Flow',
            Cash_Flow_Sum__c = cfs.Id,
            Date__c = Date.today()
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = ut.Id,
            Name = 'cash Flow',
            Cash_Flow_Sum__c = cfs.Id,
            Date__c = Date.today()
        ));
        cashFlows.add(new Cash_Flow__c(
            Unit__c = ut.Id,
            Name = 'cash Flow',
            Cash_Flow_Sum__c = cfs.Id,
            Date__c = Date.today()
        ));
        
        insert cashFlows;
        
        //Setting up Invocable Variables Params
        PopulateOpportunityPaymentPlan.FlowParams fparams = new PopulateOpportunityPaymentPlan.FlowParams();
        //fparams.ProjectId = pr.Id;
        fparams.UnitId = ut.Id;
        fparams.OpportunityId = op.Id;
        
        Test.startTest();
        PopulateOpportunityPaymentPlan.PopulatePaymentPlan(new List<PopulateOpportunityPaymentPlan.FlowParams>{ fparams });
        Test.stopTest();
    }
}