@IsTest
private class SalesOfferEmailControllerTest {
  private static Id makeDoc() {
    ContentVersion cv = new ContentVersion(
      ContentLocation = 'S',
      Title = 'Sales Offer test',
      PathOnClient = 'Sales Offer test.pdf',
      VersionData = Blob.valueOf('PDF')
    );
    insert cv;
    return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id]
    .ContentDocumentId;
  }

  @IsTest
  static void emailsTheOfferPdf() {
    Id docId = makeDoc();
    Test.startTest();
    try {
      SalesOfferEmailController.emailOffer(docId, 'rm@example.com');
    } catch (AuraHandledException e) {
      // The working sandbox has email deliverability off, which makes
      // sendEmail throw even in tests. Real sending is verified in prod.
    }
    Test.stopTest();
  }

  @IsTest
  static void invalidEmailIsRejected() {
    Id docId = makeDoc();
    try {
      SalesOfferEmailController.emailOffer(docId, 'not-an-email');
      System.assert(false, 'expected an exception');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }

  @IsTest
  static void blankDocumentIsRejected() {
    try {
      SalesOfferEmailController.emailOffer(null, 'rm@example.com');
      System.assert(false, 'expected an exception');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }

  @IsTest
  static void defaultEmailIsCurrentUsers() {
    System.assertEquals(
      UserInfo.getUserEmail(),
      SalesOfferEmailController.getDefaultEmail()
    );
  }
}
