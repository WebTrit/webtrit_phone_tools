import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import '../constants/constants.dart';
import '../models/build_bundle.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';

/// Writes the three configs the phone project's generators read.
///
/// They used to be written by `make` in that repository, run from here with
/// `Process.start`. Each target was a column of `echo` lines putting four
/// strings from the bundle into a YAML file - work this already does for every
/// other file it writes.
///
/// Doing it here rather than there also closes something that was not obvious:
/// running `make` in the phone project parsed its whole makefile, and that
/// file fetched shared build logic over the network from a hard-coded branch.
/// A release frozen to an old track thawed at exactly this point.
class GeneratorConfigProcessor {
  const GeneratorConfigProcessor({required this.logger});

  final Logger logger;

  /// Writes what the bundle has enough to describe.
  ///
  /// A brand with no colour for one of them is skipped rather than written
  /// with a guess, which is what the old targets did by being not run at all.
  Future<void> writeConfigs({
    required String workingDirectoryPath,
    required BundleApplication application,
    required BrandImages brandImages,
  }) async {
    final launchBackground = brandImages.launcher.backgroundColorHex;
    final splashBackground = brandImages.splash.backgroundColorHex;

    if (launchBackground != null) {
      await _write(
        workingDirectoryPath,
        configLauncherIconsPath,
        _launcherIcons(
          iconBackground: (splashBackground ?? launchBackground).toHex6WithHash(),
          themeColor: launchBackground.toHex6WithHash(),
        ),
      );
    } else {
      logger.warn('Skipping launcher generation: backgroundColorHex is null.');
    }

    if (splashBackground != null) {
      // Asked of the file the bundle named rather than of an address: what
      // decides whether the Android 12 splash is drawn is whether there is an
      // image for it, and that is what a path says.
      await _write(
        workingDirectoryPath,
        configNativeSplashPath,
        _nativeSplash(
          background: splashBackground.toHex6WithHash(),
          android12Image: brandImages.splash.writesTo(assetAndroid12SplashIconPath)
              ? assetAndroid12SplashIconPath
              : assetSplashIconPath,
        ),
      );
    } else {
      logger.warn('Skipping splash generation: backgroundColorHex is null.');
    }

    await _write(workingDirectoryPath, configPackageRenamePath, _packageRename(application));
  }

  String _launcherIcons({required String iconBackground, required String themeColor}) {
    return '''
flutter_launcher_icons:
  android: true
  image_path_android: "$assetLauncherAndroidIconPath"
  min_sdk_android: 23
  adaptive_icon_background: "$iconBackground"
  adaptive_icon_foreground: "$assetLauncherIconAdaptiveForegroundPath"
  adaptive_icon_foreground_inset: 0
  ios: true
  background_color_ios: "$iconBackground"
  remove_alpha_ios: true
  image_path_ios: "$assetLauncherIosIconPath"
  web:
    generate: true
    image_path: "$assetLauncherWebIconPath"
    background_color: "$iconBackground"
    theme_color: "$themeColor"
''';
  }

  String _nativeSplash({required String background, required String android12Image}) {
    return '''
flutter_native_splash:
  color: "$background"
  image: "$assetSplashIconPath"
  android_12:
    color: "$background"
    image: "$android12Image"
''';
  }

  String _packageRename(BundleApplication application) {
    return '''
package_rename_config:
  android:
    app_name: ${application.launchNameFor(BuildPlatform.android)}
    package_name: ${application.androidPlatformId ?? ''}
    override_old_package: com.webtrit.phone
    lang: kotlin
  ios:
    app_name: ${application.launchNameFor(BuildPlatform.ios)}
    package_name: ${application.iosPlatformId ?? ''}
''';
  }

  Future<void> _write(String workingDirectoryPath, String relativePath, String contents) async {
    final file = File(path.join(workingDirectoryPath, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(contents, flush: true);
    logger.success('✓ Wrote $relativePath');
  }
}
