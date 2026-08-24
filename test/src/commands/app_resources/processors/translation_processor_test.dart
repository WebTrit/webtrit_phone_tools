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

  Archive archiveWithFile(String name, Map<String, dynamic> content) {
    final archive = Archive();
    final bytes = utf8.encode(jsonEncode(content));
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
    return archive;
  }

  test('merges downloaded translations into an existing local ARB file', () async {
    final localArbFile = File(resolvePath('lib/l10n/arb/app_en.arb'))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({
        '@@locale': 'en',
        'foo': 'Foo',
        'newLocalOnlyKey': 'Not uploaded yet',
      }));

    when(() => httpClient.getTranslationFiles('app-id')).thenAnswer(
      (_) async => archiveWithFile('en.arb', {'@@locale': 'en', 'foo': 'Foo Updated'}),
    );

    await processor.process(applicationId: 'app-id', chosen: const ['en'], resolvePath: resolvePath);

    final result = jsonDecode(localArbFile.readAsStringSync()) as Map<String, dynamic>;
    expect(result['foo'], 'Foo Updated');
    expect(result['newLocalOnlyKey'], 'Not uploaded yet');
  });

  test('writes the downloaded content as-is when no local file exists yet', () async {
    when(() => httpClient.getTranslationFiles('app-id')).thenAnswer(
      (_) async => archiveWithFile('en.arb', {'@@locale': 'en', 'foo': 'Foo'}),
    );

    await processor.process(applicationId: 'app-id', chosen: const ['en'], resolvePath: resolvePath);

    final localArbFile = File(resolvePath('lib/l10n/arb/app_en.arb'));
    final result = jsonDecode(localArbFile.readAsStringSync()) as Map<String, dynamic>;
    expect(result, {'@@locale': 'en', 'foo': 'Foo'});
  });

  test('writes every language the service sends when the theme narrows none', () async {
    // An empty list is "whatever there is", not "none" - which is what a brand
    // that never chose its languages means, and what every build did before this
    // was configurable.
    final archive = Archive();
    for (final locale in ['en', 'uk', 'th']) {
      final bytes = utf8.encode(jsonEncode({'@@locale': locale, 'foo': locale}));
      archive.addFile(ArchiveFile('$locale.arb', bytes.length, bytes));
    }
    when(() => httpClient.getTranslationFiles('app-id')).thenAnswer((_) async => archive);

    await processor.process(applicationId: 'app-id', chosen: const [], resolvePath: resolvePath);

    for (final locale in ['en', 'uk', 'th']) {
      expect(File(resolvePath('lib/l10n/arb/app_$locale.arb')).existsSync(), isTrue, reason: locale);
    }
  });

  test('removes a language the brand did not choose', () async {
    // The app's own translations are checked into its repository, so a build
    // that only writes leaves them all in place - and the generator builds the
    // app's language list from whatever is in the folder. Without removing them
    // the brand offers every language the app has ever had.
    File(resolvePath('lib/l10n/arb/app_uk.arb'))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'@@locale': 'uk', 'foo': 'Фу'}));

    when(() => httpClient.getTranslationFiles('app-id')).thenAnswer(
      (_) async => archiveWithFile('en.arb', {'@@locale': 'en', 'foo': 'Foo'}),
    );

    await processor.process(applicationId: 'app-id', chosen: const ['en'], resolvePath: resolvePath);

    expect(File(resolvePath('lib/l10n/arb/app_en.arb')).existsSync(), isTrue);
    expect(File(resolvePath('lib/l10n/arb/app_uk.arb')).existsSync(), isFalse);
  });

  test('keeps every language when the theme narrows none, even ones not sent', () async {
    File(resolvePath('lib/l10n/arb/app_it.arb'))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'@@locale': 'it', 'foo': 'Foo'}));

    when(() => httpClient.getTranslationFiles('app-id')).thenAnswer(
      (_) async => archiveWithFile('en.arb', {'@@locale': 'en', 'foo': 'Foo'}),
    );

    await processor.process(applicationId: 'app-id', chosen: const [], resolvePath: resolvePath);

    expect(File(resolvePath('lib/l10n/arb/app_it.arb')).existsSync(), isTrue);
  });

  test('says so when the service sends nothing for a language the theme enables', () async {
    // Otherwise a brand ships without a language it asked for, and nobody knows
    // until somebody opens the app in it.
    when(() => httpClient.getTranslationFiles('app-id')).thenAnswer(
      (_) async => archiveWithFile('en.arb', {'@@locale': 'en', 'foo': 'Foo'}),
    );

    await processor.process(applicationId: 'app-id', chosen: const ['en', 'pl'], resolvePath: resolvePath);

    verify(() => logger.warn(any(that: contains('pl')))).called(1);
  });

  test('falls back to overwrite and logs a warning when the local ARB file is invalid JSON', () async {
    final localArbFile = File(resolvePath('lib/l10n/arb/app_en.arb'))
      ..createSync(recursive: true)
      ..writeAsStringSync('not valid json');

    when(() => httpClient.getTranslationFiles('app-id')).thenAnswer(
      (_) async => archiveWithFile('en.arb', {'@@locale': 'en', 'foo': 'Foo'}),
    );

    await processor.process(applicationId: 'app-id', chosen: const ['en'], resolvePath: resolvePath);

    final result = jsonDecode(localArbFile.readAsStringSync()) as Map<String, dynamic>;
    expect(result, {'@@locale': 'en', 'foo': 'Foo'});
    verify(() => logger.warn(any(that: contains('invalid JSON')))).called(1);
  });
}
