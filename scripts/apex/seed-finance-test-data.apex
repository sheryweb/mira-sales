/**
 * Finance Center Phase 0 — seed data for the working sandbox.
 * Creates 13 units across the three multi-currency test projects with payment plans,
 * invoices, and receipts shaped to exercise every dashboard state:
 * Fully Paid / On Track / Overdue / Defaulted health, every aging bucket, due-but-not-
 * invoiced instalments, an on-account (unallocated) receipt, PDC cheques, escrow deposits.
 * Engine is ON in working, so inserting receipts/lines also live-tests the intraday hooks.
 * Idempotent-ish: aborts if seed units already exist.
 */
class SeedException extends Exception {}

if ([SELECT COUNT() FROM Unit__c WHERE Title__c LIKE 'FIN-SEED-%'] > 0) {
    throw new SeedException('Seed units already exist — delete FIN-SEED-% units first.');
}

Map<String, Project__c> projects = new Map<String, Project__c>();
for (Project__c p : [SELECT Id, Name FROM Project__c WHERE Name IN
        ('MIRA Marina Heights (Test)', 'MIRA Bay Tower (Test)', 'MIRA Alpine Residences (Test)')]) {
    projects.put(p.Name, p);
}
if (projects.size() != 3) throw new SeedException('Expected the 3 test projects in working.');
Id marina = projects.get('MIRA Marina Heights (Test)').Id;   // AED
Id bay    = projects.get('MIRA Bay Tower (Test)').Id;        // USD
Id alpine = projects.get('MIRA Alpine Residences (Test)').Id; // CHF

// ---- units (created Draft per validation rule, then moved) ----
List<Unit__c> units = new List<Unit__c>{
    new Unit__c(Title__c='FIN-SEED-MH-201', Project__c=marina, Status__c='Draft', Cost_AED__c=1200000, Tower__c='Tower 1', Floor__c=2),
    new Unit__c(Title__c='FIN-SEED-MH-202', Project__c=marina, Status__c='Draft', Cost_AED__c=1200000, Tower__c='Tower 1', Floor__c=3),
    new Unit__c(Title__c='FIN-SEED-MH-203', Project__c=marina, Status__c='Draft', Cost_AED__c=960000,  Tower__c='Tower 1', Floor__c=4),
    new Unit__c(Title__c='FIN-SEED-MH-204', Project__c=marina, Status__c='Draft', Cost_AED__c=1200000, Tower__c='Tower 2', Floor__c=2),
    new Unit__c(Title__c='FIN-SEED-MH-205', Project__c=marina, Status__c='Draft', Cost_AED__c=900000,  Tower__c='Tower 2', Floor__c=3),
    new Unit__c(Title__c='FIN-SEED-MH-206', Project__c=marina, Status__c='Draft', Cost_AED__c=840000,  Tower__c='Tower 2', Floor__c=4),
    // USD/CHF projects price via Cost_USD__c / Cost_CHF__c (Unit_Cost_Number__c resolves to
    // them) — set both the project-currency price and an approximate Cost_AED__c like real data.
    new Unit__c(Title__c='FIN-SEED-BT-301', Project__c=bay,    Status__c='Draft', Cost_AED__c=735000,  Cost_USD__c=200000, Tower__c='A', Floor__c=5),
    new Unit__c(Title__c='FIN-SEED-BT-302', Project__c=bay,    Status__c='Draft', Cost_AED__c=735000,  Cost_USD__c=200000, Tower__c='A', Floor__c=6),
    new Unit__c(Title__c='FIN-SEED-BT-303', Project__c=bay,    Status__c='Draft', Cost_AED__c=550000,  Cost_USD__c=150000, Tower__c='B', Floor__c=5),
    new Unit__c(Title__c='FIN-SEED-BT-304', Project__c=bay,    Status__c='Draft', Cost_AED__c=550000,  Cost_USD__c=150000, Tower__c='B', Floor__c=6),
    new Unit__c(Title__c='FIN-SEED-AL-401', Project__c=alpine, Status__c='Draft', Cost_AED__c=1446000, Cost_CHF__c=320000, Tower__c='A', Floor__c=1),
    new Unit__c(Title__c='FIN-SEED-AL-402', Project__c=alpine, Status__c='Draft', Cost_AED__c=994000,  Cost_CHF__c=220000, Tower__c='A', Floor__c=2),
    new Unit__c(Title__c='FIN-SEED-AL-403', Project__c=alpine, Status__c='Draft', Cost_AED__c=1356000, Cost_CHF__c=300000, Tower__c='B', Floor__c=1)
};
insert units;
Map<String, Unit__c> byTitle = new Map<String, Unit__c>();
for (Unit__c u : units) byTitle.put(u.Title__c, u);
Map<String, String> statuses = new Map<String, String>{
    'FIN-SEED-MH-201'=>'Sold', 'FIN-SEED-MH-202'=>'Sold', 'FIN-SEED-MH-203'=>'Booked',
    'FIN-SEED-MH-204'=>'Sold', 'FIN-SEED-MH-205'=>'Reserved', 'FIN-SEED-MH-206'=>'Booked',
    'FIN-SEED-BT-301'=>'Sold', 'FIN-SEED-BT-302'=>'Sold', 'FIN-SEED-BT-303'=>'Booked',
    'FIN-SEED-BT-304'=>'Sold', 'FIN-SEED-AL-401'=>'Sold', 'FIN-SEED-AL-402'=>'Booked',
    'FIN-SEED-AL-403'=>'Sold'
};
List<Unit__c> statusUpdates = new List<Unit__c>();
for (Unit__c u : units) statusUpdates.add(new Unit__c(Id=u.Id, Status__c=statuses.get(u.Title__c)));
update statusUpdates;

// ---- customers + deals (Tab 2 actions need account/opportunity context) ----
// NOTE: the org's Opportunity automation renames new deals and resets StageName to 'New';
// the Collections dashboard falls back to any deal on the unit, so that is fine.
List<Account> accounts = new List<Account>();
for (Integer i = 0; i < units.size(); i++) {
    accounts.add(new Account(Name = 'FIN-SEED Customer ' + String.valueOf(i + 1).leftPad(2, '0')));
}
insert accounts;
List<Opportunity> opps = new List<Opportunity>();
for (Integer i = 0; i < units.size(); i++) {
    opps.add(new Opportunity(
        Name = 'FIN-SEED Deal ' + units[i].Title__c,
        StageName = statuses.get(units[i].Title__c),
        CloseDate = Date.today(),
        AccountId = accounts[i].Id,
        Unit__c = units[i].Id
    ));
}
insert opps;

// ---- cash-flow sums ----
Map<Id, Cash_Flow_Sum__c> sums = new Map<Id, Cash_Flow_Sum__c>();
List<Cash_Flow_Sum__c> sumList = new List<Cash_Flow_Sum__c>();
for (Unit__c u : units) { Cash_Flow_Sum__c s = new Cash_Flow_Sum__c(Name='CFS', Unit__c=u.Id); sumList.add(s); sums.put(u.Id, s); }
insert sumList;

// ---- payment plans (Constant__c prices; amounts in the project currency) ----
// spec per unit: list of {name, dayOffset, price}
Map<String, List<List<Object>>> plans = new Map<String, List<List<Object>>>{
    // MH-201 Sold: 4 paid past, 1 unpaid at -90d (Overdue), 3 future. AED.
    'FIN-SEED-MH-201' => new List<List<Object>>{
        new List<Object>{'Instalment 1', -540, 150000}, new List<Object>{'Instalment 2', -450, 150000},
        new List<Object>{'Instalment 3', -360, 150000}, new List<Object>{'Instalment 4', -270, 150000},
        new List<Object>{'Instalment 5', -90, 150000},  new List<Object>{'Instalment 6', 90, 150000},
        new List<Object>{'Instalment 7', 180, 150000},  new List<Object>{'Instalment 8', 270, 150000},
        new List<Object>{'DLD Fee Registration', -540, 48000} },
    // MH-202 Sold, fully paid. AED.
    'FIN-SEED-MH-202' => new List<List<Object>>{
        new List<Object>{'Instalment 1', -400, 300000}, new List<Object>{'Instalment 2', -300, 300000},
        new List<Object>{'Instalment 3', -200, 300000}, new List<Object>{'Instalment 4', -100, 300000} },
    // MH-203 Booked, on track: booking paid, rest future. AED.
    'FIN-SEED-MH-203' => new List<List<Object>>{
        new List<Object>{'Booking Amount', -30, 120000}, new List<Object>{'Instalment 1', 60, 280000},
        new List<Object>{'Instalment 2', 150, 280000},   new List<Object>{'Instalment 3', 240, 280000} },
    // MH-204 Sold, defaulted: 4 missed (oldest 400 days), rest future. AED.
    'FIN-SEED-MH-204' => new List<List<Object>>{
        new List<Object>{'Instalment 1', -400, 100000}, new List<Object>{'Instalment 2', -310, 100000},
        new List<Object>{'Instalment 3', -220, 100000}, new List<Object>{'Instalment 4', -130, 100000},
        new List<Object>{'Instalment 5', 120, 400000},  new List<Object>{'Instalment 6', 240, 400000} },
    // MH-205 Reserved: one missed at -20d (1-30 bucket), future rest. AED.
    'FIN-SEED-MH-205' => new List<List<Object>>{
        new List<Object>{'Instalment 1', -20, 90000},  new List<Object>{'Instalment 2', 70, 270000},
        new List<Object>{'Instalment 3', 160, 270000}, new List<Object>{'Instalment 4', 250, 270000} },
    // MH-206 Booked, all future. AED.
    'FIN-SEED-MH-206' => new List<List<Object>>{
        new List<Object>{'Instalment 1', 30, 210000}, new List<Object>{'Instalment 2', 120, 210000},
        new List<Object>{'Instalment 3', 210, 210000}, new List<Object>{'Instalment 4', 300, 210000} },
    // BT-301 Sold: paid first, missed -45d (31-60), future. USD.
    'FIN-SEED-BT-301' => new List<List<Object>>{
        new List<Object>{'Instalment 1', -135, 50000}, new List<Object>{'Instalment 2', -45, 50000},
        new List<Object>{'Instalment 3', 45, 50000},   new List<Object>{'Instalment 4', 135, 50000} },
    // BT-302 Sold, fully paid. USD.
    'FIN-SEED-BT-302' => new List<List<Object>>{
        new List<Object>{'Instalment 1', -180, 100000}, new List<Object>{'Instalment 2', -60, 100000} },
    // BT-303 Booked, all future. USD.
    'FIN-SEED-BT-303' => new List<List<Object>>{
        new List<Object>{'Instalment 1', 40, 50000}, new List<Object>{'Instalment 2', 130, 50000},
        new List<Object>{'Instalment 3', 220, 50000} },
    // BT-304 Sold: paid first + on-account extra, future rest. USD.
    'FIN-SEED-BT-304' => new List<List<Object>>{
        new List<Object>{'Instalment 1', -75, 50000}, new List<Object>{'Instalment 2', 15, 50000},
        new List<Object>{'Instalment 3', 105, 50000} },
    // AL-401 Sold: missed -200d (180+ bucket), future. CHF.
    'FIN-SEED-AL-401' => new List<List<Object>>{
        new List<Object>{'Instalment 1', -290, 80000}, new List<Object>{'Instalment 2', -200, 80000},
        new List<Object>{'Instalment 3', 70, 80000},   new List<Object>{'Instalment 4', 160, 80000} },
    // AL-402 Booked, all future. CHF.
    'FIN-SEED-AL-402' => new List<List<Object>>{
        new List<Object>{'Instalment 1', 50, 110000}, new List<Object>{'Instalment 2', 140, 110000} },
    // AL-403 Sold: partially paid due instalment at -70d (61-90 bucket), future. CHF.
    'FIN-SEED-AL-403' => new List<List<Object>>{
        new List<Object>{'Instalment 1', -160, 100000}, new List<Object>{'Instalment 2', -70, 100000},
        new List<Object>{'Instalment 3', 110, 100000} }
};

List<Cash_Flow__c> cfs = new List<Cash_Flow__c>();
Map<String, Cash_Flow__c> cfByKey = new Map<String, Cash_Flow__c>(); // unitTitle|name
for (String title : plans.keySet()) {
    Unit__c u = byTitle.get(title);
    for (List<Object> row : plans.get(title)) {
        Cash_Flow__c cf = new Cash_Flow__c(
            Name = (String) row[0], Unit__c = u.Id, Cash_Flow_Sum__c = sums.get(u.Id).Id,
            Date__c = Date.today().addDays((Integer) row[1]),
            Constant__c = (Integer) row[2], Received_Amount__c = 0
        );
        cfs.add(cf); cfByKey.put(title + '|' + row[0], cf);
    }
}
insert cfs;

// ---- invoices for selected instalments: {unitTitle, cfName, invoiced?paid, dueOffsetSameAsCf}
// paidMode: 'FULL', 'PART:<amount>', 'NONE'
List<List<String>> invoiceSpec = new List<List<String>>{
    new List<String>{'FIN-SEED-MH-201','Instalment 1','FULL'}, new List<String>{'FIN-SEED-MH-201','Instalment 2','FULL'},
    new List<String>{'FIN-SEED-MH-201','Instalment 3','FULL'}, new List<String>{'FIN-SEED-MH-201','Instalment 4','FULL'},
    new List<String>{'FIN-SEED-MH-201','Instalment 5','NONE'}, new List<String>{'FIN-SEED-MH-201','DLD Fee Registration','FULL'},
    new List<String>{'FIN-SEED-MH-202','Instalment 1','FULL'}, new List<String>{'FIN-SEED-MH-202','Instalment 2','FULL'},
    new List<String>{'FIN-SEED-MH-202','Instalment 3','FULL'}, new List<String>{'FIN-SEED-MH-202','Instalment 4','FULL'},
    new List<String>{'FIN-SEED-MH-203','Booking Amount','FULL'},
    new List<String>{'FIN-SEED-MH-204','Instalment 1','NONE'}, new List<String>{'FIN-SEED-MH-204','Instalment 2','NONE'},
    // MH-204 instalments 3+4 due but deliberately NOT invoiced -> Due-Not-Invoiced DQ
    new List<String>{'FIN-SEED-MH-205','Instalment 1','NONE'},
    new List<String>{'FIN-SEED-BT-301','Instalment 1','FULL'}, new List<String>{'FIN-SEED-BT-301','Instalment 2','NONE'},
    new List<String>{'FIN-SEED-BT-302','Instalment 1','FULL'}, new List<String>{'FIN-SEED-BT-302','Instalment 2','FULL'},
    new List<String>{'FIN-SEED-BT-304','Instalment 1','FULL'},
    new List<String>{'FIN-SEED-AL-401','Instalment 1','FULL'}, new List<String>{'FIN-SEED-AL-401','Instalment 2','NONE'},
    new List<String>{'FIN-SEED-AL-403','Instalment 1','FULL'}, new List<String>{'FIN-SEED-AL-403','Instalment 2','PART:60000'}
};

List<Invoice__c> invoices = new List<Invoice__c>();
Integer seq = 1;
for (List<String> spec : invoiceSpec) {
    Cash_Flow__c cf = cfByKey.get(spec[0] + '|' + spec[1]);
    invoices.add(new Invoice__c(
        Unit__c = byTitle.get(spec[0]).Id, Status__c = 'Pending', Type__c = 'Tax Invoice',
        Invoice_Date__c = cf.Date__c, Due_Date__c = cf.Date__c,
        Sub_Total_Amount__c = cf.Constant__c, VAT_Amount__c = 0, Grand_Total_Amount__c = cf.Constant__c,
        Paid_Amount__c = 0, Invoice_Number__c = 'INV-SEED-' + String.valueOf(seq++).leftPad(3, '0')
    ));
}
insert invoices;

List<Milestone_Invoice__c> mis = new List<Milestone_Invoice__c>();
for (Integer i = 0; i < invoiceSpec.size(); i++) {
    Cash_Flow__c cf = cfByKey.get(invoiceSpec[i][0] + '|' + invoiceSpec[i][1]);
    mis.add(new Milestone_Invoice__c(Invoice__c = invoices[i].Id, Cash_Flow__c = cf.Id,
        Amount__c = cf.Constant__c, Installment_Date__c = cf.Date__c));
}
insert mis;

// The invoice wizard marks invoiced instalments — mirror it so Due-Not-Invoiced stays honest.
List<Cash_Flow__c> invoicedFlags = new List<Cash_Flow__c>();
for (List<String> spec : invoiceSpec) {
    invoicedFlags.add(new Cash_Flow__c(Id = cfByKey.get(spec[0] + '|' + spec[1]).Id, Is_Invoiced__c = true));
}
update invoicedFlags;

// ---- receipts + allocation lines for the paid invoices ----
List<String> modes = new List<String>{'Bank Transfer', 'Cheque', 'Cash', 'Card'};
List<String> deposits = new List<String>{
    'Emirates NBD - AED', 'Emirates Islamic Escrow - TR1', 'Emirates Islamic Escrow - TR2',
    'Abu Dhabi Islamic Escrow - GFF', 'Cash'
};
List<Receipt__c> receipts = new List<Receipt__c>();
List<Integer> receiptInvoiceIdx = new List<Integer>();
List<Decimal> receiptAmounts = new List<Decimal>();
for (Integer i = 0; i < invoiceSpec.size(); i++) {
    String mode = invoiceSpec[i][2];
    if (mode == 'NONE') continue;
    Cash_Flow__c cf = cfByKey.get(invoiceSpec[i][0] + '|' + invoiceSpec[i][1]);
    Decimal amt = mode == 'FULL' ? cf.Constant__c : Decimal.valueOf(mode.substringAfter('PART:'));
    receipts.add(new Receipt__c(
        Unit__c = byTitle.get(invoiceSpec[i][0]).Id, Description__c = 'Seed payment ' + invoiceSpec[i][1],
        Payment_Date__c = cf.Date__c.addDays(Math.mod(i, 3) * 7 + 3), // 3-17 day collection lag
        Receipt_Added_Date__c = cf.Date__c.addDays(Math.mod(i, 3) * 7 + 3),
        Received_Amount__c = 0, Payable_Amount__c = amt,
        Status__c = 'Reconciled', Payment_Status__c = 'Fully Paid',
        Deposited_To__c = deposits[Math.mod(i, deposits.size())]
    ));
    receiptInvoiceIdx.add(i);
    receiptAmounts.add(amt);
}
// on-account receipt for BT-304 (money received, applied to no invoice)
Receipt__c onAccount = new Receipt__c(
    Unit__c = byTitle.get('FIN-SEED-BT-304').Id, Description__c = 'Seed on-account payment',
    Payment_Date__c = Date.today().addDays(-10), Receipt_Added_Date__c = Date.today().addDays(-10),
    Received_Amount__c = 0, Payable_Amount__c = 25000,
    Status__c = 'Reconciled', Payment_Status__c = 'Pending', Deposited_To__c = 'Emirates NBD - USD'
);
receipts.add(onAccount);
insert receipts;

List<Receipt_Amount__c> lines = new List<Receipt_Amount__c>();
for (Integer r = 0; r < receiptInvoiceIdx.size(); r++) {
    Integer i = receiptInvoiceIdx[r];
    String mode = modes[Math.mod(r, modes.size())];
    Receipt_Amount__c line = new Receipt_Amount__c(
        Receipt__c = receipts[r].Id, Invoice__c = invoices[i].Id,
        Amount__c = receiptAmounts[r], Mode_of_Payment__c = mode
    );
    if (mode == 'Cheque') {
        line.Cheque_Number__c = 'CHQ-' + String.valueOf(100200 + r);
        // every other cheque is post-dated -> PDC calendar seed
        line.Cheque_Date__c = Math.mod(r, 2) == 0 ? Date.today().addDays(20 + r) : receipts[r].Payment_Date__c;
        line.Bank_Name__c = 'Emirates NBD';
    }
    lines.add(line);
}
lines.add(new Receipt_Amount__c(Receipt__c = onAccount.Id, Amount__c = 25000, Mode_of_Payment__c = 'Bank Transfer'));
insert lines;

System.debug('SEEDED: ' + units.size() + ' units, ' + cfs.size() + ' cash flows, '
    + invoices.size() + ' invoices, ' + receipts.size() + ' receipts, ' + lines.size() + ' lines');
