import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:webtrit_phone_tools/src/utils/keystore_readme_updater.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  late Logger logger;
  late KeystoreReadmeUpdater readmeUpdater;

  setUp(() {
    logger = MockLogger();
    readmeUpdater = KeystoreReadmeUpdater(logger);
  });

  group('KeystoreReadmeUpdater', () {
    test('should log "README.md not found." if README.md does not exist', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      const applicationName = 'Test App';
      const applicationId = 'testAppId';

      final readmeFilePath = path.join(tempDir.path, 'README.md');
      expect(File(readmeFilePath).existsSync(), isFalse);

      await readmeUpdater.addApplicationRecord(tempDir.path, applicationName, applicationId);

      verify(() => logger.info('README.md not found.')).called(1);

      tempDir.deleteSync(recursive: true);
    });

    test('should update README.md with new application entry if it exists and has the correct section', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      const applicationName = 'Test App';
      const applicationId = 'testAppId';

      final readmeFilePath = path.join(tempDir.path, 'README.md');
      const initialContent = '## Keystore folders\n\n---\n';
      File(readmeFilePath).writeAsStringSync(initialContent);

      await readmeUpdater.addApplicationRecord(tempDir.path, applicationName, applicationId);

      final readmeContent = File(readmeFilePath).readAsStringSync();
      expect(readmeContent.contains('- [$applicationName](./$applicationId)\n'), isTrue);

      verify(() => logger.info('Updating README.md with new application entry.')).called(1);

      tempDir.deleteSync(recursive: true);
    });

    test('should throw exception if "## Keystore folders" section is missing', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      const applicationName = 'Test App';
      const applicationId = 'testAppId';

      final readmeFilePath = path.join(tempDir.path, 'README.md');
      File(readmeFilePath).writeAsStringSync('Invalid Content');

      expect(
        () async => readmeUpdater.addApplicationRecord(tempDir.path, applicationName, applicationId),
        throwsException,
      );

      verify(() => logger.err('README.md is missing the "## Keystore folders" section.')).called(1);

      tempDir.deleteSync(recursive: true);
    });
  });
}
