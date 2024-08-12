const commonName = 'KeystoreGenerator';

const parameterIndent = '  ';
const parameterDelimiter = ' - ';

// Environment APIs
const configuratorStageApiUrl = 'https://us-central1-webtrit-configurator-stage.cloudfunctions.net';
const configuratorProdApiUrl = 'https://us-central1-webtrit-configurator.cloudfunctions.net';
const configuratorApiUrl = configuratorProdApiUrl;

// Phone environment
const configureDartDefinePath = 'dart_define.json';

// Phone theme assets
const assetThemePath = 'assets/themes/original.json';
const assetImagePrimaryOnboardingLogoPath = 'assets/primary_onboardin_logo.svg';
const assetImageSecondaryOnboardingLogoPath = 'assets/secondary_onboardin_logo.svg';
const assetIconIosNotificationTemplateImagePath = 'assets/callkeep/ios_icon_template_image.png';
const assetSplashIconPath = 'assets/native_splash/image.png';
const assetLauncherIconAdaptiveForegroundPath = 'assets/launcher_icons/ic_foreground.png';
const assetLauncherAndroidIconPath = 'assets/launcher_icons/android.png';
const assetLauncherIosIconPath = 'assets/launcher_icons/ios.png';
const assetLauncherWebIconPath = 'assets/launcher_icons/web.png';

// Phone translations arb path
const translationsArbPath = 'lib/l10n/arb';

// SSL certificate
const assetSSLCertificate = 'assets/certificates';
const assetSSLCertificateCredentials = 'credentials.json';

// Config for external plugins
const configPathSplashTemplatePath = 'assets/flutter_native_splash_template.yaml';
const configPathSplashPath = 'flutter_native_splash.yaml';

const configPathPackageTemplatePath = 'assets/package_rename_config_template.yaml';
const configPathPackagePath = 'package_rename_config.yaml';

const configPathLaunchTemplatePath = 'assets/flutter_launcher_icons_template.yaml';
const configPathLaunchPath = 'flutter_launcher_icons.yaml';

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
