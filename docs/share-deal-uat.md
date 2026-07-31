# Share Deal — Deploy & UAT Checklist

## Deploy order

1. Opportunity fields + validation rules
2. `RM_Deal_Credit__c` object + fields
3. `Approval_Request__c` fields (`Opportunity__c`, `Requested_Shared_RM__c`) + `Share Deal` request type
4. Workflow field updates + `Share_Deal` approval process (activate in target org if needed)
5. Apex classes/triggers + LWC + Aura bar + permission set
6. Report types
7. Assign permission set **Share Deal Approval Access** to Sales Manager MIRA users

## Historical data load

1. Export current manually tracked share pairs (Owner + Shared RM + Opportunity Id).
2. As System Administrator, update Opportunities:
   - `Share_Deal__c` = true
   - `Shared_RM__c` = partner RM
   - `Share_Deal_Status__c` = Approved
3. Seed / rebuild credits:
   ```apex
   Database.executeBatch(new RMDealCreditRebuildBatch(), 200);
   ```

## UAT scenarios

- [ ] Booked Opportunity owned by RM A: **Request Share Deal** visible on actions bar
- [ ] Select RM B + justification ≥ 10 chars → submit → status Pending on request and Opportunity
- [ ] Line Manager approves → CSO approves → Opportunity shows Share Deal + Shared RM
- [ ] Two `RM_Deal_Credit__c` rows at 50% each; Owner Credit Amount = Unit Price / 2
- [ ] Rejection path: Opp `Share_Deal_Status__c` = Rejected; Share Deal remains unchecked
- [ ] Cannot pick Owner as Shared RM
- [ ] Non-owner cannot submit (unless System Administrator)
- [ ] Unit sharing still only grants access to Opportunity Owner (not Shared RM)
- [ ] Report type **RM Deal Credits with Opportunity**: group by RM Name, sum Credit Amount
- [ ] Opportunity custom report type shows Deal Type / Share Deal / Shared RM Name columns
