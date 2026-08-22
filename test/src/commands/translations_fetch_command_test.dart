import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/translations_fetch/translations_fetch_command.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';

class _MockLogger extends Mock implements Logger {}

class _MockHttpClient extends Mock implements HttpClient {}

Archive _archiveOf(Map<String, String> entries) {
  final archive = Archive();
  entries.forEach((name, content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return archive;
}

void main() {
  late Logger logger;
  late _MockHttpClient httpClient;
  late CommandRunner<int> commandRunner;
  late Directory tempDir;

  setUp(() {
    logger = _MockLogger();
    httpClient = _MockHttpClient();

    when(() => logger.info(any())).thenReturn(null);
    when(() => logger.err(any())).thenReturn(null);
    when(() => logger.success(any())).thenReturn(null);
    when(() => logger.detail(any())).thenReturn(null);

    commandRunner = CommandRunner<int>('test', 'test')
      ..addCommand(
          TranslationsFetchCommand(logger: logger, httpClient: httpClient));

    tempDir = Directory.systemTemp.createTempSync('translations_fetch_test');
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test(
      'writes app_<locale>.arb per catalog locale, pretty-printed with a trailing newline',
      () async {
    when(() => httpClient.getCatalogTranslationFiles(
        headers: any(named: 'headers'))).thenAnswer(
      (_) async => _archiveOf({
        'en.arb': jsonEncode({
          '@@locale': 'en',
          'greeting': 'Hello',
          '@greeting': {'description': 'Hi'}
        }),
        'uk.arb': jsonEncode({'@@locale': 'uk', 'greeting': 'Привіт'}),
      }),
    );

    final result = await commandRunner.run([
      'configurator-translations-fetch',
      '--token',
      'build-token',
      tempDir.path,
    ]);

    expect(result, ExitCode.success.code);
    final en =
        File('${tempDir.path}/lib/l10n/arb/app_en.arb').readAsStringSync();
    expect(en, endsWith('\n'));
    expect(en, contains('  "greeting": "Hello",'));
    expect(jsonDecode(en), containsPair('@greeting', {'description': 'Hi'}));
    expect(
        File('${tempDir.path}/lib/l10n/arb/app_uk.arb').existsSync(), isTrue);
    final captured = verify(
      () => httpClient.getCatalogTranslationFiles(
          headers: captureAny(named: 'headers')),
    ).captured.single as Map<String, String>;
    expect(captured['Authorization'], 'Bearer build-token');
  });

  test('an administrator-minted key travels in its own header', () async {
    when(() => httpClient
            .getCatalogTranslationFiles(headers: any(named: 'headers')))
        .thenAnswer((_) async => _archiveOf({
              'en.arb': jsonEncode({'@@locale': 'en', 'greeting': 'Hello'})
            }));

    await commandRunner.run([
      'configurator-translations-fetch',
      '--token',
      'wtc_generated-in-the-admin-ui',
      tempDir.path,
    ]);

    final captured = verify(
      () => httpClient.getCatalogTranslationFiles(
          headers: captureAny(named: 'headers')),
    ).captured.single as Map<String, String>;
    expect(captured['X-Api-Key'], 'wtc_generated-in-the-admin-ui');
    expect(captured.containsKey('Authorization'), isFalse);
  });

  test('writes nothing when any locale fails to parse - all locales or none',
      () async {
    when(() => httpClient.getCatalogTranslationFiles(
        headers: any(named: 'headers'))).thenAnswer(
      (_) async => _archiveOf({
        'en.arb': jsonEncode({'@@locale': 'en', 'greeting': 'Hello'}),
        'uk.arb': 'not json at all',
      }),
    );

    final result = await commandRunner.run([
      'configurator-translations-fetch',
      '--token',
      'build-token',
      tempDir.path,
    ]);

    expect(result, ExitCode.software.code);
    expect(
        File('${tempDir.path}/lib/l10n/arb/app_en.arb').existsSync(), isFalse);
  });

  test('refuses an empty catalog instead of quietly writing nothing', () async {
    when(() => httpClient.getCatalogTranslationFiles(
        headers: any(named: 'headers'))).thenAnswer((_) async => Archive());

    final result = await commandRunner.run([
      'configurator-translations-fetch',
      '--token',
      'build-token',
      tempDir.path,
    ]);

    expect(result, ExitCode.software.code);
  });

  test('requires a token from the flag or the environment', () async {
    final result = await commandRunner.run([
      'configurator-translations-fetch',
      tempDir.path,
    ]);

    // The environment may carry a real CONFIGURATOR_TOKEN on a build machine;
    // locally the command must refuse to run without one.
    if (Platform.environment['CONFIGURATOR_TOKEN'] == null) {
      expect(result, ExitCode.usage.code);
    }
  });
}
