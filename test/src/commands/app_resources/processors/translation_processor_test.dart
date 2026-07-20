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

  void writeLocalizelyConfig() {
    File(resolvePath('localizely.yml')).writeAsStringSync('''
config_version: 1.0
project_id: test-project
file_type: flutter_arb
branch: main
download:
  files:
    - file: lib/l10n/arb/app_en.arb
      locale_code: en
  params:
    export_empty_as: main
''');
  }

  Archive archiveWithFile(String name, Map<String, dynamic> content) {
    final archive = Archive();
    final bytes = utf8.encode(jsonEncode(content));
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
    return archive;
  }

  test('merges downloaded translations into an existing local ARB file', () async {
    writeLocalizelyConfig();
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

    await processor.process(applicationId: 'app-id', resolvePath: resolvePath);

    final result = jsonDecode(localArbFile.readAsStringSync()) as Map<String, dynamic>;
    expect(result['foo'], 'Foo Updated');
    expect(result['newLocalOnlyKey'], 'Not uploaded yet');
  });

  test('writes the downloaded content as-is when no local file exists yet', () async {
    writeLocalizelyConfig();

    when(() => httpClient.getTranslationFiles('app-id')).thenAnswer(
      (_) async => archiveWithFile('en.arb', {'@@locale': 'en', 'foo': 'Foo'}),
    );

    await processor.process(applicationId: 'app-id', resolvePath: resolvePath);

    final localArbFile = File(resolvePath('lib/l10n/arb/app_en.arb'));
    final result = jsonDecode(localArbFile.readAsStringSync()) as Map<String, dynamic>;
    expect(result, {'@@locale': 'en', 'foo': 'Foo'});
  });

  test('falls back to overwrite and logs a warning when the local ARB file is invalid JSON', () async {
    writeLocalizelyConfig();
    final localArbFile = File(resolvePath('lib/l10n/arb/app_en.arb'))
      ..createSync(recursive: true)
      ..writeAsStringSync('not valid json');

    when(() => httpClient.getTranslationFiles('app-id')).thenAnswer(
      (_) async => archiveWithFile('en.arb', {'@@locale': 'en', 'foo': 'Foo'}),
    );

    await processor.process(applicationId: 'app-id', resolvePath: resolvePath);

    final result = jsonDecode(localArbFile.readAsStringSync()) as Map<String, dynamic>;
    expect(result, {'@@locale': 'en', 'foo': 'Foo'});
    verify(() => logger.warn(any(that: contains('invalid JSON')))).called(1);
  });
}
