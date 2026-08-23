import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/configurator/configurator.dart';
import 'package:webtrit_phone_tools/src/utils/http_client.dart';

import '../support/fake_configurator_backend.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

const _applicationId = 'app-1';
const _themeId = 'theme-1';

/// The addresses the build depends on, and the token it must carry to them.
/// These used to be the configurator's own `data` package; now they are ours,
/// so the paths themselves are the contract worth pinning.
void main() {
  late FakeConfiguratorBackend backend;
  late Logger logger;
  late ConfiguratorClient client;

  setUp(() async {
    backend = await FakeConfiguratorBackend.start();
    logger = _MockLogger();
    when(() => logger.info(any())).thenReturn(null);
    when(() => logger.err(any())).thenReturn(null);
    when(() => logger.detail(any())).thenReturn(null);
    when(() => logger.progress(any())).thenReturn(_MockProgress());

    client = ConfiguratorClient(transport: HttpClient('${backend.baseUrl}/v1', logger));
  });

  tearDown(() => backend.stop());

  test('each read asks the address the backend actually serves', () async {
    backend
      ..serveJson('/v1/applications/$_applicationId', {'id': _applicationId, 'theme': _themeId})
      ..serveJson('/v1/applications/$_applicationId/themes/$_themeId', {'id': _themeId})
      ..serveJson('/v1/applications/$_applicationId/feature-access/by-theme/$_themeId', {
        'config': {'videoCall': true},
      })
      ..serveJson('/v1/applications/$_applicationId/embeds', [
        {'id': 'embed-1'},
      ])
      ..serveJson('/v1/applications/$_applicationId/themes/$_themeId/color-schemes/light', {
        'config': {'primary': '#fff'},
      })
      ..serveJson('/v1/applications/$_applicationId/themes/$_themeId/page-configs/dark', {
        'config': {'login': <String, dynamic>{}},
      })
      ..serveJson('/v1/applications/$_applicationId/themes/$_themeId/widget-configs/light', {
        'config': {'bar': <String, dynamic>{}},
      });

    expect((await client.getApplication(_applicationId)).theme, _themeId);
    expect((await client.getTheme(_applicationId, _themeId)).id, _themeId);
    expect(
      await client.getFeatureAccessConfig(applicationId: _applicationId, themeId: _themeId),
      {'videoCall': true},
    );
    expect(await client.getEmbeds(_applicationId), [
      {'id': 'embed-1'},
    ]);
    expect(
      await client.getColorSchemeConfig(applicationId: _applicationId, themeId: _themeId, variant: 'light'),
      {'primary': '#fff'},
    );
    expect(
      await client.getPageConfig(applicationId: _applicationId, themeId: _themeId, variant: 'dark'),
      {'login': <String, dynamic>{}},
    );
    expect(
      await client.getWidgetConfig(applicationId: _applicationId, themeId: _themeId, variant: 'light'),
      {'bar': <String, dynamic>{}},
    );
  });

  test('the token travels with every read, not only the first', () async {
    backend
      ..serveJson('/v1/applications/$_applicationId', {'id': _applicationId, 'theme': _themeId})
      ..serveJson('/v1/applications/$_applicationId/feature-access/by-theme/$_themeId', {
        'config': <String, dynamic>{},
      });

    final authorized = client.withHeaders({'Authorization': 'Bearer a-build-token'});
    await authorized.getApplication(_applicationId);
    await authorized.getFeatureAccessConfig(applicationId: _applicationId, themeId: _themeId);

    expect(
      backend.requestFor('/v1/applications/$_applicationId')?.header('authorization'),
      'Bearer a-build-token',
    );
    expect(
      backend.requestFor('/v1/applications/$_applicationId/feature-access/by-theme/$_themeId')?.header('authorization'),
      'Bearer a-build-token',
    );
  });

  test('a configuration answer with no config reads as empty, not as a crash', () async {
    // A brand with no widget overrides is a legitimate answer.
    backend.serveJson('/v1/applications/$_applicationId/themes/$_themeId/widget-configs/light', {'id': 'x'});

    expect(
      await client.getWidgetConfig(applicationId: _applicationId, themeId: _themeId, variant: 'light'),
      isEmpty,
    );
  });
}
