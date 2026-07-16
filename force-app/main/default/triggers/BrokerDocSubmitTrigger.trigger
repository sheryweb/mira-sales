trigger BrokerDocSubmitTrigger on Broker_Doc_Submit__e (after insert) {
    BrokerDocSubmitHandler.handle(Trigger.new);
}