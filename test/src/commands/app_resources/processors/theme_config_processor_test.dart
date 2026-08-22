import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/app_resources/processors/processors.dart';
import 'package:webtrit_phone_tools/src/configurator_datasource.dart';
import 'package:webtrit_phone_tools/src/utils/http_client.dart';

import '../../../support/fake_configurator_backend.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

/// Stands in for the step that downloads the theme font, which reaches Google
/// Fonts and has nothing to do with what a configuration carries.
class _MockFontAssetProcessor extends Mock implements FontAssetProcessor {}

const _applicationId = 'app-1';
const _themeId = 'theme-1';

/// The smallest PNG the asset migrator can recognise by its first bytes.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  late FakeConfiguratorBackend backend;
  late Logger logger;
  late Directory checkout;
  late ThemeConfigProcessor processor;

  String resolvePath(String relativePath) => p.join(checkout.path, relativePath);

  setUp(() async {
    backend = await FakeConfiguratorBackend.start();
    final baseUrl = '${backend.baseUrl}/v1';

    logger = _MockLogger();
    when(() => logger.info(any())).thenReturn(null);
    when(() => logger.warn(any())).thenReturn(null);
    when(() => logger.err(any())).thenReturn(null);
    when(() => logger.detail(any())).thenReturn(null);
    when(() => logger.success(any())).thenReturn(null);
    when(() => logger.progress(any())).thenReturn(_MockProgress());

    checkout = Directory.systemTemp.createTempSync('theme_config_test_');

    final fontAssetProcessor = _MockFontAssetProcessor();
    when(() => fontAssetProcessor.process(
          lightConfig: any(named: 'lightConfig'),
          darkConfig: any(named: 'darkConfig'),
          resolvePath: any(named: 'resolvePath'),
        )).thenAnswer((_) async {});

    processor = ThemeConfigProcessor(
      httpClient: HttpClient(baseUrl, logger),
      datasource: createConfiguratorDatasource(baseUrl: baseUrl, logPrint: (_) {}),
      logger: logger,
      fontAssetProcessor: fontAssetProcessor,
    );

    backend.serveJson('/v1/applications/$_applicationId/embeds', const []);
  });

  tearDown(() async {
    await backend.stop();
    checkout.deleteSync(recursive: true);
  });

  void serveFeatureAccess(Map<String, dynamic> config) {
    backend.serveJson(
      '/v1/applications/$_applicationId/feature-access/by-theme/$_themeId',
      {
        'applicationId': _applicationId,
        'themeId': _themeId,
        'config': config,
      },
    );
  }

  void serveThemeVariant(String variant) {
    const base = '/v1/applications/$_applicationId/themes/$_themeId';
    backend
      ..serveJson('$base/color-schemes/$variant', {
        'applicationId': _applicationId,
        'themeId': _themeId,
        'variant': variant,
        'config': {'primary': '#FF0000'},
      })
      ..serveJson('$base/page-configs/$variant', {
        'id': '${_themeId}_$variant',
        'applicationId': _applicationId,
        'themeId': _themeId,
        'variant': variant,
        'config': {
          'main': {'label': variant}
        },
      })
      ..serveJson('$base/widget-configs/$variant', {
        'id': '${_themeId}_$variant',
        'applicationId': _applicationId,
        'themeId': _themeId,
        'variant': variant,
        'config': {
          'button': {'label': variant}
        },
        'createdAt': '2026-08-22T00:00:00.000Z',
        'updatedAt': '2026-08-22T00:00:00.000Z',
      });
  }

  Map<String, dynamic> readAppConfig() => jsonDecode(
        File(resolvePath('assets/themes/app.config.json')).readAsStringSync(),
      ) as Map<String, dynamic>;

  test(
      'the fetched configuration reaches app.config.json with its fields '
      'intact', () async {
    serveFeatureAccess({
      'supported': [
        {'type': 'themeMode', 'mode': 'light'},
        {'type': 'videoCall', 'enabled': false},
        {'type': 'loggingConfig', 'logLevel': 'DEBUG', 'checkIntervalSec': 30},
      ],
      'loginConfig': {
        'common': {'signUpEnabled': false},
      },
      'aFieldTheAppDoesNotModelYet': {'kept': true},
    });
    serveThemeVariant('light');

    await processor.process(
      applicationId: _applicationId,
      themeId: _themeId,
      resolvePath: resolvePath,
    );

    final appConfig = readAppConfig();
    expect(appConfig['supported'], [
      {'type': 'themeMode', 'mode': 'light'},
      {'type': 'videoCall', 'enabled': false},
      {'type': 'loggingConfig', 'logLevel': 'DEBUG', 'checkIntervalSec': 30},
    ]);
    expect(appConfig['loginConfig'], {
      'common': {'signUpEnabled': false},
    });
    // Nothing is dropped on the way through, not even a field the app of this
    // era has no model for.
    expect(appConfig['aFieldTheAppDoesNotModelYet'], {'kept': true});
  });

  test('a light-only theme fills both the light and the dark theme files', () async {
    serveFeatureAccess({
      'supported': [
        {'type': 'themeMode', 'mode': 'light'},
      ],
    });
    serveThemeVariant('light');

    await processor.process(
      applicationId: _applicationId,
      themeId: _themeId,
      resolvePath: resolvePath,
    );

    final light = File(
      resolvePath('assets/themes/original.color_scheme.light.config.json'),
    ).readAsStringSync();
    final dark = File(
      resolvePath('assets/themes/original.color_scheme.dark.config.json'),
    ).readAsStringSync();
    expect(jsonDecode(light), {'primary': '#FF0000'});
    expect(jsonDecode(dark), jsonDecode(light));
    expect(
      backend.requestFor('/v1/applications/$_applicationId/themes/$_themeId/color-schemes/dark'),
      isNull,
    );
  });

  test('a theme that follows the system fetches both variants', () async {
    serveFeatureAccess({
      'supported': [
        {'type': 'themeMode', 'mode': 'system'},
      ],
    });
    serveThemeVariant('light');
    serveThemeVariant('dark');

    await processor.process(
      applicationId: _applicationId,
      themeId: _themeId,
      resolvePath: resolvePath,
    );

    expect(
      jsonDecode(File(resolvePath('assets/themes/original.page.light.config.json')).readAsStringSync()),
      {
        'main': {'label': 'light'},
      },
    );
    expect(
      jsonDecode(File(resolvePath('assets/themes/original.page.dark.config.json')).readAsStringSync()),
      {
        'main': {'label': 'dark'},
      },
    );
  });

  test(
      'an image the configuration points at is downloaded and referenced '
      'locally', () async {
    backend.serveBytes('/v1/assets/logo.png', _pngBytes);
    serveFeatureAccess({
      'supported': const <dynamic>[],
      'loginConfig': {
        'logoUrl': '${backend.baseUrl}/v1/assets/logo.png',
      },
    });
    serveThemeVariant('light');

    await processor.process(
      applicationId: _applicationId,
      themeId: _themeId,
      resolvePath: resolvePath,
    );

    final logo = (readAppConfig()['loginConfig'] as Map<String, dynamic>)['logoUrl'] as String;
    expect(logo, startsWith('asset://assets/images/'));
    final onDisk = File(resolvePath(logo.replaceFirst('asset://', '')));
    expect(onDisk.existsSync(), isTrue);
    expect(onDisk.readAsBytesSync(), _pngBytes);
  });

  test('embeds are written beside the application configuration', () async {
    backend.serveJson('/v1/applications/$_applicationId/embeds', [
      {
        'applicationId': _applicationId,
        'uri': 'https://brand.example/help',
        'type': 'web',
      },
    ]);
    serveFeatureAccess({'supported': const <dynamic>[]});
    serveThemeVariant('light');

    await processor.process(
      applicationId: _applicationId,
      themeId: _themeId,
      resolvePath: resolvePath,
    );

    final embeds = jsonDecode(
      File(resolvePath('assets/themes/app.embedded.config.json')).readAsStringSync(),
    ) as List<dynamic>;
    expect(embeds, hasLength(1));
    expect((embeds.single as Map<String, dynamic>)['uri'], 'https://brand.example/help');
  });
}
