import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/commands.dart';
import 'package:webtrit_phone_tools/src/utils/http_client.dart';

import '../../support/fake_configurator_backend.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

const _applicationId = 'app-1';
const _themeId = 'theme-1';
const _token = 'a-signed-in-token';
const _buildKey = 'wtc_a-minted-build-key';

/// Fetching what brands an app.
///
/// It used to take nine calls through the configurator's own client, which
/// meant this command knew which theme to ask for, how a slice is shaped and
/// where each file belongs. It now takes one, and what is left to hold are the
/// promises that survive the change: the run says who it is and which era it
/// writes for, the settings reach disk before anything that can refuse, and a
/// refusal costs the brand its picture rather than its configuration.
void main() {
  late FakeConfiguratorBackend backend;
  late Logger logger;
  late CommandRunner<int> commandRunner;
  late Directory checkout;

  String bundlePath() => '/v1/build/applications/$_applicationId/bundle';

  Map<String, Object?> bundle({List<Map<String, String>> splash = const []}) => {
        'themeId': _themeId,
        'application': {
          'id': _applicationId,
          'name': 'Brand One',
          'androidPlatformId': 'com.brand.one',
          'iosPlatformId': 'com.brand.one',
          'androidVersion': {'buildName': '1.16.5', 'buildNumber': 3},
          'iosVersion': {'buildName': '1.16.5', 'buildNumber': 3},
          'environment': <String, Object?>{},
        },
        'files': {
          'assets/themes/app.config.json': {
            'supported': [
              {'type': 'videoCall'},
            ],
          },
          'assets/themes/app.embedded.config.json': <Object?>[],
        },
        'assets': <Object?>[],
        'brandImages': {
          'splash': {'backgroundColorHex': '#FFFFFF', 'files': splash},
          'launcher': {'backgroundColorHex': null, 'files': <Object?>[]},
        },
        'font': null,
        'translations': {'locales': <String>[]},
      };

  setUp(() async {
    backend = await FakeConfiguratorBackend.start();

    logger = _MockLogger();
    when(() => logger.info(any())).thenReturn(null);
    when(() => logger.warn(any())).thenReturn(null);
    when(() => logger.err(any())).thenReturn(null);
    when(() => logger.detail(any())).thenReturn(null);
    when(() => logger.success(any())).thenReturn(null);
    when(() => logger.progress(any())).thenReturn(_MockProgress());

    checkout = Directory.systemTemp.createTempSync('resources_get_test_');
    Directory(p.join(checkout.path, 'keystores', _applicationId)).createSync(recursive: true);

    commandRunner = CommandRunner<int>('test', 'test')
      ..addCommand(AppResourcesGetCommand(
        logger: logger,
        httpClient: HttpClient('${backend.baseUrl}/v1', logger),
      ));
  });

  tearDown(() async {
    await backend.stop();
    checkout.deleteSync(recursive: true);
  });

  void writePubspec(String content) {
    File(p.join(checkout.path, 'pubspec.yaml')).writeAsStringSync(content);
  }

  Future<void> runResources({String credential = _token}) async {
    await commandRunner.run([
      'configurator-resources',
      '--applicationId',
      _applicationId,
      '--token',
      credential,
      '--keystores-path',
      'keystores',
      checkout.path,
    ]);
  }

  File appConfig() => File(p.join(checkout.path, 'assets', 'themes', 'app.config.json'));

  test('a run says who it is and which era it writes for', () async {
    writePubspec('''
name: webtrit_phone
version: 0.0.0+0000000
app_version: 1.16.5+3
''');
    backend.serveJson(bundlePath(), bundle());

    await runResources();

    final request = backend.requestFor(bundlePath());
    expect(request, isNotNull);
    expect(request!.header('authorization'), 'Bearer $_token');
    expect(request.header('x-phone-version'), '1.16.5');
  });

  test('a minted build key travels in its own header, not as a bearer', () async {
    // The reason a machine can run this at all. A key presented as a bearer is
    // not refused with an explanation - it is simply not recognised.
    writePubspec('''
name: webtrit_phone
app_version: 1.16.5+3
''');
    backend.serveJson(bundlePath(), bundle());

    await runResources(credential: _buildKey);

    final request = backend.requestFor(bundlePath());
    expect(request!.header('x-api-key'), _buildKey);
    expect(request.header('authorization'), isNull);
  });

  test('a checkout without a phone version sends the credential alone', () async {
    writePubspec('''
name: webtrit_phone
version: 0.0.0+0000000
''');
    backend.serveJson(bundlePath(), bundle());

    await runResources();

    final request = backend.requestFor(bundlePath());
    expect(request!.header('authorization'), 'Bearer $_token');
    expect(request.header('x-phone-version'), isNull);
  });

  test('a refused picture costs the brand its picture, not its settings', () async {
    writePubspec('''
name: webtrit_phone
app_version: 1.16.5+3
''');
    // A splash the bundle names and the storage will not hand over. Nothing
    // serves that address, so it answers 404 - which is what production did.
    backend.serveJson(
      bundlePath(),
      bundle(splash: [
        {'path': 'tool/assets/native_splash/image.png', 'url': '${backend.baseUrl}/v1/files/gone.png'},
      ]),
    );

    await runResources();

    expect(appConfig().existsSync(), isTrue, reason: 'the configuration must survive a refused picture');
    expect(appConfig().readAsStringSync(), contains('videoCall'));
  });

  test('the brand is told what it will get instead', () async {
    writePubspec('''
name: webtrit_phone
app_version: 1.16.5+3
''');
    backend.serveJson(bundlePath(), bundle());

    await runResources();

    final said = [
      ...verify(() => logger.warn(captureAny())).captured,
      ...verify(() => logger.err(captureAny())).captured,
    ].join('\n');
    expect(said, contains('stock WebTrit'));
  });

  test('the settings are on disk before anything that can refuse is fetched', () async {
    // Guarding the picture steps is what keeps a refusal from being fatal;
    // writing the settings first is what keeps it from mattering at all.
    // Pinned on its own, because a reordering would pass every check above.
    writePubspec('''
name: webtrit_phone
app_version: 1.16.5+3
''');
    var settingsWereOnDisk = false;
    backend
      ..serveJson(
        bundlePath(),
        bundle(splash: [
          {'path': 'tool/assets/native_splash/image.png', 'url': '${backend.baseUrl}/v1/files/splash.png'},
        ]),
      )
      ..serveWith('/v1/files/splash.png', (response) async {
        settingsWereOnDisk = appConfig().existsSync();
        response.statusCode = HttpStatus.notFound;
      });

    await runResources();

    expect(settingsWereOnDisk, isTrue, reason: 'the picture was fetched before the settings were written');
  });
}
