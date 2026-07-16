trigger BrokerProfileSubmitTrigger on Broker_Profile_Submit__e (after insert) {
    BrokerProfileSubmitHandler.handle(Trigger.new);
}