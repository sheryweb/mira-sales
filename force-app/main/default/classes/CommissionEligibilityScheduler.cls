public class CommissionEligibilityScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new CommissionEligibilityBatch(), 200);
    }
}