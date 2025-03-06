const String _webtritAppDebugLevel = 'WEBTRIT_APP_DEBUG_LEVEL';
const String _webtritAppDatabaseLogStatements = 'WEBTRIT_APP_DATABASE_LOG_STATEMENTS';
const String _webtritAppPeriodicPolling = 'WEBTRIT_APP_PERIODIC_POLLING';
const String _webtritAppDemoCoreUrl = 'WEBTRIT_APP_DEMO_CORE_URL';
const String _webtritAppCoreUrl = 'WEBTRIT_APP_CORE_URL';
const String _webtritAppName = 'WEBTRIT_APP_NAME';
const String _webtritAppGreeting = 'WEBTRIT_APP_GREETING';
const String _webtritAppDescription = 'WEBTRIT_APP_DESCRIPTION';
const String _webtritAppTermsAndConditionsUrl = 'WEBTRIT_APP_TERMS_AND_CONDITIONS_URL';
const String _webtritAppSalesEmail = 'WEBTRIT_APP_SALES_EMAIL';
const String _webtritAndroidReleaseUploadKeystorePath = 'WEBTRIT_ANDROID_RELEASE_UPLOAD_KEYSTORE_PATH';
const String _webtritAppLinkDomain = 'WEBTRIT_APP_LINK_DOMAIN';

class DartDefineTemplate {
  DartDefineTemplate({
    required this.demoFlow,
    required this.url,
    required this.termsAndConditionsUrl,
    required this.salesEmail,
    required this.appName,
    required this.appGreening,
    required this.appDescription,
    required this.keyStorePath,
  });

  final bool _webtritAppDatabaseLogStatementsDefaultValue = false;
  final bool _webtritAppPeriodicPollingDefaultValue = true;
  final String _webtritAppDebugLevelDefaultValue = 'ALL';
  final String _webtritAppLinkDomainDefaultValue = 'app.webtrit.com';

  final bool demoFlow;
  final String url;
  final String termsAndConditionsUrl;
  final String? salesEmail;
  final String appName;
  final String? appGreening;
  final String appDescription;
  final String keyStorePath;

  // The method merges the configurator environment data with the keystore environment data.
  // The configurator data takes precedence over the keystore values.
  Map<String, dynamic> toJson(Map<String, dynamic>? keystoreEnvData) {
    final configuratorEnvData = <String, dynamic>{
      _webtritAppDebugLevel: _webtritAppDebugLevelDefaultValue,
      _webtritAppDatabaseLogStatements: _webtritAppDatabaseLogStatementsDefaultValue,
      _webtritAppPeriodicPolling: _webtritAppPeriodicPollingDefaultValue,
      _webtritAppLinkDomain: _webtritAppLinkDomainDefaultValue,
      if (demoFlow) _webtritAppDemoCoreUrl: url,
      if (!demoFlow) _webtritAppCoreUrl: url,
      _webtritAppName: appName,
      if (appGreening != null) _webtritAppGreeting: appGreening,
      _webtritAppDescription: appDescription,
      _webtritAppTermsAndConditionsUrl: termsAndConditionsUrl,
      _webtritAppSalesEmail: salesEmail,
      _webtritAndroidReleaseUploadKeystorePath: keyStorePath,
    };

    return {
      if (keystoreEnvData != null) ...keystoreEnvData,
      ...configuratorEnvData,
    };
  }
}
