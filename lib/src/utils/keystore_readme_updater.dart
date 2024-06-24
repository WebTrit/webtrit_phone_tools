import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:simple_mustache/simple_mustache.dart';

import 'package:webtrit_phone_tools/src/extension/extension.dart';
import 'package:webtrit_phone_tools/src/gen/assets.dart';

class KeystoreReadmeUpdater {
  KeystoreReadmeUpdater(this._logger);

  final Logger _logger;

  static const _readmeFileName = 'README.md';
  static const _keystoreFoldersSectionStart = '## Keystore folders\n';

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
      _logger.info('Creating README.md and adding application entry.');

      final dartDefineMapValues = {
        'LIST_OF_APPLICATIONS': newKeystoreEntry,
      };
      final dartDefineTemplate = Mustache(map: dartDefineMapValues);
      final dartDefine = dartDefineTemplate.convert(StringifyAssets.readmeTemplate).toMap();

      File(readmeFilePath).writeAsStringSync(dartDefine.toJson());
    }
  }

  String _insertKeystoreEntry(String readmeContent, String newKeystoreEntry) {
    final keystoreFoldersSectionIndex = readmeContent.indexOf(_keystoreFoldersSectionStart);
    final keystoreFoldersSectionEndIndex =
        readmeContent.indexOf('##', keystoreFoldersSectionIndex + _keystoreFoldersSectionStart.length);

    final keystoreFoldersSectionEnd =
        keystoreFoldersSectionEndIndex != -1 ? keystoreFoldersSectionEndIndex : readmeContent.length;

    return readmeContent.replaceRange(
      keystoreFoldersSectionIndex,
      keystoreFoldersSectionEnd,
      '${readmeContent.substring(keystoreFoldersSectionIndex, keystoreFoldersSectionEnd).trim()}\n$newKeystoreEntry\n',
    );
  }
}
