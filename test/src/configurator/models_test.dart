import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/configurator/configurator.dart';

/// The models are hand-written now, so what they keep of an answer - and what
/// they refuse outright - is pinned here rather than left to a generator.
void main() {
  group('ApplicationInfo', () {
    test('keeps the fields a build writes into its config and dart-defines', () {
      final application = ApplicationInfo.fromJson({
        'id': 'app-1',
        'name': 'Brand One',
        'theme': 'theme-1',
        'androidPlatformId': 'com.brand.one',
        'iosPlatformId': 'com.brand.one.ios',
        'environment': {'WEBTRIT_CORE_URL': 'https://core.example'},
        'androidVersion': {'buildName': '1.2.3', 'buildNumber': 45},
        'iosVersion': {'buildName': '1.2.3', 'buildNumber': 46},
        // Fields the build has no use for must not get in the way.
        'demo': true,
        'contactInfo': {'appSalesEmail': 'sales@example'},
      });

      expect(application.name, 'Brand One');
      expect(application.theme, 'theme-1');
      expect(application.androidPlatformId, 'com.brand.one');
      expect(application.iosPlatformId, 'com.brand.one.ios');
      expect(application.environment, {'WEBTRIT_CORE_URL': 'https://core.example'});
      expect(application.androidVersion?.buildName, '1.2.3');
      expect(application.androidVersion?.buildNumber, 45);
      expect(application.iosVersion?.buildNumber, 46);
    });

    test('an application without a theme reads as one, so the caller can say so', () {
      final application = ApplicationInfo.fromJson({'id': 'app-1'});

      expect(application.theme, isNull);
      expect(application.environment, isNull);
      expect(application.androidVersion, isNull);
    });

    test('a build number sent as a JSON number of any kind still arrives as an int', () {
      final application = ApplicationInfo.fromJson({
        'androidVersion': {'buildNumber': 45.0},
      });

      expect(application.androidVersion?.buildNumber, 45);
    });
  });

  group('SplashAssets', () {
    test('reads the images and the colour behind them', () {
      final splash = SplashAssets.fromJson({
        'id': 'theme-1',
        'applicationId': 'app-1',
        'themeId': 'theme-1',
        'source': {'backgroundColorHex': '#112233'},
        'urls': {
          'splashUrl': 'https://cdn.example/splash.png',
          'android12SplashUrl': 'https://cdn.example/android12.png',
        },
      });

      expect(splash.splashUrl, 'https://cdn.example/splash.png');
      expect(splash.android12SplashUrl, 'https://cdn.example/android12.png');
      expect(splash.backgroundColorHex, '#112233');
    });

    test('an answer that names no theme is refused, not read as "no splash"', () {
      // Production has served exactly this. Reading it as an empty splash
      // would build the brand with the stock WebTrit one and say nothing.
      expect(
        () => SplashAssets.fromJson({'urls': <String, String>{}}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('LaunchIcons', () {
    test('reads one URL per platform slot and the adaptive background colour', () {
      final icons = LaunchIcons.fromJson({
        'entity': {
          'source': {'backgroundColorHex': '#445566'},
        },
        'urls': {
          'androidLegacyUrl': 'https://cdn.example/legacy.png',
          'androidAdaptiveForegroundUrl': 'https://cdn.example/foreground.png',
          'iosUrl': 'https://cdn.example/ios.png',
          'webUrl': 'https://cdn.example/web.png',
        },
      });

      expect(icons.androidLegacyUrl, 'https://cdn.example/legacy.png');
      expect(icons.androidAdaptiveForegroundUrl, 'https://cdn.example/foreground.png');
      expect(icons.iosUrl, 'https://cdn.example/ios.png');
      expect(icons.webUrl, 'https://cdn.example/web.png');
      expect(icons.backgroundColorHex, '#445566');
    });

    test('an answer without its envelope is refused', () {
      expect(
        () => LaunchIcons.fromJson({'id': 'theme-1'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('an envelope with no colour is legitimate: the caller warns and skips', () {
      final icons = LaunchIcons.fromJson({'entity': <String, dynamic>{}});

      expect(icons.backgroundColorHex, isNull);
      expect(icons.androidLegacyUrl, isNull);
    });
  });
}
