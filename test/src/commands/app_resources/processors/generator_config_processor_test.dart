import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/app_resources/models/build_bundle.dart';
import 'package:webtrit_phone_tools/src/commands/app_resources/processors/generator_config_processor.dart';

class _MockLogger extends Mock implements Logger {}

/// The three configs the phone project's generators read.
///
/// They were written by `make` in that repository until now, which meant a
/// release build parsed a makefile that fetched shared logic over the network.
/// What they hold has not changed, and these say what that is.
void main() {
  late Directory checkout;
  late GeneratorConfigProcessor processor;

  const application = BundleApplication(
    name: 'Fallback Name',
    androidPlatformId: 'com.acme.brand',
    iosPlatformId: 'com.acme.brand.ios',
    androidLaunchName: 'Acme',
    iosLaunchName: 'Acme iOS',
  );

  String read(String relativePath) => File('${checkout.path}/$relativePath').readAsStringSync();

  setUp(() {
    checkout = Directory.systemTemp.createTempSync('generator-config-');
    processor = GeneratorConfigProcessor(logger: _MockLogger());
  });

  tearDown(() => checkout.deleteSync(recursive: true));

  Future<void> write({String? launcherColor, String? splashColor, List<BrandImageFile> splashFiles = const []}) {
    return processor.writeConfigs(
      workingDirectoryPath: checkout.path,
      application: application,
      brandImages: BrandImages(
        launcher: BrandImageSet(backgroundColorHex: launcherColor),
        splash: BrandImageSet(backgroundColorHex: splashColor, files: splashFiles),
      ),
    );
  }

  test('names the package and the launch name each store shows', () async {
    await write();

    expect(read('tool/configs/package_rename_config.yaml'), '''
package_rename_config:
  android:
    app_name: Acme
    package_name: com.acme.brand
    override_old_package: com.webtrit.phone
    lang: kotlin
  ios:
    app_name: Acme iOS
    package_name: com.acme.brand.ios
''');
  });

  test('writes the launcher icons config from the brand colours', () async {
    await write(launcherColor: '#AABBCC', splashColor: '#112233');

    final written = read('tool/configs/flutter_launcher_icons.yaml');
    // The icon background follows the splash where there is one: the two sit
    // next to each other on a device and a launcher that disagreed would show.
    expect(written, contains('adaptive_icon_background: "#112233"'));
    expect(written, contains('background_color_ios: "#112233"'));
    expect(written, contains('theme_color: "#AABBCC"'));
    // The export bakes the safe-zone padding into the foreground, so the
    // package default of 16% would shrink the logo twice.
    expect(written, contains('adaptive_icon_foreground_inset: 0'));
  });

  test('falls back to the launcher colour when there is no splash colour', () async {
    await write(launcherColor: '#AABBCC');

    expect(read('tool/configs/flutter_launcher_icons.yaml'), contains('adaptive_icon_background: "#AABBCC"'));
  });

  test('points the Android 12 splash at its own image when the brand has one', () async {
    await write(
      splashColor: '#112233',
      splashFiles: const [BrandImageFile(path: 'tool/assets/native_splash/android12image.png', url: 'x')],
    );

    expect(read('tool/configs/flutter_native_splash.yaml'), '''
flutter_native_splash:
  color: "#112233"
  image: "tool/assets/native_splash/image.png"
  android_12:
    color: "#112233"
    image: "tool/assets/native_splash/android12image.png"
''');
  });

  test('points it at the ordinary splash when the brand has none', () async {
    await write(splashColor: '#112233');

    expect(
      read('tool/configs/flutter_native_splash.yaml'),
      contains('    image: "tool/assets/native_splash/image.png"'),
    );
  });

  /// A brand with no colour is skipped rather than written with a guess, which
  /// is what not running the target used to do.
  test('writes nothing for a brand with no colours', () async {
    await write();

    expect(File('${checkout.path}/tool/configs/flutter_launcher_icons.yaml').existsSync(), isFalse);
    expect(File('${checkout.path}/tool/configs/flutter_native_splash.yaml').existsSync(), isFalse);
  });
}
