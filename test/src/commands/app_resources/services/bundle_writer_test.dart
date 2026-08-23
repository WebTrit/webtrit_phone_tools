import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/app_resources/models/models.dart';
import 'package:webtrit_phone_tools/src/commands/app_resources/services/services.dart';
import 'package:webtrit_phone_tools/src/utils/http_client.dart';

import '../../../support/fake_configurator_backend.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

/// The smallest PNG that is recognisable by its first bytes.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Putting a bundle on disk.
///
/// The service decides what a brand is; this only writes it down. So what these
/// hold is the writing: that a document arrives under the path it was given
/// with its fields untouched, that a picture lands where the document already
/// points, and that a picture which cannot be fetched costs the brand its
/// picture and not its settings.
void main() {
  late FakeConfiguratorBackend backend;
  late Logger logger;
  late Directory checkout;
  late BundleWriter writer;

  String resolvePath(String relative) => p.join(checkout.path, relative);

  setUp(() async {
    backend = await FakeConfiguratorBackend.start();
    logger = _MockLogger();
    when(() => logger.progress(any())).thenReturn(_MockProgress());
    checkout = await Directory.systemTemp.createTemp('bundle-writer-test');
    writer = BundleWriter(httpClient: HttpClient('${backend.baseUrl}/v1', logger), logger: logger);
  });

  tearDown(() async {
    await backend.stop();
    await checkout.delete(recursive: true);
  });

  Map<String, dynamic> written(String relative) =>
      jsonDecode(File(resolvePath(relative)).readAsStringSync()) as Map<String, dynamic>;

  test('a document arrives under the path it was given, with its fields intact', () async {
    await writer.writeFiles({
      'assets/themes/app.config.json': {
        'supported': [
          {'type': 'themeMode', 'mode': 'light'},
        ],
        'main': {'cacheSelectedTab': true},
      },
    }, resolvePath);

    final config = written('assets/themes/app.config.json');
    expect((config['supported'] as List).single, {'type': 'themeMode', 'mode': 'light'});
    expect(config['main'], {'cacheSelectedTab': true});
  });

  test('every file in the bundle is written, not only the first', () async {
    await writer.writeFiles({
      'assets/themes/original.page.light.config.json': {'about': <String, dynamic>{}},
      'assets/themes/original.page.dark.config.json': {'about': <String, dynamic>{}},
      'assets/themes/app.embedded.config.json': <dynamic>[],
    }, resolvePath);

    expect(File(resolvePath('assets/themes/original.page.light.config.json')).existsSync(), isTrue);
    expect(File(resolvePath('assets/themes/original.page.dark.config.json')).existsSync(), isTrue);
    expect(File(resolvePath('assets/themes/app.embedded.config.json')).existsSync(), isTrue);
  });

  test('a picture lands where the document already points at it', () async {
    backend.serveBytes('/v1/files/logo.png', _pngBytes);

    await writer.downloadAssets([
      BundleAsset(id: 'logo', path: 'assets/images/logo_abc123.png', url: '${backend.baseUrl}/v1/files/logo.png'),
    ], resolvePath);

    expect(File(resolvePath('assets/images/logo_abc123.png')).readAsBytesSync(), _pngBytes);
  });

  test('a picture that cannot be fetched costs the picture, not the run', () async {
    backend.serveBytes('/v1/files/present.png', _pngBytes);

    await writer.downloadAssets([
      BundleAsset(id: 'missing', path: 'assets/images/missing.png', url: '${backend.baseUrl}/v1/files/absent.png'),
      BundleAsset(id: 'present', path: 'assets/images/present.png', url: '${backend.baseUrl}/v1/files/present.png'),
    ], resolvePath);

    expect(File(resolvePath('assets/images/missing.png')).existsSync(), isFalse);
    expect(File(resolvePath('assets/images/present.png')).existsSync(), isTrue);
  });

  test('the splash and the icons go to the files the bundle named for them', () async {
    backend.serveBytes('/v1/files/splash.png', _pngBytes);

    await writer.downloadBrandImages(
      BrandImageSet(
        backgroundColorHex: '#FFFFFF',
        files: [
          BrandImageFile(
            path: 'tool/assets/native_splash/image.png',
            url: '${backend.baseUrl}/v1/files/splash.png',
          ),
        ],
      ),
      'splash screen',
      resolvePath,
    );

    expect(File(resolvePath('tool/assets/native_splash/image.png')).existsSync(), isTrue);
  });

  test('a brand with no images of its own is said out loud, not treated as an error', () async {
    await writer.downloadBrandImages(const BrandImageSet(), 'splash screen', resolvePath);

    verify(() => logger.warn(any(that: contains('stock WebTrit')))).called(1);
  });
}
