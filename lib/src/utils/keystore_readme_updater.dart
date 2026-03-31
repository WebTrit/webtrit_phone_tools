import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

class KeystoreReadmeUpdater {
  KeystoreReadmeUpdater(this._logger);

  final Logger _logger;

  static const _readmeFileName = 'README.md';
  static const _keystoreFoldersSectionStart = '# Keystore accounts\n';
  static const _separator = '\n---';

  Future<void> addApplicationRecord(
    String workingDirectoryPath,
    String applicationName,
    String applicationId,
  ) async {
    final readmeFilePath = path.join(workingDirectoryPath, _readmeFileName);
    final newKeystoreEntry = '- [$applicationName](./$applicationId)\n';

    if (File(readmeFilePath).existsSync()) {
      _logger.info('Updating README.md with new application entry.');
      final readmeContent = File(readmeFilePath).readAsStringSync();

      if (readmeContent.contains(_keystoreFoldersSectionStart)) {
        final updatedReadmeContent = _insertKeystoreEntry(readmeContent, newKeystoreEntry);
        File(readmeFilePath).writeAsStringSync(updatedReadmeContent, mode: FileMode.writeOnly, flush: true);
      } else {
        _logger.err('README.md is missing the "## Keystore folders" section.');
        throw Exception('README.md is missing the "## Keystore folders" section.');
      }
    } else {
      _logger.info('README.md not found.');
    }
  }

  String _insertKeystoreEntry(String readmeContent, String newKeystoreEntry) {
    final keystoreFoldersSectionIndex = readmeContent.indexOf(_keystoreFoldersSectionStart);
    final separatorIndex = readmeContent.indexOf(_separator, keystoreFoldersSectionIndex);

    final keystoreFoldersEnd = separatorIndex != -1 ? separatorIndex : readmeContent.length;

    final keystoreSection = readmeContent.substring(keystoreFoldersSectionIndex, keystoreFoldersEnd).trim();
    final newKeystoreSection = '$keystoreSection\n$newKeystoreEntry';

    return readmeContent.replaceRange(
      keystoreFoldersSectionIndex,
      keystoreFoldersEnd,
      newKeystoreSection,
    );
  }
}
