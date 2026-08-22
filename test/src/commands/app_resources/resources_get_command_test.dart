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
}
