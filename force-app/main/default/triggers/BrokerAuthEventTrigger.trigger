trigger BrokerAuthEventTrigger on Broker_Auth_Event__e (after insert) {
    BrokerAuthEventHandler.handle(Trigger.new);
}