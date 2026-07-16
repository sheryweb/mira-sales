trigger UnitTrigger on Unit__c (before insert, after insert, before update, after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
          // List to hold the records that need sharing logic
          /*List<Unit__c> unitsToProcess = new List<Unit__c>();
      
          for (Unit__c unit : Trigger.new) {
              Unit__c oldUnit = Trigger.oldMap.get(unit.Id);
              
              // Check if the Status has changed to 'Booked'
              if (unit.Status__c == 'Booked' && (oldUnit.Status__c != 'Booked' || oldUnit.Status__c == null)) {
                  unitsToProcess.add(unit);  // Add unit to process if status is 'Booked'
              }
          }*/
      
          //if (Trigger.new[0].Project_Name_F__c <> 'POST HOTEL & RESIDENCES By ELLIE SAAB') {
              //UnitTriggerHandler.handleUnitsCashFlowAfterUpdate(Trigger.new, Trigger.old);
          //}
          
          // List to store units where Cost fields have changed
          List<Unit__c> unitsWithCostChanges = new List<Unit__c>();
          
          for(Unit__c newUnit : Trigger.new) {
              Unit__c oldUnit = Trigger.oldMap.get(newUnit.Id);
              
              // Check if either Cost_AED__c or Cost_CHF__c has changed
              if(newUnit.Cost_AED__c != oldUnit.Cost_AED__c || 
                 newUnit.Cost_CHF__c != oldUnit.Cost_CHF__c) {
                  unitsWithCostChanges.add(newUnit);
              }
          }
          
          // Only call the handler if we have units with cost changes
          if(!unitsWithCostChanges.isEmpty()) {
              UnitTriggerHandler.handleUnitsCashFlowAfterUpdate(unitsWithCostChanges, Trigger.old);
          }
      }
  }