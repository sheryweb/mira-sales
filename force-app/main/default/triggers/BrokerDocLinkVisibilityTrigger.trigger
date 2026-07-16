trigger BrokerDocLinkVisibilityTrigger on ContentDocumentLink (after insert) {
    BrokerDocLinkVisibilityHandler.makeAgencyFilesVisible(Trigger.new);
}