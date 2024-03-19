const commonName = 'KeystoreGenerator';

const parameterIndent = '  ';
const parameterDelimiter = ' - ';

// Environment APIs
const configuratorStageApiUrl = 'https://us-central1-webtrit-configurator-stage.cloudfunctions.net';
const configuratorProdApiUrl = 'https://us-central1-webtrit-configurator.cloudfunctions.net';
const configuratorApiUrl = configuratorProdApiUrl;

// Phone environment
const configureDartDefinePath = '/dart_define.json';
const configureDartDefineTemplatePath = 'assets/dart_define_template.yaml';

// Phone theme assets
const assetThemePath = '/assets/themes/original.json';
const assetImagePrimaryOnboardingLogo = '/assets/primary_onboardin_logo.svg';
const assetImageSecondaryOnboardingLogo = '/assets/secondary_onboardin_logo.svg';
const assetIconIosNotificationTemplateImage = '/assets/callkeep/ios_icon_tempate_image.png';
const assetSplashIcon = '/assets/native_splash/image.png';
const assetLauncherIconAdaptiveForeground = '/assets/launcher_icons/ic_foreground.png';
const assetLauncherAndroidIcon = '/assets/launcher_icons/android.png';
const assetLauncherIosIcon = '/assets/launcher_icons/ios.png';
const assetLauncherWebIcon = '/assets/launcher_icons/web.png';

// Google services
const googleServicesDestinationAndroid = '/android/app/google-services.json';
const googleServiceDestinationIos = '/ios/Runner/GoogleService-Info.plist';

// Config for external plugins
const configPathSplashTemplate = 'assets/flutter_native_splash_template.yaml';
const configPathSplash = '/flutter_native_splash.yaml';

const configPathPackageTemplate = 'assets/package_rename_config_template.yaml';
const configPathPackage = '/package_rename_config.yaml';

const configPathLaunchTemplate = 'assets/flutter_launcher_icons_template.yaml';
const configPathLaunch = '/flutter_launcher_icons.yaml';
