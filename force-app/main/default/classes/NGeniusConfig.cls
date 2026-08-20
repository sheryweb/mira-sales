/**
 * NGeniusConfig — static accessors over NGenius_Setting__mdt.getInstance('Default').
 *
 * All configuration lives in the CMDT record; nothing is hard-coded elsewhere. The API key
 * is NOT here — it lives only in the NGenius External Credential authentication parameter.
 * The shipped Default record carries the REPLACE_WITH_OUTLET_REFERENCE placeholder, and the
 * UI shows a not-configured panel until it is replaced.
 */
public with sharing class NGeniusConfig {
  @TestVisible
  private static final String OUTLET_PLACEHOLDER = 'REPLACE_WITH_OUTLET_REFERENCE';

  /** Tests set this so no deployed CMDT record is needed. */
  @TestVisible
  private static NGenius_Setting__mdt testOverride;

  private static NGenius_Setting__mdt record() {
    return testOverride != null
      ? testOverride
      : NGenius_Setting__mdt.getInstance('Default');
  }

  /** Null when usable; otherwise an admin-actionable description of what is missing. */
  public static String configurationProblem() {
    NGenius_Setting__mdt s = record();
    if (s == null) {
      return 'The NGenius Setting custom metadata record "Default" does not exist.';
    }
    if (
      String.isBlank(s.Outlet_Reference__c) ||
      s.Outlet_Reference__c == OUTLET_PLACEHOLDER
    ) {
      return 'Outlet_Reference__c on the NGenius Setting "Default" record is still the placeholder — enter the outlet ID from Network International.';
    }
    if (String.isBlank(s.Realm_Name__c)) {
      return 'Realm_Name__c on the NGenius Setting "Default" record is empty — it must be ni (sandbox) or networkinternational (production).';
    }
    return null;
  }

  private static NGenius_Setting__mdt requireRecord() {
    String problem = configurationProblem();
    if (problem != null) {
      throw new NGeniusException('N-Genius is not configured: ' + problem);
    }
    return record();
  }

  public static String outletReference() {
    return requireRecord().Outlet_Reference__c;
  }

  public static String realmName() {
    return requireRecord().Realm_Name__c;
  }

  public static String identityNamedCredential() {
    NGenius_Setting__mdt s = record();
    return s != null && String.isNotBlank(s.Identity_Named_Credential__c)
      ? s.Identity_Named_Credential__c
      : 'NGenius_Identity';
  }

  public static String apiNamedCredential() {
    NGenius_Setting__mdt s = record();
    return s != null && String.isNotBlank(s.API_Named_Credential__c)
      ? s.API_Named_Credential__c
      : 'NGenius_API';
  }

  public static String transactionType() {
    NGenius_Setting__mdt s = record();
    return s != null && String.isNotBlank(s.Transaction_Type__c)
      ? s.Transaction_Type__c
      : 'PURCHASE';
  }

  public static String defaultCurrencyCode() {
    NGenius_Setting__mdt s = record();
    return s != null && String.isNotBlank(s.Default_Currency_Code__c)
      ? s.Default_Currency_Code__c
      : 'AED';
  }

  public static String environment() {
    NGenius_Setting__mdt s = record();
    return s != null && String.isNotBlank(s.Environment__c)
      ? s.Environment__c
      : 'Sandbox';
  }

  public static String emailSubjectPrefix() {
    NGenius_Setting__mdt s = record();
    return s != null && String.isNotBlank(s.Email_Subject_Prefix__c)
      ? s.Email_Subject_Prefix__c
      : '';
  }

  public static Integer defaultExpiryDays() {
    NGenius_Setting__mdt s = record();
    return s != null &&
      s.Default_Expiry_Days__c != null &&
      s.Default_Expiry_Days__c > 0
      ? s.Default_Expiry_Days__c.intValue()
      : 3;
  }

  /** Minimum link amount in major units; 0 disables the rule. Business wants 10,000. */
  public static Decimal minimumAmount() {
    NGenius_Setting__mdt s = record();
    return s != null &&
      s.Minimum_Amount__c != null &&
      s.Minimum_Amount__c > 0
      ? s.Minimum_Amount__c
      : 0;
  }

  /** Clamped to the 1-5 range N-Genius allows. */
  public static Integer paymentAttempts() {
    NGenius_Setting__mdt s = record();
    Integer attempts = s != null &&
      s.Payment_Attempts__c != null
      ? s.Payment_Attempts__c.intValue()
      : 3;
    return Math.max(1, Math.min(5, attempts));
  }

  public static String redirectUrl() {
    NGenius_Setting__mdt s = record();
    return s != null ? s.Redirect_URL__c : null;
  }

  /** Off until N-Genius enables "pay by link via SMS" on the outlet — sending a mobile
   *  while it is disabled makes the gateway reject the whole invoice (422). */
  public static Boolean sendSms() {
    NGenius_Setting__mdt s = record();
    return s != null && s.Send_SMS__c == true;
  }

  public static Boolean logApiPayloads() {
    NGenius_Setting__mdt s = record();
    return s != null && s.Log_API_Payloads__c == true;
  }

  /**
   * A refreshed sandbox still carrying Environment__c = Production would quietly issue
   * REAL payment links against the live gateway. Refuse to run in that state.
   */
  public static void assertEnvironmentSane() {
    Boolean orgIsSandbox = [SELECT IsSandbox FROM Organization LIMIT 1]
    .IsSandbox;
    if (orgIsSandbox && environment() == 'Production') {
      throw new NGeniusException(
        'This org is a sandbox but the NGenius Setting says Production. Refusing to issue live payment links — an admin must set Environment__c to Sandbox (and point the Named Credentials at the sandbox gateway).'
      );
    }
  }
}
