import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/configurator/configurator.dart';
import 'package:webtrit_phone_tools/src/utils/http_client.dart';

import '../support/fake_configurator_backend.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

List<int> _zipOf(Map<String, String> entries) {
  final archive = Archive();
  entries.forEach((name, content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return ZipEncoder().encode(archive);
}

void main() {
  late FakeConfiguratorBackend backend;
  late Logger logger;
  late HttpClient httpClient;
  late String baseUrl;

  setUp(() async {
    backend = await FakeConfiguratorBackend.start();
    // The address a run is configured with carries the version segment, so the
    // stand-in backend gets one too.
    baseUrl = '${backend.baseUrl}/v1';

    logger = _MockLogger();
    when(() => logger.progress(any())).thenReturn(_MockProgress());
    when(() => logger.err(any())).thenReturn(null);
    when(() => logger.detail(any())).thenReturn(null);

    httpClient = HttpClient(baseUrl, logger);
  });

  tearDown(() => backend.stop());

  test('an application is asked for under the configured address', () async {
    backend.serveJson('/v1/applications/app-1', {
      'id': 'app-1',
      'name': 'Brand One',
      'theme': 'theme-1',
    });

    final application = await ConfiguratorClient(transport: httpClient).getApplication('app-1');

    expect(backend.requestFor('/v1/applications/app-1'), isNotNull);
    expect(application.id, 'app-1');
    expect(application.name, 'Brand One');
    expect(application.theme, 'theme-1');
  });

  test('translations are asked for under the configured address', () async {
    backend.serveBytes(
      '/v1/translations/compose-arb/app-1',
      _zipOf({
        'en.arb': jsonEncode({'@@locale': 'en'})
      }),
    );

    final archive = await httpClient.getTranslationFiles('app-1');

    expect(backend.requestFor('/v1/translations/compose-arb/app-1'), isNotNull);
    expect(archive.files.map((file) => file.name), contains('en.arb'));
  });

  test('the whole catalog is asked for under the configured address', () async {
    backend.serveBytes(
      '/v1/translations/catalog/arb',
      _zipOf({
        'uk.arb': jsonEncode({'@@locale': 'uk'})
      }),
    );

    final archive = await httpClient.getCatalogTranslationFiles(
      headers: const {'Authorization': 'Bearer build-token'},
    );

    final request = backend.requestFor('/v1/translations/catalog/arb');
    expect(request, isNotNull);
    expect(request!.header('authorization'), 'Bearer build-token');
    expect(archive.files.map((file) => file.name), contains('uk.arb'));
  });

  test('a deployment reached under a different address is honoured', () async {
    final other = await FakeConfiguratorBackend.start();
    addTearDown(other.stop);
    other.serveJson('/applications/app-1', {'id': 'app-1'});

    final application =
        await ConfiguratorClient(transport: HttpClient(other.baseUrl, logger)).getApplication('app-1');

    expect(application.id, 'app-1');
    expect(other.requestFor('/applications/app-1'), isNotNull);
    expect(backend.requests, isEmpty);
  });
}
