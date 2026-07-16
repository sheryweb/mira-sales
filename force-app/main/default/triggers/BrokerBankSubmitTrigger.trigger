trigger BrokerBankSubmitTrigger on Broker_Bank_Submit__e (after insert) {
    BrokerBankSubmitHandler.handle(Trigger.new);
}