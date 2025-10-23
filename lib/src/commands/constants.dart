const commonName = 'KeystoreGenerator';

const parameterIndent = '  ';
const parameterDelimiter = ' - ';

// Environment APIs
const _configuratorProdApiUrl = 'https://us-central1-webtrit-configurator.cloudfunctions.net';
const configuratorApiUrl = _configuratorProdApiUrl;

const configureDartDefinePath = 'dart_define.json';
const assetThemeFolderPath = 'assets/themes/';

// Phone theme assets
const assetLightColorSchemePath = 'assets/themes/original.color_scheme.light.config.json';
const assetDarkColorSchemePath = 'assets/themes/original.color_scheme.dark.config.json';
const assetPageLightConfig = 'assets/themes/original.page.light.config.json';
const assetPageDarkConfig = 'assets/themes/original.page.dark.config.json';
const assetWidgetsLightConfig = 'assets/themes/original.widget.light.config.json';
const assetWidgetsDarkConfig = 'assets/themes/original.widget.dark.config.json';
const assetAppConfigPath = 'assets/themes/app.config.json';
const assetAppConfigEmbeddedsPath = 'assets/themes/app.embedded.config.json';
const assetImagePrimaryOnboardingLogoPath = 'assets/primary_onboardin_logo.svg';
const assetImageSecondaryOnboardingLogoPath = 'assets/secondary_onboardin_logo.svg';
const assetIconIosNotificationTemplateImagePath = 'assets/callkeep/ios_icon_template_image.png';

const assetSplashIconPath = 'tool/assets/native_splash/image.png';
const assetLauncherIconAdaptiveForegroundPath = 'tool/assets/launcher_icons/ic_foreground.png';
const assetLauncherAndroidIconPath = 'tool/assets/launcher_icons/android.png';
const assetLauncherIosIconPath = 'tool/assets/launcher_icons/ios.png';
const assetLauncherWebIconPath = 'tool/assets/launcher_icons/web.png';

// Phone translations arb path
const translationsArbPath = 'lib/l10n/arb';

// SSL certificate
const assetSSLCertificate = 'assets/certificates';
const assetSSLCertificateCredentials = 'credentials.json';

// Cache session data
const bundleIdAndroidField = 'bundleIdAndroid';
const buildNameAndroidField = 'buildNameAndroidField';
const buildNumberAndroidField = 'buildNumberAndroidField';
const bundleIdIosField = 'bundleIdIos';
const buildNameIOSField = 'buildNameIOSField';
const buildNumberIOSField = 'buildNumberIOSField';
const keystorePathField = 'keystore_path';
const defaultCacheSessionDataPath = 'cache_session_data.json';

// Firebase service account
const projectIdField = 'project_id';

// Keystore paths
const kSSLCertificatePath = 'ssl_certificates';
const kSSLCertificateCredentialPath = 'ssl-credentials.json';

// Keystore files
const keystoreFiles = [
  firebaseServiceAccount,
  iosAuthKey,
  iosProvision,
  iosCertificates,
  iosCredentials,
  androidPlayServiceAccount,
  androidCredentials,
  androidUploadKeystoreJKS,
  androidUploadKeystoreP12,
];

// Firebase
const firebaseServiceAccount = 'firebase-service-account.json';

// IOS
const iosAuthKey = 'AuthKey_[key_id].p8';
const iosProvision = 'Provision.mobileprovision';
const iosCertificates = 'Certificates.p12';
const iosCredentials = 'upload-store-connect-metadata.json';

// Android
const androidPlayServiceAccount = 'google-play-service-account.json';
const androidCredentials = 'upload-keystore-metadata.json';
const androidUploadKeystoreJKS = 'upload-keystore.jks';
const androidUploadKeystoreP12 = 'upload-keystore.p12';
