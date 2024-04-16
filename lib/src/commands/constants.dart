const commonName = 'KeystoreGenerator';

const parameterIndent = '  ';
const parameterDelimiter = ' - ';

// Environment APIs
const configuratorStageApiUrl = 'https://us-central1-webtrit-configurator-stage.cloudfunctions.net';
const configuratorProdApiUrl = 'https://us-central1-webtrit-configurator.cloudfunctions.net';
const configuratorApiUrl = configuratorProdApiUrl;

// Phone environment
const configureDartDefinePath = 'dart_define.json';
const configureDartDefineTemplatePath = 'assets/dart_define_template.yaml';

// Phone theme assets
const assetThemePath = 'assets/themes/original.json';
const assetImagePrimaryOnboardingLogoPath = 'assets/primary_onboardin_logo.svg';
const assetImageSecondaryOnboardingLogoPath = 'assets/secondary_onboardin_logo.svg';
const assetIconIosNotificationTemplateImagePath = 'assets/callkeep/ios_icon_tempate_image.png';
const assetSplashIconPath = 'assets/native_splash/image.png';
const assetLauncherIconAdaptiveForegroundPath = 'assets/launcher_icons/ic_foreground.png';
const assetLauncherAndroidIconPath = 'assets/launcher_icons/android.png';
const assetLauncherIosIconPath = 'assets/launcher_icons/ios.png';
const assetLauncherWebIconPath = 'assets/launcher_icons/web.png';

// Google services
const googleServicesDestinationAndroidPath = 'android/app/google-services.json';
const googleServiceDestinationIosPath = 'ios/Runner/GoogleService-Info.plist';

// Config for external plugins
const configPathSplashTemplatePath = 'assets/flutter_native_splash_template.yaml';
const configPathSplashPath = 'flutter_native_splash.yaml';

const configPathPackageTemplatePath = 'assets/package_rename_config_template.yaml';
const configPathPackagePath = 'package_rename_config.yaml';

const configPathLaunchTemplatePath = 'assets/flutter_launcher_icons_template.yaml';
const configPathLaunchPath = 'flutter_launcher_icons.yaml';
