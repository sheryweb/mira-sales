trigger BrokerShareholderApplyTrigger on Broker_Shareholder_Apply__e (after insert) {
    BrokerShareholderApplyHandler.handle(Trigger.new);
}