import '../constants/constants.dart';
import '../models/build_bundle.dart';

class AppConfigFactory {
  static Map<String, dynamic> createBuildCacheConfig(BundleApplication application, String keystorePath) {
    if (application.androidVersion?.buildName == null ||
        application.androidVersion?.buildNumber == null ||
        application.iosVersion?.buildName == null ||
        application.iosVersion?.buildNumber == null) {
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

  static Map<String, dynamic> createDartDefineEnv(BundleApplication application, String keystorePath) {
    final env = Map<String, dynamic>.from(application.environment);
    env['WEBTRIT_ANDROID_RELEASE_UPLOAD_KEYSTORE_PATH'] = keystorePath;
    return env;
  }
}
