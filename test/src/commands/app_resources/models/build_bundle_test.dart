import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/app_resources/models/models.dart';

/// Reading the answer a build is given.
///
/// The service decides everything here and this tool only reads it, so what
/// these hold is the reading: that every field the service promises is picked
/// up, and that an answer missing an optional part is read rather than refused.
///
/// The field names are the other half of a contract written down in the service
/// (`the shape a build depends on`). If a name changes there and not here, a
/// build stops receiving that part and nothing says so - the whole reason both
/// halves are spelled out rather than inferred.
void main() {
  Map<String, dynamic> anAnswer() => {
        'themeId': 'theme-1',
        'phoneVersion': '1.16.5',
        'application': {
          'id': 'app-1',
          'name': 'Brand One',
          'androidPlatformId': 'com.brand.one',
          'iosPlatformId': 'com.brand.one.ios',
          'androidVersion': {'buildName': '4.4.12', 'buildNumber': 449000013},
          'iosVersion': {'buildName': '3.0.9', 'buildNumber': 30900002},
          'environment': {'WEBTRIT_APP_CHAT_SERVICE_URL': 'wss://example.invalid'},
        },
        'files': {
          'assets/themes/app.config.json': {'supported': <Object?>[]},
          'assets/themes/app.embedded.config.json': <Object?>[],
        },
        'assets': [
          {
            'id': 'logo',
            'path': 'assets/images/logo_abc.svg',
            'url': 'https://example.invalid/logo.svg',
            'sha256': 'a' * 64,
            'size': 1024,
          },
        ],
        'brandImages': {
          'splash': {
            'backgroundColorHex': '#FFFFFF',
            'files': [
              {'path': 'tool/assets/native_splash/image.png', 'url': 'https://example.invalid/splash.png'},
              {'path': 'tool/assets/native_splash/android12image.png', 'url': 'https://example.invalid/a12.png'},
            ],
          },
          'launcher': {
            'backgroundColorHex': '#000000',
            'files': [
              {'path': 'tool/assets/launcher_icons/android.png', 'url': 'https://example.invalid/android.png'},
            ],
          },
        },
        'font': {
          'family': 'Montserrat',
          'weights': [400, 600],
        },
        'translations': {
          'locales': ['en', 'uk'],
        },
      };

  test('reads every part of the answer, not only the ones it happens to use', () {
    final bundle = BuildBundle.fromJson(anAnswer());

    expect(bundle.themeId, 'theme-1');
    expect(bundle.files.keys, contains('assets/themes/app.config.json'));
    expect(bundle.assets.single.id, 'logo');
    expect(bundle.assets.single.path, 'assets/images/logo_abc.svg');
    expect(bundle.assets.single.url, 'https://example.invalid/logo.svg');
    expect(bundle.brandImages.splash.files.length, 2);
    expect(bundle.brandImages.launcher.backgroundColorHex, '#000000');
    expect(bundle.font?.family, 'Montserrat');
    expect(bundle.font?.weights, [400, 600]);
    expect(bundle.locales, ['en', 'uk']);
  });

  test('reads of an application exactly what a build writes into its config', () {
    final application = BuildBundle.fromJson(anAnswer()).application;

    expect(application.id, 'app-1');
    expect(application.name, 'Brand One');
    expect(application.androidPlatformId, 'com.brand.one');
    expect(application.iosPlatformId, 'com.brand.one.ios');
    expect(application.androidVersion?.buildName, '4.4.12');
    expect(application.androidVersion?.buildNumber, 449000013);
    expect(application.iosVersion?.buildName, '3.0.9');
    expect(application.iosVersion?.buildNumber, 30900002);
    expect(application.environment['WEBTRIT_APP_CHAT_SERVICE_URL'], 'wss://example.invalid');
  });

  test('a brand with no images of its own is read, not refused', () {
    final answer = anAnswer()
      ..['brandImages'] = {
        'splash': {'backgroundColorHex': null, 'files': <Object?>[]},
        'launcher': {'backgroundColorHex': null, 'files': <Object?>[]},
      };

    final bundle = BuildBundle.fromJson(answer);

    expect(bundle.brandImages.splash.isEmpty, isTrue);
    expect(bundle.brandImages.launcher.isEmpty, isTrue);
  });

  test('a theme that names no typeface is read, not refused', () {
    final answer = anAnswer()..['font'] = null;

    expect(BuildBundle.fromJson(answer).font, isNull);
  });

  test('knows whether an image is meant for a particular file', () {
    // How a generator asks "is there an Android 12 splash": by the file it
    // would write, not by the name of an address.
    final splash = BuildBundle.fromJson(anAnswer()).brandImages.splash;

    expect(splash.writesTo('tool/assets/native_splash/android12image.png'), isTrue);
    expect(splash.writesTo('tool/assets/launcher_icons/web.png'), isFalse);
  });

  test('an answer that arrives empty is read as empty rather than ending the run', () {
    final bundle = BuildBundle.fromJson(<String, dynamic>{});

    expect(bundle.themeId, isEmpty);
    expect(bundle.files, isEmpty);
    expect(bundle.assets, isEmpty);
    expect(bundle.locales, isEmpty);
    expect(bundle.application.id, isNull);
  });
}
