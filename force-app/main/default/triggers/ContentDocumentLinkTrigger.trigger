trigger ContentDocumentLinkTrigger  on ContentDocumentLink (before insert) {
    if (Trigger.isInsert && Trigger.isBefore){
        ContentDocumentLinkTriggerController.handleContentDocumentLinkBeforeInsert(Trigger.new);
    }
}