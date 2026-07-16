@RestResource(urlMapping='/UnitsListing/*')
global without sharing class UnitListingServiceController {

    @TestVisible
    private static String testProjectId = 'a01U900000CyAH9IAN';

    @HttpGet
    global static void getUnitsByProject() {
        RestResponse restResponse = RestContext.response;
        restResponse.addHeader('Content-Type', 'application/json');
        
        ResponseWrapper response = new ResponseWrapper();

        try {
            String projectId = RestContext.request.params.get('projectId');

            // Validate early and return before querying
            if (String.isBlank(projectId) || !projectId.startsWith('a01')) {
                response.success = false;
                response.message = 'Invalid Project ID format';
                restResponse.responseBody = Blob.valueOf(JSON.serialize(response));
                return;
            }

            // Now safe to query
            List<Project__c> projects = [
                SELECT Publish_Project__c
                FROM Project__c
                WHERE Id = :projectId
                LIMIT 1
            ];

            if (projects == null || projects.isEmpty() || projects[0].Publish_Project__c != 'Published') {
                response.success = false;
                response.message = 'Project not found or not published';
                restResponse.responseBody = Blob.valueOf(JSON.serialize(response));
                return;
            }

            List<Unit__c> units = [
                SELECT Id, 
                Project_Name_F__c, 
                Project_Handover_Date__c, 
                Type__c, 
                Number_of_Bedrooms__c, 
                Number_of_Bathrooms__c, 
                Living_Space__c, 
                Living_Space_Square_Meter__c, 
                Additional_Area__c, 
                Balcony_Size__c, 
                Project__r.Name,
                Project__r.Payment_Plan_Title__c, 
                Title__c, 
                Cost_AED__c, 
                Cost_CHF_Number__c, 
                Cost_Per_Square_Meter_AED__c, 
                Cost_per_square_foot_AED__c, 
                Status__c, 
                Total_Area__c, 
                Total_Area_Square_Meter__c, 
                Floor__c, 
                Building__c 
                FROM Unit__c 
                WHERE Project__c = :projectId AND Status__c != 'Draft'
            ];

            if (units.isEmpty()) {
                response.success = true;
                response.message = 'No units found for the specified project';
                restResponse.responseBody = Blob.valueOf(JSON.serialize(response));
                return;
            }

            Set<Id> unitIds = new Set<Id>();
            for (Unit__c u : units) {
                unitIds.add(u.Id);
            }

            // Map of Unit Id to File__c Id (Floor Plan files only)
            Map<Id, Id> unitToFileIdMap = new Map<Id, Id>();
            for (File__c file : [
                SELECT Id, Unit__c 
                FROM File__c 
                WHERE Unit__c IN :unitIds AND Type__c = 'Floor Plan'
            ]) {
                unitToFileIdMap.put(file.Unit__c, file.Id);
            }

            List<UnitWrapper> unitWrappers = new List<UnitWrapper>();
            for (Unit__c unit : units) {
                UnitWrapper wrapper = new UnitWrapper(unit);

                Id fileId = unitToFileIdMap.get(unit.Id);
                if (fileId != null) {
                    wrapper.floorPlanFileId = fileId;
                }

                unitWrappers.add(wrapper);
            }

            response.success = true;
            response.message = 'Units retrieved successfully';
            response.units = unitWrappers;

        } catch (Exception e) {
            response.success = false;
            response.message = 'Error: ' + e.getMessage();
        }

        restResponse.responseBody = Blob.valueOf(JSON.serialize(response));
    }


    global class UnitWrapper {
        global String id { get; set; }
        global String title { get; set; }
        global String projectName { get; set; }
        global String building { get; set; }
        global String type { get; set; }
        global Integer numberOfBedrooms { get; set; }
        global Integer numberOfBathrooms { get; set; }
        global Decimal costAED { get; set; }
        global Decimal costCHF { get; set; }
        global Decimal costPerSquareMeterAED { get; set; }
        global Decimal costPerSquareFootAED { get; set; }
        global Decimal totalArea { get; set; }
        global Decimal totalAreaSquareMeter { get; set; }
        global Decimal livingSpace { get; set; }
        global Decimal livingSpaceSquareMeter { get; set; }
        global Decimal additionalArea { get; set; }
        global Decimal balconySize { get; set; }
        global Decimal floor { get; set; }
        global Date projectHandoverDate { get; set; }
        global String projectPaymentPlanTitle { get; set; }
        //global Date bookingDateTime { get; set; }
        global String status { get; set; }
        global String floorPlanFileId { get; set; }

        global UnitWrapper(Unit__c unit) {
            this.id = unit.Id;
            this.title = unit.Title__c;
            this.projectName = unit.Project_Name_F__c != null ? unit.Project_Name_F__c : unit.Project__r.Name;
            this.building = unit.Building__c;
            this.type = unit.Type__c;
            this.numberOfBedrooms = unit.Number_of_Bedrooms__c != null ? Integer.valueOf(unit.Number_of_Bedrooms__c) : null;
            this.numberOfBathrooms = unit.Number_of_Bathrooms__c != null ? Integer.valueOf(unit.Number_of_Bathrooms__c) : null;
            this.costAED = unit.Cost_AED__c;
            this.costCHF = unit.Cost_CHF_Number__c;
            this.costPerSquareMeterAED = unit.Cost_Per_Square_Meter_AED__c;
            this.costPerSquareFootAED = unit.Cost_per_square_foot_AED__c;
            this.totalArea = unit.Total_Area__c;
            this.totalAreaSquareMeter = unit.Total_Area_Square_Meter__c;
            this.livingSpace = unit.Living_Space__c;
            this.livingSpaceSquareMeter = unit.Living_Space_Square_Meter__c;
            this.additionalArea = unit.Additional_Area__c;
            this.balconySize = unit.Balcony_Size__c;
            this.floor = unit.Floor__c;
            this.projectHandoverDate = unit.Project_Handover_Date__c;
            this.projectPaymentPlanTitle = unit.Project__r.Payment_Plan_Title__c;
            //this.bookingDateTime = unit.Booking_Date_Time__c != null ? unit.Booking_Date_Time__c.date() : null;
            this.status = (unit.Status__c == 'Published') ? 'Available' : unit.Status__c;
        }
    }

    global class ResponseWrapper {
        global Boolean success { get; set; }
        global String message { get; set; }
        global List<UnitWrapper> units { get; set; }

        global ResponseWrapper() {
            this.success = false;
            this.message = '';
            this.units = new List<UnitWrapper>();
        }
    }
}