import 'package:data/dto/dto.dart';
import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';

class AppConfigFactory {
  static Map<String, dynamic> createBuildCacheConfig(ApplicationDTO application, String keystorePath) {
    if (application.androidVersion?.buildName == null || application.iosVersion?.buildName == null) {
      throw Exception('Android or iOS version build info is missing.');
    }

    return {
      bundleIdAndroidField: application.androidPlatformId,
      buildNameAndroidField: application.androidVersion?.buildName,
      buildNumberAndroidField: application.androidVersion?.buildNumber,
      bundleIdIosField: application.iosPlatformId,
      buildNameIOSField: application.iosVersion?.buildName,
      buildNumberIOSField: application.iosVersion?.buildNumber,
      keystorePathField: keystorePath,
    };
  }

  static Map<String, dynamic> createDartDefineEnv(ApplicationDTO application, String keystorePath) {
    final env = Map<String, dynamic>.from(application.environment ?? {});
    env['WEBTRIT_ANDROID_RELEASE_UPLOAD_KEYSTORE_PATH'] = keystorePath;
    return env;
  }

  static Map<String, String> createLauncherIconsEnv(String backgroundColorHex) {
    final hexCode = backgroundColorHex.toHex6WithHash();
    return {
      'LAUNCHER_ICON_IMAGE_ANDROID': assetLauncherAndroidIconPath,
      'ICON_BACKGROUND_COLOR': hexCode,
      'LAUNCHER_ICON_FOREGROUND': assetLauncherIconAdaptiveForegroundPath,
      'LAUNCHER_ICON_IMAGE_IOS': assetLauncherIosIconPath,
      'LAUNCHER_ICON_IMAGE_WEB': assetLauncherWebIconPath,
      'THEME_COLOR': hexCode,
    };
  }

  static Map<String, String> createNativeSplashEnv(String backgroundColorHex) {
    final hexCode = backgroundColorHex.toHex6WithHash();
    return {
      'SPLASH_COLOR': hexCode,
      'SPLASH_IMAGE': assetSplashIconPath,
      'ANDROID_12_SPLASH_COLOR': hexCode,
    };
  }

  static Map<String, String> createPackageConfigEnv(ApplicationDTO application) {
    return {
      'ANDROID_APP_NAME': application.name ?? '',
      'PACKAGE_NAME': application.androidPlatformId ?? '',
      'IOS_APP_NAME': application.name ?? '',
      'BUNDLE_ID': application.iosPlatformId ?? '',
    };
  }
}
