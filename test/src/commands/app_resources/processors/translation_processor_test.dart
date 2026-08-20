import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/app_resources/processors/processors.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';

class MockLogger extends Mock implements Logger {}

class MockHttpClient extends Mock implements HttpClient {}

void main() {
  late Logger logger;
  late MockHttpClient httpClient;
  late TranslationProcessor processor;
  late Directory tempDir;

  setUp(() {
    logger = MockLogger();
    httpClient = MockHttpClient();
    processor = TranslationProcessor(httpClient: httpClient, logger: logger);
    tempDir = Directory.systemTemp.createTempSync('translation_processor_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  String resolvePath(String relativePath) => p.join(tempDir.path, relativePath);

  File writeLocalArb(String locale, Map<String, dynamic> content) {
    return File(resolvePath('lib/l10n/arb/app_$locale.arb'))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(content));
  }

  Archive archiveWithFiles(Map<String, Map<String, dynamic>> files) {
    final archive = Archive();
    for (final entry in files.entries) {
      final bytes = utf8.encode(jsonEncode(entry.value));
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
    }
    return archive;
  }

  test('merges downloaded translations into an existing local ARB file', () async {
    final localArbFile = writeLocalArb('en', {
      '@@locale': 'en',
      'foo': 'Foo',
      'newLocalOnlyKey': 'Not uploaded yet',
    });

    when(() => httpClient.getTranslationFiles('app-id')).thenAnswer(
      (_) async => archiveWithFiles({
        'en.arb': {'@@locale': 'en', 'foo': 'Foo Updated'},
      }),
    );

    await processor.process(applicationId: 'app-id', resolvePath: resolvePath);

    final result = jsonDecode(localArbFile.readAsStringSync()) as Map<String, dynamic>;
    expect(result['foo'], 'Foo Updated');
    expect(result['newLocalOnlyKey'], 'Not uploaded yet');
  });

  test('skips locales that have no local ARB file when others exist', () async {
    writeLocalArb('en', {'@@locale': 'en', 'foo': 'Foo'});

    when(() => httpClient.getTranslationFiles('app-id')).thenAnswer(
      (_) async => archiveWithFiles({
        'en.arb': {'@@locale': 'en', 'foo': 'Foo Updated'},
        'de.arb': {'@@locale': 'de', 'foo': 'Foo DE'},
      }),
    );

    await processor.process(applicationId: 'app-id', resolvePath: resolvePath);

    expect(File(resolvePath('lib/l10n/arb/app_de.arb')).existsSync(), isFalse);
    final result = jsonDecode(File(resolvePath('lib/l10n/arb/app_en.arb')).readAsStringSync());
    expect((result as Map<String, dynamic>)['foo'], 'Foo Updated');
  });

  test('accepts all downloaded locales and writes content as-is when no local ARB files exist', () async {
    when(() => httpClient.getTranslationFiles('app-id')).thenAnswer(
      (_) async => archiveWithFiles({
        'en.arb': {'@@locale': 'en', 'foo': 'Foo'},
        'uk.arb': {'@@locale': 'uk', 'foo': 'Foo UK'},
      }),
    );

    await processor.process(applicationId: 'app-id', resolvePath: resolvePath);

    final en = jsonDecode(File(resolvePath('lib/l10n/arb/app_en.arb')).readAsStringSync());
    final uk = jsonDecode(File(resolvePath('lib/l10n/arb/app_uk.arb')).readAsStringSync());
    expect(en, {'@@locale': 'en', 'foo': 'Foo'});
    expect(uk, {'@@locale': 'uk', 'foo': 'Foo UK'});
    verify(() => logger.warn(any(that: contains('accepting all downloaded locales')))).called(1);
  });

  test('matches locales case-insensitively with underscore and hyphen treated as equivalent', () async {
    writeLocalArb('pt_BR', {'@@locale': 'pt_BR', 'foo': 'Foo'});

    when(() => httpClient.getTranslationFiles('app-id')).thenAnswer(
      (_) async => archiveWithFiles({
        'pt-BR.arb': {'@@locale': 'pt_BR', 'foo': 'Foo BR'},
      }),
    );

    await processor.process(applicationId: 'app-id', resolvePath: resolvePath);

    final result = jsonDecode(File(resolvePath('lib/l10n/arb/app_pt-BR.arb')).readAsStringSync());
    expect((result as Map<String, dynamic>)['foo'], 'Foo BR');
  });

  test('falls back to overwrite and logs a warning when the local ARB file is invalid JSON', () async {
    final localArbFile = File(resolvePath('lib/l10n/arb/app_en.arb'))
      ..createSync(recursive: true)
      ..writeAsStringSync('not valid json');

    when(() => httpClient.getTranslationFiles('app-id')).thenAnswer(
      (_) async => archiveWithFiles({
        'en.arb': {'@@locale': 'en', 'foo': 'Foo'},
      }),
    );

    await processor.process(applicationId: 'app-id', resolvePath: resolvePath);

    final result = jsonDecode(localArbFile.readAsStringSync()) as Map<String, dynamic>;
    expect(result, {'@@locale': 'en', 'foo': 'Foo'});
    verify(() => logger.warn(any(that: contains('invalid JSON')))).called(1);
  });
}
