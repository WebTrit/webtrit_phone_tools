import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/models/keystore_metadata.dart';

const _keytoolLogFileName = 'keytool.log';
const _keystoreMetadataFileName = 'upload-keystore-metadata.json';

class KeystoreFileProcessor {
  const KeystoreFileProcessor({required this.logger});

  final Logger logger;

  void createWorkingDirectory({
    required String workingDirectoryPath,
    required bool createParentDirectories,
  }) {
    logger.info('Creating working directory: $workingDirectoryPath');
    Directory(workingDirectoryPath).createSync(recursive: createParentDirectories);
  }

  void writeKeytoolLog({
    required String workingDirectoryPath,
    required ProcessResult processResult,
  }) {
    logger.info('Writing keytool execution log to: $_keytoolLogFileName');
    final keytoolLogPath = path.join(workingDirectoryPath, _keytoolLogFileName);
    File(keytoolLogPath).writeAsStringSync(processResult.stdout.toString(), flush: true);
    File(keytoolLogPath).writeAsStringSync(
      processResult.stderr.toString(),
      mode: FileMode.append,
      flush: true,
    );
  }

  void writeMetadata({
    required String workingDirectoryPath,
    required KeystoreMetadata metadata,
  }) {
    logger.info('Writing conventional keystore metadata to: $_keystoreMetadataFileName');
    final metadataPath = path.join(workingDirectoryPath, _keystoreMetadataFileName);
    File(metadataPath).writeAsStringSync(metadata.toJsonString(), flush: true);
  }
}
