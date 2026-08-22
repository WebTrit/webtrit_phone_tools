import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/app_resources/resources_get_command.dart';
import 'package:webtrit_phone_tools/src/configurator_datasource.dart';
import 'package:webtrit_phone_tools/src/utils/http_client.dart';

import '../../support/fake_configurator_backend.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

const _applicationId = 'app-1';
const _themeId = 'theme-1';
const _token = 'build-token';

/// Everything the configuration half of a run asks for. The image half is left
/// to each test, since that is what they are about.
extension _TheConfiguration on FakeConfiguratorBackend {
  void serveTheConfiguration() {
    serveJson('/v1/applications/$_applicationId/feature-access/by-theme/$_themeId', {
      'applicationId': _applicationId,
      'themeId': _themeId,
      'config': {
        'supported': [
          {'type': 'videoCall', 'enabled': true},
        ],
      },
    });
    serveJson('/v1/applications/$_applicationId/embeds', []);
    for (final slice in ['color-schemes', 'page-configs', 'widget-configs']) {
      serveJson('/v1/applications/$_applicationId/themes/$_themeId/$slice/light', {
        // Page and widget answers name an id of their own; the colour one may.
        'id': '${_themeId}_light',
        'applicationId': _applicationId,
        'themeId': _themeId,
        'variant': 'light',
        // The widget answer's reader parses these as dates, not as optionals.
        'createdAt': '2026-08-22T00:00:00.000Z',
        'updatedAt': '2026-08-22T00:00:00.000Z',
        'config': slice == 'widget-configs'
            ? {
                'fonts': {'fontFamily': 'Montserrat'},
              }
            : <String, Object?>{},
      });
    }
  }
}

void main() {
  late FakeConfiguratorBackend backend;
  late Logger logger;
  late CommandRunner<int> commandRunner;
  late Directory checkout;

  setUp(() async {
    backend = await FakeConfiguratorBackend.start();
    final baseUrl = '${backend.baseUrl}/v1';

    // Enough of the backend for the run to get past fetching the application
    // and its theme; every later call answers 404, which ends the run.
    backend
      ..serveJson('/v1/applications/$_applicationId', {
        'id': _applicationId,
        'name': 'Brand One',
        'theme': _themeId,
        // The build cache step refuses to write without both platforms' versions.
        'androidVersion': {'buildName': '1.16.5', 'buildNumber': 3},
        'iosVersion': {'buildName': '1.16.5', 'buildNumber': 3},
      })
      ..serveJson('/v1/applications/$_applicationId/themes/$_themeId', {
        'id': _themeId,
        'applicationId': _applicationId,
        'title': 'Default',
      });

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
        httpClient: HttpClient(baseUrl, logger),
        datasource: createConfiguratorDatasource(
          baseUrl: baseUrl,
          logPrint: (_) {},
        ),
      ));
  });

  tearDown(() async {
    await backend.stop();
    checkout.deleteSync(recursive: true);
  });

  void writePubspec(String content) {
    File(p.join(checkout.path, 'pubspec.yaml')).writeAsStringSync(content);
  }

  Future<void> runResources() async {
    await commandRunner.run([
      'configurator-resources',
      '--applicationId',
      _applicationId,
      '--token',
      _token,
      '--keystores-path',
      'keystores',
      checkout.path,
    ]);
  }

  test('a run identifies itself with the token and the phone version', () async {
    writePubspec('''
name: webtrit_phone
version: 0.0.0+0000000
app_version: 1.16.5+3
''');

    await runResources();

    final applicationRequest = backend.requestFor('/v1/applications/$_applicationId');
    expect(applicationRequest, isNotNull);
    expect(applicationRequest!.header('authorization'), 'Bearer $_token');
    expect(applicationRequest.header('x-phone-version'), '1.16.5');
  });

  test('the theme is fetched with the same identification', () async {
    writePubspec('''
name: webtrit_phone
app_version: 1.16.5+3
''');

    await runResources();

    final themeRequest = backend.requestFor('/v1/applications/$_applicationId/themes/$_themeId');
    expect(themeRequest, isNotNull);
    expect(themeRequest!.header('authorization'), 'Bearer $_token');
    expect(themeRequest.header('x-phone-version'), '1.16.5');
  });

  test('a checkout without a phone version sends the token alone', () async {
    writePubspec('''
name: webtrit_phone
version: 0.0.0+0000000
''');

    await runResources();

    final applicationRequest = backend.requestFor('/v1/applications/$_applicationId');
    expect(applicationRequest, isNotNull);
    expect(applicationRequest!.header('authorization'), 'Bearer $_token');
    expect(applicationRequest.header('x-phone-version'), isNull);
  });

  test('a refused launcher answer no longer costs the brand its settings', () async {
    // The whole point of the ordering. `launch-assets` answers with something
    // its reader cannot unwrap - which is exactly what production did - and the
    // app configuration must still be on disk afterwards.
    writePubspec('''
name: webtrit_phone
app_version: 1.16.5+3
''');
    backend
      ..serveTheConfiguration()
      // No `entity` key - the shape that used to end the run on its first read.
      ..serveJson('/v1/applications/$_applicationId/themes/$_themeId/launch-assets', {
        'id': _themeId,
        'applicationId': _applicationId,
        'themeId': _themeId,
      });

    await runResources();

    final appConfig = File(p.join(checkout.path, 'assets', 'themes', 'app.config.json'));
    expect(appConfig.existsSync(), isTrue, reason: 'the app configuration must survive a refused image answer');
    expect(appConfig.readAsStringSync(), contains('videoCall'));
  });

  test('the brand is told what it will get instead', () async {
    writePubspec('''
name: webtrit_phone
app_version: 1.16.5+3
''');
    backend
      ..serveTheConfiguration()
      ..serveJson('/v1/applications/$_applicationId/themes/$_themeId/launch-assets', {
        'id': _themeId,
      });

    await runResources();

    final said = verify(() => logger.err(captureAny())).captured.join('\n');
    expect(said, contains('launcher icons'));
    expect(said, contains('stock WebTrit icons'));
  });

  test('the settings are asked for before the images', () async {
    // Guarding the image steps is what keeps a refusal from being fatal; asking
    // for the settings first is what keeps a refusal from mattering at all.
    // Pinned separately, because a reordering would not fail the checks above.
    writePubspec('''
name: webtrit_phone
app_version: 1.16.5+3
''');
    backend.serveTheConfiguration();

    await runResources();

    final asked = backend.requests.map((request) => request.path).toList();
    final featureAccess = asked.indexWhere((path) => path.contains('/feature-access/'));
    final images = asked.indexWhere(
      (path) => path.contains('/splash-asset') || path.contains('/launch-assets'),
    );

    expect(featureAccess, isNot(-1), reason: 'the settings were never asked for');
    expect(images, isNot(-1), reason: 'the images were never asked for');
    expect(featureAccess, lessThan(images));
  });
}
