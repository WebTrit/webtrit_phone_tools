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
      ..addCommand(TranslationsFetchCommand(logger: logger, httpClient: httpClient));

    tempDir = Directory.systemTemp.createTempSync('translations_fetch_test');
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('writes app_<locale>.arb per catalog locale, pretty-printed with a trailing newline', () async {
    when(() => httpClient.getCatalogTranslationFiles(headers: any(named: 'headers'))).thenAnswer(
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
    final en = File('${tempDir.path}/lib/l10n/arb/app_en.arb').readAsStringSync();
    expect(en, endsWith('\n'));
    expect(en, contains('  "greeting": "Hello",'));
    expect(jsonDecode(en), containsPair('@greeting', {'description': 'Hi'}));
    expect(File('${tempDir.path}/lib/l10n/arb/app_uk.arb').existsSync(), isTrue);
    final captured = verify(
      () => httpClient.getCatalogTranslationFiles(headers: captureAny(named: 'headers')),
    ).captured.single as Map<String, String>;
    expect(captured['Authorization'], 'Bearer build-token');
  });

  test('an administrator-minted key travels in its own header', () async {
    when(() => httpClient.getCatalogTranslationFiles(headers: any(named: 'headers')))
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
      () => httpClient.getCatalogTranslationFiles(headers: captureAny(named: 'headers')),
    ).captured.single as Map<String, String>;
    expect(captured['X-Api-Key'], 'wtc_generated-in-the-admin-ui');
    expect(captured.containsKey('Authorization'), isFalse);
  });

  test('writes nothing when any locale fails to parse - all locales or none', () async {
    when(() => httpClient.getCatalogTranslationFiles(headers: any(named: 'headers'))).thenAnswer(
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
    expect(File('${tempDir.path}/lib/l10n/arb/app_en.arb').existsSync(), isFalse);
  });

  group('refuses an export that would lose what the checkout has', () {
    late Directory arbDir;

    setUp(() {
      arbDir = Directory('${tempDir.path}/lib/l10n/arb')..createSync(recursive: true);
    });

    void writeCheckout(String locale, Map<String, dynamic> arb) {
      File('${arbDir.path}/app_$locale.arb').writeAsStringSync(jsonEncode(arb));
    }

    test('a catalog behind the checkout is refused, and the lost keys are named', () async {
      // The catalog was synced from an older ref, so it has never seen
      // `farewell`. Overwriting would delete it from every locale at once, and
      // the app calls it.
      writeCheckout('en', {'@@locale': 'en', 'greeting': 'Hello', 'farewell': 'Bye'});
      when(() => httpClient.getCatalogTranslationFiles(headers: any(named: 'headers'))).thenAnswer(
        (_) async => _archiveOf({
          'en.arb': jsonEncode({'@@locale': 'en', 'greeting': 'Hello'}),
        }),
      );

      final result = await commandRunner.run([
        'configurator-translations-fetch',
        '--token',
        'build-token',
        tempDir.path,
      ]);

      expect(result, ExitCode.software.code);
      final complaint = verify(() => logger.err(captureAny())).captured.single as String;
      expect(complaint, contains('behind this checkout'));
      expect(complaint, contains('farewell'));
      // The whole point: the file it would have destroyed is untouched.
      expect(
        jsonDecode(File('${arbDir.path}/app_en.arb').readAsStringSync()),
        containsPair('farewell', 'Bye'),
      );
    });

    test('an export missing a locale the checkout has is refused', () async {
      writeCheckout('en', {'@@locale': 'en', 'greeting': 'Hello'});
      writeCheckout('uk', {'@@locale': 'uk', 'greeting': 'Привіт'});
      when(() => httpClient.getCatalogTranslationFiles(headers: any(named: 'headers'))).thenAnswer(
        (_) async => _archiveOf({
          'en.arb': jsonEncode({'@@locale': 'en', 'greeting': 'Hello'}),
        }),
      );

      final result = await commandRunner.run([
        'configurator-translations-fetch',
        '--token',
        'build-token',
        tempDir.path,
      ]);

      expect(result, ExitCode.software.code);
      expect(verify(() => logger.err(captureAny())).captured.single as String, contains('no uk'));
      expect(File('${arbDir.path}/app_uk.arb').existsSync(), isTrue);
    });

    test('metadata the catalog drops does not count as a loss', () async {
      // `@greeting` is metadata; the catalog carries one copy and the source
      // locale owns it. Losing it from a translated file is not losing a string.
      writeCheckout('uk', {'@@locale': 'uk', 'greeting': 'Привіт', '@greeting': <String, dynamic>{}});
      when(() => httpClient.getCatalogTranslationFiles(headers: any(named: 'headers'))).thenAnswer(
        (_) async => _archiveOf({
          'uk.arb': jsonEncode({'@@locale': 'uk', 'greeting': 'Вітаю'}),
        }),
      );

      final result = await commandRunner.run([
        'configurator-translations-fetch',
        '--token',
        'build-token',
        tempDir.path,
      ]);

      expect(result, ExitCode.success.code);
      expect(jsonDecode(File('${arbDir.path}/app_uk.arb').readAsStringSync()), containsPair('greeting', 'Вітаю'));
    });
  });

  test('leaves a file alone when the catalog says the same thing in another shape', () async {
    final arbDir = Directory('${tempDir.path}/lib/l10n/arb')..createSync(recursive: true);
    // The checkout's own shape: compact metadata, keys in template order.
    const asWritten = '{"@@locale": "en", "greeting": "Hello", "@greeting": {"description": "Hi"}}';
    final file = File('${arbDir.path}/app_en.arb')..writeAsStringSync(asWritten);

    when(() => httpClient.getCatalogTranslationFiles(headers: any(named: 'headers'))).thenAnswer(
      (_) async => _archiveOf({
        // Same meaning, catalog ordering.
        'en.arb': jsonEncode({
          '@@locale': 'en',
          '@greeting': {'description': 'Hi'},
          'greeting': 'Hello',
        }),
      }),
    );

    final result = await commandRunner.run([
      'configurator-translations-fetch',
      '--token',
      'build-token',
      tempDir.path,
    ]);

    expect(result, ExitCode.success.code);
    // Byte-for-byte untouched: a pull that changes nothing leaves no diff.
    expect(file.readAsStringSync(), asWritten);
  });

  test('nested or foreign archive entries are skipped, honest ones written', () async {
    when(() => httpClient.getCatalogTranslationFiles(headers: any(named: 'headers'))).thenAnswer(
      (_) async => _archiveOf({
        'en.arb': jsonEncode({'@@locale': 'en', 'greeting': 'Hello'}),
        '../escape.arb': jsonEncode({'@@locale': 'xx'}),
        'notes/readme.txt': 'not a language file',
      }),
    );

    final result = await commandRunner.run([
      'configurator-translations-fetch',
      '--token',
      'build-token',
      tempDir.path,
    ]);

    expect(result, ExitCode.success.code);
    expect(File('${tempDir.path}/lib/l10n/arb/app_en.arb').existsSync(), isTrue);
    // Nothing escaped the output directory and nothing foreign was written.
    expect(File('${tempDir.path}/escape.arb').existsSync(), isFalse);
    expect(File('${tempDir.path}/lib/escape.arb').existsSync(), isFalse);
    expect(
      Directory('${tempDir.path}/lib/l10n/arb').listSync().map((entry) => entry.path.split('/').last).toList(),
      ['app_en.arb'],
    );
  });

  test('refuses an empty catalog instead of quietly writing nothing', () async {
    when(() => httpClient.getCatalogTranslationFiles(headers: any(named: 'headers')))
        .thenAnswer((_) async => Archive());

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
